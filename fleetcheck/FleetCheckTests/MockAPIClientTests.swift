import Testing
@testable import FleetCheck

@Suite("Mock API")
struct MockAPIClientTests {
    @Test("Every endpoint's JSON file decodes")
    func everyMockFileDecodes() async throws {
        let snapshot = try await TestData.loadSnapshot()
        #expect(snapshot.vehicles.count == 10)
        #expect(snapshot.drivers.count == 10)
        #expect(snapshot.telemetry.count == 10)
        #expect(!snapshot.dailyMetrics.isEmpty)
        #expect(!snapshot.trips.isEmpty)
        #expect(!snapshot.maintenance.isEmpty)
        #expect(!snapshot.expenses.isEmpty)
        #expect(snapshot.valuationModels.count == VehicleSegment.allCases.count)

        let repository = DefaultFleetRepository(client: MockAPIClient(latency: .zero))
        let routes = try await repository.liveRoutes()
        #expect(routes.count == 10)
        let ack = try await repository.report([])
        #expect(ack.accepted)
    }

    @Test("Every vehicle references a valid driver and valuation model")
    func referentialIntegrity() async throws {
        let snapshot = try await TestData.loadSnapshot()
        for vehicle in snapshot.vehicles {
            #expect(snapshot.driver(id: vehicle.assignedDriverId) != nil, "\(vehicle.id) has no driver")
            #expect(snapshot.valuationModel(for: vehicle.segment) != nil, "\(vehicle.segment) has no valuation model")
        }
    }

    @Test("Missing resource surfaces a readable error")
    func missingResource() async {
        let client = MockAPIClient(bundle: .init(for: BundleToken.self), latency: .zero)
        await #expect(throws: APIError.missingMockResource("company")) {
            _ = try await client.send(.company, as: Company.self)
        }
    }
}

private final class BundleToken {}
