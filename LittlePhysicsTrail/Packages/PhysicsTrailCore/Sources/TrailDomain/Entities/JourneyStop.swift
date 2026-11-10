//
//  JourneyStop.swift
//  TrailDomain
//
//  One stop on the journey = one big physics idea, played as a sorting game:
//  drag each item into the bin it belongs to ("Sinks" / "Floats", "Push" / "Pull" …).
//

import Foundation

public struct JourneyStop: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let emoji: String
    public let theme: StopTheme
    public let bigIdea: BigIdea
    /// Asked at the top of the game board, e.g. "Will it sink or float?"
    public let question: String
    public let bins: [SortBin]
    public let items: [SortItem]
    /// Headline on the finish screen.
    public let finishTitle: String

    public init(id: String, title: String, emoji: String, theme: StopTheme, bigIdea: BigIdea,
                question: String, bins: [SortBin], items: [SortItem], finishTitle: String) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.theme = theme
        self.bigIdea = bigIdea
        self.question = question
        self.bins = bins
        self.items = items
        self.finishTitle = finishTitle
    }

    public func bin(id: SortBin.ID) -> SortBin? { bins.first { $0.id == id } }
}

/// Semantic color of a stop. Presentation maps it to a real color, so Domain stays UI-free.
public enum StopTheme: String, CaseIterable, Sendable {
    case sky, coral, orange, sun, pink, teal, mint, purple
}

/// The concept a stop teaches, shown before the game and on the finish screen.
public struct BigIdea: Hashable, Sendable {
    public let headline: String
    public let explanation: String
    /// A tiny safe experiment to try with a grown-up.
    public let tryAtHome: String

    public init(headline: String, explanation: String, tryAtHome: String) {
        self.headline = headline
        self.explanation = explanation
        self.tryAtHome = tryAtHome
    }
}

public struct SortBin: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let emoji: String

    public init(id: String, title: String, emoji: String) {
        self.id = id
        self.title = title
        self.emoji = emoji
    }
}

public struct SortItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let emoji: String
    public let binID: SortBin.ID
    /// The "why" shown and read aloud after a correct drop — this is where the learning happens.
    public let fact: String

    public init(id: String, name: String, emoji: String, binID: SortBin.ID, fact: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.binID = binID
        self.fact = fact
    }
}
