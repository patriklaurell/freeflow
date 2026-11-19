#if FREEFLOW_LOCAL
import SwiftUI

struct LocalVocabularyView: View {
    @ObservedObject private var store = LocalVocabularyController.shared.store
    @AppStorage("local_vocabulary_learning") private var learning = false
    @State private var editing: VocabularyCorrection?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Suggest vocabulary from edits after dictation", isOn: $learning)
                .onChange(of: learning) { enabled in
                    if !enabled { LocalVocabularyController.shared.stop(); store.clearSuggestions() }
                }
            Text("When enabled, watches the inserted text for up to 30 seconds in supported focused fields. Suggestions stay in memory until approved. Approved vocabulary guides optional local cleanup.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
            if !store.suggestions.isEmpty {
                Text("Review suggestions").font(.headline)
                ForEach(store.suggestions) { item in
                    HStack {
                        Text("\(item.heard) → \(item.preferred)")
                        Spacer()
                        Button("Review") { editing = item }
                        Button("Dismiss") { store.dismiss(item.id) }
                    }
                }
            }
            ForEach(store.entries) { item in
                HStack {
                    Text("\(item.heard) → \(item.preferred)")
                    Spacer()
                    Button("Edit") { editing = item }
                    Button("Remove") { store.remove(item.id) }
                }
            }
            Button("Add vocabulary correction") { editing = VocabularyCorrection(heard: "", preferred: "") }
        }
        .sheet(item: $editing) { item in
            VocabularyCorrectionEditor(item: item, store: store)
        }
    }
}

private struct VocabularyCorrectionEditor: View {
    @State var item: VocabularyCorrection
    @ObservedObject var store: LearnedVocabularyStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review vocabulary").font(.headline)
            TextField("Recognized as", text: $item.heard)
            TextField("Preferred spelling", text: $item.preferred)
            Text("Save only the correction you want remembered. It stays on this Mac.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Approve and save") { if store.save(item) { dismiss() } }
                    .disabled(!item.isValid)
            }
        }.padding(24).frame(width: 420)
    }
}
#endif
