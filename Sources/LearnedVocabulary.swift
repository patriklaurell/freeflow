import Foundation
import Combine

struct VocabularyCorrection: Codable, Identifiable, Equatable {
    var id = UUID()
    var heard: String
    var preferred: String

    var isValid: Bool {
        [heard, preferred].allSatisfy { value in
            !value.isEmpty && value.count <= 80 && value.split(whereSeparator: \.isWhitespace).count <= 3
                && !value.contains(where: { $0.isNewline || $0.asciiValue.map { $0 < 32 } == true })
        } && heard != preferred
    }
}

/// Conservative suggestions only: a single word replaced in an otherwise unchanged sentence.
/// This never modifies dictation or accepts a correction automatically.
enum VocabularyCorrectionDetector {
    static func suggestion(original: String, edited: String) -> VocabularyCorrection? {
        guard original.count <= 4_000, edited.count <= 4_000 else { return nil }
        let before = original.split(whereSeparator: \.isWhitespace).map(String.init)
        let after = edited.split(whereSeparator: \.isWhitespace).map(String.init)
        guard before.count >= 3, before.count == after.count else { return nil }
        let changed = before.indices.filter { before[$0] != after[$0] }
        guard changed.count == 1, let index = changed.first else { return nil }
        let trim = CharacterSet.punctuationCharacters
        let heard = before[index].trimmingCharacters(in: trim)
        let preferred = after[index].trimmingCharacters(in: trim)
        guard heard.count >= 2, preferred.count >= 2,
              heard.lowercased() != preferred.lowercased(),
              heard.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }),
              preferred.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return nil }
        // Require a plausible spelling change, not an unrelated content replacement.
        let lhs = Array(heard.lowercased()), rhs = Array(preferred.lowercased())
        var row = Array(0...rhs.count)
        for (i, letter) in lhs.enumerated() {
            var next = [i + 1]
            for (j, other) in rhs.enumerated() {
                next.append(min(next[j] + 1, row[j + 1] + 1, row[j] + (letter == other ? 0 : 1)))
            }
            row = next
        }
        guard row[rhs.count] <= 2 else { return nil }
        let result = VocabularyCorrection(heard: heard, preferred: preferred)
        return result.isValid ? result : nil
    }
}

@MainActor
final class LearnedVocabularyStore: ObservableObject {
    @Published private(set) var entries: [VocabularyCorrection] = []
    @Published private(set) var suggestions: [VocabularyCorrection] = []
    @Published private(set) var errorMessage: String?
    private let file: URL
    private var canSave = true

    init(directory: URL) {
        file = directory.appendingPathComponent("vocabulary.json")
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                let data = try Data(contentsOf: file)
                guard data.count <= 1_000_000 else { throw CocoaError(.fileReadCorruptFile) }
                let saved = try JSONDecoder().decode([VocabularyCorrection].self, from: data)
                guard saved.count <= 500, saved.allSatisfy(\.isValid), Set(saved.map(\.id)).count == saved.count else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                entries = saved
            } catch {
                canSave = false
                errorMessage = "Could not read saved vocabulary. Your file has been preserved."
            }
        }
    }

    func suggest(_ correction: VocabularyCorrection) {
        guard correction.isValid, suggestions.count < 20,
              !entries.contains(where: { $0.heard == correction.heard && $0.preferred == correction.preferred }),
              !suggestions.contains(where: { $0.heard == correction.heard && $0.preferred == correction.preferred }) else { return }
        suggestions.append(correction)
    }

    @discardableResult
    func save(_ correction: VocabularyCorrection) -> Bool {
        guard canSave else { return false }
        let item = VocabularyCorrection(id: correction.id,
            heard: correction.heard.trimmingCharacters(in: .whitespacesAndNewlines),
            preferred: correction.preferred.trimmingCharacters(in: .whitespacesAndNewlines))
        guard item.isValid else { errorMessage = "Use two different words or short phrases (up to 80 characters each)."; return false }
        var next = entries.filter { $0.id != item.id && $0.heard.caseInsensitiveCompare(item.heard) != .orderedSame }
        guard next.count < 500 else { errorMessage = "Vocabulary is limited to 500 entries."; return false }
        next.append(item)
        guard persist(next) else { return false }
        dismiss(item.id)
        return true
    }

    func remove(_ id: UUID) { _ = persist(entries.filter { $0.id != id }) }
    func dismiss(_ id: UUID) { suggestions.removeAll { $0.id == id } }
    func clearSuggestions() { suggestions.removeAll() }

    private func persist(_ next: [VocabularyCorrection]) -> Bool {
        guard canSave else { return false }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(next).write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            entries = next
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Could not save vocabulary. Please check available disk space and folder access."
            return false
        }
    }
}
