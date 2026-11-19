import Foundation
import MLXLLM
import MLXLMCommon
import Tokenizers

public actor QwenCleanup {
    private let directory: URL
    private var modelLoad: Task<ModelContainer, Error>?
    private var busy = false

    public init(directory: URL) { self.directory = directory }

    public func validateTokenizer() async throws {
        let tokenizer = try await LocalTokenizerLoader().load(from: directory)
        for text in ["The blue bicycle is outside.", "Den blå cykeln står utanför."] {
            let tokens = tokenizer.encode(text: text, addSpecialTokens: false)
            guard !tokens.isEmpty, tokenizer.decode(tokenIds: tokens, skipSpecialTokens: true) == text else {
                throw CleanupPolicy.Rejected()
            }
        }
        let prompt = try tokenizer.applyChatTemplate(messages: [["role": "user", "content": "Hello"]],
            tools: nil, additionalContext: ["enable_thinking": false])
        guard !prompt.isEmpty else { throw CleanupPolicy.Rejected() }
    }

    public func clean(_ transcript: String, vocabulary: [String]) async throws -> String {
        guard !busy else { throw CleanupPolicy.Rejected() }
        busy = true
        defer { busy = false }
        try Task.checkCancellation()
        let prompt = try CleanupPolicy.request(transcript: transcript, vocabulary: vocabulary)
        let model = try await loadedModel()
        try Task.checkCancellation()
        // Model weights are shared; every request gets fresh conversation and KV state.
        let session = ChatSession(model, instructions: CleanupPolicy.instructions,
            generateParameters: .init(maxTokens: 1024, temperature: 0),
            additionalContext: ["enable_thinking": false])
        let response = try await session.respond(to: prompt)
        try Task.checkCancellation()
        return try CleanupPolicy.validated(response, original: transcript)
    }

    private func loadedModel() async throws -> ModelContainer {
        if let modelLoad { return try await modelLoad.value }
        let directory = directory
        let task = Task {
            try await LLMModelFactory.shared.loadContainer(from: directory, using: LocalTokenizerLoader())
        }
        modelLoad = task
        do { return try await task.value }
        catch { modelLoad = nil; throw error }
    }
}

/// Only the directory-loading API is used. No Hub lookup or downloader exists in this adapter.
private struct LocalTokenizerLoader: TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let tokenizer = try await AutoTokenizer.from(modelFolder: directory)
        let template = try String(contentsOf: directory.appendingPathComponent("chat_template.jinja"), encoding: .utf8)
        return LocalTokenizer(tokenizer: tokenizer, template: template)
    }
}

private struct LocalTokenizer: MLXLMCommon.Tokenizer {
    let tokenizer: any Tokenizers.Tokenizer
    let template: String
    func encode(text: String, addSpecialTokens: Bool) -> [Int] { tokenizer.encode(text: text, addSpecialTokens: addSpecialTokens) }
    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String { tokenizer.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens) }
    func convertTokenToId(_ token: String) -> Int? { tokenizer.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { tokenizer.convertIdToToken(id) }
    var bosToken: String? { tokenizer.bosToken }
    var eosToken: String? { tokenizer.eosToken }
    var unknownToken: String? { tokenizer.unknownToken }
    func applyChatTemplate(messages: [[String: any Sendable]], tools: [[String: any Sendable]]?,
                           additionalContext: [String: any Sendable]?) throws -> [Int] {
        try tokenizer.applyChatTemplate(messages: messages, chatTemplate: .literal(template),
            addGenerationPrompt: true, truncation: false, maxLength: nil, tools: tools, additionalContext: additionalContext)
    }
}
