import SwiftUI
import ServiceManagement

struct HostSettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView().tabItem { Label("General", systemImage: "gearshape") }
            WorkspacesSettingsView().tabItem { Label("Workspaces", systemImage: "folder") }
            DevicesSettingsView().tabItem { Label("Devices", systemImage: "iphone") }
        }
        .frame(width: 520, height: 360)
    }
}

private struct GeneralSettingsView: View {
    @Environment(HostEngine.self) private var engine
    @State private var claudePath = ""
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Claude Code CLI") {
                LabeledContent("Detected") {
                    Text(engine.claude?.executable.path ?? "Not found")
                        .textSelection(.enabled)
                        .foregroundStyle(engine.claude == nil ? .red : .primary)
                }
                TextField("Custom path (optional)", text: $claudePath, prompt: Text("/opt/homebrew/bin/claude"))
                HStack {
                    Button("Apply") { engine.setClaudePathOverride(claudePath) }
                    Button("Detect again") { Task { await engine.refreshClaude() } }
                }
            }
            Section("Startup") {
                Toggle("Launch CodeRelay Host at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .onAppear { claudePath = engine.settings.claudePathOverride ?? "" }
    }
}

private struct WorkspacesSettingsView: View {
    @Environment(HostEngine.self) private var engine

    var body: some View {
        VStack(alignment: .leading) {
            Text("Your phone can only open these folders and their direct sub-folders.")
                .font(.callout)
                .foregroundStyle(.secondary)
            List {
                ForEach(engine.settings.workspaceRoots, id: \.self) { root in
                    HStack {
                        Image(systemName: "folder")
                        Text(root).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button(role: .destructive) { engine.removeWorkspaceRoot(root) } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            Button("Add Folder…", action: addFolder)
        }
        .padding()
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Allow"
        if panel.runModal() == .OK {
            panel.urls.forEach { engine.addWorkspaceRoot($0.path) }
        }
    }
}

private struct DevicesSettingsView: View {
    @Environment(HostEngine.self) private var engine

    var body: some View {
        VStack(alignment: .leading) {
            if engine.pairedDevices.isEmpty {
                ContentUnavailableView("No paired devices", systemImage: "iphone.slash",
                                       description: Text("Use “Pair a device” in the menu bar."))
            } else {
                List(engine.pairedDevices) { device in
                    HStack {
                        Image(systemName: engine.connectedDeviceIDs.contains(device.id) ? "iphone.radiowaves.left.and.right" : "iphone")
                        VStack(alignment: .leading) {
                            Text(device.name)
                            Text("Paired \(device.pairedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Revoke", role: .destructive) { engine.revoke(device) }
                    }
                }
            }
        }
        .padding()
    }
}
