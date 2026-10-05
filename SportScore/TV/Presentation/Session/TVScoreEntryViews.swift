import SwiftUI

/// Apple TV counterpart of the iOS `ScoreEntryView` factory. Every view produces exactly
/// the same `ScoreEntry` values/labels/metadata as its iOS twin, so the shared scoring
/// engines behave identically; only the layout is adapted to focus + Siri Remote.
@MainActor
@ViewBuilder
func TVScoreEntryView(
    session: GameSession,
    activePlayer: Player,
    context: EntryContext,
    onSubmit: @escaping (ScoreEntry, Player) -> Void
) -> some View {
    let submit: (ScoreEntry) -> Void = { onSubmit($0, activePlayer) }

    switch session.sport {
    case .darts:
        TVDartsEntryView(onSubmit: submit)
    case .archery:
        TVArcheryEntryView(onSubmit: submit)
    case .bowlingTenPin, .bowlingCandlepin, .bowlingDuckpin:
        TVBowlingEntryView(maxPins: context.maxValue ?? 10, onSubmit: submit)
    case .snooker:
        TVSnookerEntryView(activePlayer: activePlayer, onSubmit: submit)
    case .discGolf:
        TVDiscGolfEntryView(onSubmit: submit)
    case .pokerTournament:
        TVPokerEntryView(activePlayer: activePlayer, stack: context.maxValue ?? .max, onSubmit: submit)
    case .backgammon:
        TVBackgammonEntryView(activePlayer: activePlayer, onSubmit: submit)
    case .scrabble:
        TVScrabbleEntryView(onSubmit: submit)
    case .go:
        TVGoEntryView(onSubmit: submit)
    case .kubb:
        TVKubbEntryView(activePlayer: activePlayer, onSubmit: submit)
    case .houseGame:
        TVHouseGameEntryView(rules: session.houseGame?.rules ?? HouseGameRules(), onSubmit: submit)

    // Result-based games
    case .chess:
        TVActionEntryView(actions: [
            TVEntryAction(title: "\(activePlayer.name) won", systemImage: "trophy.fill", isProminent: true) { ScoreEntry(value: 2, label: "win") },
            TVEntryAction(title: "Draw", systemImage: "equal") { ScoreEntry(value: 1, label: "draw") },
            TVEntryAction(title: "\(activePlayer.name) lost", systemImage: "xmark") { ScoreEntry(value: 0, label: "loss") },
        ], onSubmit: submit)
    case .checkers:
        TVActionEntryView(actions: [
            TVEntryAction(title: "Captured a piece", systemImage: "plus.circle") { ScoreEntry(value: 1, label: "capture") },
            TVEntryAction(title: "\(activePlayer.name) won the game", systemImage: "trophy.fill", isProminent: true) { ScoreEntry(value: 0, label: "gameWin") },
        ], onSubmit: submit)
    case .pool:
        TVActionEntryView(actions: [
            TVEntryAction(title: "\(activePlayer.name) won the rack", systemImage: "trophy.fill", isProminent: true) { ScoreEntry(value: 1, label: "rackWin") },
        ], onSubmit: submit)
    case .croquet:
        TVActionEntryView(actions: [
            TVEntryAction(title: "Ran a hoop", systemImage: "arrow.right.circle", isProminent: true) { ScoreEntry(value: 1, label: "hoop") },
        ] + (session.variant == "Golf Croquet" ? [] : [
            TVEntryAction(title: "Pegged out — win", systemImage: "flag.checkered", tint: .orange) { ScoreEntry(value: 0, label: "pegOut") },
        ]), onSubmit: submit)

    default:
        TVQuickScoreEntryView(sport: session.sport, variant: session.variant, context: context, onSubmit: submit)
    }
}

// MARK: - Focus

private struct PreferredFocusNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// Set by the scoreboard so each entry panel's main button gets focus when a game opens.
    var tvPreferredFocusNamespace: Namespace.ID? {
        get { self[PreferredFocusNamespaceKey.self] }
        set { self[PreferredFocusNamespaceKey.self] = newValue }
    }
}

