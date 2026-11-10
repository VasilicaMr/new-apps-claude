//
//  AppContainer.swift
//  LittlePhysicsTrail
//
//  Composition root: the only place that knows concrete types. It wires Data into Domain
//  use cases and hands Presentation ready-made view models. Views never build their own
//  dependencies — they ask the container from the environment.
//

import SwiftUI
import TrailDomain
import TrailData

final class AppContainer {
    private let stops: StopRepository
    private let progress: ProgressRepository
    private let settings: SettingsRepository
    private let narrator: Narrator
    private let purchases: PurchaseService
    private let policy = AccessPolicy.standard

    init(stops: StopRepository, progress: ProgressRepository, settings: SettingsRepository,
         narrator: Narrator, purchases: PurchaseService) {
        self.stops = stops
        self.progress = progress
        self.settings = settings
        self.narrator = narrator
        self.purchases = purchases
    }

    static func live(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppContainer {
        let isUITesting = arguments.contains("-uiTesting")
        if isUITesting, let id = Bundle.main.bundleIdentifier {
            // UI tests start from a fresh install.
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
        #if DEBUG
        let unlockAll = arguments.contains("-unlockFullJourney")
        #else
        let unlockAll = false
        #endif
        let settings = UserDefaultsSettingsRepository()
        return AppContainer(
            stops: StaticStopRepository(),
            progress: UserDefaultsProgressRepository(),
            settings: settings,
            narrator: SpeechNarrator(settings: settings, isMuted: isUITesting),
            purchases: StoreKitPurchaseService(unlockAll: unlockAll)
        )
    }

    /// Sandboxed container for SwiftUI previews and the environment default: own defaults suite, silent.
    static func preview() -> AppContainer {
        let defaults = UserDefaults(suiteName: "LittlePhysicsTrail.preview") ?? .standard
        let settings = UserDefaultsSettingsRepository(defaults: defaults)
        return AppContainer(
            stops: StaticStopRepository(),
            progress: UserDefaultsProgressRepository(defaults: defaults),
            settings: settings,
            narrator: SpeechNarrator(settings: settings, isMuted: true),
            purchases: StoreKitPurchaseService(unlockAll: true)
        )
    }

    /// Loads the product and entitlements at launch.
    func start() async {
        await purchases.refresh()
    }

    // MARK: Use cases

    private var loadJourney: LoadJourneyUseCase {
        LoadJourneyUseCase(stops: stops, progress: progress, entitlements: purchases, policy: policy)
    }
    private var intro: StopIntroUseCase { StopIntroUseCase(progress: progress) }

    // MARK: View models

    @MainActor
    func makeJourneyViewModel() -> JourneyViewModel {
        JourneyViewModel(loadJourney: loadJourney, intro: intro, entitlements: purchases, narrator: narrator)
    }

    @MainActor
    func makeLessonViewModel(stop: JourneyStop, showIntro: Bool) -> LessonViewModel {
        LessonViewModel(
            stop: stop,
            showIntro: showIntro,
            completeStop: CompleteStopUseCase(progress: progress),
            intro: intro,
            narrator: narrator
        )
    }

    @MainActor
    func makeGrownUpsViewModel() -> GrownUpsViewModel {
        GrownUpsViewModel(
            loadJourney: loadJourney,
            resetProgress: ResetProgressUseCase(progress: progress),
            unlock: UnlockJourneyUseCase(purchases: purchases),
            settings: settings
        )
    }

    @MainActor
    func makeUnlockViewModel() -> UnlockViewModel {
        UnlockViewModel(
            includedStops: Array(stops.allStops().dropFirst(policy.freeStopCount)),
            unlock: UnlockJourneyUseCase(purchases: purchases)
        )
    }
}

// MARK: - Environment

private struct AppContainerKey: EnvironmentKey {
    static let defaultValue = AppContainer.preview()
}

extension EnvironmentValues {
    var container: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
