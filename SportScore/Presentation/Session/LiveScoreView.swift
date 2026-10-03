import SwiftUI

struct LiveScoreView: View {
    @State var viewModel: LiveScoreViewModel
    var coordinator: HomeCoordinator

    @State private var activePlayerID: UUID?
    @State private var showGameOverOverlay = true
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// Two-player "one half each" layout; always used in landscape when available.
    @AppStorage("prefersSplitScoring") private var prefersSplit = false

    var body: some View {
        Group {
            if let session = viewModel.session {
                ZStack {
                    mainContent(session: session)
                    if viewModel.isGameOver && showGameOverOverlay {
                        gameOverOverlay
                    }
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
        .navigationTitle(viewModel.session?.sport.displayName ?? "Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        // Give the score buttons the whole screen during a game.
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.load()
            if let first = viewModel.session?.players.first {
                activePlayerID = viewModel.entryContexts[first.id]?.isPlayerFinished == true
                    ? viewModel.nextPlayer(after: first.id)
                    : first.id
            }
        }
        .onChange(of: viewModel.isGameOver) { _, isOver in
            if isOver { showGameOverOverlay = true }
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

    /// Rally and goal games let any player score at any time, so there is no active player.
    private func usesTurns(_ sport: SportType) -> Bool {
        HeadToHeadEntryView.unit(for: sport) == nil
    }

    /// Split layout works for two players with one-tap input (presets or point buttons).
    private func canSplit(_ session: GameSession) -> Bool {
        session.players.count == 2
            && (QuickScorePresets.sports.contains(session.sport) || !usesTurns(session.sport))
    }

    private func useSplit(_ session: GameSession) -> Bool {
        canSplit(session) && (prefersSplit || verticalSizeClass == .compact)
    }

    @ViewBuilder
    private func mainContent(session: GameSession) -> some View {
        if useSplit(session) {
            splitContent(session: session)
                .overlay(alignment: .bottom) { feedback(session: session) }
        } else {
            stackedContent(session: session)
        }
    }

    /// Confirmation + warnings, placed where they don't hide the score they refer to.
    private func feedback(session: GameSession) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if let notice = viewModel.notice {
                noticeBanner(notice)
            }
            if let flash = viewModel.flash {
                flashBanner(flash, session: session)
            }
        }
        .padding(.bottom, AppTheme.Spacing.sm)
        .animation(.snappy, value: viewModel.flash)
        .animation(.snappy, value: viewModel.notice)
    }

    @ViewBuilder
    private func stackedContent(session: GameSession) -> some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ScrollView {
                    scoreBoardSection(session: session)
                }
                .frame(minHeight: min(160, geo.size.height * 0.3))
                .overlay(alignment: .bottom) { feedback(session: session) }

                Divider()

                // The panel scrolls instead of being clipped when it doesn't fit
                // (landscape, small phones, large Dynamic Type).
                ViewThatFits(in: .vertical) {
                    entryPanel(session: session)
                    ScrollView {
                        entryPanel(session: session)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .frame(maxHeight: geo.size.height * 0.7)
                .background(.bar)
            }
        }
    }

    private func scoreBoardSection(session: GameSession) -> some View {
        let turns = usesTurns(session.sport)
        return LazyVGrid(
            columns: session.players.count > 2
                ? [GridItem(.adaptive(minimum: 140))]
                : Array(repeating: GridItem(.flexible()), count: max(session.players.count, 1)),
            spacing: AppTheme.Spacing.sm
        ) {
            ForEach(session.players) { player in
                PlayerScoreCard(
                    player: player,
                    score: viewModel.currentScores[player.id] ?? .zero,
                    isActive: turns && player.id == activePlayerID,
                    isHighlighted: viewModel.flash?.playerID == player.id,
                    onSelect: { if turns { activePlayerID = player.id } },
                    onUndo: {
                        Task {
                            await viewModel.undoLast(for: player)
                            if turns { activePlayerID = player.id }
                        }
                    }
                )
            }
        }
        .padding(AppTheme.Spacing.md)
    }

    @ViewBuilder
    private func entryPanel(session: GameSession) -> some View {
        let turns = usesTurns(session.sport)
        let player = session.players.first { $0.id == activePlayerID } ?? session.players.first

        VStack(spacing: AppTheme.Spacing.sm) {
            if let player {
                let context = viewModel.entryContexts[player.id] ?? EntryContext()

                if turns && session.players.count > 1 {
                    playerSelector(players: session.players)
                }
                if turns, let prompt = context.prompt {
                    Text(turns && session.players.count > 1 ? "\(player.name) · \(prompt)" : prompt)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                if turns && context.isPlayerFinished {
                    Label("\(player.name) has finished", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding(.vertical, AppTheme.Spacing.md)
                } else {
                    ScoreEntryView(
                        session: session,
                        activePlayer: player,
                        context: context,
                        onSubmit: { entry, scorer in submit(entry, for: scorer, in: session) }
                    )
                    .id("\(player.id)-\(session.frames.count)")
                    .disabled(viewModel.isGameOver)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
    }

    // MARK: - Split layout (two players, one half each)

    private func splitContent(session: GameSession) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                if index > 0 { Divider() }
                splitColumn(player: player, session: session)
            }
        }
    }

    private func splitColumn(player: Player, session: GameSession) -> some View {
        let context = viewModel.entryContexts[player.id] ?? EntryContext()
        let score = viewModel.currentScores[player.id] ?? .zero
        let turns = usesTurns(session.sport)
        let isActive = turns && activePlayerID == player.id
        let isHighlighted = viewModel.flash?.playerID == player.id && viewModel.flash?.isBust == false

        return ScrollView {
            VStack(spacing: AppTheme.Spacing.sm) {
                HStack {
                    Text(player.name)
                        .font(.title3.bold())
                        .lineLimit(1)
                    Spacer()
                    Button {
                        Task {
                            await viewModel.undoLast(for: player)
                            if turns { activePlayerID = player.id }
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Undo last entry for \(player.name)")
                }

                Text(score.primary)
                    .font(AppTheme.Typography.scoreLarge)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.bouncy, value: score.primary)
                if let secondary = score.secondary {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if turns, let prompt = context.prompt {
                    Text(prompt)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if turns && context.isPlayerFinished {
                    Label("Finished", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding(.vertical, AppTheme.Spacing.md)
                } else if let unit = HeadToHeadEntryView.unit(for: session.sport) {
                    Button {
                        submit(ScoreEntry(value: 1), for: player, in: session)
                    } label: {
                        VStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 48))
                            Text(unit)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, minHeight: 160)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("\(unit), \(player.name)")
                } else {
                    QuickScoreEntryView(
                        sport: session.sport,
                        variant: session.variant,
                        context: context,
                        compact: true,
                        onSubmit: { submit($0, for: player, in: session) }
                    )
                    .id("\(player.id)-\(session.frames.count)")
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .scrollBounceBehavior(.basedOnSize)
        .disabled(viewModel.isGameOver)
        .background(isHighlighted ? AnyShapeStyle(Color.green.opacity(0.18)) : isActive ? AnyShapeStyle(.tint.opacity(0.08)) : AnyShapeStyle(.clear))
        .animation(.easeOut(duration: 0.25), value: isHighlighted)
    }

    // MARK: - Feedback

    private func flashBanner(_ flash: ScoreFlash, session: GameSession) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 0) {
                Text(flash.text)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(flash.detail.map { "\(flash.playerName) · \($0)" } ?? flash.playerName)
                    .font(.headline)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button {
                Task {
                    if let player = await viewModel.undoMostRecent(), usesTurns(session.sport) {
                        activePlayerID = player.id
                    }
                }
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.headline)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(flash.isBust ? .red : .green)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(flash.isBust ? Color.red : Color.green, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .shadow(radius: 8, y: 4)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .task(id: flash.id) {
            try? await Task.sleep(for: .seconds(4))
            if viewModel.flash?.id == flash.id { viewModel.flash = nil }
        }
        .onTapGesture { viewModel.flash = nil }
    }

    private func submit(_ entry: ScoreEntry, for player: Player, in session: GameSession) {
        let turnPasses = viewModel.submitEntry(entry, for: player)
        guard usesTurns(session.sport), !viewModel.isGameOver else { return }
        if turnPasses || viewModel.entryContexts[player.id]?.isPlayerFinished == true {
            activePlayerID = viewModel.nextPlayer(after: player.id)
        }
    }

    private func noticeBanner(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(.orange, in: Capsule())
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: text) {
                try? await Task.sleep(for: .seconds(3))
                if viewModel.notice == text { viewModel.notice = nil }
            }
            .onTapGesture { viewModel.notice = nil }
    }

    private func playerSelector(players: [Player]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(players) { p in
                    playerSelectorButton(p)
                }
            }
        }
    }

    @ViewBuilder
    private func playerSelectorButton(_ p: Player) -> some View {
        if p.id == activePlayerID {
            Button(p.name) { activePlayerID = p.id }
                .buttonStyle(.borderedProminent)
                .font(.caption.bold())
                .lineLimit(1)
        } else {
            Button(p.name) { activePlayerID = p.id }
                .buttonStyle(.bordered)
                .font(.caption.bold())
                .lineLimit(1)
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)
                Text(viewModel.winner.map { "\($0.name) wins!" } ?? "Game Over")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Button("View Results") {
                    if let session = viewModel.session {
                        coordinator.push(.sessionResult(sessionID: session.id))
                    }
                }
                .buttonStyle(.borderedProminent)

                HStack(spacing: AppTheme.Spacing.sm) {
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
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .padding(AppTheme.Spacing.xl)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    Task {
                        if let player = await viewModel.undoMostRecent(),
                           let session = viewModel.session, usesTurns(session.sport) {
                            activePlayerID = player.id
                        }
                    }
                } label: {
                    Label("Undo last entry", systemImage: "arrow.uturn.backward")
                }
                .disabled(viewModel.session?.frames.isEmpty ?? true)

                if let session = viewModel.session, canSplit(session) {
                    Toggle(isOn: $prefersSplit) {
                        Label("Split screen", systemImage: "rectangle.split.2x1")
                    }
                }

                if !viewModel.isGameOver {
                    Menu {
                        ForEach(viewModel.session?.players ?? []) { player in
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
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

struct PlayerScoreCard: View {
    let player: Player
    let score: DisplayScore
    let isActive: Bool
    var isHighlighted: Bool = false
    let onSelect: () -> Void
    let onUndo: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Button(action: onSelect) {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text(player.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(score.primary)
                        .font(AppTheme.Typography.scoreLarge)
                        .minimumScaleFactor(0.3)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .animation(.bouncy, value: score.primary)

                    if let secondary = score.secondary {
                        Text(secondary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let detail = score.detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isActive ? .isSelected : [])

            // A sibling of the card button (not nested), so taps reliably hit Undo.
            Button(action: onUndo) {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .accessibilityLabel("Undo last entry for \(player.name)")
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            isActive
                ? AnyShapeStyle(.tint.opacity(0.12))
                : AnyShapeStyle(.quaternary),
            in: RoundedRectangle(cornerRadius: AppTheme.Radius.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .strokeBorder(isHighlighted ? Color.green : isActive ? Color.accentColor : Color.clear,
                              lineWidth: isHighlighted ? 4 : 2)
        )
        .scaleEffect(isHighlighted ? 1.03 : 1)
        .animation(.spring(duration: 0.3), value: isHighlighted)
    }
}
