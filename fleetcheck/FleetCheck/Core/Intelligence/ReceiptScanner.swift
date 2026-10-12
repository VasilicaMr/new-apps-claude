import Foundation
import FoundationModels

/// Receipt photo → expense, on device: Vision reads the text, Apple Intelligence understands it,
/// keyword matching (`ReceiptTextParser`) covers iPhones without Apple Intelligence.
struct ReceiptScanner: Sendable {
    var reader = ScreenshotTextReader()
    var parser = ReceiptTextParser()
    var useAppleIntelligence = true

    func scan(_ imageData: Data) async throws -> ScannedReceipt {
        let lines = EarningsTextParser().lines(from: try await reader.fragments(in: imageData))
        let fallback = parser.parse(lines: lines)
        guard useAppleIntelligence, AppleIntelligence.status == .available else { return fallback }
        do {
            var result = try await extract(lines)
            if result.liters == nil { result.liters = fallback.liters }
            if result.date == nil { result.date = fallback.date }
            if result.vendor == nil { result.vendor = fallback.vendor }
            return result.isEmpty ? fallback : result
        } catch {
            return fallback
        }
    }

    @Generable(description: "A receipt for a driver's car expense")
    struct GeneratedReceipt {
        var category: ExpenseCategoryArgument
        @Guide(description: "Total amount paid, as a plain number; 0 if not visible")
        var total: Double
        @Guide(description: "Liters of fuel (or kWh); 0 if not a fuel/charging receipt")
        var liters: Double
        @Guide(description: "Store, station or garage name; empty if unknown")
        var vendor: String
        @Guide(description: "Receipt date as yyyy-MM-dd; empty if not visible")
        var date: String
    }

    private func extract(_ lines: [String]) async throws -> ScannedReceipt {
        let session = LanguageModelSession(instructions: """
            You read text recognized from a photo of a receipt (often Romanian: TOTAL, TVA, BENZINA, MOTORINA, LITRI) \
            and extract the expense. Numbers may use a comma for decimals ("250,00" is 250.00). \
            The total is the final amount paid, not a VAT (TVA) or subtotal line. Do not invent values.
            """)
        let text = String(lines.joined(separator: "\n").prefix(4_000))
        let generated = try await session.respond(to: "Receipt text:\n\(text)", generating: GeneratedReceipt.self,
                                                  options: GenerationOptions(sampling: .greedy)).content
        return ScannedReceipt(
            category: generated.category.category,
            amount: generated.total > 0 ? generated.total : nil,
            liters: generated.liters > 0 ? generated.liters : nil,
            vendor: generated.vendor.isEmpty ? nil : generated.vendor,
            date: generated.date.isEmpty ? nil : try? Date(generated.date, strategy: .iso8601.year().month().day()),
            source: .appleIntelligence)
    }
}
