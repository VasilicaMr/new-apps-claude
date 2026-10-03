import StoreKit
import Foundation

/// StoreKit 2 purchase management (spec §7). One non-consumable product —
/// "Unlock Full Version" — no subscriptions. Observable so SwiftUI views can
/// reactively show/hide the watermark and paywall.
@Observable
@MainActor
final class SubscriptionManager {

    /// The single one-time purchase that removes the watermark and unlocks 4K.
    static let unlockID = "com.adaptiveservices.realto.unlock"

    private(set) var products: [Product] = []
    private(set) var isUnlocked = false
    private(set) var isPurchasing = false
    var purchaseError: String?

    // `listener` runs for the app's lifetime — SubscriptionManager is never deallocated.
    private var listener: Task<Void, Never>?

    init() {
        listener = Task { [weak self] in await self?.listenForTransactions() }
    }

    // MARK: - Load

    func load() async {
        do {
            products = try await Product.products(for: [Self.unlockID])
        } catch {
            // Not fatal — simulator has no StoreKit configuration yet.
        }
        await refreshEntitlements()
    }

    var unlockProduct: Product? { products.first { $0.id == Self.unlockID } }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result {
                let tx = try verification.payloadValue
                await tx.finish()
                await refreshEntitlements()
            }
        } catch StoreKitError.userCancelled {
            // no-op
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = String(localized: "Restore failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Status

    /// Non-consumables never expire, so once purchased this stays true forever
    /// (and is restorable on any device signed into the same Apple ID).
    private func refreshEntitlements() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if tx.productID == Self.unlockID {
                found = true
                break
            }
        }
        isUnlocked = found
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let tx) = result {
                await tx.finish()
                await refreshEntitlements()
            }
        }
    }
}
