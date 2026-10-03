import SwiftUI

/// Builds the input panel for a sport. Every entry produced here must be one the
/// sport's engine understands (labels such as "hoop", "capture", "frameWin"…).
@MainActor
@ViewBuilder
func ScoreEntryView(
    session: GameSession,
    activePlayer: Player,
    context: EntryContext,
    onSubmit: @escaping (ScoreEntry, Player) -> Void
) -> some View {
    let submit: (ScoreEntry) -> Void = { onSubmit($0, activePlayer) }

    switch session.sport {
    case .darts:
        DartsEntryView(sport: session.sport, onSubmit: submit)
    case .archery:
        ArcheryEntryView(onSubmit: submit)
    case .bowlingTenPin, .bowlingCandlepin, .bowlingDuckpin:
        BowlingEntryView(maxPins: context.maxValue ?? 10, onSubmit: submit)
    case .snooker:
        SnookerEntryView(activePlayer: activePlayer, onSubmit: submit)
    case .discGolf:
        DiscGolfEntryView(onSubmit: submit)
    case .pokerTournament:
        PokerEntryView(activePlayer: activePlayer, stack: context.maxValue ?? .max, onSubmit: submit)
    case .backgammon:
        BackgammonEntryView(activePlayer: activePlayer, onSubmit: submit)
    case .scrabble:
        ScrabbleEntryView(onSubmit: submit)
    case .go:
        GoEntryView(onSubmit: submit)
    case .kubb:
        KubbEntryView(activePlayer: activePlayer, onSubmit: submit)

    // Rally / goal games: anyone can score at any time, so show a button per player.
    case .tennis, .padel, .tableTennis, .badminton, .squash, .racquetball, .pickleball,
         .airHockey, .foosball, .armWrestling:
        HeadToHeadEntryView(
            players: session.players,
            unit: HeadToHeadEntryView.unit(for: session.sport) ?? "Point",
            onSubmit: onSubmit
        )

    // Result-based games
    case .chess:
        ActionEntryView(actions: [
            EntryAction(title: "\(activePlayer.name) won", systemImage: "trophy.fill", isProminent: true) { ScoreEntry(value: 2, label: "win") },
            EntryAction(title: "Draw", systemImage: "equal") { ScoreEntry(value: 1, label: "draw") },
            EntryAction(title: "\(activePlayer.name) lost", systemImage: "xmark") { ScoreEntry(value: 0, label: "loss") },
        ], onSubmit: submit)
    case .checkers:
        ActionEntryView(actions: [
            EntryAction(title: "Captured a piece", systemImage: "plus.circle") { ScoreEntry(value: 1, label: "capture") },
            EntryAction(title: "\(activePlayer.name) won the game", systemImage: "trophy.fill", isProminent: true) { ScoreEntry(value: 0, label: "gameWin") },
        ], onSubmit: submit)
    case .pool:
        ActionEntryView(actions: [
            EntryAction(title: "\(activePlayer.name) won the rack", systemImage: "trophy.fill", isProminent: true) { ScoreEntry(value: 1, label: "rackWin") },
        ], onSubmit: submit)
    case .croquet:
        ActionEntryView(actions: [
            EntryAction(title: "Ran a hoop", systemImage: "arrow.right.circle", isProminent: true) { ScoreEntry(value: 1, label: "hoop") },
        ] + (session.variant == "Golf Croquet" ? [] : [
            EntryAction(title: "Pegged out — win", systemImage: "flag.checkered", tint: .orange) { ScoreEntry(value: 0, label: "pegOut") },
        ]), onSubmit: submit)

    default:
        QuickScoreEntryView(sport: session.sport, variant: session.variant, context: context, onSubmit: submit)
    }
}
