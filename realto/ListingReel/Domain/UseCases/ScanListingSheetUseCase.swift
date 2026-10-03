import Foundation

/// Pre-fills the property-info step from a photo of a listing sheet.
struct ScanListingSheetUseCase {
    let reader: ListingSheetReader

    var isAvailable: Bool { reader.isAvailable }

    /// Returns what was read off the sheet; merge it with `PropertyInfo.fillingBlanks(from:)`.
    func scan(imageData: Data) async throws -> PropertyInfo {
        guard reader.isAvailable else { throw ListingSheetScanError.unavailable }
        let scanned = try await reader.readPropertyInfo(fromImage: imageData)
        guard scanned.filledFieldCount > 0 else { throw ListingSheetScanError.noDetailsFound }
        return scanned
    }
}

extension PropertyInfo {
    /// Takes each of `other`'s values only where `self` has nothing (nil or blank), so a
    /// scan never overwrites what the agent already typed.
    func fillingBlanks(from other: PropertyInfo) -> PropertyInfo {
        var result = self
        if address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.address = other.address
        }
        if price.isBlank { result.price = other.price }
        if headline.isBlank { result.headline = other.headline }
        result.beds = beds ?? other.beds
        result.baths = baths ?? other.baths
        result.squareFeet = squareFeet ?? other.squareFeet
        return result
    }

    var filledFieldCount: Int {
        [!address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
         !price.isBlank, !headline.isBlank,
         beds != nil, baths != nil, squareFeet != nil]
            .filter { $0 }.count
    }
}

private extension Optional where Wrapped == String {
    var isBlank: Bool { self?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true }
}
