import SwiftUI

struct TVSessionDetailView: View {
    @State var viewModel: SessionDetailViewModel
    let coordinator: TVAppCoordinator
    /// Shown right after a game ends: offers a way back to the list of games.
    var isResult = false

    var body: some View {
        Group {
            if let session = viewModel.session {
                HStack(alignment: .top, spacing: 80) {
                    summary(session: session)
                        .frame(width: 620)
                    List {
                        Section("Match Info") {
                            LabeledContent(session.houseGame == nil ? "Sport" : "Game", value: session.title)
                            if let rules = session.houseGame?.rules {
                                LabeledContent("Rules", value: rules.summary)
                            }
                            if let variant = session.variant {
                                LabeledContent("Variant", value: variant)
                            }
                            LabeledContent("Date", value: session.startedAt.formatted(date: .long, time: .shortened))
                            if let duration = session.duration {
                                LabeledContent("Duration", value: Duration.seconds(duration)
                                    .formatted(.units(allowed: [.hours, .minutes], width: .wide)))
                            }
                        }

                        Section("Players") {
                            ForEach(session.players) { player in
                                HStack(spacing: 24) {
                                    TVInitialsAvatar(player: player)
                                    Text(player.name)
                                    if player.id == viewModel.winner?.id {
                                        Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                                    }
                                    Spacer()
                                    Text(viewModel.finalScore(for: player, in: session))
                                        .font(.title3.bold().monospacedDigit())
                                }
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
        .task { await viewModel.load() }
    }

    private func summary(session: GameSession) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            Image(systemName: session.iconName)
                .font(.system(size: 100, weight: .semibold))
                .foregroundStyle(Color.forSession(session))
            Text(session.title)
                .font(.system(size: 56, weight: .heavy, design: .rounded))

            if let winner = viewModel.winner {
                Label("\(winner.name) wins!", systemImage: "trophy.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.yellow)
            } else if session.isActive {
                Label("In progress", systemImage: "play.circle.fill")
                    .font(.title3.bold())
                    .foregroundStyle(.tint)
            } else {
                Text("No winner")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if session.isActive {
                Button {
                    coordinator.startLiveScore(sessionID: session.id)
                } label: {
                    Label("Resume game", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else if isResult {
                Button {
                    coordinator.showGames()
                } label: {
                    Label("New Game", systemImage: "square.grid.2x2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
