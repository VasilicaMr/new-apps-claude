//
//  PackStore.swift
//  ShadowMatch
//
//  StoreKit 2 — one non-consumable product per paid picture pack.
//  Product ids: ShadowPack.productIDs (local testing: ShadowMatch.storekit, wired into the scheme).
//

import SwiftUI
import StoreKit

@MainActor
final class PackStore: ObservableObject {
    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var purchasedIDs: Set<String> = []
    @Published private(set) var purchasingID: String? = nil
    @Published var errorMessage: String? = nil

    private var updatesTask: Task<Void, Never>?

    /// `-unlockAllPacks` (DEBUG only) opens every pack for screenshots / UI tests.
    private let unlockAll: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-unlockAllPacks")
        #else
        return false
        #endif
    }()

    init() {
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

    func isUnlocked(_ pack: ShadowPack) -> Bool {
        guard let id = pack.productID else { return true }
        return unlockAll || purchasedIDs.contains(id)
    }

    func product(for pack: ShadowPack) -> Product? {
        pack.productID.flatMap { products[$0] }
    }

    /// Localized price, or nil while products are loading / unavailable.
    func price(for pack: ShadowPack) -> String? {
        product(for: pack)?.displayPrice
    }

    func load() async {
        do {
            let list = try await Product.products(for: ShadowPack.productIDs)
            products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        } catch {
            #if DEBUG
            print("PackStore.load error:", error)
            #endif
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.revocationDate == nil {
                ids.insert(t.productID)
            }
        }
        purchasedIDs = ids
    }

    /// Returns true when the pack is unlocked afterwards.
    @discardableResult
    func purchase(_ pack: ShadowPack) async -> Bool {
        guard let product = product(for: pack) else {
            errorMessage = "The store isn't available right now. Please try again later."
            return false
        }
        purchasingID = product.id
        defer { purchasingID = nil }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "We couldn't verify this purchase."
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
            case .pending:
                errorMessage = "Waiting for approval. The pack will unlock as soon as it's approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        return isUnlocked(pack)
    }

    func restore() async {
        // AppStore.sync() always asks for the Apple ID password — only use it when needed.
        await refreshEntitlements()
        guard ShadowPack.all.contains(where: { !isUnlocked($0) }) else { return }
        do {
            try await AppStore.sync()
        } catch {
            #if DEBUG
            print("PackStore.restore sync error:", error)
            #endif
        }
        await refreshEntitlements()
    }
}
