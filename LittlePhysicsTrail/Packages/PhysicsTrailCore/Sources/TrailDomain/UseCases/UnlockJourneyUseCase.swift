//
//  UnlockJourneyUseCase.swift
//  TrailDomain
//

import Foundation

/// Buying / restoring the Full Journey. Only reachable from grown-up screens behind the parental gate.
public struct UnlockJourneyUseCase {
    private let purchases: PurchaseService

    public init(purchases: PurchaseService) {
        self.purchases = purchases
    }

    public var isUnlocked: Bool { purchases.ownsFullJourney }
    public var offer: JourneyOffer? { purchases.offer }

    public func load() async { await purchases.refresh() }
    public func purchase() async -> PurchaseOutcome { await purchases.purchaseFullJourney() }
    public func restore() async -> Bool { await purchases.restore() }
}
