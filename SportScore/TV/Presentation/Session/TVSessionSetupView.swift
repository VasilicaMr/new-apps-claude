import SwiftUI

struct TVSessionSetupView: View {
    @State var viewModel: SessionSetupViewModel
    let coordinator: TVAppCoordinator
    /// Set for home/custom games, whose name, icon and rules come from the game itself.
    var houseGame: HouseGame? = nil

    @State private var newPlayerName = ""
    @State private var showAddPlayer = false
    @State private var isStarting = false

    private var sport: SportType { viewModel.sport }

    var body: some View {
        HStack(alignment: .top, spacing: 80) {
            // Focus sections so left/right always moves between the columns, e.g. from the
            // first player to "Start", which sits far below it.
            sportColumn
                .frame(width: 620)
                .focusSection()
            playersList
                .focusSection()
        }
        .task { await viewModel.loadPlayers() }
        .alert("New Player", isPresented: $showAddPlayer) {
            TextField("Name", text: $newPlayerName)
            Button("Add") {
                Task {
                    if let player = await viewModel.addPlayer(name: newPlayerName) {
                        viewModel.togglePlayer(player)
                    }
                    newPlayerName = ""
                }
            }
            Button("Cancel", role: .cancel) { newPlayerName = "" }
        }
    }

    private var sportColumn: some View {
        VStack(alignment: .leading, spacing: 28) {
            Image(systemName: houseGame?.symbol ?? sport.systemImageName)
                .font(.system(size: 110, weight: .semibold))
                .foregroundStyle(houseGame.map(Color.forHouseGame) ?? Color.forSport(sport))
            VStack(alignment: .leading, spacing: 6) {
                Text(houseGame?.name ?? sport.displayName)
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .lineLimit(2)
                if let houseGame {
                    Label(houseGame.category?.rawValue ?? "Your Games", systemImage: houseGame.category?.systemImageName ?? "star.fill")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("\(houseGame.rules.summary) · \(houseGame.rules.entry.title)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Label(sport.category.rawValue, systemImage: sport.category.systemImageName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            if let houseGame {
                Button {
                    coordinator.showEditor(for: houseGame)
                } label: {
                    Label(houseGame.isCustom ? "Edit Game" : "Customize Rules…",
                          systemImage: houseGame.isCustom ? "pencil" : "slider.horizontal.3")
                }
            }

            if sport.defaultVariants.count > 1 {
                // A menu picker only shows its value on tvOS, so name what it changes.
                HStack(spacing: 20) {
                    Text("Variant")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Picker("Variant", selection: $viewModel.selectedVariant) {
                        ForEach(sport.defaultVariants, id: \.self) { variant in
                            Text(variant).tag(variant)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Spacer(minLength: 0)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }

            Button {
                start()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedPlayers.isEmpty || isStarting)
        }
    }

    private var playersList: some View {
        List {
            Section {
                if viewModel.allPlayers.isEmpty && !viewModel.isLoading {
                    Label("Select \"Add new player…\" to get started", systemImage: "person.badge.plus")
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.allPlayers) { player in
                    Button {
                        viewModel.togglePlayer(player)
                    } label: {
                        TVPlayerRow(player: player, order: viewModel.selectedPlayers.firstIndex { $0.id == player.id })
                    }
                }
                Button {
                    showAddPlayer = true
                } label: {
                    Label("Add new player…", systemImage: "person.badge.plus")
                }
            } header: {
                Text("Players")
            } footer: {
                Text("Players take turns in the order you select them.")
            }
        }
    }

    private func start() {
        isStarting = true
        Task {
            if let id = await viewModel.startGame() {
                coordinator.startLiveScore(sessionID: id)
            }
            isStarting = false
        }
    }
}

/// Player row with the same initials avatar as the iOS Players tab.
/// `order` shows the turn order when the player is selected for a game.
struct TVPlayerRow: View {
    let player: Player
    var order: Int? = nil
    var showsSelection = true

    var body: some View {
        HStack(spacing: 24) {
            TVInitialsAvatar(player: player)
            Text(player.name)
            Spacer()
            if showsSelection {
                if let order {
                    Text("\(order + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(.blue))
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct TVInitialsAvatar: View {
    let player: Player

    var body: some View {
        Text(player.initials)
            .font(.headline)
            .foregroundStyle(.blue)
            .frame(width: 60, height: 60)
            .background(Circle().fill(Color.blue.opacity(0.15)))
    }
}
