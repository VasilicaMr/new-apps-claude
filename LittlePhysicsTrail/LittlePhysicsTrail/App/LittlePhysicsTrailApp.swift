//
//  LittlePhysicsTrailApp.swift
//  LittlePhysicsTrail
//

import SwiftUI

@main
struct LittlePhysicsTrailApp: App {
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            JourneyView(viewModel: container.makeJourneyViewModel())
                .environment(\.container, container)
                .task { await container.start() }
        }
    }
}
