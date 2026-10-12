import Foundation
import Observation

/// Loads the fleet snapshot and keeps the derived reports in sync with the selected period.
@MainActor
@Observable
final class FleetStore {
    enum State {
        case idle, loading, loaded, failed(String)
    }

    private(set) var state: State = .idle
    private(set) var snapshot: FleetSnapshot?
    private(set) var report: FleetReport?
    private(set) var insights: [Insight] = []
    var period: AnalysisPeriod = .month {
        didSet { if oldValue != period { recompute() } }
    }

    private let repository: any FleetRepository
    private let analyzer = FleetAnalyzer()
    private let insightsEngine = InsightsEngine()

    init(repository: any FleetRepository) {
        self.repository = repository
    }

    var money: MoneyFormatter { MoneyFormatter(currencyCode: snapshot?.company.currencyCode ?? "EUR") }

    func loadIfNeeded() async {
        if case .idle = state { await reload() }
    }

    func reload() async {
        if snapshot == nil { state = .loading }
        do {
            snapshot = try await repository.loadSnapshot()
            recompute()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func report(for vehicleId: String) -> VehicleReport? {
        report?.vehicles.first { $0.vehicle.id == vehicleId }
    }

    func insights(for vehicleId: String) -> [Insight] {
        insights.filter { $0.vehicleId == vehicleId }
    }

    private func recompute() {
        guard let snapshot else { return }
        let report = analyzer.report(for: snapshot, period: period)
        let money = money
        self.report = report
        insights = insightsEngine.insights(for: report, snapshot: snapshot) { money.string($0) }
    }
}
