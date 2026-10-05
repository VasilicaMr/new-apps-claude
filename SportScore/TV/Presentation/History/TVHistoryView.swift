import SwiftUI

struct TVHistoryView: View {
    @State var viewModel: HistoryViewModel
    @State private var showPaywall = false
    private let premium = PremiumManager.shared

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
                    Section {
                        ForEach(Array(viewModel.sessions.enumerated()), id: \.element.id) { index, session in
                            NavigationLink(value: TVHistoryRoute.sessionDetail(sessionID: session.id)) {
                                TVSessionRow(session: session)
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    Task { await viewModel.deleteSessions(at: IndexSet(integer: index)) }
                                }
                            }
                        }

                        if viewModel.lockedCount > 0 {
                            lockedRow
                        }
                    } footer: {
                        Text("Hold on a game to delete it.")
                    }
                }
            }
        }
        .navigationTitle("History")
        .overlay {
            if viewModel.isLoading && viewModel.sessions.isEmpty { ProgressView() }
        }
        .task { await viewModel.load() }
        .onChange(of: premium.isPremium) {
            Task { await viewModel.load() }
        }
        .sheet(isPresented: $showPaywall) {
            TVPaywallView()
                .tvThemed()
        }
    }

    private var lockedRow: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.lockedCount) more session\(viewModel.lockedCount == 1 ? "" : "s") locked")
                        .font(.headline)
                    Text("Upgrade to Premium to see your full history")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct TVSessionRow: View {
    let session: GameSession

    var body: some View {
        HStack(spacing: 30) {
            Image(systemName: session.iconName)
                .font(.title)
                .foregroundStyle(Color.forSession(session))
                .frame(width: 70)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                if let variant = session.variant {
                    Text(variant).font(.callout).foregroundStyle(.secondary)
                }
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if session.isActive {
                Label("In progress", systemImage: "play.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.tint)
            } else if let winnerID = session.winnerID,
                      let winner = session.players.first(where: { $0.id == winnerID }) {
                Label(winner.name, systemImage: "trophy.fill")
                    .font(.callout)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 6)
    }
}
