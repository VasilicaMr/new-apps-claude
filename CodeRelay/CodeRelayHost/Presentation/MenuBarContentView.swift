import SwiftUI
import RelayKit

struct MenuBarContentView: View {
    @Environment(HostEngine.self) private var engine
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            if let code = engine.pairingCode {
                PairingCodeView(code: code, expiresAt: engine.pairingExpiresAt) { engine.endPairing() }
            } else {
                Button {
                    engine.beginPairing()
                } label: {
                    Label("Pair a device", systemImage: "iphone.gen3.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
            if engine.settings.workspaceRoots.isEmpty {
                Label("Add a workspace folder in Settings so your phone can open projects.",
                      systemImage: "folder.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            sessionsSection
            Divider()
            HStack {
                Button("Settings…") {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CodeRelay Host").font(.headline)
            HStack(spacing: 6) {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(statusText).font(.caption).foregroundStyle(.secondary)
            }
            if let claude = engine.claude {
                Text("Claude Code \(claude.version ?? "")").font(.caption).foregroundStyle(.secondary)
            } else if engine.isLocatingClaude {
                Text("Looking for Claude Code…").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Claude Code CLI not found — set its path in Settings.")
                    .font(.caption).foregroundStyle(.red)
            }
            Text("\(engine.connectedDeviceIDs.count) device(s) connected")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var sessionsSection: some View {
        let running = engine.sessions.filter(\.isRunning)
        if !running.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Running sessions").font(.subheadline.bold())
                ForEach(running) { session in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(session.title).lineLimit(1)
                            Text(session.projectName).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            engine.stopSession(session.id)
                        } label: {
                            Image(systemName: "stop.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Stop Claude for this session")
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        switch engine.serverStatus {
        case .listening: return .green
        case .stopped: return .gray
        case .failed: return .red
        }
    }

    private var statusText: String {
        switch engine.serverStatus {
        case .listening(let port): return "Listening on port \(port)"
        case .stopped: return "Stopped"
        case .failed(let message): return "Error: \(message)"
        }
    }
}

private struct PairingCodeView: View {
    let code: String
    let expiresAt: Date?
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Enter this code in CodeRelay on your iPhone")
                .font(.caption)
                .multilineTextAlignment(.center)
            Text(code.prefix(3) + " " + code.suffix(3))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .textSelection(.enabled)
            if let expiresAt {
                Text(timerInterval: Date()...expiresAt, countsDown: true)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Button("Cancel", action: cancel)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
