//
//  StarRating.swift
//  TrailDomain
//
//  Finishing always earns at least one star — kids are rewarded for completing, more for accuracy.
//

import Foundation

public enum StarRating {
    public static let maximum = 3

    public static func stars(forMistakes mistakes: Int) -> Int {
        switch mistakes {
        case ..<1: return 3
        case 1...2: return 2
        default: return 1
        }
    }
}
