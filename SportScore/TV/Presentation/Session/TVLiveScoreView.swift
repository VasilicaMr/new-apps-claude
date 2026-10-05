import SwiftUI

/// Full-screen scoreboard for Apple TV, driven by the same `LiveScoreViewModel` and
/// scoring engines as iOS.
///
/// Siri Remote:
/// - Rally / goal sports: click a player's card to give them the point (like the iOS split layout).
/// - Turn-based sports: everyone's score is in the strip on top; the current player scores in the
///   big panel below. The turn passes automatically and focus stays on the same button, so the next
///   player can score with one click.
/// - Play/Pause undoes the most recent entry; Menu leaves the scoreboard (the game is saved and can be resumed).
struct TVLiveScoreView: View {
    @State var viewModel: LiveScoreViewModel
    let coordinator: TVAppCoordinator

    @State private var activePlayerID: UUID?
    @State private var showGameOverOverlay = true
    /// Player whose points are being typed on the number pad (home games).
    @State private var padPlayer: Player?
    @Namespace private var focusNamespace
    @FocusState private var resultFocused: Bool
    @Environment(\.resetFocus) private var resetFocus

    var body: some View {
        ZStack {
            // Opaque backdrop: without it the screens underneath show through the full-screen cover.
            LinearGradient(
                colors: [TVTheme.Colors.scoreboardTop, TVTheme.Colors.scoreboardBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let session = viewModel.session {
                let showsOverlay = viewModel.isGameOver && showGameOverOverlay
                mainContent(session: session)
                    .overlay(alignment: .bottom) { feedback(session: session) }
                    // Nothing behind the result can take focus, so the remote stays in the overlay.
                    .disabled(showsOverlay)
                if showsOverlay {
                    gameOverOverlay(session: session)
                }
            } else if viewModel.isLoading {
                ProgressView("Loading…")
            } else {
                ContentUnavailableView(
                    "Session not found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The game session could not be loaded.")
                )
            }
        }
        .focusScope(focusNamespace)
        .onAppear { coordinator.liveScoreDidAppear() }
        .task {
            await viewModel.load()
            if let first = viewModel.session?.players.first {
                activePlayerID = viewModel.entryContexts[first.id]?.isPlayerFinished == true
                    ? viewModel.nextPlayer(after: first.id)
                    : first.id
            }
            // Focus was decided while loading (nothing to focus yet); move it to the score buttons.
            try? await Task.sleep(for: .milliseconds(150))
            resetFocus(in: focusNamespace)
        }
        .onChange(of: viewModel.isGameOver) { _, isOver in
            if isOver { showGameOverOverlay = true }
        }
        .onPlayPauseCommand { undoMostRecent() }
        .sheet(item: $padPlayer) { player in
            TVNumberPadView(title: "Points for \(player.name)", confirmTitle: { "Add \($0)" }) { points in
                if let session = viewModel.session {
                    submit(ScoreEntry(value: points), for: player, in: session)
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    /// Rally/goal sports and "tally" home games let any player score at any time, so there is no active player.
    private func usesTurns(_ session: GameSession) -> Bool {
        TVHeadToHead.unit(for: session) == nil
    }

    // MARK: - Layout

    private func mainContent(session: GameSession) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            header(session: session)

            if usesTurns(session) {
                playersStrip(session: session)
                entryPanel(session: session)
            } else {
                scoreBoard(session: session, turns: false)
                Spacer(minLength: 0)
            }

            Text(hint(for: session))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private func header(session: GameSession) -> some View {
        HStack(spacing: 24) {
            Image(systemName: session.iconName)
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(Color.forSession(session))
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.title2.bold())
                if let rules = session.houseGame?.rules {
                    Text(rules.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if let variant = session.variant, variant != "Standard" {
                    Text(variant)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                undoMostRecent()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(session.frames.isEmpty)

            if !viewModel.isGameOver {
                Menu {
                    if session.sport == .houseGame,
                       let leaderID = HouseGameScoringEngine.leader(in: session),
                       let leader = session.players.first(where: { $0.id == leaderID }) {
                        Button("Finish — \(leader.name) wins (leader)") {
                            Task { await viewModel.endGameEarly(winnerID: leader.id) }
                        }
                    }
                    ForEach(session.players) { player in
                        Button("\(player.name) wins") {
                            Task { await viewModel.endGameEarly(winnerID: player.id) }
                        }
                    }
                    Button("No winner", role: .destructive) {
                        Task { await viewModel.endGameEarly(winnerID: nil) }
                    }
                } label: {
                    Label("End game", systemImage: "flag.checkered")
                }
            } else if !showGameOverOverlay {
                Button {
                    showGameOverOverlay = true
                } label: {
                    Label("Show result", systemImage: "trophy")
                }
            }
        }
        // Up from the score buttons reaches Undo / End game, which are far to the right.
        .focusSection()
    }

    private func scoreBoard(session: GameSession, turns: Bool) -> some View {
        let count = session.players.count
        let columnCount = turns ? min(count, 2) : min(count, 4)
        let unit = TVHeadToHead.unit(for: session)
        let isHouseTally = session.sport == .houseGame && !turns

        return TVGrid(columns: columnCount, spacing: 40) {
            ForEach(session.players) { player in
                Button {
                    if turns {
                        activePlayerID = player.id
                    } else {
                        submit(ScoreEntry(value: 1), for: player, in: session)
                    }
                } label: {
                    TVPlayerScoreCard(
                        player: player,
                        score: viewModel.currentScores[player.id] ?? .zero,
                        isActive: turns && player.id == activePlayerID,
                        isHighlighted: viewModel.flash?.playerID == player.id && viewModel.flash?.isBust == false,
                        unit: turns ? nil : unit,
                        isLarge: !turns
                    )
                }
                .buttonStyle(.card)
                .disabled(viewModel.isGameOver && !turns)
                .contextMenu {
                    if isHouseTally {
                        Button {
                            submit(ScoreEntry(value: -1), for: player, in: session)
                        } label: {
                            Label("−1 for \(player.name)", systemImage: "minus.circle")
                        }
                        Button {
                            padPlayer = player
                        } label: {
                            Label("Add points…", systemImage: "number")
                        }
                    }
                    Button {
                        Task {
                            await viewModel.undoLast(for: player)
                            if turns { activePlayerID = player.id }
                        }
                    } label: {
                        Label("Undo last entry for \(player.name)", systemImage: "arrow.uturn.backward")
                    }
                }
            }
        }
    }

    /// Everyone's score at a glance. Display only, so focus stays on the score buttons below.
    private func playersStrip(session: GameSession) -> some View {
        let count = CGFloat(max(session.players.count, 1))
        // All players always fit across the screen (1760pt is the TV's safe width).
        let chipWidth = min(420, (1760 - (count - 1) * 24) / count)

        return HStack(spacing: 24) {
            ForEach(session.players) { player in
                TVPlayerChip(
                    player: player,
                    score: viewModel.currentScores[player.id] ?? .zero,
                    isActive: player.id == activePlayerID,
                    isHighlighted: viewModel.flash?.playerID == player.id && viewModel.flash?.isBust == false,
                    width: chipWidth
                )
            }
        }
    }

    /// The current player's turn: who is up, their score, and the sport's score buttons.
    @ViewBuilder
    private func entryPanel(session: GameSession) -> some View {
        let player = session.players.first { $0.id == activePlayerID } ?? session.players.first

        if let player {
            let context = viewModel.entryContexts[player.id] ?? EntryContext()
            let score = viewModel.currentScores[player.id] ?? .zero

            HStack(alignment: .top, spacing: 60) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(context.isPlayerFinished ? "Finished" : "Now playing")
                        .font(.headline)
                        .foregroundStyle(.tint)
                    Text(player.name)
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(score.primary)
                        .font(.system(size: 110, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())
                        .animation(.bouncy, value: score.primary)
                    if let prompt = context.prompt {
                        Text(prompt)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if session.players.count > 1 {
                        Menu {
                            ForEach(session.players) { other in
                                Button(other.name) { activePlayerID = other.id }
                            }
                        } label: {
                            Label("Switch player", systemImage: "arrow.left.arrow.right")
                                .font(.callout)
                        }
                    }
                }
                .frame(width: 380, alignment: .leading)
                // Lets the score buttons reach "Switch player", which sits below them on the left.
                .focusSection()

                ScrollView {
                    Group {
                        if context.isPlayerFinished {
                            Label("\(player.name) has finished", systemImage: "checkmark.seal.fill")
                                .font(.title3.bold())
                                .foregroundStyle(.green)
                                .padding(.vertical, 30)
                        } else {
                            // Not re-created on each turn: focus stays on the button just used,
                            // so the next player can enter the same kind of score with one click.
                            TVScoreEntryView(
                                session: session,
                                activePlayer: player,
                                context: context,
                                onSubmit: { entry, scorer in submit(entry, for: scorer, in: session) }
                            )
                            .disabled(viewModel.isGameOver)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollClipDisabled()
                .environment(\.tvPreferredFocusNamespace, focusNamespace)
                .focusSection()
            }
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: TVTheme.Radius.panel))
            .focusSection()
        }
    }

    private func hint(for session: GameSession) -> String {
        let click = usesTurns(session)
            ? "The turn passes automatically"
            : "Click a player: \(TVHeadToHead.unit(for: session) ?? "Point")   ·   Hold: more options"
        return "\(click)   ·   ⏯ Undo   ·   Menu: leave, game is saved"
    }

    // MARK: - Feedback

    private func feedback(session: GameSession) -> some View {
        VStack(spacing: 16) {
            if let notice = viewModel.notice {
                noticeBanner(notice)
            }
            if let flash = viewModel.flash {
                flashBanner(flash)
            }
        }
        .padding(.bottom, 70)
        .animation(.snappy, value: viewModel.flash)
        .animation(.snappy, value: viewModel.notice)
        .allowsHitTesting(false)
    }

    private func flashBanner(_ flash: ScoreFlash) -> some View {
        HStack(spacing: 30) {
            Text(flash.text)
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .lineLimit(1)
            Text(flash.detail.map { "\(flash.playerName) · \($0)" } ?? flash.playerName)
                .font(.title3.bold())
                .lineLimit(2)
            Label("Undo", systemImage: "playpause.fill")
                .font(.headline)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 44)
        .padding(.vertical, 20)
        .background(flash.isBust ? Color.red : Color.green, in: RoundedRectangle(cornerRadius: TVTheme.Radius.panel))
        .shadow(radius: 16, y: 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task(id: flash.id) {
            try? await Task.sleep(for: .seconds(4))
            if viewModel.flash?.id == flash.id { viewModel.flash = nil }
        }
    }

    private func noticeBanner(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 36)
            .padding(.vertical, 16)
            .background(.orange, in: Capsule())
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: text) {
                try? await Task.sleep(for: .seconds(3))
                if viewModel.notice == text { viewModel.notice = nil }
            }
    }

    private func gameOverOverlay(session: GameSession) -> some View {
        ZStack {
            TVTheme.Colors.scrim.ignoresSafeArea()
            VStack(spacing: 36) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce, options: .nonRepeating)
                Text(viewModel.winner.map { "\($0.name) wins!" } ?? "Game Over")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))

                Button("View Results") {
                    coordinator.showResult(sessionID: session.id)
                }
                .buttonStyle(.borderedProminent)
                .focused($resultFocused)

                HStack(spacing: 30) {
                    Button {
                        Task {
                            if let player = await viewModel.undoMostRecent() {
                                activePlayerID = player.id
                            }
                        }
                    } label: {
                        Label("Undo last", systemImage: "arrow.uturn.backward")
                    }
                    Button("See scores") { showGameOverOverlay = false }
                    Button("Done") { coordinator.closeLiveScore() }
                }
            }
            .padding(80)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: TVTheme.Radius.sheet))
            .focusSection()
        }
        .task {
            // Focus the result as soon as it appears, instead of the score button that ended the game.
            try? await Task.sleep(for: .milliseconds(100))
            resultFocused = true
        }
    }

    // MARK: - Actions

    private func submit(_ entry: ScoreEntry, for player: Player, in session: GameSession) {
        let turnPasses = viewModel.submitEntry(entry, for: player)
        guard usesTurns(session), !viewModel.isGameOver else { return }
        if turnPasses || viewModel.entryContexts[player.id]?.isPlayerFinished == true {
            activePlayerID = viewModel.nextPlayer(after: player.id)
        }
    }

    private func undoMostRecent() {
        Task {
            if let player = await viewModel.undoMostRecent(),
               let session = viewModel.session, usesTurns(session) {
                activePlayerID = player.id
            }
        }
    }
}

/// Same rally/goal sports as the iOS `HeadToHeadEntryView`, plus "tally" home games.
enum TVHeadToHead {
    static func unit(for session: GameSession) -> String? {
        if let rules = session.houseGame?.rules {
            return rules.entry == .tally ? "+1" : nil
        }
        return unit(for: session.sport)
    }

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
}

struct TVPlayerScoreCard: View {
    let player: Player
    let score: DisplayScore
    let isActive: Bool
    var isHighlighted: Bool = false
    /// Shown at the bottom of head-to-head cards, where clicking the card scores.
    var unit: String? = nil
    var isLarge: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(player.name)
                    .font(isLarge ? .title2.bold() : .title3.bold())
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isActive {
                    Image(systemName: "arrowtriangle.right.fill")
                        .foregroundStyle(.tint)
                }
            }

