import SwiftUI

struct StatsView: View {
    @State var viewModel: StatsViewModel
    @State private var showPaywall = false
    private let premium = PremiumManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.playerStats.isEmpty && viewModel.sportStats.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No stats yet",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Play some games to see statistics here.")
                    )
                } else {
                    List {
                        if !viewModel.playerStats.isEmpty {
                            Section("Leaderboard") {
                                if premium.isPremium {
                                    ForEach(Array(viewModel.playerStats.enumerated()), id: \.element.id) { index, stat in
                                        PlayerStatRow(stat: stat, rank: index + 1)
                                    }
                                } else {
                                    lockedLeaderboardRow
                                }
                            }
                        }
                        if !viewModel.sportStats.isEmpty {
                            Section("Sports") {
                                ForEach(viewModel.sportStats) { stat in
                                    SportStatRow(stat: stat)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Stats")
            .overlay { if viewModel.isLoading { ProgressView() } }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var lockedLeaderboardRow: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Player leaderboard")
                        .font(.headline)
                    Text("Upgrade to Premium to see wins, win rates, and rankings for all players.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.yellow.opacity(0.08))
    }
}

private struct PlayerStatRow: View {
    let stat: PlayerStat
    let rank: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(rankColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.player.name).font(.headline)
                if let sport = stat.favoriteSport {
                    Text("Favorite: \(sport.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stat.wins)W · \(stat.gamesPlayed - stat.wins)L")
                    .font(.subheadline.monospacedDigit())
                if stat.gamesPlayed > 0 {
                    Text("\(Int(stat.winRate * 100))% wins")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var rankColor: Color {
        switch rank {
        case 1: .yellow
        case 2: Color(white: 0.6)
        case 3: Color(red: 0.8, green: 0.5, blue: 0.2)
        default: .secondary
        }
    }
}

private struct SportStatRow: View {
    let stat: SportStat

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: stat.sportIcon)
                .font(.title3)
                .foregroundStyle(Color.forSport(stat.sport))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.sportName).font(.headline)
                Text("\(stat.gamesPlayed) games · \(stat.completedGames) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
