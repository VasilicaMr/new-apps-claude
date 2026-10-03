import StoreKit
import Foundation

@Observable
@MainActor
final class PremiumManager {
    static let shared = PremiumManager()

    static let productID = "com.yourapp.sportscore.premium"
    static let freeHistoryLimit = 5

    private(set) var isPremium: Bool = false
    private(set) var product: Product?
    private(set) var isPurchasing: Bool = false
    var purchaseError: String?

    private init() {}

    func initialize() async {
        await checkEntitlement()
        await loadProduct()
    }

    func observeTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let tx) = result, tx.productID == Self.productID {
                await tx.finish()
                await checkEntitlement()
            }
        }
    }

    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    isPremium = true
                }
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await checkEntitlement()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func checkEntitlement() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == Self.productID,
               tx.revocationDate == nil {
                found = true
                break
            }
        }
        isPremium = found
    }

    private func loadProduct() async {
        let products = try? await Product.products(for: [Self.productID])
        product = products?.first
    }
}