            Text(score.primary)
                .font(.system(size: isLarge ? 180 : 110, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.bouncy, value: score.primary)

            if let secondary = score.secondary {
                Text(secondary)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let detail = score.detail {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            if let unit {
                Spacer(minLength: 0)
                Label(unit, systemImage: "plus.circle.fill")
                    .font(.title3.bold())
                    .foregroundStyle(.tint)
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity, minHeight: isLarge ? 520 : 280)
        .background(
            isHighlighted ? AnyShapeStyle(Color.green.opacity(0.3))
                : isActive ? AnyShapeStyle(.tint.opacity(0.18))
                : AnyShapeStyle(.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TVTheme.Radius.tile)
                .strokeBorder(isHighlighted ? Color.green : isActive ? Color.accentColor : Color.clear, lineWidth: 6)
        )
        .animation(.spring(duration: 0.3), value: isHighlighted)
    }
}

/// Compact player tile for the strip at the top of turn-based games.
struct TVPlayerChip: View {
    let player: Player
    let score: DisplayScore
    let isActive: Bool
    var isHighlighted: Bool = false
    let width: CGFloat

    private var fill: Color {
        isHighlighted ? .green.opacity(0.3) : isActive ? .accentColor.opacity(0.22) : TVTheme.Colors.surface
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(player.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isActive {
                    Text("TURN")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor))
                }
            }
            Text(score.primary)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText())
                .animation(.bouncy, value: score.primary)
            Text(score.secondary ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(24)
        .frame(width: width, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: TVTheme.Radius.tile))
        .overlay(
            RoundedRectangle(cornerRadius: TVTheme.Radius.tile)
                .strokeBorder(isHighlighted ? Color.green : isActive ? Color.accentColor : Color.clear, lineWidth: 5)
        )
        .animation(.spring(duration: 0.3), value: isHighlighted)
        .animation(.spring(duration: 0.3), value: isActive)
    }
}
