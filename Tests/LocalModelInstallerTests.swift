import Foundation

enum LocalModelInstallerTests {
    static func run() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("test-model")
        try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("weight.bin")
        try! Data("abc".utf8).write(to: file)
        let model = LocalModelDescriptor(name: "Synthetic", folder: "test-model", repository: "test/test",
            revision: String(repeating: "a", count: 40), files: [
                .init(path: "weight.bin", size: 3, sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")])
        let installer = LocalModelInstaller(root: root)
        let valid = try? await installer.verify(model)
        TestSupport.expect(valid != nil, "Accept exact synthetic model checksum")
        try! Data("abd".utf8).write(to: file)
        let corrupt = try? await installer.verify(model)
        TestSupport.expect(corrupt == nil, "Reject same-size corruption")
        let failedInstaller = LocalModelInstaller(root: root, download: { url in
            let temporary = root.appendingPathComponent(UUID().uuidString)
            try Data("bad".utf8).write(to: temporary)
            return (temporary, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let failedInstall = try? await failedInstaller.install(model) { _, _ in }
        TestSupport.expect(failedInstall == nil && (try? String(contentsOf: file, encoding: .utf8)) == "abd", "Failed verification preserves existing model")
        let cancelledInstaller = LocalModelInstaller(root: root, download: { _ in throw CancellationError() })
        let cancelledInstall = try? await cancelledInstaller.install(model) { _, _ in }
        TestSupport.expect(cancelledInstall == nil && (try? String(contentsOf: file, encoding: .utf8)) == "abd", "Cancelled downloads preserve existing model")
        let successfulInstaller = LocalModelInstaller(root: root, download: { url in
            let temporary = root.appendingPathComponent(UUID().uuidString)
            try Data("abc".utf8).write(to: temporary)
            return (temporary, HTTPURLResponse(url: url, statusCode: 206, httpVersion: nil, headerFields: nil)!)
        })
        let installed = try? await successfulInstaller.install(model) { _, _ in }
        TestSupport.expect(installed != nil && (try? String(contentsOf: file, encoding: .utf8)) == "abc", "A resumed download replaces the model only after full size and checksum verification")
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        TestSupport.expect(!leftovers.contains(where: { $0.hasPrefix(".download-") }), "Download staging folders are cleaned up")
        let unsafe = LocalModelDescriptor(name: "Invalid", folder: "../escape", repository: "test/test",
            revision: model.revision, files: model.files)
        let escaped = try? await installer.verify(unsafe)
        TestSupport.expect(escaped == nil, "Reject path traversal in manifests")
        try! FileManager.default.removeItem(at: file)
        let outside = root.appendingPathComponent("outside.bin")
        try! Data("abc".utf8).write(to: outside)
        try! FileManager.default.createSymbolicLink(at: file, withDestinationURL: outside)
        let linked = try? await installer.verify(model)
        TestSupport.expect(linked == nil, "Reject model files linked outside their folder")
    }
}
