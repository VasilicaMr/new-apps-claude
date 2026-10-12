import SwiftUI

struct SettingsView: View {
    let assistant: AIAssistant
    let hosts: HostsViewModel

    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferenceKeys.fontSize) private var fontSize = 14.0
    @AppStorage(PreferenceKeys.autoSuggest) private var autoSuggest = true
    @AppStorage(PreferenceKeys.autoTitle) private var autoTitle = true
    @AppStorage(PreferenceKeys.haptics) private var haptics = true
    @AppStorage(PreferenceKeys.hasOnboarded) private var hasOnboarded = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Terminal") {
                    VStack(alignment: .leading) {
                        Text("Font size: \(Int(fontSize))pt")
                        Slider(value: $fontSize, in: 11...20, step: 1)
                        Text("❯ claude is ready").font(Theme.mono(fontSize)).foregroundStyle(Theme.accent)
                    }
                    Toggle("Haptics", isOn: $haptics)
                }

                Section {
                    switch assistant.availability {
                    case .available:
                        Label("Available on this device", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                    case .unavailable(let reason):
                        Label(reason, systemImage: "xmark.circle").foregroundStyle(Theme.dim)
                    }
                    Toggle("Suggest follow-ups after each reply", isOn: $autoSuggest)
                    Toggle("Name sessions automatically", isOn: $autoTitle)
                } header: {
                    Label("Apple Intelligence", systemImage: "apple.intelligence")
                } footer: {
                    Text("Refine prompts, explain permission requests, summarise sessions and suggest next steps. Everything runs on-device; nothing is sent to Apple or any server.")
                }

                Section("Macs") {
                    ForEach(hosts.savedHosts) { host in
                        Text(host.name)
                            .swipeActions { Button("Forget", role: .destructive) { hosts.remove(host) } }
                    }
                    if hosts.savedHosts.isEmpty { Text("No paired Macs").foregroundStyle(Theme.dim) }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    Button("Show welcome again") {
                        dismiss()
                        hasOnboarded = false
                    }
                    Text("CodeRelay is an independent app and is not affiliated with or endorsed by Anthropic. Claude and Claude Code are trademarks of Anthropic, PBC.")
                        .font(.footnote)
                        .foregroundStyle(Theme.dim)
                }
            }
            .font(Theme.mono(14))
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
