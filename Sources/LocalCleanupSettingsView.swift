#if FREEFLOW_LOCAL
import SwiftUI

struct LocalCleanupSettingsView: View {
    @AppStorage("local_cleanup_enabled") private var enabled = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Clean up dictation on this Mac", isOn: $enabled)
            Text("Uses Qwen 3.5 4B for punctuation and spelling while keeping your language and style. Requires the Qwen model above. Exact-wording shortcuts bypass cleanup. If cleanup fails, FreeFlow inserts the original transcript.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
#endif
