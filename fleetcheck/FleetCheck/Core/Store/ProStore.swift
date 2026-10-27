import Foundation
import Observation
import StoreKit

/// DriveCap Pro with StoreKit 2: a monthly or yearly subscription (7-day free trial) or a one-time lifetime unlock.
///
/// `isPro` is cached in UserDefaults so the app doesn't flash the free version at launch; the real
/// entitlements replace it as soon as StoreKit answers, and again whenever a transaction changes.
@MainActor
@Observable
final class ProStore {
    enum ProductID {
        static let monthly = "com.adaptiveservices.drivecap.pro.monthly"
        static let yearly = "com.adaptiveservices.drivecap.pro.yearly"
        static let lifetime = "com.adaptiveservices.drivecap.pro.lifetime"
        static let all = [yearly, monthly, lifetime]
    }

    /// Yearly, monthly, lifetime: the order the paywall shows them in.
    private(set) var products: [Product] = []
    private(set) var isPro: Bool
    private(set) var isPurchasing = false
    private(set) var loadFailed = false
    /// Product IDs whose free trial this Apple ID can still get.
    private(set) var trialEligible: Set<String> = []
    var purchaseError: String?

    private let cacheKey = "pro.isActive"
    // Runs for the app's lifetime; ProStore is never deallocated.
    private var listener: Task<Void, Never>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: cacheKey)
        #if DEBUG
        // `-forcePro YES` / `-forcePro NO` for screenshots and testing either version.
        if let forced = Self.forcedPro { isPro = forced }
        #endif
        listener = Task { [weak self] in await self?.listenForTransactions() }
    }

    func load() async {
        do {
            let loaded = try await Product.products(for: ProductID.all)
            products = ProductID.all.compactMap { id in loaded.first { $0.id == id } }
            loadFailed = products.isEmpty
            var eligible: Set<String> = []
            for product in products where product.subscription?.introductoryOffer != nil {
                if await product.subscription?.isEligibleForIntroOffer == true { eligible.insert(product.id) }
            }
            trialEligible = eligible
        } catch {
            loadFailed = true
        }
        await refreshEntitlements()
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    func hasTrial(_ product: Product) -> Bool { trialEligible.contains(product.id) }

    /// Returns true when the purchase went through (not cancelled, not pending).
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            guard case let .success(verification) = try await product.purchase() else { return false }
            let transaction = try verification.payloadValue
            await transaction.finish()
            await refreshEntitlements()
            return isPro
        } catch StoreKitError.userCancelled {
            return false
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro { purchaseError = String(localized: "No DriveCap Pro purchase was found for this Apple Account.") }
        } catch StoreKitError.userCancelled {
        } catch {
            purchaseError = String(localized: "Restore failed: \(error.localizedDescription)")
        }
    }

    /// Current entitlements only include active subscriptions and unrevoked purchases.
    private func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result, ProductID.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        #if DEBUG
        if let forced = Self.forcedPro { active = forced }
        #endif
        isPro = active
        UserDefaults.standard.set(active, forKey: cacheKey)
    }

    #if DEBUG
    /// A launch argument arrives as the string "YES"/"NO", so read it with `bool(forKey:)`.
    private static var forcedPro: Bool? {
        UserDefaults.standard.object(forKey: "forcePro") == nil ? nil : UserDefaults.standard.bool(forKey: "forcePro")
    }
    #endif

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case let .verified(transaction) = result { await transaction.finish() }
            await refreshEntitlements()
        }
    }
}
