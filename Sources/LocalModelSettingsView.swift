#if FREEFLOW_LOCAL
import SwiftUI

@MainActor
private final class LocalModelOperations: ObservableObject {
    static let shared = LocalModelOperations()
    @Published private(set) var statuses: [String: String] = [:]
    @Published private(set) var busy = Set<String>()
    private var operations: [String: Task<Void, Never>] = [:]

    func cancel(_ model: LocalModelDescriptor) { operations[model.folder]?.cancel() }

    func run(_ model: LocalModelDescriptor, download: Bool) {
        guard busy.isEmpty else { return }
        let key = model.folder
        busy.insert(key)
        statuses[key] = download ? "Preparing download…" : "Checking every file…"
        operations[key] = Task { @MainActor in
            do {
                if download {
                    _ = try await LocalModelInstaller.shared.install(model) { completed, count in
                        Task { @MainActor in
                            if self.busy.contains(key) {
                                self.statuses[key] = "Downloading and verifying file \(min(completed + 1, count)) of \(count)…"
                            }
                        }
                    }
                } else {
                    _ = try await LocalModelInstaller.shared.verify(model)
                }
                statuses[key] = "Verified. Ready for offline use."
            } catch is CancellationError {
                statuses[key] = "Cancelled. Existing model preserved."
            } catch {
                statuses[key] = "Not ready: \(error.localizedDescription)"
            }
            busy.remove(key)
            operations[key] = nil
        }
    }
}

struct LocalModelSettingsView: View {
    let model: LocalModelDescriptor
    @ObservedObject private var operations = LocalModelOperations.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.name).font(.headline)
            Text("\(ByteCountFormatter.string(fromByteCount: model.totalBytes, countStyle: .file)) · revision \(model.revision.prefix(8))")
                .font(.caption).foregroundStyle(.secondary)
            Text(operations.statuses[model.folder] ?? "Not checked").font(.caption)
            HStack {
                Button("Verify installed model") { operations.run(model, download: false) }
                    .disabled(!operations.busy.isEmpty)
                Button("Download / repair") { operations.run(model, download: true) }
                    .disabled(!operations.busy.isEmpty)
                if operations.busy.contains(model.folder) {
                    Button("Cancel") { operations.cancel(model) }
                }
            }
        }
    }
}
#endif
