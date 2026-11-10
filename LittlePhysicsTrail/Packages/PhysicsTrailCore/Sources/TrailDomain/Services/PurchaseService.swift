//
//  PurchaseService.swift
//  TrailDomain
//
//  The one in-app purchase: a non-consumable "Full Journey". Implemented in the app with
//  StoreKit 2; Domain only knows whether it is owned, its price, and how a purchase ended.
//

import Foundation

/// Read-only view of the entitlement — all that journey building needs.
public protocol EntitlementProvider: AnyObject {
    var ownsFullJourney: Bool { get }
}

public protocol PurchaseService: EntitlementProvider {
    /// Nil while the product is loading or the store is unavailable.
    var offer: JourneyOffer? { get }
    /// Loads the product and current entitlements.
    func refresh() async
    func purchaseFullJourney() async -> PurchaseOutcome
    /// Returns true when the full journey is owned afterwards.
    func restore() async -> Bool
}

public struct JourneyOffer: Equatable, Sendable {
    public let displayPrice: String

    public init(displayPrice: String) {
        self.displayPrice = displayPrice
    }
}

public enum PurchaseOutcome: Equatable, Sendable {
    case unlocked
    /// Ask to Buy: waiting for a parent's approval.
    case pending
    case cancelled
    case failed(String)
}
