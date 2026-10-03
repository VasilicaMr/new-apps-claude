import XCTest
@testable import ListingReel

/// Pure domain coverage for "scan a listing sheet" — the OCR + model reader is faked.
final class ListingSheetScanTests: XCTestCase {

    private struct FakeReader: ListingSheetReader {
        var isAvailable = true
        var result = PropertyInfo()
        func readPropertyInfo(fromImage imageData: Data) async throws -> PropertyInfo { result }
    }

    func testFillingBlanksNeverOverwritesTypedValues() {
        let typed = PropertyInfo(address: "12 Oak St", price: nil, beds: 4, baths: nil,
                                 squareFeet: nil, headline: "  ")
        let scanned = PropertyInfo(address: "99 Elm Rd", price: "$749,000", beds: 3, baths: 2.5,
                                   squareFeet: 1850, headline: "Just Listed")

        let merged = typed.fillingBlanks(from: scanned)

        XCTAssertEqual(merged.address, "12 Oak St")
        XCTAssertEqual(merged.beds, 4)
        XCTAssertEqual(merged.price, "$749,000")
        XCTAssertEqual(merged.baths, 2.5)
        XCTAssertEqual(merged.squareFeet, 1850)
        XCTAssertEqual(merged.headline, "Just Listed", "whitespace-only counts as blank")
    }

    func testScanReturnsReaderResult() async throws {
        let useCase = ScanListingSheetUseCase(
            reader: FakeReader(result: PropertyInfo(address: "99 Elm Rd", beds: 3)))
        let scanned = try await useCase.scan(imageData: Data())
        XCTAssertEqual(scanned.address, "99 Elm Rd")
        XCTAssertEqual(scanned.beds, 3)
    }

    func testScanThrowsWhenNothingWasFound() async {
        let useCase = ScanListingSheetUseCase(reader: FakeReader(result: PropertyInfo()))
        do {
            _ = try await useCase.scan(imageData: Data())
            XCTFail("expected noDetailsFound")
        } catch {
            XCTAssertEqual(error as? ListingSheetScanError, .noDetailsFound)
        }
    }

    func testScanThrowsWhenUnavailable() async {
        let useCase = ScanListingSheetUseCase(reader: FakeReader(isAvailable: false))
        XCTAssertFalse(useCase.isAvailable)
        do {
            _ = try await useCase.scan(imageData: Data())
            XCTFail("expected unavailable")
        } catch {
            XCTAssertEqual(error as? ListingSheetScanError, .unavailable)
        }
    }
}
