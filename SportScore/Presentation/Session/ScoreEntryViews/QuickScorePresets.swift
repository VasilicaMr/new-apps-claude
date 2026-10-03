import Foundation

struct QuickPreset: Hashable, Identifiable {
    let value: Int
    var caption: String? = nil
    var id: Int { value }
}

/// One-tap score buttons per sport, so nobody has to type in a noisy room.
/// Values are the scores that actually happen in each game.
enum QuickScorePresets {

    /// Sports whose input is the preset grid (everything without a dedicated entry view).
    static let sports: Set<SportType> = [
        .sportShooting, .axeThrowing, .knifeThrowing, .slingshot, .blowgun,
        .caroms, .cushionCaroms,
        .bowlingNinePin, .skittles, .bocce, .petanque, .boules, .lawnBowls,
        .dominoes, .mahjong, .cribbage,
        .curling, .horseshoes, .cornhole, .ringToss, .shuffleboard,
        .pinball,
    ]

    static func presets(for sport: SportType, variant: String?, context: EntryContext) -> [QuickPreset] {
        var presets = sportPresets(sport, variant: variant)
            ?? context.maxValue.flatMap { $0 <= 12 ? (0...$0).map { QuickPreset(value: $0) } : nil }
            ?? [1, 2, 3, 5, 10].map { QuickPreset(value: $0) }
        if let max = context.maxValue {
            presets = presets.filter { $0.value <= max }
        }
        return presets
    }

    private static func values(_ v: [Int]) -> [QuickPreset] { v.map { QuickPreset(value: $0) } }

    private static func sportPresets(_ sport: SportType, variant: String?) -> [QuickPreset]? {
        switch sport {
        case .sportShooting:
            return values(Array(0...10))
        case .axeThrowing:
            return [QuickPreset(value: 0, caption: "Miss")] + values([1, 2, 3, 4])
                + [QuickPreset(value: 6, caption: "Bull"), QuickPreset(value: 7, caption: "Clutch")]
        case .knifeThrowing, .slingshot, .blowgun:
            return [QuickPreset(value: 0, caption: "Miss")] + values(Array(1...5))
        case .caroms, .cushionCaroms:
            return values([0, 1, 2, 3, 4, 5, 6, 8, 10])
        case .bowlingNinePin, .skittles:
            return values(Array(0...9))
        case .bocce:
            return values(Array(0...4))
        case .petanque, .boules:
            return values(Array(0...6))
        case .lawnBowls, .curling:
            return values(Array(0...8))
        case .dominoes:
            return values([5, 10, 15, 20, 25, 30, 40, 50])
        case .mahjong:
            switch variant {
            case "Japanese": return values([1000, 2000, 3900, 5800, 8000, 12000, 18000, 24000])
            case "American": return values([25, 30, 35, 40, 50, 60, 75, 100])
            default:         return values([8, 12, 16, 24, 32, 48, 64, 88])
            }
        case .cribbage:
            return values([1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 24])
        case .horseshoes:
            return [QuickPreset(value: 1, caption: "Close"), QuickPreset(value: 2), QuickPreset(value: 3, caption: "Ringer"),
                    QuickPreset(value: 4), QuickPreset(value: 6, caption: "2 ringers")]
        case .cornhole:
            return [QuickPreset(value: 1, caption: "Board"), QuickPreset(value: 2), QuickPreset(value: 3, caption: "Hole")]
                + values([4, 5, 6, 9, 12])
        case .shuffleboard:
            return [QuickPreset(value: 7), QuickPreset(value: 8), QuickPreset(value: 10),
                    QuickPreset(value: -10, caption: "Kitchen")]
        case .ringToss:
            return values([1, 2, 3, 5, 10])
        case .pinball:
            return values([10_000, 50_000, 100_000, 250_000, 500_000, 1_000_000, 5_000_000, 10_000_000])
        default:
            return nil
        }
    }

    /// "12K", "1.5M" for big numbers; plain digits otherwise.
    static func format(_ value: Int, signed: Bool = false) -> String {
        let body = abs(value) >= 1000
            ? abs(value).formatted(.number.notation(.compactName))
            : "\(abs(value))"
        if value < 0 { return "−\(body)" }
        return signed ? "+\(body)" : body
    }
}
