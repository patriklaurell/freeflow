#if FREEFLOW_LOCAL
import AppKit
import ApplicationServices

@MainActor
final class LocalVocabularyController {
    static let shared = LocalVocabularyController()
    let store = LearnedVocabularyStore(directory: FileManager.default.urls(for: .applicationSupportDirectory,
        in: .userDomainMask)[0].appendingPathComponent("FreeFlow Local"))
    private var observation: Task<Void, Never>?

    func stop() { observation?.cancel(); observation = nil }

    func observeInsertion(_ transcript: String, target expectedTarget: AppTextInsertionTarget? = nil) {
        stop()
        guard UserDefaults.standard.bool(forKey: "local_vocabulary_learning"),
              !transcript.isEmpty, transcript.count <= 4_000,
              let app = NSWorkspace.shared.frontmostApplication,
              let initial = AppTextInsertionTarget.capture(from: AXUIElementCreateApplication(app.processIdentifier),
                processIdentifier: app.processIdentifier),
              expectedTarget.map({ CFEqual($0.element, initial.element) }) ?? true else { return }
        observation = Task { [weak self] in
            // Wait for the editor to publish the paste. A mismatch is discarded, never guessed.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self, initial.isFocused,
                  let target = AppTextInsertionTarget.capture(from: AXUIElementCreateApplication(app.processIdentifier),
                    processIdentifier: app.processIdentifier), CFEqual(initial.element, target.element),
                  let value = target.valueAtCapture, value.utf16.count <= 32_000,
                  let selection = target.selectedTextRange, selection.length == 0 else { return }
            let ns = value as NSString
            let length = transcript.utf16.count
            let end = selection.location
            guard end >= length, end <= ns.length,
                  ns.substring(with: NSRange(location: end - length, length: length)) == transcript else { return }
            let prefix = ns.substring(to: end - length)
            let suffix = ns.substring(from: end)
            var lastEdit: String?
            for _ in 0..<60 {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, UserDefaults.standard.bool(forKey: "local_vocabulary_learning"),
                      target.isFocused,
                      let current = AppTextInsertionTarget.capture(from: AXUIElementCreateApplication(app.processIdentifier),
                        processIdentifier: app.processIdentifier), CFEqual(target.element, current.element),
                      let edited = current.valueAtCapture, edited.utf16.count <= 32_000,
                      edited.hasPrefix(prefix), edited.hasSuffix(suffix),
                      edited.utf16.count >= prefix.utf16.count + suffix.utf16.count else { return }
                let content = (edited as NSString).substring(with: NSRange(location: prefix.utf16.count,
                    length: edited.utf16.count - prefix.utf16.count - suffix.utf16.count))
                guard content != transcript else { lastEdit = nil; continue }
                if content == lastEdit, let suggestion = VocabularyCorrectionDetector.suggestion(original: transcript, edited: content) {
                    self.store.suggest(suggestion)
                    return
                }
                lastEdit = content
            }
        }
    }
}
#endif
