import XCTest
@testable import ListingReel

/// Pure, fast, device-free domain tests (spec §3.1 "testable core").
final class DomainTests: XCTestCase {

    func testRenderSizesAreEvenAndCorrectAspect() {
        let vertical = AspectRatio.vertical9x16.renderSize(for: .hd1080)
        XCTAssertEqual(vertical.height, 1920)
        XCTAssertEqual(Int(vertical.width) % 2, 0)

        let square = AspectRatio.square1x1.renderSize(for: .hd1080)
        XCTAssertEqual(square.width, square.height)

        let wide = AspectRatio.wide16x9.renderSize(for: .uhd4K)
        XCTAssertEqual(wide.width, 3840)
        XCTAssertEqual(Int(wide.height) % 2, 0)
    }

    func testPropertySpecsLineFormattingUsesImperialUnitsInUSLocale() {
        let info = PropertyInfo(beds: 3, baths: 2, squareFeet: 1850)
        let line = info.specsLine(locale: Locale(identifier: "en_US"))
        XCTAssertTrue(line.contains("3 bd"))
        XCTAssertTrue(line.contains("2 ba"))
        // Grouping separator is locale-dependent; just assert the number + unit.
        XCTAssertTrue(line.contains("850"))
        XCTAssertTrue(line.contains("ft²"))
    }

    /// Auto-by-locale unit handling (spec: localize units/currency, not just strings) — a
    /// metric-system locale should render the area in m² instead of ft².
    func testPropertySpecsLineFormattingUsesMetricUnitsInMetricLocale() {
        let info = PropertyInfo(beds: 3, baths: 2, squareFeet: 1850)
        let line = info.specsLine(locale: Locale(identifier: "fr_FR"))
        XCTAssertTrue(line.contains("m²"))
        XCTAssertFalse(line.contains("ft²"))
    }

    func testHalfBathRendersAsDecimal() {
        let info = PropertyInfo(baths: 2.5)
        XCTAssertTrue(info.specsLine.contains("2.5 ba"))
    }

    func testProjectOrdersClipsByOrderField() {
        let project = Project(
            clips: [
                MediaClip(sourceIdentifier: "b", kind: .video, order: 1),
                MediaClip(sourceIdentifier: "a", kind: .video, order: 0)
            ],
            templateID: "classic")
        XCTAssertEqual(project.orderedClips.map(\.sourceIdentifier), ["a", "b"])
    }

    func testExportSettingsDefaultsToWatermarkedVertical() {
        let settings = ExportSettings()
        XCTAssertTrue(settings.includeWatermark)
        XCTAssertEqual(settings.aspectRatios, [.vertical9x16])
    }

    func testDefaultTemplatesLoad() {
        let repo = DefaultTemplateRepository()
        XCTAssertFalse(repo.allTemplates().isEmpty)
        XCTAssertNotNil(repo.template(id: "classic"))
    }

    func testRenderErrorMessagesAreUserFacing() {
        XCTAssertNotNil(RenderError.noClips.errorDescription)
        XCTAssertFalse(RenderError.cancelled.isRetryable)
        XCTAssertTrue(RenderError.outOfMemory.isRetryable)
    }
}
