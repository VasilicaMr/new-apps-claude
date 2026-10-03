//
//  ShadowMatchApp.swift
//  ShadowMatch
//

import SwiftUI

@main
struct ShadowMatchApp: App {
    @StateObject private var store = PackStore()
    @StateObject private var progress = GameProgress()
    @StateObject private var account = AccountManager()

    init() {
        // UI tests start from a fresh install state (no stars, intros or tutorial seen).
        if ProcessInfo.processInfo.arguments.contains("-uiTesting"), let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environmentObject(progress)
                .environmentObject(account)
                .task { await store.load() }
                .task { await account.refreshCredentialState() }
        }
    }
}
