//
//  StoreKitPurchaseService.swift
//  LittlePhysicsTrail
//
//  StoreKit 2 implementation of `PurchaseService`: one non-consumable, family-shareable
//  "Full Journey" product (local testing: LittlePhysicsTrail.storekit, wired into the scheme).
//  Same entitlement / restore approach as ShadowMatch/Store/PackStore.swift.
//

import Foundation
import Observation
import StoreKit
import TrailDomain

@Observable
final class StoreKitPurchaseService: PurchaseService {
    static let productID = "com.adaptiveservices.littlephysicstrail.fulljourney"

    private(set) var ownsFullJourney: Bool
    private(set) var offer: JourneyOffer?

    @ObservationIgnored private var product: Product?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    /// `-unlockFullJourney` (DEBUG only) opens every stop for screenshots / UI tests.
    @ObservationIgnored private let unlockAll: Bool

    init(unlockAll: Bool = false) {
        self.unlockAll = unlockAll
        self.ownsFullJourney = unlockAll
        // Purchases made outside the app (Ask to Buy approval, other devices, refunds).
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func refresh() async {
        if product == nil {
            do {
                product = try await Product.products(for: [Self.productID]).first
            } catch {
                #if DEBUG
                print("StoreKitPurchaseService.refresh error:", error)
                #endif
            }
            let price = product?.displayPrice
            await MainActor.run { offer = price.map { JourneyOffer(displayPrice: $0) } }
        }
        await refreshEntitlements()
    }

    func purchaseFullJourney() async -> PurchaseOutcome {
        if product == nil { await refresh() }
        guard let product else {
            return .failed("The store isn't available right now. Please try again later.")
        }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed("We couldn't verify this purchase.")
                }
                await transaction.finish()
                await refreshEntitlements()
                return .unlocked
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async -> Bool {
        // AppStore.sync() always asks for the Apple ID password — only use it when needed.
        await refreshEntitlements()
        guard !ownsFullJourney else { return true }
        do {
            try await AppStore.sync()
        } catch {
            #if DEBUG
            print("StoreKitPurchaseService.restore sync error:", error)
            #endif
        }
        await refreshEntitlements()
        return ownsFullJourney
    }

    private func refreshEntitlements() async {
        var owns = unlockAll
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil {
                owns = true
            }
        }
        await MainActor.run { ownsFullJourney = owns }
    }
}
