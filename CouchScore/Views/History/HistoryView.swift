import SwiftUI

struct HistoryView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.finishedMatches.isEmpty {
                    ContentUnavailableView(
                        "No games yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Finished games and their final scores show up here.")
                    )
                } else {
                    List {
                        ForEach(store.finishedMatches) { match in
                            NavigationLink(value: match.id) {
                                HistoryRow(match: match)
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    store.deleteMatch(match.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 80)
                }
            }
            .background(.appBackground)
            .navigationDestination(for: UUID.self) { id in
                if let match = store.match(id: id) {
                    MatchDetailView(match: match)
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let match: Match

    var body: some View {
        HStack(spacing: 30) {
            Image(systemName: match.game.symbol)
                .font(.title)
                .foregroundStyle(match.game.tint)
                .frame(width: 70)
            VStack(alignment: .leading, spacing: 6) {
                Text(match.game.name)
                    .font(.headline)
                Text(match.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(match.winnerText)
                .font(.callout.weight(.semibold))
        }
    }
}

private struct MatchDetailView: View {
    let match: Match

    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Label(match.game.name, systemImage: match.game.symbol)
                    .font(.title.weight(.bold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
                Text(match.winnerText)
                    .font(.title2.weight(.heavy))
                StandingsList(match: match)
                    .frame(maxWidth: 900)
                Button {
                    store.rematch(match.id)
                } label: {
                    Label("Play Again", systemImage: "arrow.clockwise")
                }
            }
            .padding(80)
            .frame(maxWidth: .infinity)
        }
        .background(.appBackground)
    }

    private var subtitle: String {
        let date = match.startedAt.formatted(date: .long, time: .shortened)
        guard let end = match.endedAt else { return date }
        let duration = Duration.seconds(end.timeIntervalSince(match.startedAt))
            .formatted(.units(allowed: [.hours, .minutes], width: .wide))
        return "\(date) · \(duration) · \(match.game.rules.summary)"
    }
}
