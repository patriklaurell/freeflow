import Foundation

enum WordErrorRateTests {
    static func run() {
        TestSupport.expect(WordErrorRate.errors(reference: "Den blå cykeln.", hypothesis: "DEN BLA\u{030A} CYKELN!") == 0, "WER normalizes Unicode, punctuation and case")
        TestSupport.expect(WordErrorRate.errors(reference: "Den blå cykeln", hypothesis: "Den bla cykeln") == 1, "WER retains Swedish accents")
        TestSupport.expect(WordErrorRate.errors(reference: "one two three", hypothesis: "one four five three") == 2, "WER counts substitutions and insertions")
        TestSupport.expect(WordErrorRate.errors(reference: "one two", hypothesis: "") == 2, "WER counts deletions")
        TestSupport.expect(WordErrorRate.errors(reference: "", hypothesis: "one two") == 2, "WER handles empty references")
    }
}
