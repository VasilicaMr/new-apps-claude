//
//  UnlockViewModel.swift
//  LittlePhysicsTrail
//

import Foundation
import Observation
import TrailDomain

@MainActor
@Observable
final class UnlockViewModel {
    /// The stops the Full Journey adds (shown even after purchase, as "what you got").
    let includedStops: [JourneyStop]
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    var message: String?

    private let unlock: UnlockJourneyUseCase

    init(includedStops: [JourneyStop], unlock: UnlockJourneyUseCase) {
        self.includedStops = includedStops
        self.unlock = unlock
    }

    var isUnlocked: Bool { unlock.isUnlocked }
    var price: String? { unlock.offer?.displayPrice }
    var itemCount: Int { includedStops.reduce(0) { $0 + $1.items.count } }

    func load() async {
        if price == nil { await unlock.load() } // e.g. offline at launch
    }

    func buy() async {
        isPurchasing = true
        defer { isPurchasing = false }
        switch await unlock.purchase() {
        case .unlocked, .cancelled:
            break
        case .pending:
            message = "Waiting for approval. The journey unlocks as soon as it's approved."
        case .failed(let reason):
            message = reason
        }
    }

    func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        if !(await unlock.restore()) {
            message = "No previous purchase was found for this Apple ID."
        }
    }
}
