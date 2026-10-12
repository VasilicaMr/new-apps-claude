import Foundation

struct Insight: Sendable, Identifiable, Hashable {
    enum Category: String, Sendable {
        case replacement, profitability, utilization, fuel, safety, maintenance, compliance, diagnostics, performance

        var symbol: String {
            switch self {
            case .replacement: "arrow.triangle.2.circlepath.circle"
            case .profitability: "eurosign.circle"
            case .utilization: "calendar.badge.clock"
            case .fuel: "fuelpump"
            case .safety: "steeringwheel.exclamationmark"
            case .maintenance: "wrench.and.screwdriver"
            case .compliance: "doc.badge.clock"
            case .diagnostics: "engine.combustion.badge.exclamationmark"
            case .performance: "trophy"
            }
        }
    }

    let id: String
    let vehicleId: String?
    let severity: Severity
    let category: Category
    let title: String
    let detail: String
    /// Approximate money at stake per month, when it can be estimated.
    let monthlyImpact: Double?
}

/// Rule-based analysis that turns reports into plain-language recommendations for the owner.
/// Every threshold lives here so they're easy to tune (or to move to a remote config later).
struct InsightsEngine: Sendable {
    var replaceWhenRepairBurdenAbove = 0.25
    var underutilizedBelow = 0.55
    var fuelDeviationAbove = 0.12
    var harshEventsPer100KmAbove = 2.0
    var idleShareAbove = 0.2
    /// Rough idle fuel burn for a passenger car / small van, litres per hour.
    var idleLitresPerHour = 0.8

