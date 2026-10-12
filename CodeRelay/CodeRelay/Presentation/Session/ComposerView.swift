import SwiftUI

/// Prompt input with Apple Intelligence "Refine", follow-up chips and send/stop.
struct ComposerView: View {
    @Bindable var viewModel: SessionViewModel
    let fontSize: Double
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            if !viewModel.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.intelligence").foregroundStyle(Theme.ai)
                        ForEach(viewModel.suggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                viewModel.use(suggestion: suggestion)
                                focused = true
                            }
                            .font(Theme.mono(12))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.surfaceRaised, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.ai.opacity(0.4)))
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                Text("❯")
                    .font(Theme.mono(fontSize, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.bottom, 10)

                TextField(viewModel.isConnected ? "Ask Claude…" : "Reconnecting…", text: $viewModel.draft, axis: .vertical)
                    .font(Theme.mono(fontSize))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1...8)
                    .focused($focused)
                    .textInputAutocapitalization(.sentences)
                    .padding(.vertical, 10)
                    .onSubmit(viewModel.submit)

                if viewModel.aiAvailable, !viewModel.draft.isEmpty {
                    Button {
                        Task { await viewModel.refineDraft() }
                    } label: {
                        if viewModel.isRefining {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "wand.and.sparkles")
                        }
                    }
                    .foregroundStyle(Theme.ai)
                    .padding(.bottom, 10)
                    .accessibilityLabel("Refine prompt with Apple Intelligence")
                }

                if viewModel.transcript.isWorking && viewModel.draft.isEmpty {
                    Button(action: viewModel.interrupt) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 34, height: 34)
                            .background(Theme.danger, in: Circle())
                            .foregroundStyle(Theme.background)
                    }
                    .padding(.bottom, 4)
                    .accessibilityLabel("Interrupt Claude")
                } else {
                    Button(action: viewModel.submit) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                            .background(viewModel.canSend ? Theme.accent : Theme.surfaceRaised, in: Circle())
                            .foregroundStyle(viewModel.canSend ? Theme.background : Theme.dim)
                    }
                    .disabled(!viewModel.canSend)
                    .padding(.bottom, 4)
                    .accessibilityLabel("Send")
                }
            }
            .padding(.horizontal, 14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(focused ? Theme.accent.opacity(0.6) : Theme.border))
            .padding(.horizontal, 10)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Theme.background)
    }
}
