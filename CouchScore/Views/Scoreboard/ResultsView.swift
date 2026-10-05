import SwiftUI

struct ResultsView: View {
    let match: Match

    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 40) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 110))
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, options: .nonRepeating)

            Text(match.winnerText)
                .font(.system(size: 76, weight: .heavy, design: .rounded))

            Text(match.game.name)
                .font(.title3)
                .foregroundStyle(.secondary)

            StandingsList(match: match)
                .frame(maxWidth: 900)

            HStack(spacing: 40) {
                Button {
                    store.rematch(match.id)
                } label: {
                    Label("Rematch", systemImage: "arrow.clockwise")
                }
                Button {
                    store.presentedMatchID = nil
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
            }
        }
        .padding(80)
    }
}

/// Ranked final scores, shared by the results screen and history detail.
struct StandingsList: View {
    let match: Match

    var body: some View {
        let standings = match.standings
        VStack(spacing: 16) {
            ForEach(Array(standings.enumerated()), id: \.element.id) { _, participant in
                HStack(spacing: 24) {
                    Text(rankLabel(for: participant, in: standings))
                        .font(.title3.weight(.bold).monospacedDigit())
                        .frame(width: 70, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(PlayerPalette.color(participant.colorIndex))
                        .frame(width: 26, height: 26)
                    Text(participant.name)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text("\(participant.score)")
                        .font(.title2.weight(.heavy).monospacedDigit())
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 20).fill(.white.opacity(0.07)))
            }
        }
    }

    /// Players with equal scores share a rank (1, 1, 3…).
    private func rankLabel(for participant: Participant, in standings: [Participant]) -> String {
        let rank = (standings.firstIndex { $0.score == participant.score } ?? 0) + 1
        return "#\(rank)"
    }
}
