//
//  SortSession.swift
//  TrailDomain
//
//  The rules of one play-through of a stop, as a plain value type (no timers, no UI).
//  Flow per item: place(on:) → .correct shows the fact → advance() → next item.
//  A wrong bin is never a dead end: the item stays and the child tries again.
//

import Foundation

public enum PlacementOutcome: Equatable, Sendable {
    case correct(SortItem)
    case tryAgain(SortItem)
    /// Nothing to place (finished, or waiting for `advance()` after a correct drop).
    case ignored
}

public struct SortSession: Equatable, Sendable {
    public let stop: JourneyStop
    public private(set) var deck: [SortItem]
    public private(set) var position = 0
    public private(set) var mistakes = 0
    public private(set) var placed: [SortItem] = []
    /// True between a correct drop and `advance()` — the fact card is on screen.
    public private(set) var awaitingNext = false

    public init(stop: JourneyStop, order: ([SortItem]) -> [SortItem] = { $0.shuffled() }) {
        self.stop = stop
        self.deck = order(stop.items)
    }

    public var current: SortItem? { position < deck.count ? deck[position] : nil }
    public var isFinished: Bool { position >= deck.count }
    /// Items still waiting after the current one.
    public var remaining: Int { max(0, deck.count - position - 1) }
    public var progress: Double { Double(placed.count) / Double(max(deck.count, 1)) }

    public func placedItems(in binID: SortBin.ID) -> [SortItem] {
        placed.filter { $0.binID == binID }
    }

    public mutating func place(on binID: SortBin.ID) -> PlacementOutcome {
        guard let item = current, !awaitingNext else { return .ignored }
        guard item.binID == binID else {
            mistakes += 1
            return .tryAgain(item)
        }
        placed.append(item)
        awaitingNext = true
        return .correct(item)
    }

    public mutating func advance() {
        guard awaitingNext else { return }
        awaitingNext = false
        position += 1
    }
}
