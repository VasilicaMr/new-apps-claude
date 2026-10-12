import Foundation

/// Turns raw GPS fixes into kilometers driven and time spent moving.
///
/// A fix is accepted only when it is accurate enough and the car has moved at least
/// `minStepMeters` (or the fix's own uncertainty, if larger) from the last *accepted* point.
/// That keeps GPS jitter at a red light or in a parking lot from adding phantom kilometers,
/// while slow traffic still adds up because distance is measured from the last stored point.
/// Jumps faster than `maxSpeedKmh` (a bad fix, a tunnel exit) are dropped.
struct DistanceAccumulator: Sendable {
    var minStepMeters: Double = 25
    var maxAccuracyMeters: Double = 50
    var maxSpeedKmh: Double = 200
    /// Segments slower than this count as waiting (traffic jam, waiting for a passenger).
    var movingSpeedKmh: Double = 5

    private(set) var distanceMeters: Double
    private(set) var movingSeconds: Double
    private(set) var lastPoint: RoutePoint?

    init(distanceMeters: Double = 0, movingSeconds: Double = 0, lastPoint: RoutePoint? = nil) {
        self.distanceMeters = distanceMeters
        self.movingSeconds = movingSeconds
        self.lastPoint = lastPoint
    }

    /// Returns the point to store, or nil if the sample was filtered out.
    mutating func add(_ sample: LocationSample) -> RoutePoint? {
        guard sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= maxAccuracyMeters else { return nil }
        let point = RoutePoint(coordinate: sample.coordinate, timestamp: sample.timestamp)
        guard let last = lastPoint else {
            lastPoint = point
            return point
        }
        let seconds = sample.timestamp.timeIntervalSince(last.timestamp)
        guard seconds > 0 else { return nil }
        let meters = last.coordinate.distance(to: sample.coordinate)
        guard meters >= max(minStepMeters, sample.horizontalAccuracy) else { return nil }
        let speedKmh = meters / seconds * 3.6
        guard speedKmh <= maxSpeedKmh else { return nil }

        distanceMeters += meters
        if speedKmh >= movingSpeedKmh { movingSeconds += seconds }
        lastPoint = point
        return point
    }
}
