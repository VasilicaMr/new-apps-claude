import SwiftUI
import RelayKit

/// The terminal: streaming transcript, permission cards and the prompt composer.
struct SessionView: View {
    @State var viewModel: SessionViewModel
    @AppStorage(PreferenceKeys.fontSize) private var fontSize = 14.0
    @AppStorage(PreferenceKeys.haptics) private var haptics = true
    @State private var showRename = false
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            transcript
            ComposerView(viewModel: viewModel, fontSize: fontSize)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(viewModel.summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sensoryFeedback(.warning, trigger: viewModel.transcript.pendingPermissions.count) { old, new in
            haptics && new > old
        }
        .sensoryFeedback(.success, trigger: viewModel.transcript.isWorking) { old, new in
            haptics && old && !new
        }
        .sheet(isPresented: Binding(get: { viewModel.sessionSummaryText != nil },
                                    set: { if !$0 { viewModel.sessionSummaryText = nil } })) {
            AISheet(title: "Session summary", text: viewModel.sessionSummaryText ?? "")
        }
        .alert("Rename session", isPresented: $showRename) {
            TextField("Title", text: $renameText)
            Button("Save") { viewModel.rename(renameText) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Apple Intelligence", isPresented: Binding(get: { viewModel.aiError != nil },
                                                          set: { if !$0 { viewModel.aiError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.aiError ?? "")
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    SessionHeader(summary: viewModel.summary, model: viewModel.transcript.model,
                                  cost: viewModel.transcript.totalCostUSD)
                    if viewModel.transcript.items.isEmpty {
                        Text("Ask Claude to do something in ~/\(viewModel.summary.projectName).")
                            .foregroundStyle(Theme.dim)
                            .font(Theme.mono(fontSize))
                    }
                    ForEach(viewModel.transcript.items) { item in
                        TranscriptRow(item: item, fontSize: fontSize, viewModel: viewModel)
                    }
                    if viewModel.transcript.isWorking {
                        WorkingIndicator().font(Theme.mono(fontSize))
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .textSelection(.enabled)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: viewModel.transcript.revision) {
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if viewModel.aiAvailable {
                    Button {
                        Task { await viewModel.summarizeSession() }
                    } label: {
                        Label("Summarize with Apple Intelligence", systemImage: "apple.intelligence")
                    }
                }
                Button {
                    renameText = viewModel.summary.title
                    showRename = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                if viewModel.transcript.isWorking {
                    Button(role: .destructive) { viewModel.interrupt() } label: {
                        Label("Interrupt Claude", systemImage: "stop.circle")
                    }
                }
            } label: {
                if viewModel.isSummarizing {
                    ProgressView()
                } else {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

private struct SessionHeader: View {
    let summary: SessionSummary
    let model: String?
    let cost: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("~/\(summary.projectName)").foregroundStyle(Theme.accent)
            HStack(spacing: 6) {
                Text(summary.permissionMode.title)
                if let model { Text("· \(model)") }
                if cost > 0 { Text("· $" + String(format: "%.3f", cost)) }
            }
            .foregroundStyle(Theme.dim)
        }
        .font(Theme.mono(11))
        .padding(.bottom, 6)
    }
}

private struct WorkingIndicator: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { context in
            let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
            let index = Int(context.date.timeIntervalSinceReferenceDate / 0.12) % frames.count
            HStack(spacing: 8) {
                Text(frames[index]).foregroundStyle(Theme.accent)
                Text("working…").foregroundStyle(Theme.dim)
            }
        }
        .accessibilityLabel("Claude is working")
    }
}

struct AISheet: View {
    let title: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Generated on-device by Apple Intelligence", systemImage: "apple.intelligence")
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.ai)
                    Text(text)
                        .font(Theme.mono(14))
                        .foregroundStyle(Theme.text)
                        .textSelection(.enabled)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { ShareLink(item: text) }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
