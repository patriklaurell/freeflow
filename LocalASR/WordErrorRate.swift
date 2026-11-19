import Foundation

/// Word-level Levenshtein distance, normalized for case and punctuation.
/// Accents are retained so Swedish spelling errors remain visible.
public enum WordErrorRate {
    public static func words(_ text: String) -> [String] {
        text.lowercased().precomposedStringWithCanonicalMapping
            .split { !($0.isLetter || $0.isNumber) }.map(String.init)
    }

    public static func errors(reference: String, hypothesis: String) -> Int {
        let expected = words(reference)
        let actual = words(hypothesis)
        var previous = Array(0...actual.count)
        for (i, word) in expected.enumerated() {
            var current = [i + 1]
            for (j, other) in actual.enumerated() {
                current.append(min(current[j] + 1, previous[j + 1] + 1,
                                   previous[j] + (word == other ? 0 : 1)))
            }
            previous = current
        }
        return previous[actual.count]
    }
}
