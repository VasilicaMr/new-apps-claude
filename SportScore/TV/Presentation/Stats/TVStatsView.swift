import SwiftUI

struct TVStatsView: View {
    @State var viewModel: StatsViewModel
    @State private var showPaywall = false
    private let premium = PremiumManager.shared

    var body: some View {
        Group {
            if viewModel.playerStats.isEmpty && viewModel.sportStats.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No stats yet",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Play some games to see statistics here.")
                )
            } else {
                HStack(alignment: .top, spacing: 60) {
                    List {
                        Section("Leaderboard") {
                            if premium.isPremium {
                                ForEach(Array(viewModel.playerStats.enumerated()), id: \.element.id) { index, stat in
                                    Button {} label: {
                                        TVPlayerStatRow(stat: stat, rank: index + 1)
                                    }
                                }
                            } else {
                                lockedLeaderboardRow
                            }
                        }
                    }
                    .focusSection()
                    List {
                        Section("Sports") {
                            ForEach(viewModel.sportStats) { stat in
                                Button {} label: {
                                    TVSportStatRow(stat: stat)
                                }
                            }
                        }
                    }
                    .focusSection()
                }
            }
        }
        .navigationTitle("Stats")
        .overlay { if viewModel.isLoading && viewModel.sportStats.isEmpty { ProgressView() } }
        .task { await viewModel.load() }
        .sheet(isPresented: $showPaywall) {
            TVPaywallView()
                .tvThemed()
        }
    }

    private var lockedLeaderboardRow: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Player leaderboard")
                        .font(.headline)
                    Text("Upgrade to Premium to see wins, win rates, and rankings for all players.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct TVPlayerStatRow: View {
    let stat: PlayerStat
    let rank: Int

    var body: some View {
        HStack(spacing: 24) {
            Text("\(rank)")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(rankColor)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(stat.player.name).font(.headline)
                if let favorite = stat.favoriteGame ?? stat.favoriteSport?.displayName {
                    Text("Favorite: \(favorite)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(stat.wins)W · \(stat.gamesPlayed - stat.wins)L")
                    .font(.headline.monospacedDigit())
                if stat.gamesPlayed > 0 {
                    Text("\(Int(stat.winRate * 100))% wins")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
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

private struct TVSportStatRow: View {
    let stat: SportStat

    var body: some View {
        HStack(spacing: 24) {
            Image(systemName: stat.sportIcon)
                .font(.title2)
                .foregroundStyle(Color.forSport(stat.sport))
                .frame(width: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(stat.sportName).font(.headline)
                Text("\(stat.gamesPlayed) games · \(stat.completedGames) completed")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
