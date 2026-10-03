import XCTest
@testable import ListingReel

/// Pure domain coverage for the AI voiceover script — the on-device model is faked.
final class VoiceoverScriptTests: XCTestCase {

    private final class FakeWriter: VoiceoverScriptWriter {
        var isAvailable = true
        var script = "  Welcome home.  "
        private(set) var lastRequest: VoiceoverScriptRequest?
        func writeScript(for request: VoiceoverScriptRequest) async throws -> String {
            lastRequest = request
            return script
        }
    }

    private func project(clips: [MediaClip], info: PropertyInfo = PropertyInfo(address: "12 Oak St")) -> Project {
        Project(propertyInfo: info, clips: clips, templateID: "t")
    }

    func testRoomOrderFollowsPlaybackOrderAndCollapsesRepeats() {
        let clips = [
            MediaClip(sourceIdentifier: "c", kind: .video, order: 2, roomLabel: "Kitchen"),
            MediaClip(sourceIdentifier: "a", kind: .video, order: 0, roomLabel: "Exterior"),
            MediaClip(sourceIdentifier: "b", kind: .video, order: 1, roomLabel: "Kitchen"),
            MediaClip(sourceIdentifier: "d", kind: .photo, order: 3, roomLabel: nil),
            MediaClip(sourceIdentifier: "e", kind: .video, order: 4, roomLabel: " "),
            MediaClip(sourceIdentifier: "f", kind: .video, order: 5, roomLabel: "Backyard"),
        ]
        XCTAssertEqual(WriteVoiceoverScriptUseCase.roomOrder(of: project(clips: clips)),
                       ["Exterior", "Kitchen", "Backyard"])
    }

    func testWritePassesDetailsAndTrimsScript() async throws {
        let writer = FakeWriter()
        let useCase = WriteVoiceoverScriptUseCase(writer: writer)
        let brand = BrandProfile(agentName: "Dana Reyes", brokerage: "  ")

        let script = try await useCase.write(
            project: project(clips: [MediaClip(sourceIdentifier: "a", kind: .video, order: 0, roomLabel: "Kitchen")]),
            brand: brand)

        XCTAssertEqual(script, "Welcome home.")
        XCTAssertEqual(writer.lastRequest?.roomOrder, ["Kitchen"])
        XCTAssertEqual(writer.lastRequest?.agentName, "Dana Reyes")
        XCTAssertNil(writer.lastRequest?.brokerage)
        XCTAssertEqual(writer.lastRequest?.targetSeconds, 30)
    }

    func testWriteNeedsSomethingToTalkAbout() async {
        let useCase = WriteVoiceoverScriptUseCase(writer: FakeWriter())
        do {
            _ = try await useCase.write(project: project(clips: [], info: PropertyInfo()), brand: nil)
            XCTFail("Expected missingDetails")
        } catch {
            XCTAssertEqual(error as? VoiceoverScriptError, .missingDetails)
        }
    }

    func testUnavailableWriterIsRejectedUpFront() async {
        let writer = FakeWriter()
        writer.isAvailable = false
        do {
            _ = try await WriteVoiceoverScriptUseCase(writer: writer).write(project: project(clips: []), brand: nil)
            XCTFail("Expected unavailable")
        } catch {
            XCTAssertEqual(error as? VoiceoverScriptError, .unavailable)
        }
        XCTAssertNil(writer.lastRequest)
    }

    func testEstimatedSecondsIsAboutThirtyForSeventyWords() {
        let script = Array(repeating: "word", count: 69).joined(separator: " ")
        XCTAssertEqual(WriteVoiceoverScriptUseCase.estimatedSeconds(of: script), 30)
    }

    // MARK: - Narration in preview/export ("only if available")

    private final class FakeAudioRenderer: NarrationAudioRenderer {
        var fails = false
        private(set) var calls: [(script: String, voiceID: String?)] = []
        func renderAudio(script: String, voiceID: String?) async throws -> URL {
            calls.append((script, voiceID))
            if fails { throw CancellationError() }
            return URL(fileURLWithPath: "/tmp/voiceover.caf")
        }
    }

    private func narratedProject(_ script: String) -> Project {
        var project = project(clips: [])
        project.voiceover = Voiceover(script: script, voiceID: "voice.1")
        return project
    }

    func testNarratesWhenAvailableWithScript() async {
        let audio = FakeAudioRenderer()
        let useCase = NarrateVoiceoverUseCase(writer: FakeWriter(), renderer: audio)

        let url = await useCase.audio(for: narratedProject("  Welcome home.\n"))

        XCTAssertNotNil(url)
        XCTAssertEqual(audio.calls.first?.script, "Welcome home.")
        XCTAssertEqual(audio.calls.first?.voiceID, "voice.1")
    }

    func testNoNarrationWhenFeatureUnavailable() async {
        let writer = FakeWriter()
        writer.isAvailable = false
        let audio = FakeAudioRenderer()
        let useCase = NarrateVoiceoverUseCase(writer: writer, renderer: audio)

        XCTAssertFalse(useCase.willNarrate(narratedProject("Welcome home.")))
        let url = await useCase.audio(for: narratedProject("Welcome home."))
        XCTAssertNil(url)
        XCTAssertTrue(audio.calls.isEmpty)
    }

    func testNoNarrationWithoutScript() async {
        let audio = FakeAudioRenderer()
        let useCase = NarrateVoiceoverUseCase(writer: FakeWriter(), renderer: audio)

        let blank = await useCase.audio(for: narratedProject("   "))
        let none = await useCase.audio(for: project(clips: []))
        XCTAssertNil(blank)
        XCTAssertNil(none)
        XCTAssertTrue(audio.calls.isEmpty)
    }

    func testSpeechFailureMeansNoNarrationNotAFailedExport() async {
        let audio = FakeAudioRenderer()
        audio.fails = true
        let url = await NarrateVoiceoverUseCase(writer: FakeWriter(), renderer: audio)
            .audio(for: narratedProject("Welcome home."))
        XCTAssertNil(url)
    }
}
