import Foundation
import Testing
@testable import FleetCheck

@Suite("Kilometers from GPS")
struct DistanceAccumulatorTests {
    let origin = GeoCoordinate(latitude: 44.4268, longitude: 26.1025)
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// Moves `meters` north of the origin.
    func north(_ meters: Double) -> GeoCoordinate {
        GeoCoordinate(latitude: origin.latitude + meters / 111_195, longitude: origin.longitude)
    }

    func sample(_ meters: Double, after seconds: TimeInterval, accuracy: Double = 10) -> LocationSample {
        LocationSample(coordinate: north(meters), timestamp: start.addingTimeInterval(seconds), horizontalAccuracy: accuracy)
    }

    @Test func haversineIsAccurate() {
        #expect(abs(origin.distance(to: north(1000)) - 1000) < 1)
    }

    @Test func steadyDrivingAddsUp() {
        var accumulator = DistanceAccumulator()
        // 2 km at 36 km/h (10 m/s), one fix per second.
        for second in 0...200 { _ = accumulator.add(sample(Double(second) * 10, after: Double(second))) }
        #expect(abs(accumulator.distanceMeters - 2000) < 30)
        #expect(abs(accumulator.movingSeconds - 200) < 5)
    }

    @Test("GPS jitter while parked adds nothing")
    func jitterIsIgnored() {
        var accumulator = DistanceAccumulator()
        _ = accumulator.add(sample(0, after: 0))
        for second in 1...600 {
            _ = accumulator.add(sample(second.isMultiple(of: 2) ? 8 : -8, after: Double(second)))
        }
        #expect(accumulator.distanceMeters == 0)
    }

    @Test func inaccurateFixesAreDropped() {
        var accumulator = DistanceAccumulator()
        #expect(accumulator.add(sample(0, after: 0, accuracy: 120)) == nil)
        #expect(accumulator.add(sample(0, after: 1, accuracy: -1)) == nil)
        #expect(accumulator.lastPoint == nil)
    }

    @Test("Teleport jumps (bad fix) are rejected")
    func jumpsAreRejected() {
        var accumulator = DistanceAccumulator()
        _ = accumulator.add(sample(0, after: 0))
        #expect(accumulator.add(sample(5000, after: 10)) == nil) // 1800 km/h
        #expect(accumulator.distanceMeters == 0)
    }

    @Test("Slow traffic counts as distance but as waiting time")
    func slowTrafficIsWaiting() {
        var accumulator = DistanceAccumulator()
        _ = accumulator.add(sample(0, after: 0))
        _ = accumulator.add(sample(30, after: 60)) // 1.8 km/h
        #expect(abs(accumulator.distanceMeters - 30) < 1)
        #expect(accumulator.movingSeconds == 0)
    }

    @Test func resumesFromSavedState() {
        let last = RoutePoint(coordinate: north(100), timestamp: start)
        var accumulator = DistanceAccumulator(distanceMeters: 5000, movingSeconds: 600, lastPoint: last)
        _ = accumulator.add(sample(200, after: 10))
        #expect(abs(accumulator.distanceMeters - 5100) < 1)
    }

    @Test func routeEncodingRoundTrips() {
        let points = [RoutePoint(coordinate: origin, timestamp: start), RoutePoint(coordinate: north(50), timestamp: start.addingTimeInterval(5))]
        #expect(RoutePoint.decode(RoutePoint.encode(points)) == points)
        #expect(RoutePoint.decode(Data()).isEmpty)
    }
}
