import Foundation
import Testing
@testable import FleetCheck

@Suite("50 m location filter")
struct LocationChangeFilterTests {
    let origin = GeoCoordinate(latitude: 44.4268, longitude: 26.1025)
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// Moves `meters` north of the origin.
    func north(_ meters: Double) -> GeoCoordinate {
        GeoCoordinate(latitude: origin.latitude + meters / 111_195, longitude: origin.longitude)
    }

    func position(_ coordinate: GeoCoordinate, after seconds: TimeInterval = 0, vehicle: String = "veh-1") -> VehiclePosition {
        VehiclePosition(vehicleId: vehicle, coordinate: coordinate, speedKmh: 30, timestamp: start.addingTimeInterval(seconds))
    }

    @Test func haversineIsAccurate() {
        #expect(abs(origin.distance(to: north(100)) - 100) < 0.5)
    }

    @Test func firstFixIsAlwaysReported() {
        var filter = LocationChangeFilter()
        #expect(filter.evaluate(position(origin))?.reason == .firstFix)
    }

    @Test func smallMovesAreSuppressed() {
        var filter = LocationChangeFilter(thresholdMeters: 50)
        _ = filter.evaluate(position(origin))
        #expect(filter.evaluate(position(north(20), after: 2)) == nil)
        #expect(filter.evaluate(position(north(45), after: 4)) == nil)
        let event = filter.evaluate(position(north(55), after: 6))
        #expect(event?.reason == .movedBeyondThreshold)
        #expect(abs((event?.distanceFromPreviousMeters ?? 0) - 55) < 1)
    }

    @Test("Distance is measured from the last reported point, not the last sample")
    func slowDriftAccumulates() {
        var filter = LocationChangeFilter(thresholdMeters: 50)
        _ = filter.evaluate(position(origin))
        var reported = 0
        for step in 1...10 where filter.evaluate(position(north(Double(step) * 11), after: Double(step))) != nil {
            reported += 1
        }
        #expect(reported == 2) // at 55 m and 110 m; no single step exceeds 11 m
    }

    @Test func heartbeatWhileParked() {
        var filter = LocationChangeFilter(thresholdMeters: 50, heartbeat: 300)
        _ = filter.evaluate(position(origin))
        #expect(filter.evaluate(position(north(5), after: 120)) == nil)
        #expect(filter.evaluate(position(north(5), after: 301))?.reason == .heartbeat)
    }

    @Test func vehiclesAreTrackedIndependently() {
        var filter = LocationChangeFilter()
        _ = filter.evaluate(position(origin, vehicle: "a"))
        #expect(filter.evaluate(position(north(10), vehicle: "b"))?.reason == .firstFix)
    }
}
