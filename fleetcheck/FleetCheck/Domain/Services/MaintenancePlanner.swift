import Foundation

struct DueItem: Sendable, Hashable, Identifiable {
    enum Kind: String, Sendable {
        case service, insurance, inspection, roadTax, driverLicense

        var title: String {
            switch self {
            case .service: "Scheduled service"
            case .insurance: "Insurance renewal"
            case .inspection: "Technical inspection (ITP)"
            case .roadTax: "Road tax (rovinieta)"
            case .driverLicense: "Driver license renewal"
            }
        }

        var symbol: String {
            switch self {
            case .service: "wrench.and.screwdriver"
            case .insurance: "shield.lefthalf.filled"
            case .inspection: "checkmark.seal"
            case .roadTax: "road.lanes"
            case .driverLicense: "person.text.rectangle"
            }
        }
    }

    let vehicleId: String
    let kind: Kind
    let dueDate: Date
    /// Only for odometer-based items.
    let kmRemaining: Double?
    let severity: Severity

    var id: String { "\(vehicleId)-\(kind.rawValue)" }
}

/// Everything with a deadline: services (by km, converted to a date using the recent pace)
/// and paperwork that can take a vehicle off the road if it lapses.
struct MaintenancePlanner: Sendable {
    var lookAheadDays: Double = 60
    var warningDays: Double = 14
    var warningKm: Double = 1_000

    func dueItems(for vehicle: Vehicle, snapshot: FleetSnapshot) -> [DueItem] {
        let asOf = snapshot.company.dataAsOf
        let odometer = snapshot.telemetry(for: vehicle.id)?.odometerKm ?? vehicle.odometerKm
        let kmPerDay = recentKmPerDay(vehicleId: vehicle.id, snapshot: snapshot)

        var items: [DueItem] = []
        let kmRemaining = vehicle.nextServiceKm - odometer
        let serviceDate = asOf.addingTimeInterval(kmRemaining / max(kmPerDay, 1) * 86_400)
        items.append(DueItem(vehicleId: vehicle.id, kind: .service, dueDate: serviceDate, kmRemaining: kmRemaining,
                             severity: severity(daysLeft: days(from: asOf, to: serviceDate), kmLeft: kmRemaining)))

        let paperwork: [(DueItem.Kind, Date)] = [
            (.insurance, vehicle.insuranceExpiry),
            (.inspection, vehicle.inspectionExpiry),
            (.roadTax, vehicle.roadTaxExpiry),
        ] + (snapshot.driver(id: vehicle.assignedDriverId).map { [(.driverLicense, $0.licenseExpiry)] } ?? [])

        for (kind, date) in paperwork {
            items.append(DueItem(vehicleId: vehicle.id, kind: kind, dueDate: date, kmRemaining: nil,
                                 severity: severity(daysLeft: days(from: asOf, to: date), kmLeft: nil)))
        }
        return items
            .filter { days(from: asOf, to: $0.dueDate) <= lookAheadDays || ($0.kmRemaining ?? .infinity) <= warningKm * 3 }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func recentKmPerDay(vehicleId: String, snapshot: FleetSnapshot, days: Int = 30) -> Double {
        let range = DateRange.lastDays(days, endingOn: snapshot.company.dataAsOf)
        let km = snapshot.metrics(for: vehicleId).filter { range.contains($0.date) }.reduce(0) { $0 + $1.distanceKm }
        return km / Double(days)
    }

    private func severity(daysLeft: Double, kmLeft: Double?) -> Severity {
        if daysLeft < 0 || (kmLeft ?? 1) <= 0 { return .critical }
        if daysLeft <= warningDays || (kmLeft ?? .infinity) <= warningKm { return .warning }
        return .info
    }

    private func days(from: Date, to: Date) -> Double { to.timeIntervalSince(from) / 86_400 }
}
