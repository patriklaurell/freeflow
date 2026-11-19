import Foundation
import Darwin
import LocalASR

@main
struct ParakeetSmoke {
    static func main() async throws {
        defer {
            var usage = rusage()
            if getrusage(RUSAGE_SELF, &usage) == 0 { print("peak_resident_bytes=\(usage.ru_maxrss)") }
        }
        let arguments = CommandLine.arguments.dropFirst()
        if arguments.count == 2, arguments.first == "--load-only" {
            let start = ContinuousClock.now
            let transcriber = ParakeetTranscriber(modelDirectory: URL(fileURLWithPath: arguments.last!, isDirectory: true))
            try await transcriber.prepare()
            print("Local model load passed in \(start.duration(to: .now)). No speech evaluation performed.")
            return
        }
        guard arguments.count == 5 else {
            throw SmokeFailure(message: "Usage: ParakeetSmoke MODEL_DIR EN_AUDIO EN_REFERENCE SV_AUDIO SV_REFERENCE")
        }

        let inputs = Array(arguments)
        let transcriber = ParakeetTranscriber(modelDirectory: URL(fileURLWithPath: inputs[0], isDirectory: true))
        var failed = false
        for (label, index) in [("English (cold)", 1), ("Swedish (warm)", 3), ("English (warm)", 1)] {
            let clock = ContinuousClock()
            let start = clock.now
            let text = try await transcriber.transcribe(fileURL: URL(fileURLWithPath: inputs[index]))
            let elapsed = start.duration(to: clock.now)
            let count = WordErrorRate.words(inputs[index + 1]).count
            guard count > 0 else { throw SmokeFailure(message: "Reference must contain words.") }
            let errors = WordErrorRate.errors(reference: inputs[index + 1], hypothesis: text)
            let wer = Double(errors) / Double(count)
            print("\(label): seconds=\(elapsed), word_errors=\(errors)/\(count), WER=\(wer)")
            failed = failed || errors > 0
        }
        if failed { throw SmokeFailure(message: "One or more synthetic fixtures differed; see WER above.") }
    }

    private struct SmokeFailure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}
