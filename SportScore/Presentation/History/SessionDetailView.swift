import SwiftUI

struct SessionDetailView: View {
    @State var viewModel: SessionDetailViewModel

    var body: some View {
        Group {
            if let session = viewModel.session {
                List {
                    Section("Match Info") {
                        LabeledContent("Sport", value: session.sport.displayName)
                        if let variant = session.variant {
                            LabeledContent("Variant", value: variant)
                        }
                        LabeledContent("Date", value: session.startedAt.formatted(date: .long, time: .shortened))
                        if let winner = viewModel.winner {
                            LabeledContent("Winner") {
                                Label(winner.name, systemImage: "trophy.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }

                    Section("Players") {
                        ForEach(session.players) { player in
                            HStack {
                                Text(player.name)
                                Spacer()
                                Text(viewModel.finalScore(for: player, in: session))
                                    .font(.headline.monospacedDigit())
                            }
                        }
                    }
                }
            } else if viewModel.isLoading {
                ProgressView("Loading…")
            } else {
                ContentUnavailableView(
                    "Session not found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This session could not be loaded.")
                )
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}
