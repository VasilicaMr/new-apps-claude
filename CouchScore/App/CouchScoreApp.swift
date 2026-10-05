import SwiftUI

@main
struct CouchScoreApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        TabView {
            Tab("Play", systemImage: "play.fill") { PlayView() }
            Tab("History", systemImage: "clock.arrow.circlepath") { HistoryView() }
            Tab("Players", systemImage: "person.2.fill") { PlayersView() }
        }
        .fullScreenCover(isPresented: scoreboardPresented) {
            if let id = store.presentedMatchID {
                ScoreboardView(matchID: id)
                    .id(id) // fresh view state on rematch
            }
        }
    }

    private var scoreboardPresented: Binding<Bool> {
        Binding(
            get: { store.presentedMatchID != nil },
            set: { if !$0 { store.presentedMatchID = nil } }
        )
    }
}
