import SwiftUI

/// One big button per player for rally/goal games, where any player can score
/// at any moment and there is no turn order.
struct HeadToHeadEntryView: View {
    /// What one tap means for rally/goal sports; nil for turn-based sports.
    static func unit(for sport: SportType) -> String? {
        switch sport {
        case .tennis, .padel, .tableTennis, .badminton, .squash, .racquetball, .pickleball:
            return "Point won"
        case .airHockey, .foosball:
            return "Goal"
        case .armWrestling:
            return "Won the pull"
        default:
            return nil
        }
    }

    let players: [Player]
    var unit: String = "Point"
    let onSubmit: (ScoreEntry, Player) -> Void

    var body: some View {
        let columns = players.count == 2
            ? [GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 140))]
        LazyVGrid(columns: columns, spacing: AppTheme.Spacing.sm) {
            ForEach(players) { player in
                Button {
                    onSubmit(ScoreEntry(value: 1), player)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                        Text(player.name)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(unit)
                            .font(.caption)
                            .opacity(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("\(unit) to \(player.name)")
            }
        }
    }
}
