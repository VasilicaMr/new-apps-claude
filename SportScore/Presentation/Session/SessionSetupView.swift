import SwiftUI

struct SessionSetupView: View {
    @State var viewModel: SessionSetupViewModel
    var coordinator: HomeCoordinator
    @State private var newPlayerName: String = ""
    @State private var showAddPlayer: Bool = false

    var body: some View {
        Form {
            if viewModel.sport.defaultVariants.count > 1 {
                Section("Variant") {
                    Picker("Variant", selection: $viewModel.selectedVariant) {
                        ForEach(viewModel.sport.defaultVariants, id: \.self) { v in
                            Text(v).tag(v)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section("Players") {
                if viewModel.allPlayers.isEmpty {
                    Label("Tap \"Add new player\" to get started", systemImage: "person.badge.plus")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .padding(.vertical, 4)
                }
                ForEach(viewModel.allPlayers) { player in
                    HStack {
                        Text(player.name)
                        Spacer()
                        if viewModel.selectedPlayers.contains(where: { $0.id == player.id }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.togglePlayer(player) }
                }
                Button("Add new player…") { showAddPlayer = true }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(viewModel.sport.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Start") {
                    Task {
                        if let id = await viewModel.startGame() {
                            coordinator.push(.liveScore(sessionID: id))
                        }
                    }
                }
            }
        }
        .task { await viewModel.loadPlayers() }
        .alert("New Player", isPresented: $showAddPlayer) {
            TextField("Name", text: $newPlayerName)
            Button("Add") {
                Task {
                    if let player = await viewModel.addPlayer(name: newPlayerName) {
                        viewModel.togglePlayer(player)
                        newPlayerName = ""
                    }
                }
            }
            Button("Cancel", role: .cancel) { newPlayerName = "" }
        }
    }
}
