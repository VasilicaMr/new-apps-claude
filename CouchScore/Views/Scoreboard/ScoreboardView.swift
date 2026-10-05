import SwiftUI

/// Full-screen scoreboard driven by the Siri Remote:
/// click a player = score, hold = more options, Play/Pause = undo, Menu = back to the app.
struct ScoreboardView: View {
    let matchID: UUID

    @Environment(AppStore.self) private var store
    @State private var padParticipant: Participant?
    @State private var confirmFinish = false
    @State private var targetPromptDismissed = false

    var body: some View {
        ZStack {
            Rectangle().fill(.appBackground).ignoresSafeArea()

            if let match = store.match(id: matchID) {
                if match.isFinished {
                    ResultsView(match: match)
                } else {
                    board(match)
                }
            }
        }
    }

    private func board(_ match: Match) -> some View {
        let count = match.participants.count
        let columns = count <= 4 ? max(count, 1) : (count <= 6 ? 3 : 4)
        let compact = count > 4
        let leaderIDs = Set(match.leaders.map(\.id))

        return VStack(spacing: 40) {
            header(match)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: columns), spacing: 40) {
                ForEach(match.participants) { participant in
                    Button {
                        primaryAction(for: participant, in: match)
                    } label: {
                        ScoreCard(participant: participant, isLeader: leaderIDs.contains(participant.id), compact: compact)
                    }
                    .buttonStyle(.card)
                    .contextMenu {
                        Button("+1") { record(1, participant) }
                        Button("−1") { record(-1, participant) }
                        Button("Enter Points…") { padParticipant = participant }
                    }
                }
            }

            Spacer(minLength: 0)

            Text(hint(for: match))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 50)
        .onPlayPauseCommand { undo() }
        .sheet(item: $padParticipant) { participant in
            PointsPadView(participant: participant, countsDown: match.game.rules.mode == .countDown) { delta in
                record(delta, participant)
            }
        }
        .alert("Finish this game?", isPresented: $confirmFinish) {
            Button("Finish & Save") { finish() }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text(match.winnerText)
        }
        .alert(match.winnerText, isPresented: targetPromptBinding(match)) {
            Button("Finish & Save") { finish() }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("The game's end score was reached.")
        }
        .onChange(of: match.reachedTarget) { _, reached in
            if !reached { targetPromptDismissed = false }
        }
    }

    private func header(_ match: Match) -> some View {
        HStack(spacing: 24) {
            Image(systemName: match.game.symbol)
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(match.game.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(match.game.name)
                    .font(.title2.weight(.bold))
                Text(match.game.rules.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!match.canUndo)
            Button {
                confirmFinish = true
            } label: {
                Label("Finish", systemImage: "flag.checkered")
            }
        }
    }

    private func hint(for match: Match) -> String {
        let click = match.game.rules.entry == .tally ? "Click: +1" : "Click: enter points"
        return "\(click)   ·   Hold: more options   ·   ⏯ Play/Pause: undo"
    }

    private func targetPromptBinding(_ match: Match) -> Binding<Bool> {
        Binding(
            get: { match.reachedTarget && !targetPromptDismissed && padParticipant == nil },
            set: { if !$0 { targetPromptDismissed = true } }
        )
    }

    private func primaryAction(for participant: Participant, in match: Match) {
        switch match.game.rules.entry {
        case .tally: record(1, participant)
        case .points: padParticipant = participant
        }
    }

    private func record(_ delta: Int, _ participant: Participant) {
        withAnimation(.snappy) {
            store.record(delta, for: participant.id, in: matchID)
        }
    }

    private func undo() {
        withAnimation(.snappy) {
            store.undo(in: matchID)
        }
    }

    private func finish() {
        withAnimation {
            store.finish(matchID)
        }
    }
}

private struct ScoreCard: View {
    let participant: Participant
    let isLeader: Bool
    let compact: Bool

    private var color: Color { PlayerPalette.color(participant.colorIndex) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(participant.name)
                    .font(compact ? .title3.weight(.semibold) : .title2.weight(.bold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isLeader {
                    Image(systemName: "crown.fill")
                        .font(compact ? .title3 : .title2)
                        .foregroundStyle(.yellow)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            Spacer(minLength: 0)
            Text("\(participant.score)")
                .font(.system(size: compact ? 120 : 190, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .contentTransition(.numericText(value: Double(participant.score)))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(36)
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 330 : 520)
        .background(
            LinearGradient(colors: [color.opacity(0.9), color.opacity(0.45)], startPoint: .top, endPoint: .bottom)
        )
    }
}
