//
//  StopRepository.swift
//  TrailDomain
//

import Foundation

/// Source of the journey content, in journey order.
public protocol StopRepository {
    func allStops() -> [JourneyStop]
}
