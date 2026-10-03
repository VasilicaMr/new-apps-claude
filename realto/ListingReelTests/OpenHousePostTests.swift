import XCTest
@testable import ListingReel

/// Pure domain coverage for open house posts and post captions — the on-device model is faked.
final class OpenHousePostTests: XCTestCase {

    private final class FakeCaptionWriter: PostCaptionWriter {
        var isAvailable = true
        var caption = PostCaption(hook: " Your weekend plans just changed 🏡 ", body: "Sunlit kitchen, big backyard.",
                                  hashtags: ["#DreamKitchen", "openhouse", "Backyard Goals", ""])
        var error: PostCaptionError?
        private(set) var lastRequest: PostCaptionRequest?
        func writeCaption(for request: PostCaptionRequest) async throws -> PostCaption {
            lastRequest = request
            if let error { throw error }
            return caption
        }
    }

    private final class FakeScriptWriter: VoiceoverScriptWriter {
        var isAvailable = true
        private(set) var lastRequest: VoiceoverScriptRequest?
        func writeScript(for request: VoiceoverScriptRequest) async throws -> String {
            lastRequest = request
            return "Come see it Saturday."
        }
    }

    private let utc = TimeZone(identifier: "UTC")!
    private let enUS = Locale(identifier: "en_US")

    /// Saturday, October 4, 2025, 14:00–16:00 UTC.
    private var schedule: OpenHouseSchedule {
        let start = Date(timeIntervalSince1970: 1_759_586_400)
        return OpenHouseSchedule(start: start, end: start.addingTimeInterval(2 * 60 * 60))
    }

    private var source: Project {
        Project(name: "Willow",
                propertyInfo: PropertyInfo(address: "12 Oak St", price: "$749,000", beds: 3, headline: "Just Listed"),
                clips: [MediaClip(sourceIdentifier: "a", kind: .video, order: 0, roomLabel: "Kitchen")],
                templateID: "bold",
                musicTrackID: "track",
                voiceover: Voiceover(script: "Just listed!", voiceID: "my-voice"),
                socialCaption: "Old caption")
    }

    private let brand = BrandProfile(agentName: "Dana Reyes", phone: "555-0100", brokerage: "Oak Realty")

    // MARK: - Schedule

    func testScheduleFormatsWithoutMinutesOnTheHour() {
        let badge = schedule.badge(locale: enUS, timeZone: utc)
        XCTAssertTrue(badge.hasPrefix("Open House Sat"), badge)
        XCTAssertFalse(badge.contains(":"), badge)
        XCTAssertTrue(schedule.spokenWhen(locale: enUS, timeZone: utc).contains("Saturday, October 4"))
    }

    func testScheduleShowsMinutesWhenNeeded() {
        var halfPast = schedule
        halfPast.end = halfPast.end.addingTimeInterval(30 * 60)
        XCTAssertTrue(halfPast.badge(locale: enUS, timeZone: utc).contains(":30"))
    }

