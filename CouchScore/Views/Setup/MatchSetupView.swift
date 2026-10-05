import SwiftUI

/// Pick players and adjust the rules before starting. Also where custom games are created.
struct MatchSetupView: View {
    @Environment(AppStore.self) private var store

    private let original: GameDefinition?
    private let onStarted: () -> Void

    @State private var game: GameDefinition
    @State private var selectedPlayerIDs: [UUID] = []
    @State private var newPlayerName = ""
    @State private var rememberGame = true
    @State private var didPreselect = false

    init(game: GameDefinition?, onStarted: @escaping () -> Void) {
        self.original = game
        self.onStarted = onStarted
        _game = State(initialValue: game ?? .newCustom())
    }

    private var trimmedName: String { game.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canStart: Bool { !trimmedName.isEmpty && !selectedPlayerIDs.isEmpty }

    var body: some View {
        HStack(alignment: .top, spacing: 60) {
            List {
                Section("Game") {
                    if game.isCustom {
                        TextField("Game name", text: $game.name)
                        Picker("Icon", selection: $game.symbol) {
                            ForEach(GameCatalog.customSymbols, id: \.self) { symbol in
                                Label(symbol, systemImage: symbol)
                                    .labelStyle(.iconOnly)
                                    .tag(symbol)
                            }
                        }
                    } else {
                        Label(game.name, systemImage: game.symbol)
                            .font(.title3.weight(.semibold))
                    }
                }

                Section("Scoring") {
                    Picker("Winner", selection: $game.rules.mode) {
                        ForEach(ScoringMode.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Scoring", selection: $game.rules.entry) {
                        ForEach(EntryStyle.allCases) { Text($0.title).tag($0) }
                    }
                    if game.rules.mode == .countDown {
                        Picker("Start at", selection: $game.rules.startingScore) {
                            ForEach(Self.options([101, 201, 301, 501, 701, 1001], including: game.rules.startingScore), id: \.self) {
                                Text("\($0)").tag($0)
                            }
                        }
                    } else {
                        Picker(game.rules.mode == .highestWins ? "Play to" : "Game ends at", selection: $game.rules.target) {
                            Text("No limit").tag(Int?.none)
                            ForEach(Self.options(Self.targetOptions, including: game.rules.target), id: \.self) {
                                Text("\($0)").tag(Int?.some($0))
                            }
                        }
                    }
                }

                if game.isCustom && original == nil {
                    Section {
                        Toggle("Save to Your Games", isOn: $rememberGame)
                    }
                }
            }
            .frame(width: 820)

            VStack(alignment: .leading, spacing: 30) {
                List {
                    Section("Who's playing?") {
                        TextField("Add a player or team", text: $newPlayerName)
                            .onSubmit(addPlayer)

                        ForEach(store.players) { player in
                            Button {
                                toggle(player)
                            } label: {
                                PlayerRow(player: player, order: selectedPlayerIDs.firstIndex(of: player.id))
                            }
                        }
                    }
                }

                Button(action: start) {
                    Label("Start Game", systemImage: "play.fill")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canStart)
            }
        }
        .padding(.horizontal, 80)
        .background(.appBackground)
        .navigationTitle(original == nil ? "New Game" : game.name)
        .onChange(of: game.rules.mode) { _, mode in
            if mode == .countDown && game.rules.startingScore <= 0 {
                game.rules.startingScore = 501
                game.rules.entry = .points
            }
        }
        .onAppear {
            guard !didPreselect else { return }
            didPreselect = true
            selectedPlayerIDs = store.lastGroup
        }
    }

    private func toggle(_ player: Player) {
        if let index = selectedPlayerIDs.firstIndex(of: player.id) {
            selectedPlayerIDs.remove(at: index)
        } else {
            selectedPlayerIDs.append(player.id)
        }
    }

    private func addPlayer() {
        guard let player = store.addPlayer(named: newPlayerName) else { return }
        if !selectedPlayerIDs.contains(player.id) {
            selectedPlayerIDs.append(player.id)
        }
        newPlayerName = ""
    }

    private func start() {
        guard canStart else { return }
        var final = game
        final.name = trimmedName
        if final.isCustom && (original != nil || rememberGame) {
            store.saveCustomGame(final)
        }
        let players = selectedPlayerIDs.compactMap { id in store.players.first { $0.id == id } }
        store.startMatch(game: final, players: players)
        onStarted()
    }

    private static let targetOptions = [3, 5, 7, 10, 11, 12, 15, 21, 25, 50, 100, 121, 150, 200, 250, 300, 500, 1000, 5000, 10000]

    private static func options(_ values: [Int], including current: Int?) -> [Int] {
        guard let current, !values.contains(current) else { return values }
        return (values + [current]).sorted()
    }
}

private struct PlayerRow: View {
    let player: Player
    let order: Int?

    var body: some View {
        HStack(spacing: 20) {
            Circle()
                .fill(PlayerPalette.color(player.colorIndex))
                .frame(width: 28, height: 28)
            Text(player.name)
            Spacer()
            if let order {
                Text("\(order + 1)")
                    .font(.headline.monospacedDigit())
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(PlayerPalette.color(player.colorIndex)))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
