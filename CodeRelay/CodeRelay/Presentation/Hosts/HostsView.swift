import SwiftUI
import RelayKit

struct HostsView: View {
    @State var viewModel: HostsViewModel
    @Environment(AppContainer.self) private var container
    @State private var path: [SavedHost] = []
    @State private var pairingTarget: PairingTarget?
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if !viewModel.savedHosts.isEmpty { savedSection }
                    discoveredSection
                    if viewModel.savedHosts.isEmpty { gettingStarted }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { pairingTarget = .manual } label: { Label("Add by address…", systemImage: "network") }
                        Button(action: openDemo) { Label("Try the demo", systemImage: "play.circle") }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a Mac")
                }
            }
            .navigationDestination(for: SavedHost.self) { host in
                WorkspaceView(viewModel: container.makeWorkspaceViewModel(host: host))
            }
            .sheet(item: $pairingTarget) { target in
                PairingView(target: target, viewModel: viewModel) { host in
                    pairingTarget = nil
                    path = [host]
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(assistant: container.assistant, hosts: viewModel)
            }
            .onAppear {
                viewModel.reload()
                viewModel.startDiscovery()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("❯_").foregroundStyle(Theme.accent)
                Text("CodeRelay").foregroundStyle(Theme.text)
            }
            .font(Theme.mono(30, weight: .bold))
            Text("Claude Code on your Mac, from anywhere in the house.")
                .font(Theme.mono(13))
                .foregroundStyle(Theme.dim)
        }
        .padding(.top, 8)
    }

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("your macs")
            ForEach(viewModel.savedHosts) { host in
                NavigationLink(value: host) {
                    HostRow(name: host.name, subtitle: host.endpoint.displayAddress,
                            status: viewModel.isOnline(host) ? .online : .unknown, icon: host.endpoint == .demo ? "play.desktopcomputer" : "desktopcomputer")
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) { viewModel.remove(host) } label: { Label("Forget this Mac", systemImage: "trash") }
                }
            }
        }
    }

    private var discoveredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("on this network")
                ProgressView().controlSize(.mini).tint(Theme.dim)
            }
            if viewModel.unpairedHosts.isEmpty {
                Text("Looking for Macs running CodeRelay Host…")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.dim)
            }
            ForEach(viewModel.unpairedHosts) { host in
                Button {
                    pairingTarget = .discovered(host)
                } label: {
                    HostRow(name: host.serviceName, subtitle: "Tap to pair", status: .online, icon: "desktopcomputer.and.arrow.down")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var gettingStarted: some View {
        TerminalCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("# getting started").font(Theme.mono(14, weight: .bold)).foregroundStyle(Theme.accent)
                StepLine(number: 1, text: "Install Claude Code and CodeRelay Host on your Mac.")
                StepLine(number: 2, text: "In the Host menu bar, add a workspace folder.")
                StepLine(number: 3, text: "Click “Pair a device” and enter the code here.")
                Button("Try the demo", action: openDemo)
                    .buttonStyle(GhostButtonStyle(color: Theme.accent))
                    .padding(.top, 4)
            }
        }
    }

    private func openDemo() {
        container.hostRepository.save(.demo, key: nil)
        viewModel.reload()
        path = [.demo]
    }
}

enum PairingTarget: Identifiable {
    case discovered(DiscoveredHost)
    case manual

    var id: String {
        switch self {
        case .discovered(let host): return host.id
        case .manual: return "manual"
        }
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text("// " + text)
            .font(Theme.mono(12, weight: .semibold))
            .foregroundStyle(Theme.dim)
            .textCase(.uppercase)
    }
}

struct StepLine: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number).").foregroundStyle(Theme.accent)
            Text(text).foregroundStyle(Theme.text)
        }
        .font(Theme.mono(13))
    }
}

struct HostRow: View {
    enum Status { case online, unknown }

    let name: String
    let subtitle: String
    let status: Status
    let icon: String

    var body: some View {
        TerminalCard {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(Theme.mono(16, weight: .semibold)).foregroundStyle(Theme.text)
                    Text(subtitle).font(Theme.mono(12)).foregroundStyle(Theme.dim)
                }
                Spacer()
                Circle()
                    .fill(status == .online ? Theme.accent : Theme.dim.opacity(0.5))
                    .frame(width: 8, height: 8)
                Image(systemName: "chevron.right").foregroundStyle(Theme.dim)
            }
        }
        .contentShape(Rectangle())
    }
}
