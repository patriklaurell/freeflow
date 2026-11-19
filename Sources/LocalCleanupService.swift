import Foundation

protocol TranscriptCleanupService: Sendable {
    func clean(_ transcript: String, vocabulary: [String]) async throws -> String
}

#if FREEFLOW_LOCAL
import LocalCleanup

struct LocalQwenCleanupService: TranscriptCleanupService {
    private static let engine = QwenCleanup(directory: LocalModelInstaller.root
        .appendingPathComponent(LocalModelCatalog.qwen.folder, isDirectory: true))

    func clean(_ transcript: String, vocabulary: [String]) async throws -> String {
        _ = try await LocalModelInstaller.shared.verifyForInference(LocalModelCatalog.qwen)
        return try await Self.engine.clean(transcript, vocabulary: vocabulary)
    }
}
#endif
