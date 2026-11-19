import Foundation

enum LocalDictationBuild {
    static var isEnabled: Bool {
#if FREEFLOW_LOCAL
        true
#else
        false
#endif
    }
}

#if FREEFLOW_LOCAL
import LocalASR

struct LocalFileTranscriptionService: FileTranscriptionService {
    private static let transcriber = ParakeetTranscriber(modelDirectory: modelDirectory)
    let language: String?

    static var modelDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("FreeFlow Local/Models", isDirectory: true)
            .appendingPathComponent(ParakeetTranscriber.modelFolder, isDirectory: true)
    }

    func transcribe(fileURL: URL) async throws -> String {
        _ = try await LocalModelInstaller.shared.verifyForInference(LocalModelCatalog.parakeet)
        return try await Self.transcriber.transcribe(fileURL: fileURL, language: language)
    }
}
#endif
