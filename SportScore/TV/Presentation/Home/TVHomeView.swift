import SwiftUI

struct TVHomeView: View {
    let coordinator: TVAppCoordinator
    @State private var activeSessions: [GameSession] = []
    @State private var gamePendingDelete: HouseGame?

    private let columnCount = 5
    private static let sportCount = SportCategory.allCases.flatMap(\.sports).count

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 56) {
                headerSection

                if let session = activeSessions.first {
                    TVContinueBanner(session: session) {
                        coordinator.startLiveScore(sessionID: session.id)
                    }
                }

                yourGamesSection

                sectionTitle("Home Game Night", subtitle: "Card, board and party games everyone knows")
                ForEach(HouseGameCategory.allCases) { category in
                    homeGamesSection(category)
                }

                sectionTitle("Sports", subtitle: "Full scoring rules for \(Self.sportCount) sports")
                ForEach(SportCategory.allCases) { category in
                    categorySection(category)
                }
            }
            .padding(.vertical, 30)
        }
        // Refresh whenever the scoreboard closes, so "Continue" reflects the latest game.
        .task(id: coordinator.liveSessionID) {
            guard coordinator.liveSessionID == nil else { return }
            activeSessions = (try? await coordinator.container.fetchSessionsUseCase.execute(activeOnly: true)) ?? []
        }
        .task { await coordinator.customGames.load() }
        .alert(
            "Delete \(gamePendingDelete?.name ?? "game")?",
            isPresented: Binding(get: { gamePendingDelete != nil }, set: { if !$0 { gamePendingDelete = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let game = gamePendingDelete {
                    Task { await coordinator.customGames.delete(game) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Past games keep their scores in History.")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ScoreCap")
                .font(.system(size: 76, weight: .heavy, design: .rounded))
            Text("Pick a game")
                .font(.title2.bold())
            Text("Select to start tracking")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Your games

    private var yourGamesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Label("Your Games", systemImage: "star.fill")
                .font(.title3.bold())
                .foregroundStyle(.teal)

            TVGrid(columns: columnCount, spacing: 40) {
                Button {
                    coordinator.showEditor(for: nil)
                } label: {
                    VStack(spacing: 14) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.teal)
                        Text("Create Custom Game")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text("Any game, your rules")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, minHeight: 210)
                }
                .buttonStyle(.card)

                ForEach(coordinator.customGames.games) { game in
                    Button {
                        coordinator.showSetup(for: game)
                    } label: {
                        TVHouseGameTile(game: game)
                    }
                    .buttonStyle(.card)
                    .contextMenu {
                        Button {
                            coordinator.showSetup(for: game)
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                        Button {
                            coordinator.showEditor(for: game)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            gamePendingDelete = game
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            if !coordinator.customGames.games.isEmpty {
                Text("Hold on a game to edit or delete it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .focusSection()
    }

    // MARK: - Home games

    private func homeGamesSection(_ category: HouseGameCategory) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Label(category.rawValue, systemImage: category.systemImageName)
                .font(.title3.bold())
                .foregroundStyle(Color.forHouseGame(HouseGameCatalog.games(in: category)[0]))

            TVGrid(columns: columnCount, spacing: 40) {
                ForEach(HouseGameCatalog.games(in: category)) { game in
                    Button {
                        coordinator.showSetup(for: game)
                    } label: {
                        TVHouseGameTile(game: game)
                    }
                    .buttonStyle(.card)
                    .contextMenu {
                        Button {
                            coordinator.showEditor(for: game)
                        } label: {
                            Label("Customize Rules…", systemImage: "slider.horizontal.3")
                        }
                    }
                }
            }
        }
        // Up/down from any column reaches the next row of games, even a shorter one.
        .focusSection()
    }

    // MARK: - Sports

    private func categorySection(_ category: SportCategory) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Label(category.rawValue, systemImage: category.systemImageName)
                .font(.title3.bold())
                .foregroundStyle(Color.forSportCategory(category))

            TVGrid(columns: columnCount, spacing: 40) {
                ForEach(category.sports) { sport in
                    Button {
                        coordinator.showSetup(for: sport)
                    } label: {
                        TVSportCard(sport: sport)
                    }
                    .buttonStyle(.card)
                }
            }
        }
        .focusSection()
    }
}

struct TVSportCard: View {
    let sport: SportType

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: sport.systemImageName)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(Color.forSport(sport))
            Spacer(minLength: 0)
            Text(sport.displayName)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
    }
}

private struct TVContinueBanner: View {
    let session: GameSession
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 32) {
                Image(systemName: session.iconName)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Color.forSession(session))
                    .frame(width: 90)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Continue \(session.title)")
                        .font(.title3.bold())
                    Text(session.players.map(\.name).formatted(.list(type: .and)))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)
            }
            .padding(36)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.card)
    }
}
