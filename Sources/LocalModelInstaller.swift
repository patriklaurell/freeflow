import Foundation
import CryptoKit

/// Networking is reachable only through explicit provisioning, never through verify().
actor LocalModelInstaller {
    static let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("FreeFlow Local/Models", isDirectory: true)
    static let shared = LocalModelInstaller(root: root)
    typealias Download = @Sendable (URL) async throws -> (URL, URLResponse)
    private let root: URL
    private let download: Download?
    private var installing = false
    private var verifiedRevisions = Set<String>()

    init(root: URL, download: Download? = nil) { self.root = root; self.download = download }

    func verify(_ model: LocalModelDescriptor) throws -> URL {
        verifiedRevisions.remove(model.repository + ":" + model.revision)
        try verify(model, at: directory(model))
        return directory(model)
    }

    func verifyForInference(_ model: LocalModelDescriptor) throws -> URL {
        try validatePaths(model)
        let key = model.repository + ":" + model.revision
        if !verifiedRevisions.contains(key) {
            _ = try verify(model)
            verifiedRevisions.insert(key)
        }
        return directory(model)
    }

    func install(_ model: LocalModelDescriptor, progress: @escaping @Sendable (Int, Int) -> Void) async throws -> URL {
        guard !installing else { throw ModelError(message: "A model download is already running.") }
        verifiedRevisions.remove(model.repository + ":" + model.revision)
        installing = true
        defer { installing = false }
        let destination = directory(model)
        if (try? verify(model, at: destination)) != nil { return destination }
        try validatePaths(model)
        let stage = root.appendingPathComponent(".download-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: stage) }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 7_200
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        for (index, file) in model.files.enumerated() {
            try Task.checkCancellation()
            progress(index, model.files.count)
            let url = URL(string: "https://huggingface.co/\(model.repository)/resolve/\(model.revision)/\(file.path)")!
            let (temporary, response): (URL, URLResponse)
            if let download { (temporary, response) = try await download(url) }
            else { (temporary, response) = try await downloadWithRetry(url, session: session) }
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard let status = (response as? HTTPURLResponse)?.statusCode, [200, 206].contains(status),
                  response.url?.scheme == "https" else { throw ModelError(message: "Model download failed. Please retry.") }
            let output = stage.appendingPathComponent(file.path)
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: temporary, to: output)
            try verifyFile(file, at: output)
            progress(index + 1, model.files.count)
        }
        try Task.checkCancellation()
        try Data(model.revision.utf8).write(to: stage.appendingPathComponent("revision.txt"), options: .atomic)
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: stage)
        } else {
            try FileManager.default.moveItem(at: stage, to: destination)
        }
        return destination
    }

    private func downloadWithRetry(_ url: URL, session: URLSession) async throws -> (URL, URLResponse) {
        var resumeData: Data?
        for attempt in 0..<3 {
            do {
                if let resumeData { return try await session.download(resumeFrom: resumeData) }
                return try await session.download(from: url)
            } catch {
                try Task.checkCancellation()
                guard attempt < 2, let urlError = error as? URLError,
                      [URLError.networkConnectionLost, .timedOut, .cannotConnectToHost,
                       .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet].contains(urlError.code) else { throw error }
                resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                try await Task.sleep(for: .seconds(attempt + 1))
            }
        }
        throw ModelError(message: "Model download failed. Please retry.")
    }

    private func directory(_ model: LocalModelDescriptor) -> URL { root.appendingPathComponent(model.folder, isDirectory: true) }

    private func validatePaths(_ model: LocalModelDescriptor) throws {
        func safe(_ path: String) -> Bool {
            !path.isEmpty && !path.hasPrefix("/") && !path.contains("\\")
                && path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
        }
        guard safe(model.folder), !model.folder.contains("/"), safe(model.repository),
              model.revision.count == 40, model.revision.allSatisfy(\.isHexDigit),
              !model.files.isEmpty, model.files.allSatisfy({ safe($0.path) && $0.size > 0 && $0.sha256.count == 64 }) else {
            throw ModelError(message: "Invalid model manifest.")
        }
    }

    private func verify(_ model: LocalModelDescriptor, at directory: URL) throws {
        try validatePaths(model)
        for file in model.files {
            try Task.checkCancellation()
            let url = directory.appendingPathComponent(file.path)
            // Refuse links outside the model directory, including links in parent components.
            guard url.resolvingSymlinksInPath().path.hasPrefix(directory.resolvingSymlinksInPath().path + "/") else {
                throw ModelError(message: "Model files must be stored inside their model folder.")
            }
            try verifyFile(file, at: url)
        }
    }

    private func verifyFile(_ file: LocalModelFile, at url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.size] as? NSNumber)?.int64Value == file.size else {
            throw ModelError(message: "Model file is missing or incomplete: \(file.path)")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            try Task.checkCancellation()
            hash.update(data: data)
        }
        let actual = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard actual == file.sha256 else { throw ModelError(message: "Model integrity check failed: \(file.path)") }
    }

    struct ModelError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}
