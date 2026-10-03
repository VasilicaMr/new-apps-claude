import SwiftUI

struct HistoryView: View {
    @State var viewModel: HistoryViewModel
    var coordinator: HistoryCoordinator
    @State private var showPaywall = false

    var body: some View {
        Group {
            if viewModel.sessions.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No games yet",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Start a game to see your history here.")
                )
            } else {
                List {
                    ForEach(viewModel.sessions) { session in
                        Button {
                            coordinator.push(.sessionDetail(sessionID: session.id))
                        } label: {
                            SessionRowView(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        Task { await viewModel.deleteSessions(at: indexSet) }
                    }

                    if viewModel.lockedCount > 0 {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.yellow)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(viewModel.lockedCount) more session\(viewModel.lockedCount == 1 ? "" : "s") locked")
                                        .font(.subheadline.bold())
                                    Text("Upgrade to Premium to see your full history")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.yellow.opacity(0.08))
                    }
                }
            }
        }
        .navigationTitle("History")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .overlay {
            if viewModel.isLoading { ProgressView() }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

struct SessionRowView: View {
    let session: GameSession

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: session.sport.systemImageName)
                .font(.title2)
                .foregroundStyle(Color.forSport(session.sport))
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.sport.displayName)
                    .font(.headline)
                if let variant = session.variant {
                    Text(variant).font(.caption).foregroundStyle(.secondary)
                }
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let winnerID = session.winnerID,
               let winner = session.players.first(where: { $0.id == winnerID }) {
                Label(winner.name, systemImage: "trophy.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}