    func insights(for report: FleetReport, snapshot: FleetSnapshot, formatMoney: (Double) -> String) -> [Insight] {
        let monthsInPeriod = max(report.range.days / 30, 1 / 30)
        var result: [Insight] = []

        for vehicleReport in report.vehicles {
            let vehicle = vehicleReport.vehicle
            let name = "\(vehicle.plate) · \(vehicle.displayName)"
            func add(_ key: String, _ severity: Severity, _ category: Insight.Category, _ title: String, _ detail: String, impact: Double? = nil) {
                result.append(Insight(id: "\(vehicle.id)-\(key)", vehicleId: vehicle.id, severity: severity, category: category,
                                      title: title, detail: detail, monthlyImpact: impact))
            }

            if vehicleReport.repairBurden > replaceWhenRepairBurdenAbove, let value = vehicleReport.valuation?.currentValue {
                add("replace", .critical, .replacement, "Consider replacing \(vehicle.plate)",
                    "\(name) cost \(formatMoney(vehicleReport.maintenanceLast12Months)) in repairs over 12 months — \(percent(vehicleReport.repairBurden)) of its \(formatMoney(value)) market value. Selling now avoids further losses as value keeps dropping.",
                    impact: vehicleReport.maintenanceLast12Months / 12)
            }

            if vehicleReport.financials.profit < 0 {
                add("loss", .critical, .profitability, "\(vehicle.plate) is losing money",
                    "Net result \(formatMoney(vehicleReport.financials.profit)) in the last \(report.period.rawValue) days (\(formatMoney(vehicleReport.costPerKm)) cost vs \(formatMoney(vehicleReport.financials.revenue / max(vehicleReport.usage.distanceKm, 1))) revenue per km).",
                    impact: -vehicleReport.financials.profit / monthsInPeriod)
            }

            if vehicleReport.usage.utilization < underutilizedBelow {
                let fixedCosts = vehicle.monthlyFinancingCost
                add("idle-days", .warning, .utilization, "\(vehicle.plate) is underused",
                    "Worked only \(percent(vehicleReport.usage.utilization)) of days. Reassign it to a busier driver, rent it out, or sell it\(fixedCosts > 0 ? " — leasing alone costs \(formatMoney(fixedCosts))/month" : "").",
                    impact: fixedCosts > 0 ? fixedCosts : nil)
            }

            if vehicleReport.consumptionDeviation > fuelDeviationAbove {
                let extra = vehicleReport.financials.energyCost * vehicleReport.consumptionDeviation / (1 + vehicleReport.consumptionDeviation)
                add("fuel", .warning, .fuel, "\(vehicle.plate) uses \(percent(vehicleReport.consumptionDeviation)) more \(vehicle.fuelType == .electric ? "energy" : "fuel") than expected",
                    "\(String(format: "%.1f", vehicleReport.usage.consumptionPer100Km)) \(vehicle.fuelType.energyUnit)/100 km vs \(String(format: "%.1f", vehicle.baselineConsumption)) baseline. Check tyre pressure, injectors and air filter — and compare fuel card receipts with tank readings (possible fuel theft).",
                    impact: extra / monthsInPeriod)
            }

            if vehicleReport.usage.harshEventsPer100Km > harshEventsPer100KmAbove {
                add("harsh", .warning, .safety, "Risky driving on \(vehicle.plate)",
                    "\(vehicleReport.driver?.name ?? "The driver") averages \(String(format: "%.1f", vehicleReport.usage.harshEventsPer100Km)) harsh events per 100 km (score \(Int(vehicleReport.usage.drivingScore))/100). Harsh driving wears brakes and tyres faster and raises accident risk — consider coaching.")
            }

            if vehicleReport.usage.idleShare > idleShareAbove {
                let pricePerUnit = vehicleReport.usage.energyUsed > 0 ? vehicleReport.financials.energyCost / vehicleReport.usage.energyUsed : 0
                let idleCost = vehicleReport.usage.idleMinutes / 60 * idleLitresPerHour * pricePerUnit
                add("idle", .info, .fuel, "\(vehicle.plate) idles \(percent(vehicleReport.usage.idleShare)) of engine time",
                    "Engine running while stationary costs about \(formatMoney(idleCost / monthsInPeriod)) per month. A no-idling policy usually fixes this.",
                    impact: idleCost / monthsInPeriod)
            }

            if let telemetry = snapshot.telemetry(for: vehicle.id), !telemetry.diagnosticCodes.isEmpty {
                add("dtc", .critical, .diagnostics, "Engine fault codes on \(vehicle.plate)",
                    "Active codes: \(telemetry.diagnosticCodes.joined(separator: ", ")). Book a diagnostic before a small issue becomes a breakdown.")
            }

            for item in vehicleReport.dueItems where item.severity >= .warning {
                let category: Insight.Category = item.kind == .service ? .maintenance : .compliance
                let when = item.kmRemaining.map { "in \(Int($0)) km" } ?? "on \(item.dueDate.formatted(date: .abbreviated, time: .omitted))"
                let consequence = item.kind == .service
                    ? "Skipping services voids warranties and turns cheap wear into expensive breakdowns."
                    : "Driving with lapsed paperwork risks fines and invalid insurance."
                add("due-\(item.kind.rawValue)", item.severity, category, "\(item.kind.title) due for \(vehicle.plate)",
                    "\(item.kind.title) is due \(when). \(consequence)")
            }
        }

        if let best = report.vehicles.filter({ $0.usage.distanceKm > 0 }).max(by: { $0.profitPerKm < $1.profitPerKm }) {
            result.append(Insight(
                id: "fleet-best", vehicleId: best.vehicle.id, severity: .info, category: .performance,
                title: "Top earner: \(best.vehicle.plate)",
                detail: "\(best.vehicle.displayName) makes \(formatMoney(best.profitPerKm)) profit per km. Use it as the benchmark when choosing your next vehicle.",
                monthlyImpact: nil))
        }

        return result.sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            return ($0.monthlyImpact ?? 0) > ($1.monthlyImpact ?? 0)
        }
    }

    private func percent(_ value: Double) -> String { value.formatted(.percent.precision(.fractionLength(0))) }
}
