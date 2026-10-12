import SwiftUI

extension Color {
    static func forSportCategory(_ category: SportCategory) -> Color {
        switch category {
        case .precisionAiming: return .orange
        case .cueSports:       return .green
        case .bowling:         return .blue
        case .racket:          return .yellow
        case .cardTile:        return .purple
        case .mindSports:      return .indigo
        case .iceOutdoor:      return .cyan
        case .gameRoom:        return .pink
        }
    }

    static func forSport(_ sport: SportType) -> Color {
        forSportCategory(sport.category)
    }
}
