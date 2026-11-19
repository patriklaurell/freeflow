import Foundation
import Darwin
import LocalCleanup

@main
struct CleanupSmoke {
    static func main() async throws {
        defer {
            var usage = rusage()
            if getrusage(RUSAGE_SELF, &usage) == 0 { print("peak_resident_bytes=\(usage.ru_maxrss)") }
        }
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--tokenizer-only" {
            let cleanup = QwenCleanup(directory: URL(fileURLWithPath: CommandLine.arguments[2]))
            try await cleanup.validateTokenizer()
            print("English/Swedish tokenizer round trips and local chat template passed. No generation performed.")
            return
        }
        guard CommandLine.arguments.count == 2 else {
            throw NSError(domain: "Usage: CleanupSmoke MODEL_DIRECTORY", code: 1)
        }
        let cleanup = QwenCleanup(directory: URL(fileURLWithPath: CommandLine.arguments[1]))
        let fixtures = [
            ("English", "the blue bicycle is outside", "The blue bicycle is outside."),
            ("Swedish", "den blå cykeln står utanför", "Den blå cykeln står utanför."),
            ("English negation", "I do not want 12 bicycles", "I do not want 12 bicycles."),
            ("Swedish negation", "jag vill inte ha 12 cyklar", "Jag vill inte ha 12 cyklar."),
        ]
        for (language, raw, expected) in fixtures {
            let start = ContinuousClock.now
            let text = try await cleanup.clean(raw, vocabulary: [])
            guard text == expected else { throw NSError(domain: "\(language) cleanup fixture differed", code: 2) }
            print("\(language) cleanup passed in \(start.duration(to: .now))")
        }
    }
}
