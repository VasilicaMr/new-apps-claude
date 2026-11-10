//
//  Journey.swift
//  TrailDomain
//
//  Read models for the journey map and the result of finishing a stop.
//

import Foundation

public struct StopProgress: Identifiable, Hashable, Sendable {
    public let stop: JourneyStop
    public let bestStars: Int
    /// Needs the Full Journey purchase.
    public let isLocked: Bool

    public init(stop: JourneyStop, bestStars: Int, isLocked: Bool = false) {
        self.stop = stop
        self.bestStars = bestStars
        self.isLocked = isLocked
    }

    public var id: String { stop.id }
    public var isCompleted: Bool { bestStars > 0 }
}

public struct Journey: Equatable, Sendable {
    public let stops: [StopProgress]
    public let totalStars: Int
    /// Suggested next stop: first unfinished *unlocked* one. Locked stops are never suggested —
    /// no purchase nudges aimed at kids. Nil when every open stop is done.
    public let nextStopID: String?

    public init(stops: [StopProgress], totalStars: Int, nextStopID: String?) {
        self.stops = stops
        self.totalStars = totalStars
        self.nextStopID = nextStopID
    }

    public static let empty = Journey(stops: [], totalStars: 0, nextStopID: nil)

    public var completedCount: Int { stops.filter(\.isCompleted).count }
    public var lockedStops: [JourneyStop] { stops.filter(\.isLocked).map(\.stop) }
    public var nextStop: JourneyStop? { stops.first { $0.id == nextStopID }?.stop }
}

public struct StopResult: Equatable, Sendable {
    public let stars: Int
    public let isNewBest: Bool
    public let totalStars: Int

    public init(stars: Int, isNewBest: Bool, totalStars: Int) {
        self.stars = stars
        self.isNewBest = isNewBest
        self.totalStars = totalStars
    }
}
