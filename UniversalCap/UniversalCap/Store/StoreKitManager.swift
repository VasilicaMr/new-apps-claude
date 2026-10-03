import StoreKit
import Observation

@Observable
final class StoreKitManager {
    static let shared = StoreKitManager()

    private let proID = "com.universalcap.app.pro_lifetime"

    var isPro        = false
    var product: Product?
    var isPurchasing = false
    var errorMessage: String?

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProduct()
            await refreshStatus()
        }
    }

    deinit { transactionListener?.cancel() }

    // MARK: - Public

    func purchase() async {
        guard let product else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try verified(verification)
                await tx.finish()
                await refreshStatus()
            case .userCancelled: break
            case .pending:       break
            @unknown default:    break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [proID])
            product = products.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshStatus() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == proID,
               tx.revocationDate == nil {
                hasPro = true
            }
        }
        isPro = hasPro
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    await self.refreshStatus()
                }
            }
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let v): return v
        }
    }
}

enum StoreError: LocalizedError {
    case failedVerification
    var errorDescription: String? { "Purchase verification failed. Please try again." }
}
