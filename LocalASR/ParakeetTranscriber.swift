import FluidAudio
import Foundation

public actor ParakeetTranscriber {
    public static let modelFolder = "parakeet-tdt-0.6b-v3-coreml"

    private let modelDirectory: URL
    private var modelLoad: Task<AsrModels, Error>?

    public init(modelDirectory: URL) {
        // Library debug traces can contain decoded text. Never mirror them to the console.
        AppLogger.minimumLevel = .fault
        AppLogger.mirrorsToConsole = false
        self.modelDirectory = modelDirectory
    }

    public func prepare() async throws { _ = try await loadedModels() }

    public func transcribe(fileURL: URL, language: String? = nil) async throws -> String {
        try Task.checkCancellation()
        let models = try await loadedModels()
        try Task.checkCancellation()
        // Core ML models are shared. Decoder and inference state belong to this recording.
        let manager = AsrManager(models: models)
        var decoder = TdtDecoderState.make()
        let result = try await manager.transcribe(
            fileURL,
            decoderState: &decoder,
            language: language.flatMap { Language(rawValue: $0) }
        )
        try Task.checkCancellation()
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadedModels() async throws -> AsrModels {
        if let modelLoad {
            return try await modelLoad.value
        }
        let directory = modelDirectory
        let task = Task.detached(priority: .userInitiated) {
            do {
                return try AsrModels.loadLocal(from: directory, version: .v3)
            } catch {
                throw ModelLoadError(directory: directory, cause: error.localizedDescription)
            }
        }
        modelLoad = task
        do {
            return try await task.value
        } catch {
            modelLoad = nil
            throw error
        }
    }

    private struct ModelLoadError: LocalizedError {
        let directory: URL
        let cause: String

        var errorDescription: String? {
            "Could not load the local Parakeet v3 model. Check the model files in \(directory.path). \(cause)"
        }
    }
}
