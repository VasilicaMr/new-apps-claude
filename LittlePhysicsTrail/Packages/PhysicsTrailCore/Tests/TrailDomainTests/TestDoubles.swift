//
//  TestDoubles.swift
//  TrailDomainTests
//

import TrailDomain

final class InMemoryProgressRepository: ProgressRepository {
    var best: [String: Int] = [:]
    var total = 0
    var intros: Set<String> = []

    func bestStars(for stopID: String) -> Int { best[stopID] ?? 0 }
    func setBestStars(_ stars: Int, for stopID: String) { best[stopID] = stars }
    func totalStars() -> Int { total }
    func setTotalStars(_ stars: Int) { total = stars }
    func hasSeenIntro(for stopID: String) -> Bool { intros.contains(stopID) }
    func markIntroSeen(for stopID: String) { intros.insert(stopID) }
    func reset() { best = [:]; total = 0; intros = [] }
}

struct FixedStopRepository: StopRepository {
    let stops: [JourneyStop]
    func allStops() -> [JourneyStop] { stops }
}

enum Fixtures {
    static func stop(_ id: String = "float") -> JourneyStop {
        JourneyStop(
            id: id,
            title: "Sink or Float",
            emoji: "🛁",
            theme: .sky,
            bigIdea: BigIdea(headline: "h", explanation: "e", tryAtHome: "t"),
            question: "Will it sink or float?",
            bins: [SortBin(id: "float", title: "Floats", emoji: "🛟"), SortBin(id: "sink", title: "Sinks", emoji: "⚓️")],
            items: [
                SortItem(id: "duck", name: "Duck", emoji: "🦆", binID: "float", fact: "Air inside."),
                SortItem(id: "rock", name: "Rock", emoji: "🪨", binID: "sink", fact: "Heavy for its size."),
            ],
            finishTitle: "Done"
        )
    }

    /// Session that keeps catalog order, so tests know which item is current.
    static func session(_ stop: JourneyStop = stop()) -> SortSession {
        SortSession(stop: stop, order: { $0 })
    }
}

final class FakePurchaseService: PurchaseService {
    var ownsFullJourney = false
    var offer: JourneyOffer? = JourneyOffer(displayPrice: "$3.99")
    var nextOutcome: PurchaseOutcome = .unlocked
    var restoreOwns = false

    func refresh() async {}
    func purchaseFullJourney() async -> PurchaseOutcome {
        if nextOutcome == .unlocked { ownsFullJourney = true }
        return nextOutcome
    }
    func restore() async -> Bool {
        if restoreOwns { ownsFullJourney = true }
        return ownsFullJourney
    }
}
