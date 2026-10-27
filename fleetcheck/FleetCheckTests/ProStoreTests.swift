import Foundation
import StoreKitTest
import Testing
@testable import FleetCheck

/// Runs the real StoreKit purchase flow against FleetCheck.storekit, the same products the simulator uses.
@MainActor
@Suite("DriveCap Pro purchases", .serialized)
struct ProStoreTests {
    func session() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "FleetCheck")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    @Test func loadsThePlansInPaywallOrder() async throws {
        _ = try session()
        let store = ProStore()
        await store.load()
        #expect(store.products.map(\.id) == ProStore.ProductID.all)
        #expect(store.hasTrial(try #require(store.product(ProStore.ProductID.yearly))))
        #expect(!store.isPro)
    }

    @Test(arguments: ProStore.ProductID.all)
    func buyingUnlocksPro(_ id: String) async throws {
        let session = try session()
        let store = ProStore()
        await store.load()
        #expect(await store.purchase(try #require(store.product(id))))
        #expect(store.isPro)
        session.clearTransactions()
    }

    @Test func refundTakesProAway() async throws {
        let session = try session()
        let store = ProStore()
        await store.load()
        await store.purchase(try #require(store.product(ProStore.ProductID.lifetime)))
        #expect(store.isPro)
        let transaction = try #require(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        // The refund reaches the entitlements (and Transaction.updates) shortly after.
        for _ in 0..<20 where store.isPro {
            try await Task.sleep(for: .milliseconds(100))
            await store.load()
        }
        #expect(!store.isPro)
    }
}
