import Foundation
import FoundationModels

/// Screenshot → earnings, entirely on device:
/// 1. Vision reads the text and its layout.
/// 2. Apple Intelligence (Foundation Models) turns the messy text into typed fields.
/// 3. If Apple Intelligence isn't available (older iPhone, turned off, model still downloading)
///    or fails, keyword matching does a best effort instead.
/// The result is always normalized so the parts add up to the total the app shows.
struct EarningsScreenshotScanner: Sendable {
    var reader = ScreenshotTextReader()
    var parser = EarningsTextParser()
    var useAppleIntelligence = true

    func scan(_ imageData: Data, now: Date = .now) async throws -> ScreenshotEarnings {
        let lines = parser.lines(from: try await reader.fragments(in: imageData))
        let fallback = parser.parse(lines: lines, now: now)

        guard useAppleIntelligence, AppleIntelligence.status == .available else { return fallback }
        do {
            var result = try await AppleIntelligenceEarningsExtractor().extract(lines: lines, now: now)
            // Keep keyword results for anything the model left out.
            if result.platform == nil { result.platform = fallback.platform }
            if result.trips == nil { result.trips = fallback.trips }
            if result.isEmpty { return fallback }
            return result.normalized()
        } catch {
            return fallback
        }
    }
}

/// Whether the on-device model can be used, in words a driver understands.
enum AppleIntelligence {
    enum Status: Equatable {
        case available, deviceNotEligible, notEnabled, downloading

        var description: String {
            switch self {
            case .available: "On"
            case .deviceNotEligible: "Not supported on this iPhone"
            case .notEnabled: "Turned off in Settings"
            case .downloading: "Downloading, try again later"
            }
        }
    }

    static var status: Status {
        switch SystemLanguageModel.default.availability {
        case .available: .available
        case .unavailable(.deviceNotEligible): .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): .notEnabled
        case .unavailable: .downloading
        }
    }
}

/// What the model fills in. Descriptions are the model's instructions per field; enums limit
/// the model to valid answers (guided generation).
@Generable(description: "Earnings shown on a ride-sharing driver app screenshot")
struct GeneratedEarnings {
    @Generable
    enum App { case uber, bolt, freenow, other }

    @Generable
    enum Scope { case trip, day, week, unknown }

    @Guide(description: "The app the screenshot is from")
    var platform: App

    @Guide(description: "What the amounts cover: one trip, one day, a week, or unknown")
    var scope: Scope

    @Guide(description: "Date shown on the screen as yyyy-MM-dd, or the first day for a week. Empty if no date is shown.")
    var date: String

    @Guide(description: "Headline total earnings the driver receives, as a plain number. 0 if not shown.")
    var total: Double

    @Guide(description: "Fare / trip earnings before tips and promotions. 0 if not shown separately.")
    var fares: Double

    @Guide(description: "Tips. 0 if not shown.")
    var tips: Double

    @Guide(description: "Promotions, bonuses, quests or boosts added on top. 0 if not shown.")
    var bonus: Double

    @Guide(description: "Number of trips completed. 0 if not shown.")
    var trips: Int
}

struct AppleIntelligenceEarningsExtractor: Sendable {
    /// The on-device model has a small context window; an earnings screen is far below this.
    private let maxCharacters = 4_000

    func extract(lines: [String], now: Date) async throws -> ScreenshotEarnings {
        let session = LanguageModelSession(instructions: """
            You read text recognized from a screenshot of a ride-sharing driver app (Uber, Bolt, FREENOW) \
            and extract the driver's earnings. The text may be in English or Romanian. Each line is one row of \
            the screen; a label and its amount are on the same line. Numbers may use a comma as the decimal \
            separator ("12,50" means 12.50) and a dot for thousands ("1.234,56" means 1234.56). \
            Return amounts as plain numbers without currency. Do not invent values: use 0 or empty when a value \
            is not on the screen. Ignore cash collected, balance, and payouts to the bank account; \
            "Trip earnings"/"Câștiguri din curse" are fares, "Tips"/"Bacșiș" are tips, "Promotions"/"Promoții" are bonus.
            """)
        let today = now.formatted(.iso8601.year().month().day())
        let text = String(lines.joined(separator: "\n").prefix(maxCharacters))
        let response = try await session.respond(
            to: "Today is \(today).\n\nScreenshot text:\n\(text)",
            generating: GeneratedEarnings.self,
            options: GenerationOptions(sampling: .greedy))
        return map(response.content)
    }

    private func map(_ generated: GeneratedEarnings) -> ScreenshotEarnings {
        let platform: Platform? = switch generated.platform {
        case .uber: .uber
        case .bolt: .bolt
        case .freenow: .freeNow
        case .other: nil
        }
        let scope: ScreenshotEarnings.Scope = switch generated.scope {
        case .trip: .trip
        case .day: .day
        case .week: .week
        case .unknown: .unknown
        }
        let positive = { (value: Double) in value > 0 ? value : nil }
        let date = generated.date.isEmpty ? nil : try? Date(generated.date, strategy: .iso8601.year().month().day())
        return ScreenshotEarnings(
            platform: platform,
            scope: scope,
            date: date,
            total: positive(generated.total),
            fares: positive(generated.fares),
            tips: positive(generated.tips),
            bonus: positive(generated.bonus),
            trips: generated.trips > 0 ? generated.trips : nil,
            source: .appleIntelligence)
    }
}
