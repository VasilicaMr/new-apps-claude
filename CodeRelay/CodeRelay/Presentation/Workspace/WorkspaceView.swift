import SwiftUI
import RelayKit

struct WorkspaceView: View {
    @State var viewModel: WorkspaceViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showNewSession = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ConnectionBanner(state: viewModel.state) { Task { await viewModel.connect() } }
                if let info = viewModel.hostInfo, !info.claudeAvailable {
                    TerminalCard(tint: Theme.warning) {
                        Label("Claude Code wasn't found on this Mac. Install it, then set its path in CodeRelay Host → Settings.",
                              systemImage: "exclamationmark.triangle")
                            .font(Theme.mono(12))
                            .foregroundStyle(Theme.warning)
                    }
                }
                Button { showNewSession = true } label: {
                    Label("New Claude session", systemImage: "plus.rectangle.on.rectangle")
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(!viewModel.state.isConnected)
                .opacity(viewModel.state.isConnected ? 1 : 0.5)

                sessionsList
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(viewModel.host.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.connect() }
        .task { await viewModel.connectIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.connectIfNeeded() } }
        }
        .navigationDestination(item: $viewModel.openedSession) { summary in
            SessionView(viewModel: viewModel.sessionModel(for: summary))
        }
        .sheet(isPresented: $showNewSession) {
            NewSessionView(projects: viewModel.projects) { project, mode in
                showNewSession = false
                viewModel.startSession(in: project, mode: mode)
            }
        }
        .alert("CodeRelay", isPresented: Binding(get: { viewModel.errorMessage != nil },
                                                 set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("sessions")
            if viewModel.sessions.isEmpty {
                Text(viewModel.state.isConnected ? "No sessions yet. Start one above." : "Connect to see sessions.")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.dim)
            }
            ForEach(viewModel.sessions) { session in
                Button { viewModel.openedSession = session } label: { SessionRow(session: session) }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) { viewModel.delete(session) } label: {
                            Label("Close session", systemImage: "xmark.circle")
                        }
                    }
            }
        }
    }
}

private struct SessionRow: View {
    let session: SessionSummary

    var body: some View {
        TerminalCard(tint: session.isRunning ? Theme.accent.opacity(0.5) : Theme.border) {
            HStack(alignment: .top, spacing: 12) {
                Text(session.isRunning ? "●" : "○")
                    .foregroundStyle(session.isRunning ? Theme.accent : Theme.dim)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(Theme.mono(15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text("~/\(session.projectName)")
                        Text("·")
                        Text(session.createdAt, style: .relative)
                    }
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.dim)
                }
                Spacer()
                if session.permissionMode == .bypassPermissions {
                    Image(systemName: "bolt.trianglebadge.exclamationmark").foregroundStyle(Theme.danger)
                }
            }
        }
    }
}

struct ConnectionBanner: View {
    let state: ConnectionState
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            switch state {
            case .idle, .connecting:
                ProgressView().tint(Theme.accent)
                Text("connecting…").foregroundStyle(Theme.dim)
            case .connected(let info):
                Circle().fill(Theme.accent).frame(width: 8, height: 8)
                Text("connected · claude \(info.claudeVersion?.components(separatedBy: " ").first ?? "?")")
                    .foregroundStyle(Theme.dim)
            case .disconnected(let reason):
                Image(systemName: "bolt.horizontal.circle").foregroundStyle(Theme.danger)
                Text(reason).foregroundStyle(Theme.danger).lineLimit(3)
                Spacer()
                Button("Retry", action: retry).foregroundStyle(Theme.accent)
            }
        }
        .font(Theme.mono(12))
    }
}

/// Pick a project folder and a permission mode.
struct NewSessionView: View {
    let projects: [ProjectInfo]
    let onStart: (ProjectInfo, PermissionMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: PermissionMode = .ask
    @State private var search = ""
    @State private var pendingBypass: ProjectInfo?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Permissions", selection: $mode) {
                        ForEach(PermissionMode.allCases) { Text($0.title).tag($0) }
                    }
                    .font(Theme.mono(14))
                } footer: {
                    Text(modeFooter).font(Theme.mono(11))
                }
                Section("Project") {
                    if projects.isEmpty {
                        Text("No projects. On your Mac, add a workspace folder in CodeRelay Host → Settings → Workspaces.")
                            .font(Theme.mono(12))
                            .foregroundStyle(Theme.dim)
                    }
                    ForEach(filtered) { project in
                        Button { choose(project) } label: {
                            HStack {
                                Image(systemName: project.isGitRepository ? "arrow.triangle.branch" : "folder")
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text(project.name).foregroundStyle(Theme.text)
                                    Text(project.path).font(Theme.mono(10)).foregroundStyle(Theme.dim).lineLimit(1)
                                }
                            }
                            .font(Theme.mono(14))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .searchable(text: $search, prompt: "Filter projects")
            .navigationTitle("New session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .confirmationDialog("Bypass all permission checks?", isPresented: Binding(
                get: { pendingBypass != nil }, set: { if !$0 { pendingBypass = nil } }), titleVisibility: .visible) {
                Button("Start without permission prompts", role: .destructive) {
                    if let project = pendingBypass { onStart(project, mode) }
                }
            } message: {
                Text("Claude will be able to run any command and change any file in this project without asking.")
            }
        }
    }

    private var filtered: [ProjectInfo] {
        search.isEmpty ? projects : projects.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var modeFooter: String {
        switch mode {
        case .ask: return "Every action that needs permission is sent to this device for approval."
        case .acceptEdits: return "File edits are accepted automatically. Commands still ask."
        case .plan: return "Claude can read and plan but not change anything."
        case .bypassPermissions: return "Nothing is asked. Use only in disposable or sandboxed projects."
        }
    }

    private func choose(_ project: ProjectInfo) {
        if mode == .bypassPermissions { pendingBypass = project } else { onStart(project, mode) }
    }
}
