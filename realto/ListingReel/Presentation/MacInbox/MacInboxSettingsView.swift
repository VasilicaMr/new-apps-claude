import SwiftUI
import AppKit

/// Content of the app's `Settings { }` scene (⌘,) — the one visible place the
/// Mac Inbox feature flag lives, per the user's choice of an opt-in toggle
/// over a hidden dev flag. Off by default; flipping it is the only thing
/// that makes the Home toolbar's "Inbox" button (and the watcher itself)
/// appear.
struct MacInboxSettingsView: View {
    @Bindable var model: InboxViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Inbox (Beta)", isOn: Binding(
                    get: { model.settings.isEnabled },
                    set: { model.setEnabled($0) }))
                Text("Watch a Finder folder for new footage and turn it into draft listing videos automatically, plus export several at once in the background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.settings.isEnabled {
                Section("Watched folder") {
                    if let folder = model.settings.watchedFolder {
                        LabeledContent("Folder", value: folder.displayPath)
                        Button("Choose a Different Folder…", action: chooseFolder)
                        Button("Stop Watching", role: .destructive) { model.stopWatchingFolder() }
                    } else {
                        Text("No folder chosen yet.")
                            .foregroundStyle(.secondary)
                        Button("Choose Folder…", action: chooseFolder)
                    }
                    if let error = model.folderAccessError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .task { await model.onAppear() }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Choose")
        panel.message = String(localized: "Choose a folder to watch for new property footage.")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            model.chooseFolder(url)
        }
    }
}
