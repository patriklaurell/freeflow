import Foundation

enum LearnedVocabularyTests {
    @MainActor static func run() {
        TestSupport.expect(VocabularyCorrectionDetector.suggestion(original: "Open the Paraquet project.", edited: "Open the Parakeet project.")?.preferred == "Parakeet", "Suggest a single plausible vocabulary correction")
        TestSupport.expect(VocabularyCorrectionDetector.suggestion(original: "Den bla cykeln står utanför.", edited: "Den blå cykeln står utanför.")?.preferred == "blå", "Swedish accent correction remains eligible")
        TestSupport.expect(VocabularyCorrectionDetector.suggestion(original: "I like this bicycle.", edited: "I hate this bicycle.") == nil, "Reject unrelated rewrites")
        TestSupport.expect(VocabularyCorrectionDetector.suggestion(original: "Open the new project.", edited: "Open the new project tomorrow.") == nil, "Do not learn appended typing")
        TestSupport.expect(VocabularyCorrectionDetector.suggestion(original: "Open the blue project.", edited: "Open a green project.") == nil, "Reject multiple changed words")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LearnedVocabularyStore(directory: folder)
        let item = VocabularyCorrection(heard: "Paraquet", preferred: "Parakeet")
        store.suggest(item)
        TestSupport.expect(LearnedVocabularyStore(directory: folder).entries.isEmpty, "Unapproved suggestions never persist")
        TestSupport.expect(store.save(item), "Approval saves vocabulary")
        let reloaded = LearnedVocabularyStore(directory: folder)
        TestSupport.expect(reloaded.entries == [item], "Approved entries survive a new store instance")
        var edited = item; edited.preferred = "Parakeet v3"
        TestSupport.expect(reloaded.save(edited) && reloaded.entries.count == 1, "Editing updates the existing entry")
        reloaded.remove(item.id)
        TestSupport.expect(LearnedVocabularyStore(directory: folder).entries.isEmpty, "Removal persists")
        try! Data("corrupt".utf8).write(to: folder.appendingPathComponent("vocabulary.json"))
        let corrupt = LearnedVocabularyStore(directory: folder)
        TestSupport.expect(!corrupt.save(item) && corrupt.errorMessage != nil, "Do not overwrite corrupt vocabulary")
    }
}
