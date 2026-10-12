import SwiftUI
import RelayKit

struct TranscriptRow: View {
    let item: TranscriptItem
    let fontSize: Double
    let viewModel: SessionViewModel

    var body: some View {
        switch item.kind {
        case .user(let text):
            PrefixedLine(prefix: "❯", prefixColor: Theme.accent) {
                Text(text).foregroundStyle(Theme.accent)
            }
            .font(Theme.mono(fontSize, weight: .semibold))
            .padding(.top, 8)
        case .assistant(let text, let isStreaming):
            PrefixedLine(prefix: "⏺", prefixColor: Theme.text) {
                Text(Self.markdown(text) + (isStreaming ? AttributedString("▍") : AttributedString()))
                    .foregroundStyle(Theme.text)
            }
            .font(Theme.mono(fontSize))
        case .tool(let name, let summary, let output, let isError):
            ToolRow(name: name, summary: summary, output: output, isError: isError, fontSize: fontSize)
        case .permission(let prompt, let state):
            PermissionCard(prompt: prompt, state: state, fontSize: fontSize, viewModel: viewModel)
        case .notice(let text):
            PrefixedLine(prefix: "!", prefixColor: Theme.warning) {
                Text(text).foregroundStyle(Theme.warning)
            }
            .font(Theme.mono(fontSize - 2))
        case .system(let text):
            Text("● \(text)")
                .font(Theme.mono(fontSize - 3))
                .foregroundStyle(Theme.dim)
        case .turnSummary(let isError, let cost, let duration):
            HStack(spacing: 6) {
                Text(isError ? "✗" : "✓").foregroundStyle(isError ? Theme.danger : Theme.accent)
                if let duration { Text(String(format: "%.1fs", Double(duration) / 1000)) }
                if let cost { Text("· $" + String(format: "%.4f", cost)) }
            }
            .font(Theme.mono(fontSize - 3))
            .foregroundStyle(Theme.dim)
        }
    }

    static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

/// Terminal-style hanging indent: `⏺ text that wraps
///                                     under itself`.
struct PrefixedLine<Content: View>: View {
    let prefix: String
    let prefixColor: Color
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(prefix).foregroundStyle(prefixColor)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ToolRow: View {
    let name: String
    let summary: String
    let output: String?
    let isError: Bool
    let fontSize: Double
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { withAnimation(.snappy) { expanded.toggle() } } label: {
                PrefixedLine(prefix: "⏺", prefixColor: output == nil ? Theme.dim : (isError ? Theme.danger : Theme.tool)) {
                    (Text(name).bold() + Text("(\(summary))"))
                        .foregroundStyle(Theme.tool)
                        .lineLimit(expanded ? nil : 2)
                }
            }
            .buttonStyle(.plain)
            if let output, !output.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("  ⎿").foregroundStyle(Theme.dim)
                    Text(expanded ? output : firstLine(of: output))
                        .foregroundStyle(isError ? Theme.danger : Theme.dim)
                        .lineLimit(expanded ? nil : 1)
                }
                .font(Theme.mono(fontSize - 2))
            }
        }
        .font(Theme.mono(fontSize))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to \(expanded ? "collapse" : "expand") output")
    }

    private func firstLine(of text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let first = String(lines.first ?? "")
        return lines.count > 1 ? "\(first)  … +\(lines.count - 1) lines" : first
    }
}

private struct PermissionCard: View {
    let prompt: PermissionPrompt
    let state: TranscriptItem.PermissionState
    let fontSize: Double
    let viewModel: SessionViewModel
    @State private var showDetail = false

    var body: some View {
        TerminalCard(tint: state == .pending ? Theme.warning : Theme.border) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "hand.raised.fill").foregroundStyle(Theme.warning)
                    Text("\(prompt.toolName) wants permission").font(Theme.mono(fontSize, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                Text(prompt.summary)
                    .font(Theme.mono(fontSize - 1))
                    .foregroundStyle(Theme.tool)

                if showDetail, !prompt.detail.isEmpty {
                    ScrollView(.horizontal) {
                        Text(prompt.detail).font(Theme.mono(fontSize - 3)).foregroundStyle(Theme.dim)
                    }
                    .frame(maxHeight: 220)
                }

                if let explanation = viewModel.explanations[prompt.id] {
                    Label { Text(explanation) } icon: { Image(systemName: "apple.intelligence") }
                        .font(Theme.mono(fontSize - 2))
                        .foregroundStyle(Theme.ai)
                }

                HStack(spacing: 14) {
                    Button(showDetail ? "Hide details" : "Details") { withAnimation { showDetail.toggle() } }
                    if viewModel.aiAvailable, viewModel.explanations[prompt.id] == nil, state == .pending {
                        Button {
                            Task { await viewModel.explain(prompt) }
                        } label: {
                            if viewModel.explaining.contains(prompt.id) {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Explain", systemImage: "apple.intelligence")
                            }
                        }
                        .foregroundStyle(Theme.ai)
                    }
                }
                .font(Theme.mono(12))
                .foregroundStyle(Theme.dim)

                switch state {
                case .pending:
                    HStack(spacing: 10) {
                        Button("Deny") { viewModel.decide(prompt, allow: false) }
                            .buttonStyle(GhostButtonStyle(color: Theme.danger))
                        Button("Allow") { viewModel.decide(prompt, allow: true) }
                            .buttonStyle(AccentButtonStyle())
                    }
                    .disabled(!viewModel.isConnected)
                case .allowed:
                    Text("✓ allowed").font(Theme.mono(12)).foregroundStyle(Theme.accent)
                case .denied:
                    Text("✗ denied").font(Theme.mono(12)).foregroundStyle(Theme.danger)
                case .expired:
                    Text("— expired (Claude stopped)").font(Theme.mono(12)).foregroundStyle(Theme.dim)
                }
            }
        }
    }
}