private struct TVPrefersFocus: ViewModifier {
    @Environment(\.tvPreferredFocusNamespace) private var namespace
    var isPreferred = true

    func body(content: Content) -> some View {
        if let namespace {
            content.prefersDefaultFocus(isPreferred, in: namespace)
        } else {
            content
        }
    }
}

private extension View {
    /// Marks the button that should be focused when the scoreboard opens.
    func tvPrefersFocus(_ isPreferred: Bool = true) -> some View {
        modifier(TVPrefersFocus(isPreferred: isPreferred))
    }
}

// MARK: - Shared building blocks

private struct TVCaption: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.secondary)
    }
}

/// A selectable option (multiplier, sign, cube value…) that looks filled when selected.
private struct TVOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        if isSelected {
            Button(action: action) { label }.buttonStyle(.borderedProminent)
        } else {
            Button(action: action) { label }.buttonStyle(.bordered)
        }
    }

    private var label: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity)
    }
}

/// Coloured tile (archery rings, snooker balls) that lifts on focus.
private struct TVColorTile<Content: View>: View {
    let color: Color
    let action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, minHeight: 90)
                .background(color)
        }
        .buttonStyle(.card)
    }
}

/// − value + row used where iOS has steppers, sliders or ± buttons.
private struct TVAdjuster: View {
    let value: String
    var valueColor: Color = .primary
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 40) {
            Button(action: decrement) {
                Image(systemName: "minus").font(.title2.bold()).frame(width: 70, height: 50)
            }
            Text(value)
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
                .frame(minWidth: 200)
            Button(action: increment) {
                Image(systemName: "plus").font(.title2.bold()).frame(width: 70, height: 50)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick score (presets)

struct TVQuickScoreEntryView: View {
    let sport: SportType
    var variant: String? = nil
    var context: EntryContext = EntryContext()
    let onSubmit: (ScoreEntry) -> Void

    @State private var isNegative = false
    @State private var showCustom = false

    private var presets: [QuickPreset] {
        QuickScorePresets.presets(for: sport, variant: variant, context: context)
    }

    private var sign: Int { context.allowsNegative && isNegative ? -1 : 1 }

    var body: some View {
        VStack(spacing: 24) {

            TVGrid(columns: min(max(presets.count, 1), 4), spacing: 20) {
                ForEach(presets) { preset in
                    presetButton(preset)
                        .tvPrefersFocus(preset.id == presets.first?.id)
                }
            }
            if context.allowsNegative {
                HStack(spacing: 20) {
                    TVOptionButton(title: "+ Won", isSelected: !isNegative) { isNegative = false }
                    TVOptionButton(title: "− Paid", isSelected: isNegative) { isNegative = true }
                }
            }

            Button {
                showCustom = true
            } label: {
                Label("Custom…", systemImage: "number")
                    .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showCustom) {
            TVNumberPadView(
                title: isNegative ? "Points paid" : "Custom score",
                maxValue: sign > 0 ? context.maxValue : nil,
                confirmTitle: { "Add \(QuickScorePresets.format($0 * sign, signed: true))" },
                onCommit: { onSubmit(ScoreEntry(value: $0 * sign)) }
            )
        }
    }

    private func presetButton(_ preset: QuickPreset) -> some View {
        let value = preset.value < 0 ? preset.value : preset.value * sign
        return Button {
            onSubmit(ScoreEntry(value: value))
        } label: {
            VStack(spacing: 2) {
                Text(QuickScorePresets.format(value))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if let caption = preset.caption {
                    Text(caption)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        }
        .buttonStyle(.borderedProminent)
        .tint(value < 0 ? .red : .accentColor)
    }
}

// MARK: - Darts

struct TVDartsEntryView: View {
    let onSubmit: (ScoreEntry) -> Void

    @State private var multiplier = 1
    private let segments = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]

    var body: some View {
        VStack(spacing: 24) {

            TVGrid(columns: 10, spacing: 16, columnSpacing: 20) {
                ForEach(segments, id: \.self) { segment in
                    Button {
                        submit(value: multiplier * segment, meta: ["segment": "\(segment)", "multiplier": "\(multiplier)"])
                    } label: {
                        Text(label(for: segment))
                            .font(.headline.monospacedDigit())
                            .lineLimit(1)
                            .fixedSize()
                            .frame(maxWidth: .infinity)
                    }
                    .tvPrefersFocus(segment == 20)
                }
            }
            HStack(spacing: 20) {
                TVOptionButton(title: "Single", isSelected: multiplier == 1) { multiplier = 1 }
                TVOptionButton(title: "Double", isSelected: multiplier == 2) { multiplier = 2 }
                TVOptionButton(title: "Triple", isSelected: multiplier == 3) { multiplier = 3 }
            }

            HStack(spacing: 20) {
                Button("Bull (25)") { submit(value: 25, meta: ["segment": "bull", "multiplier": "1"]) }
                Button("D.Bull (50)") { submit(value: 50, meta: ["segment": "bull", "multiplier": "2"]) }
                Button("Miss (0)") { submit(value: 0, meta: ["segment": "0", "multiplier": "1"]) }
            }
            .font(.headline)
        }
    }

    private func label(for segment: Int) -> String {
        switch multiplier {
        case 3: "T\(segment)"
        case 2: "D\(segment)"
        default: "\(segment)"
        }
    }

    private func submit(value: Int, meta: [String: String]) {
        onSubmit(ScoreEntry(value: value, metadata: meta))
        multiplier = 1
    }
}

// MARK: - Archery

struct TVArcheryEntryView: View {
    let onSubmit: (ScoreEntry) -> Void

    private let rings: [(label: String, value: Int, color: Color)] = [
        ("X", 10, .yellow), ("10", 10, .yellow), ("9", 9, .yellow),
        ("8", 8, .red), ("7", 7, .red),
        ("6", 6, .blue), ("5", 5, .blue),
        ("4", 4, .black), ("3", 3, .black),
        ("2", 2, .white), ("1", 1, .white),
        ("M", 0, .gray),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TVCaption("Select arrow score")
            TVGrid(columns: 6, spacing: 20) {
                ForEach(rings, id: \.label) { ring in
                    TVColorTile(color: ring.color) {
                        let meta: [String: String]? = ring.label == "X" ? ["isX": "true"] : nil
                        onSubmit(ScoreEntry(value: ring.value, metadata: meta))
                    } content: {
                        Text(ring.label)
                            .font(.title2.bold())
                            .foregroundStyle(ring.color == .white || ring.color == .yellow ? Color.black : Color.white)
                    }
                    .tvPrefersFocus(ring.label == "10")
                }
            }
        }
    }
}

// MARK: - Bowling

struct TVBowlingEntryView: View {
    /// Pins still standing for this ball; the input can never exceed it.
    var maxPins: Int = 10
    let onSubmit: (ScoreEntry) -> Void

    private var allDownLabel: String {
        maxPins == 10 ? "Strike" : "Spare (\(maxPins))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            TVCaption("Pins knocked down")
            TVGrid(columns: 6, spacing: 16, columnSpacing: 20) {
                ForEach(0...max(maxPins, 0), id: \.self) { pins in
                    Button {
                        onSubmit(ScoreEntry(value: pins))
                    } label: {
                        Text("\(pins)")
                            .font(.title2.bold().monospacedDigit())
                            .frame(maxWidth: .infinity)
                    }
                    .tvPrefersFocus(pins == 0)
                }
            }
            HStack(spacing: 20) {
                Button("Gutter (0)") { onSubmit(ScoreEntry(value: 0)) }
                    .buttonStyle(.bordered)
                Button(allDownLabel) { onSubmit(ScoreEntry(value: maxPins)) }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(maxPins == 0)
            }
            .font(.headline)
        }
    }
}

// MARK: - Snooker

struct TVSnookerEntryView: View {
    let activePlayer: Player
    let onSubmit: (ScoreEntry) -> Void

    private let balls: [(name: String, value: Int, color: Color)] = [
        ("Red", 1, .red), ("Yellow", 2, .yellow), ("Green", 3, .green), ("Brown", 4, .brown),
        ("Blue", 5, .blue), ("Pink", 6, .pink), ("Black", 7, .black),
    ]

    var body: some View {
        VStack(spacing: 24) {
            TVGrid(columns: 7, spacing: 16, columnSpacing: 20) {
                ForEach(balls, id: \.value) { ball in
                    TVColorTile(color: TVTheme.Colors.surface) {
                        onSubmit(ScoreEntry(value: ball.value, metadata: ["ball": ball.name.lowercased()]))
                    } content: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(ball.color)
                                .frame(width: 54, height: 54)
                                .overlay(Circle().strokeBorder(TVTheme.Colors.outline, lineWidth: 2))
                            Text("\(ball.value)")
                                .font(.headline)
                        }
                        .padding(.vertical, 10)
                    }
                    .tvPrefersFocus(ball.value == 1)
                }
            }

            HStack(spacing: 20) {
                Button("Miss / End break") {
                    onSubmit(ScoreEntry(value: 0, metadata: ["miss": "true"]))
                }
                Menu {
                    ForEach(4...7, id: \.self) { penalty in
                        Button("Foul — \(penalty) to opponent") {
                            onSubmit(ScoreEntry(value: 0, metadata: ["foul": "\(penalty)"]))
                        }
                    }
                } label: {
                    Text("Foul…")
                }
            }
            .font(.headline)

            Button {
                onSubmit(ScoreEntry(value: 0, label: "frameWin"))
            } label: {
                Label("\(activePlayer.name) won the frame", systemImage: "flag.checkered")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Disc golf

struct TVDiscGolfEntryView: View {
    let onSubmit: (ScoreEntry) -> Void

    @State private var strokes = 3

    var body: some View {
        VStack(spacing: 24) {
            TVCaption("Strokes this hole")
            TVAdjuster(
                value: "\(strokes)",
                decrement: { strokes = max(1, strokes - 1) },
                increment: { strokes = min(20, strokes + 1) }
            )
            Button {
                onSubmit(ScoreEntry(value: strokes))
                strokes = 3
            } label: {
                Text("Record \(strokes) stroke\(strokes == 1 ? "" : "s")")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tvPrefersFocus()
        }
    }
}

// MARK: - Poker

struct TVPokerEntryView: View {
    let activePlayer: Player
    /// Chips the player currently has; a loss can't exceed it.
    var stack: Int = .max
    let onSubmit: (ScoreEntry) -> Void

    @State private var delta = 0
    @State private var isWin = true
    @State private var showPad = false

    var body: some View {
        VStack(spacing: 24) {
            TVCaption("Stack change for \(activePlayer.name)")

            HStack(spacing: 20) {
                TVOptionButton(title: "Win (+)", isSelected: isWin) { isWin = true }
                TVOptionButton(title: "Loss (−)", isSelected: !isWin) { isWin = false }
            }

            TVAdjuster(
                value: "\(isWin ? "+" : "−")\(delta)",
                valueColor: isWin ? .green : .red,
                decrement: { delta = max(0, delta - 100) },
                increment: { delta += 100 }
            )

            HStack(spacing: 16) {
                ForEach([100, 500, 1000, 2500], id: \.self) { value in
                    Button("\(value)") { delta = value }
                        .font(.headline)
                        .tvPrefersFocus(value == 100)
                }
                Button {
                    showPad = true
                } label: {
                    Image(systemName: "number")
                }
            }

            HStack(spacing: 20) {
                Button("Busted out") {
                    onSubmit(ScoreEntry(value: -stack, label: "eliminated"))
                    delta = 0
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(stack == .max || stack <= 0)

                Button {
                    let signed = isWin ? delta : -min(delta, stack)
                    onSubmit(ScoreEntry(value: signed))
                    delta = 0
                } label: {
                    Text("Record").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(delta == 0)
            }
        }
        .sheet(isPresented: $showPad) {
            TVNumberPadView(title: "Chips", confirmTitle: { "Set \($0)" }) { delta = $0 }
        }
    }
}

// MARK: - Backgammon

struct TVBackgammonEntryView: View {
    let activePlayer: Player
    let onSubmit: (ScoreEntry) -> Void

    @State private var cubeValue = 1
    private let cubeValues = [1, 2, 4, 8, 16, 32, 64]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            TVCaption("Doubling cube")
            TVGrid(columns: 7, spacing: 12, columnSpacing: 20) {
                ForEach(cubeValues, id: \.self) { value in
                    TVOptionButton(title: "\(value)", isSelected: cubeValue == value) { cubeValue = value }
                }
            }

            TVCaption("\(activePlayer.name) won with…")
            HStack(spacing: 20) {
                resultButton(label: "Single", value: 1)
                    .tvPrefersFocus()
                resultButton(label: "Gammon", value: 2)
                resultButton(label: "Backgammon", value: 3)
            }
        }
    }

    private func resultButton(label: String, value: Int) -> some View {
        Button {
            var meta = ["cubeValue": "\(cubeValue)"]
            if value == 2 { meta["gammon"] = "true" }
            if value == 3 { meta["backgammon"] = "true" }
            onSubmit(ScoreEntry(value: value, metadata: meta))
            cubeValue = 1
        } label: {
            VStack(spacing: 4) {
                Text(label).font(.headline)
                Text("+\(value * cubeValue)").font(.callout)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Scrabble

struct TVScrabbleEntryView: View {
    let onSubmit: (ScoreEntry) -> Void

    @State private var wordScore = 0
    @State private var isBingo = false
    @State private var isChallenged = false
    @State private var showPad = false

    private var total: Int { wordScore + (isBingo ? 50 : 0) }

    var body: some View {
        VStack(spacing: 24) {
            TVAdjuster(
                value: "\(total)",
                decrement: { wordScore = max(0, wordScore - 1) },
                increment: { wordScore += 1 }
            )
            if isBingo {
                Text("Bingo +50")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 16) {
                ForEach([5, 10, 15, 20, 30], id: \.self) { value in
                    Button("+\(value)") { wordScore += value }
                        .font(.headline)
                        .tvPrefersFocus(value == 5)
                }
                Button {
                    showPad = true
                } label: {
                    Image(systemName: "number")
                }
            }

            HStack(spacing: 20) {
                TVOptionButton(title: "Bingo (+50)", isSelected: isBingo) { isBingo.toggle() }
                TVOptionButton(title: "Challenged", isSelected: isChallenged) { isChallenged.toggle() }
            }

            Button {
                var meta: [String: String] = [:]
                if isBingo { meta["bingo"] = "true" }
                if isChallenged { meta["challenged"] = "true" }
                onSubmit(ScoreEntry(value: isChallenged ? 0 : total, metadata: meta.isEmpty ? nil : meta))
                wordScore = 0
                isBingo = false
                isChallenged = false
            } label: {
                Text(isChallenged ? "Challenged (0 pts)" : "Record \(total) pts")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isChallenged ? .red : .blue)
        }
        .sheet(isPresented: $showPad) {
            TVNumberPadView(title: "Word score", confirmTitle: { "Set \($0)" }) { wordScore = $0 }
        }
    }
}

// MARK: - Go

struct TVGoEntryView: View {
    let onSubmit: (ScoreEntry) -> Void

    @State private var territory = 0
    @State private var showPad = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            TVCaption("Stones captured")
            HStack(spacing: 20) {
                ForEach([1, 2, 3, 5], id: \.self) { n in
                    Button {
                        onSubmit(ScoreEntry(value: n, label: "capture"))
                    } label: {
                        Text("+\(n)").frame(maxWidth: .infinity)
                    }
                    .tvPrefersFocus(n == 1)
                }
            }

            Divider()

            TVCaption("End of game — territory")
            TVAdjuster(
                value: "\(territory)",
                decrement: { territory = max(0, territory - 1) },
                increment: { territory = min(361, territory + 1) }
            )
            HStack(spacing: 20) {
                Button("−10") { territory = max(0, territory - 10) }
                Button("+10") { territory = min(361, territory + 10) }
                Button {
                    showPad = true
                } label: {
                    Image(systemName: "number")
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                onSubmit(ScoreEntry(value: territory, label: "territory"))
                territory = 0
            } label: {
                Text("Submit final territory").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showPad) {
            TVNumberPadView(title: "Territory", maxValue: 361, confirmTitle: { "Set \($0)" }) { territory = $0 }
        }
    }
}

// MARK: - Kubb

struct TVKubbEntryView: View {
    let activePlayer: Player
    let onSubmit: (ScoreEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            TVCaption("Kubbs toppled this turn")
            TVGrid(columns: 6, spacing: 16, columnSpacing: 20) {
                ForEach(0...5, id: \.self) { n in
                    Button {
                        onSubmit(ScoreEntry(value: n, label: "kubb"))
                    } label: {
                        Text("\(n)").font(.title2.bold()).frame(maxWidth: .infinity)
                    }
                    .tvPrefersFocus(n == 1)
                }
            }
            Button {
                onSubmit(ScoreEntry(value: 0, label: "king", metadata: ["kingHit": "true"]))
            } label: {
                Label("\(activePlayer.name) toppled the king", systemImage: "crown.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }
}

// MARK: - Result-based games

struct TVEntryAction: Identifiable {
    let id = UUID()
    let title: String
    var systemImage: String? = nil
    var tint: Color? = nil
    var isProminent: Bool = false
    let entry: () -> ScoreEntry
}

/// A column of outcome buttons for result-based games (chess, pool racks, croquet hoops…).
struct TVActionEntryView: View {
    let actions: [TVEntryAction]
    let onSubmit: (ScoreEntry) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Indexed so the buttons keep their identity (and focus) when the turn passes.
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                Group {
                    if action.isProminent {
                        button(action).buttonStyle(.borderedProminent)
                    } else {
                        button(action).buttonStyle(.bordered)
                    }
                }
                .tvPrefersFocus(index == 0)
            }
        }
    }

    private func button(_ action: TVEntryAction) -> some View {
        Button {
            onSubmit(action.entry())
        } label: {
            Group {
                if let image = action.systemImage {
                    Label(action.title, systemImage: image)
                } else {
                    Text(action.title)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .tint(action.tint)
    }
}

// MARK: - Home & custom games

struct TVHouseGameEntryView: View {
    let rules: HouseGameRules
    let onSubmit: (ScoreEntry) -> Void

    @State private var isSubtracting = false
    @State private var showPad = false

    private var isCountDown: Bool { rules.mode == .countDown }
    /// Count-down games subtract by design, so they don't need the add/subtract switch.
    private var sign: Int { !isCountDown && isSubtracting ? -1 : 1 }

    private var presets: [Int] {
        isCountDown ? [10, 20, 26, 41, 45, 60, 81, 100] : [1, 2, 5, 10, 15, 20, 25, 50]
    }

    var body: some View {
        VStack(spacing: 18) {

            TVGrid(columns: 4, spacing: 20) {
                ForEach(presets, id: \.self) { value in
                    Button {
                        onSubmit(ScoreEntry(value: value * sign))
                    } label: {
                        Text(isCountDown ? "\(value)" : QuickScorePresets.format(value * sign, signed: true))
                            .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                            .frame(maxWidth: .infinity, minHeight: 60)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(sign < 0 ? .red : .accentColor)
                    .tvPrefersFocus(value == presets.first)
                }
            }
            if !isCountDown {
                HStack(spacing: 20) {
                    TVOptionButton(title: "+ Add", isSelected: !isSubtracting) { isSubtracting = false }
                    TVOptionButton(title: "− Subtract", isSelected: isSubtracting) { isSubtracting = true }
                }
            }

            Button {
                showPad = true
            } label: {
                Label("Enter points…", systemImage: "number")
                    .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showPad) {
            TVNumberPadView(
                title: isCountDown ? "Points scored" : (sign < 0 ? "Points to subtract" : "Points to add"),
                confirmTitle: { isCountDown ? "Score \($0)" : QuickScorePresets.format($0 * sign, signed: true) },
                onCommit: { onSubmit(ScoreEntry(value: $0 * sign)) }
            )
        }
    }
}
