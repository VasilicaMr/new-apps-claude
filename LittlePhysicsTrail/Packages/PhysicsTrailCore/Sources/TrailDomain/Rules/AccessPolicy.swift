//
//  AccessPolicy.swift
//  TrailDomain
//
//  Freemium rule: the first stops are free, one purchase unlocks the full journey.
//

import Foundation

public struct AccessPolicy: Equatable, Sendable {
    public let freeStopCount: Int

    public init(freeStopCount: Int) {
        self.freeStopCount = freeStopCount
    }

    /// Stops 1–3 free (buoyancy, magnets, forces), the rest with the Full Journey purchase.
    public static let standard = AccessPolicy(freeStopCount: 3)

    public func isLocked(stopAt index: Int, ownsFullJourney: Bool) -> Bool {
        !ownsFullJourney && index >= freeStopCount
    }
}
