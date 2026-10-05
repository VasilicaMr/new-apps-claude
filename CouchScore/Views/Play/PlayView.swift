import SwiftUI

/// Navigation value for the setup screen. `nil` game means "create a new custom game".
struct SetupRequest: Hashable {
    var game: GameDefinition?
}

struct PlayView: View {
    @Environment(AppStore.self) private var store
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 56) {
                    if let active = store.activeMatch {
                        ContinueBanner(match: active) {
                            store.presentedMatchID = active.id
                        }
                    }

                    GameRow(title: "Your Games") {
                        NavigationLink(value: SetupRequest(game: nil)) {
                            NewGameTile()
                        }
                        .buttonStyle(.card)

                        ForEach(store.customGames) { game in
                            NavigationLink(value: SetupRequest(game: game)) {
                                GameTile(game: game)
                            }
                            .buttonStyle(.card)
                            .contextMenu {
                                Button("Delete \(game.name)", role: .destructive) {
                                    store.deleteCustomGame(game)
                                }
                            }
                        }
                    }

                    ForEach(GameCategory.allCases) { category in
                        GameRow(title: category.title) {
                            ForEach(GameCatalog.games(in: category)) { game in
                                NavigationLink(value: SetupRequest(game: game)) {
                                    GameTile(game: game)
                                }
                                .buttonStyle(.card)
                            }
                        }
                    }
                }
                .padding(.vertical, 40)
            }
            .background(.appBackground)
            .navigationDestination(for: SetupRequest.self) { request in
                MatchSetupView(game: request.game) {
                    path = NavigationPath()
                }
            }
        }
    }
}

private struct GameRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 80)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 40) {
                    content
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 20)
            }
            .scrollClipDisabled()
        }
    }
}

struct GameTile: View {
    let game: GameDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: game.symbol)
                .font(.system(size: 56, weight: .semibold))
            Spacer(minLength: 0)
            Text(game.name)
                .font(.headline)
                .lineLimit(2)
            Text(game.rules.summary)
                .font(.caption)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(width: 330, height: 230, alignment: .leading)
        .background(
            LinearGradient(colors: [game.tint, game.tint.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

private struct NewGameTile: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 64))
            Text("New Custom Game")
                .font(.headline)
            Text("Any game, your rules")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 330, height: 230)
        .background(Color.white.opacity(0.08))
    }
}

private struct ContinueBanner: View {
    let match: Match
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 32) {
                Image(systemName: match.game.symbol)
                    .font(.system(size: 60, weight: .semibold))
                    .frame(width: 100)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Continue \(match.game.name)")
                        .font(.title2.weight(.bold))
                    Text(match.standings.map { "\($0.name) \($0.score)" }.joined(separator: "  ·  "))
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 64))
            }
            .foregroundStyle(.white)
            .padding(40)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [match.game.tint, match.game.tint.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
            )
        }
        .buttonStyle(.card)
        .padding(.horizontal, 80)
    }
}
