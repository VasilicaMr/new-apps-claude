import SwiftUI

/// Create, edit or delete a custom game. Opening a built-in home game here makes an
/// editable custom copy ("Customize"), leaving the template untouched.
struct TVCustomGameEditorView: View {
    let coordinator: TVAppCoordinator

    @State private var game: HouseGame
    @State private var confirmDelete = false
    @State private var isSaving = false

    /// Editing a game that already exists in "Your Games".
    private let isExisting: Bool

    init(game: HouseGame?, coordinator: TVAppCoordinator) {
        self.coordinator = coordinator
        let editable = game.map { $0.isCustom ? $0 : $0.customCopy() } ?? .newCustom()
        _game = State(initialValue: editable)
        isExisting = game?.isCustom == true
    }

    private var trimmedName: String { game.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        HStack(alignment: .top, spacing: 80) {
            VStack(alignment: .leading, spacing: 36) {
                Text(isExisting ? "Edit Game" : "New Custom Game")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))

                TVHouseGameTile(game: HouseGame(
                    id: game.id,
                    name: trimmedName.isEmpty ? "Your game" : trimmedName,
                    symbol: game.symbol,
                    category: nil,
                    rules: game.rules
                ))
                .frame(width: 420)

                Spacer(minLength: 0)

                Button {
                    save(andPlay: true)
                } label: {
                    Label("Save & Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(trimmedName.isEmpty || isSaving)

                Button {
                    save(andPlay: false)
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .disabled(trimmedName.isEmpty || isSaving)

                if isExisting {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete Game", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(width: 560)
            // The buttons sit at the bottom, below anything to the left of the form's top rows,
            // so each column is a focus section: pressing left/right always reaches the other.
            .focusSection()

            List {
                Section("Game") {
                    TextField("Game name", text: $game.name)
                    // In a tvOS list a picker defaults to a segmented control, which squeezes long
                    // option lists into "…". Icons get their own page; the rules use menus.
                    Picker(selection: $game.symbol) {
                        ForEach(HouseGameCatalog.customSymbols, id: \.self) { symbol in
                            Image(systemName: symbol).tag(symbol)
                        }
                    } label: {
                        Label("Icon", systemImage: game.symbol)
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    Picker("Winner", selection: $game.rules.mode) {
                        ForEach(HouseScoringMode.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Scoring", selection: $game.rules.entry) {
                        ForEach(HouseEntryStyle.allCases) { Text($0.title).tag($0) }
                    }
                    if game.rules.mode == .countDown {
                        Picker("Start at", selection: $game.rules.startingScore) {
                            ForEach(Self.options(Self.startOptions, including: game.rules.startingScore), id: \.self) {
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
                } header: {
                    Text("Scoring")
                } footer: {
                    Text(footer)
                }
            }
            .pickerStyle(.menu)
            .focusSection()
        }
        .onChange(of: game.rules.mode) { _, mode in
            // Count-down games (like darts) need a start score and per-turn points.
            if mode == .countDown {
                if game.rules.startingScore <= 0 { game.rules.startingScore = 501 }
                game.rules.entry = .points
            }
        }
        .alert("Delete \(trimmedName)?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                Task {
                    await coordinator.customGames.delete(game)
                    coordinator.closeEditor()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Past games keep their scores in History.")
        }
    }

    private var footer: String {
        switch game.rules.entry {
        case .tally: "On the scoreboard, click a player to give them a point — great for rounds, goals or wins."
        case .points: "Players take turns entering their points with presets or the number pad."
        }
    }

    private func save(andPlay: Bool) {
        isSaving = true
        Task {
            if await coordinator.customGames.save(game) {
                var saved = game
                saved.name = trimmedName
                coordinator.finishEditing(saved, play: andPlay)
            }
            isSaving = false
        }
    }

    private static let startOptions = [101, 201, 301, 501, 701, 1001]
    private static let targetOptions = [3, 5, 6, 7, 10, 11, 12, 15, 21, 25, 50, 100, 121, 150, 200, 250, 300, 500, 1000, 1500, 5000, 10000]

    private static func options(_ values: [Int], including current: Int?) -> [Int] {
        guard let current, !values.contains(current) else { return values }
        return (values + [current]).sorted()
    }
}

/// Tile for a home or custom game, matching the sport cards' layout.
struct TVHouseGameTile: View {
    let game: HouseGame

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: game.symbol)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(Color.forHouseGame(game))
            Spacer(minLength: 0)
            Text(game.name)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(game.rules.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .leading)
    }
}

extension Color {
    static func forHouseGame(_ game: HouseGame) -> Color {
        switch game.category {
        case .card:  .red
        case .board: .blue
        case .party: .purple
        case .video: .orange
        case nil:    .teal
        }
    }

    /// Colour for any session: the sport's category colour, or the home game's colour.
    static func forSession(_ session: GameSession) -> Color {
        session.houseGame.map(forHouseGame) ?? forSport(session.sport)
    }
}