    func testSuggestedScheduleIsNextSaturdayAfternoonForTwoHours() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let wednesday = Date(timeIntervalSince1970: 1_759_276_800) // Wed, October 1, 2025
        let suggested = OpenHouseSchedule.suggested(after: wednesday, calendar: calendar)
        XCTAssertEqual(calendar.component(.weekday, from: suggested.start), 7)
        XCTAssertEqual(calendar.component(.hour, from: suggested.start), 13)
        XCTAssertEqual(suggested.end.timeIntervalSince(suggested.start), 2 * 60 * 60)
        XCTAssertTrue(suggested.isValid)
    }

    // MARK: - New project

    func testOpenHouseProjectReusesFootageAndDropsOldCopy() {
        let post = CreateOpenHousePostUseCase.makeProject(from: source, schedule: schedule)
        XCTAssertNotEqual(post.id, source.id)
        XCTAssertEqual(post.clips, source.clips)
        XCTAssertEqual(post.templateID, "bold")
        XCTAssertEqual(post.musicTrackID, "track")
        XCTAssertEqual(post.openHouse, schedule)
        XCTAssertEqual(post.propertyInfo.headline, schedule.badge())
        XCTAssertEqual(post.propertyInfo.price, "$749,000")
        XCTAssertEqual(post.voiceover, Voiceover(script: "", voiceID: "my-voice"))
        XCTAssertNil(post.socialCaption)
    }

    func testCreateWritesOpenHouseNarrationAndCaption() async {
        let scripts = FakeScriptWriter()
        let captions = FakeCaptionWriter()
        let useCase = CreateOpenHousePostUseCase(writeVoiceover: WriteVoiceoverScriptUseCase(writer: scripts),
                                                 writeCaption: WritePostCaptionUseCase(writer: captions))

        let result = await useCase.create(from: source, schedule: schedule, brand: brand)

        XCTAssertNil(result.notice)
        XCTAssertEqual(result.project.voiceover, Voiceover(script: "Come see it Saturday.", voiceID: "my-voice"))
        XCTAssertEqual(scripts.lastRequest?.openHouseWhen, schedule.spokenWhen())
        XCTAssertEqual(captions.lastRequest?.openHouseWhen, schedule.spokenWhen())
        let caption = try? XCTUnwrap(result.project.socialCaption)
        XCTAssertTrue(caption?.hasPrefix("Your weekend plans just changed 🏡") ?? false)
        XCTAssertTrue(caption?.contains(schedule.spokenWhen()) ?? false)
    }

    func testCreateFallsBackToPlainCaptionWhenTheModelFails() async {
        let scripts = FakeScriptWriter()
        scripts.isAvailable = false
        let captions = FakeCaptionWriter()
        captions.error = .refused
        let useCase = CreateOpenHousePostUseCase(writeVoiceover: WriteVoiceoverScriptUseCase(writer: scripts),
                                                 writeCaption: WritePostCaptionUseCase(writer: captions))

        let result = await useCase.create(from: source, schedule: schedule, brand: brand)

        XCTAssertEqual(result.notice, PostCaptionError.refused.errorDescription)
        XCTAssertNil(scripts.lastRequest)
        XCTAssertEqual(result.project.voiceover?.hasScript, false)
        XCTAssertEqual(result.project.socialCaption,
                       WritePostCaptionUseCase.basicCaption(project: result.project, brand: brand))
    }

    // MARK: - Caption

    func testHashtagsPutTheMomentFirstAndAreCleanedDedupedAndCapped() {
        let tags = WritePostCaptionUseCase.hashtags(
            ["#DreamKitchen", "openhouse", "Backyard Goals", "", "a", "b", "c"], isOpenHouse: true)
        XCTAssertEqual(tags, ["#OpenHouse", "#RealEstate", "#DreamKitchen", "#BackyardGoals", "#a", "#b"])
    }

    func testBasicCaptionHasTheFactsAndContact() {
        let caption = WritePostCaptionUseCase.basicCaption(project: source, brand: brand)
        XCTAssertTrue(caption.hasPrefix("Just Listed"))
        XCTAssertTrue(caption.contains("📍 12 Oak St"))
        XCTAssertTrue(caption.contains("$749,000 · 3 bd"))
        XCTAssertTrue(caption.contains("📞 Dana Reyes · Oak Realty · 555-0100"))
        XCTAssertTrue(caption.hasSuffix("#JustListed #RealEstate"))
    }

    func testWriteCaptionIsRejectedUpFrontWhenUnavailable() async {
        let captions = FakeCaptionWriter()
        captions.isAvailable = false
        do {
            _ = try await WritePostCaptionUseCase(writer: captions).write(project: source, brand: nil)
            XCTFail("Expected unavailable")
        } catch {
            XCTAssertEqual(error as? PostCaptionError, .unavailable)
        }
        XCTAssertNil(captions.lastRequest)
    }

    func testProjectsSavedBeforeThisFeatureStillDecode() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as! [String: Any]
        json.removeValue(forKey: "openHouse")
        json.removeValue(forKey: "socialCaption")
        let decoded = try JSONDecoder().decode(Project.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.openHouse)
        XCTAssertNil(decoded.socialCaption)
    }
}
