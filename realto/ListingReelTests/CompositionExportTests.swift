import XCTest
import AVFoundation
import UIKit
@testable import ListingReel

/// Composition + export pipeline tests exercising every step of the "create a
/// video" wizard's export area against real (synthetic) media — spec §4 and the
/// §4.5 reliability checklist. Fixtures live in `ListingReelTests/Fixtures`
/// (simple generated clips/photo standing in for real listing footage).
///
/// `ListingReelTests` is hosted by the `ListingReel` app (see `TEST_HOST` /
/// `BUNDLE_LOADER` in project.yml) so `Bundle.main` here resolves to the real
/// app bundle — the same one production code sees at runtime. That's what lets
/// `testAllBundledMusicTracksResolveToRealFiles` actually catch a music track
/// that isn't shipped in the bundle (the reported "songs don't work" bug: the
/// three catalog tracks pointed at `.m4a` files that were never added to the
/// app, so `CompositionAssembler.musicURL` silently returned nil and no music
/// was ever attached).
final class CompositionExportTests: XCTestCase {

    // MARK: - Fixtures

    private func fixtureURL(_ name: String, ext: String) -> URL {
        guard let url = Bundle(for: Self.self).url(forResource: name, withExtension: ext) else {
            XCTFail("Missing test fixture \(name).\(ext)")
            return URL(fileURLWithPath: "/dev/null")
        }
        return url
    }

    private func clip(_ fixture: String, order: Int,
                       trimStart: TimeInterval? = nil, trimEnd: TimeInterval? = nil) -> MediaClip {
        let url = fixtureURL(fixture, ext: "mp4")
        return MediaClip(sourceIdentifier: "file:\(url.path)", kind: .video,
                          trimStart: trimStart, trimEnd: trimEnd, order: order)
    }

    private let brand = BrandProfile(agentName: "Jane Realtor", phone: "(555) 123-4567",
                                      brokerage: "Blue Door Realty")

    private func project(clips: [MediaClip], templateID: String = "classic",
                          aspectRatios: Set<AspectRatio> = [.vertical9x16],
                          resolution: Resolution = .hd1080,
                          musicTrackID: ListingReel.MusicTrack.ID? = nil,
                          watermark: Bool = false) -> Project {
        var p = Project(
            propertyInfo: PropertyInfo(address: "123 Maple Ave", price: "$749,000",
                                        beds: 3, baths: 2, squareFeet: 1850, headline: "Just Listed"),
            clips: clips, templateID: templateID)
        p.musicTrackID = musicTrackID
        p.exportSettings = ExportSettings(aspectRatios: aspectRatios, resolution: resolution,
                                           codec: .hevc, includeWatermark: watermark)
        return p
    }

    private func makeAssembler() -> CompositionAssembler { CompositionAssembler(resolver: AVAssetResolver()) }
    private func makeRenderer() -> AVVideoCompositionService {
        AVVideoCompositionService(brandRepository: FileBrandProfileRepository())
    }

    private var tempFilesToClean: [URL] = []
    override func tearDown() {
        for url in tempFilesToClean { try? FileManager.default.removeItem(at: url) }
        tempFilesToClean = []
        super.tearDown()
    }

    @discardableResult
    private func export(clips: [MediaClip], templateID: String = "classic",
                         aspectRatios: Set<AspectRatio> = [.vertical9x16],
                         resolution: Resolution = .hd1080,
                         musicTrackID: ListingReel.MusicTrack.ID? = nil,
                         watermark: Bool = false) async throws -> [ExportedFile] {
        let template = DefaultTemplateRepository().template(id: templateID)!
        let music = musicTrackID.flatMap { DefaultMusicRepository().track(id: $0) }
        let proj = project(clips: clips, templateID: templateID, aspectRatios: aspectRatios,
                            resolution: resolution, musicTrackID: musicTrackID, watermark: watermark)
        let files = try await makeRenderer().export(
            project: proj, template: template, brand: brand, music: music, narration: nil,
            settings: proj.exportSettings, progress: { _ in })
        tempFilesToClean.append(contentsOf: files.map(\.url))
        return files
    }

    // MARK: - 1. Music — step 5 (regression coverage for the reported bug)

    func testAllBundledMusicTracksResolveToRealFiles() {
        for track in DefaultMusicRepository().allTracks() {
            let url = CompositionAssembler.musicURL(for: track)
            XCTAssertNotNil(url, "'\(track.fileName)' is not bundled — picking '\(track.title)' " +
                             "would silently export with no music.")
            if let url { XCTAssertTrue(FileManager.default.fileExists(atPath: url.path)) }
        }
    }

    func testAssembleAttachesSelectedMusicAsAudioTrack() async throws {
        let music = DefaultMusicRepository().track(id: "upbeat_01")!
        let assembled = try await makeAssembler().assemble(
            project: project(clips: [clip("exterior_landscape", order: 0)]), music: music,
            stillSize: CGSize(width: 720, height: 720), useSourceAudioIfNoMusic: true)

        let audioTracks = assembled.composition.tracks(withMediaType: .audio)
        XCTAssertFalse(audioTracks.isEmpty, "No audio track after selecting music — the reported bug.")
        XCTAssertGreaterThan(audioTracks[0].timeRange.duration.seconds, 0)
    }

    func testAssembleMixesVoiceoverOverMusicWithDucking() async throws {
        let music = DefaultMusicRepository().track(id: "upbeat_01")!
        // Any audio file stands in for the rendered speech here.
        let narration = try XCTUnwrap(CompositionAssembler.musicURL(
            for: DefaultMusicRepository().track(id: "calm_01")!))
        let assembled = try await makeAssembler().assemble(
            project: project(clips: [clip("exterior_landscape", order: 0)]), music: music,
            narration: narration,
            stillSize: CGSize(width: 720, height: 720), useSourceAudioIfNoMusic: true)

        let audioTracks = assembled.composition.tracks(withMediaType: .audio)
        XCTAssertEqual(audioTracks.count, 2, "Voiceover should get its own track over the music.")
        let voiceover = audioTracks[1].timeRange
        XCTAssertEqual(voiceover.start, CompositionAssembler.narrationLeadIn)
        XCTAssertLessThanOrEqual(voiceover.end, assembled.totalDuration,
                                 "Voiceover must be cut off at the video's end.")
        XCTAssertNotNil(assembled.audioMix, "Music should duck under the voiceover.")
    }

    func testAssembleWithoutNarrationHasNoAudioMix() async throws {
        let assembled = try await makeAssembler().assemble(
            project: project(clips: [clip("exterior_landscape", order: 0)]),
            music: DefaultMusicRepository().track(id: "upbeat_01")!,
            stillSize: CGSize(width: 720, height: 720), useSourceAudioIfNoMusic: true)
        XCTAssertEqual(assembled.composition.tracks(withMediaType: .audio).count, 1)
        XCTAssertNil(assembled.audioMix)
    }

    func testAssembleWithoutMusicFallsBackToSourceAudio() async throws {
        let assembled = try await makeAssembler().assemble(
            project: project(clips: [clip("exterior_landscape", order: 0)]), music: nil,
            stillSize: CGSize(width: 720, height: 720), useSourceAudioIfNoMusic: true)
        XCTAssertFalse(assembled.composition.tracks(withMediaType: .audio).isEmpty)
    }

    func testExportedFileActuallyContainsTheSelectedMusic() async throws {
        let track = DefaultMusicRepository().track(id: "calm_01")!
        let files = try await export(clips: [clip("living_room_portrait", order: 0)],
                                      aspectRatios: [.vertical9x16], musicTrackID: track.id)
        let asset = AVURLAsset(url: files[0].url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertFalse(audioTracks.isEmpty, "Exported file has no audio track even though music was selected.")
    }

    // MARK: - 2. Media / orientation — step 1 (spec §4.1, "the single most common bug")

    func testPortraitClipOrientedSizeStaysPortrait() async throws {
        let assembled = try await makeAssembler().assemble(
            project: project(clips: [clip("living_room_portrait", order: 0)]), music: nil,
            stillSize: CGSize(width: 720, height: 720), useSourceAudioIfNoMusic: false)
        let size = assembled.segments[0].orientedSize
        XCTAssertGreaterThan(size.height, size.width)
    }

    func testLandscapeClipOrientedSizeStaysLandscape() async throws {
        let assembled = try await makeAssembler().assemble(
            project: project(clips: [clip("exterior_landscape", order: 0)]), music: nil,
            stillSize: CGSize(width: 720, height: 720), useSourceAudioIfNoMusic: false)
        let size = assembled.segments[0].orientedSize
        XCTAssertGreaterThan(size.width, size.height)
    }

    func testLandscapeStoredPortraitTransformCorrectsOrientation() async throws {
        // kitchen_rotated.mp4 is stored 1080x608 (landscape) with a baked-in 90°
        // preferredTransform — exactly how a real iPhone portrait recording is
        // encoded. If this regresses, portrait exports come out sideways.
        let assembled = try await makeAssembler().assemble(
            project: project(clips: [clip("kitchen_rotated", order: 0)]), music: nil,
            stillSize: CGSize(width: 720, height: 720), useSourceAudioIfNoMusic: false)
        let size = assembled.segments[0].orientedSize
        XCTAssertGreaterThan(size.height, size.width,
            "Orientation transform was not honored — this is the spec §4.1 rotation bug.")
    }

    func testMixedOrientationProjectAssemblesAllSegmentsInOrder() async throws {
        let clips = [
            clip("living_room_portrait", order: 0),
            clip("exterior_landscape", order: 1),
            clip("kitchen_rotated", order: 2)
        ]
        let assembled = try await makeAssembler().assemble(
            project: project(clips: clips), music: nil,
            stillSize: CGSize(width: 720, height: 720), useSourceAudioIfNoMusic: false)
        XCTAssertEqual(assembled.segments.count, 3)
        XCTAssertEqual(assembled.totalDuration.seconds, 6, accuracy: 0.2)
    }

    func testTrimmedClipProducesShorterSegment() async throws {
        let trimmed = clip("hallway_long", order: 0, trimStart: 1, trimEnd: 3)
        let assembled = try await makeAssembler().assemble(
            project: project(clips: [trimmed]), music: nil,
            stillSize: CGSize(width: 720, height: 720), useSourceAudioIfNoMusic: false)
        XCTAssertEqual(assembled.totalDuration.seconds, 2, accuracy: 0.1)
    }

    // MARK: - 3. Photos-to-video (spec §4.5 checklist item)

    func testPhotoRendersAsVideoSegmentAndAssembles() async throws {
        let image = try loadFixtureImage("property_photo")
        let videoURL = try await StillImageVideoGenerator().makeVideo(
            from: image, duration: 3, size: CGSize(width: 720, height: 720))
        tempFilesToClean.append(videoURL)

        let photoClip = MediaClip(sourceIdentifier: "file:\(videoURL.path)", kind: .video, order: 0)
        let assembled = try await makeAssembler().assemble(
            project: project(clips: [photoClip]), music: nil,
            stillSize: CGSize(width: 720, height: 720), useSourceAudioIfNoMusic: false)
        XCTAssertEqual(assembled.segments.count, 1)
        XCTAssertEqual(assembled.totalDuration.seconds, 3, accuracy: 0.2)
    }

    private func loadFixtureImage(_ name: String) throws -> UIImage {
        let data = try Data(contentsOf: fixtureURL(name, ext: "jpg"))
        return try XCTUnwrap(UIImage(data: data))
    }

    // MARK: - 4. Export — steps 2/3/4/7 (templates, formats, resolution, watermark)

    func testExportProducesOneFileForEachRequestedAspectRatio() async throws {
        // Multi-format one-tap export (spec §1.4.6).
        let clips = [clip("living_room_portrait", order: 0), clip("exterior_landscape", order: 1)]
        let files = try await export(clips: clips, aspectRatios: [.vertical9x16, .square1x1, .wide16x9])
        XCTAssertEqual(files.count, 3)
        XCTAssertEqual(Set(files.map(\.aspectRatio)), [.vertical9x16, .square1x1, .wide16x9])

        for file in files {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.url.path))
            XCTAssertGreaterThan(file.fileSizeBytes, 0)
            let asset = AVURLAsset(url: file.url)
            let track = try await asset.loadTracks(withMediaType: .video).first
            let naturalSize = try await track?.load(.naturalSize) ?? .zero
            let expected = file.aspectRatio.renderSize(for: .hd1080)
            XCTAssertEqual(abs(naturalSize.width), expected.width, accuracy: 2)
            XCTAssertEqual(abs(naturalSize.height), expected.height, accuracy: 2)
        }
    }

    func test4KExportProducesCorrectRenderSize() async throws {
        let files = try await export(clips: [clip("exterior_landscape", order: 0)],
                                      aspectRatios: [.wide16x9], resolution: .uhd4K)
        let asset = AVURLAsset(url: files[0].url)
        let track = try await asset.loadTracks(withMediaType: .video).first
        let size = try await track?.load(.naturalSize) ?? .zero
        XCTAssertEqual(abs(size.width), 3840, accuracy: 2)
        XCTAssertEqual(abs(size.height), 2160, accuracy: 2)
    }

    func testExportSucceedsWithWatermarkOn() async throws {
        let files = try await export(clips: [clip("exterior_landscape", order: 0)], watermark: true)
        XCTAssertGreaterThan(files[0].fileSizeBytes, 0)
    }

    func testExportSucceedsWithWatermarkOff() async throws {
        let files = try await export(clips: [clip("exterior_landscape", order: 0)], watermark: false)
        XCTAssertGreaterThan(files[0].fileSizeBytes, 0)
    }

    func testEveryBuiltInTemplateExportsSuccessfully() async throws {
        // Templates are data (spec §1.4.5) — every shipped template must actually render.
        for template in DefaultTemplateRepository.builtIn {
            let files = try await export(clips: [clip("living_room_portrait", order: 0)],
                                          templateID: template.id, aspectRatios: [.vertical9x16])
            XCTAssertEqual(files.count, 1, "Template '\(template.id)' failed to export.")
            XCTAssertGreaterThan(files[0].fileSizeBytes, 0, "Template '\(template.id)' produced an empty file.")
        }
    }

    func testOverlayFactoryHandlesMissingOptionalPropertyAndBrandFields() {
        // Property/branding steps feed into the overlay layer — missing optional
        // fields (no headline/price/logo/brand) must not crash card layout.
        let template = DefaultTemplateRepository().template(id: "bold")!
        let layer = OverlayLayerFactory().makeOverlayLayer(.init(
            template: template, brand: nil, property: PropertyInfo(address: ""),
            logo: nil, renderSize: CGSize(width: 1080, height: 1920),
            introDuration: template.intro.duration, outroDuration: template.outro.duration,
            totalDuration: 10, includeWatermark: true))
        XCTAssertFalse(layer.sublayers?.isEmpty ?? true)
    }

    // MARK: - 5. Failure & reliability — step 7 (spec §4.4/§4.5, never fail silently)

    func testExportThrowsNoClipsForEmptyProject() async {
        let template = DefaultTemplateRepository().template(id: "classic")!
        do {
            _ = try await makeRenderer().export(
                project: project(clips: []), template: template, brand: brand, music: nil,
                narration: nil, settings: ExportSettings(), progress: { _ in })
            XCTFail("Expected RenderError.noClips")
        } catch let error as RenderError {
            XCTAssertEqual(error, .noClips)
        } catch {
            XCTFail("Expected RenderError.noClips, got \(error)")
        }
    }

    func testCancelledExportLeavesNoOrphanTempFiles() async throws {
        let before = try orphanExportFiles()
        let template = DefaultTemplateRepository().template(id: "classic")!
        let renderer = makeRenderer()
        // 4K x 3 formats of a 6s clip gives the cancel a real window to land mid-export.
        let proj = project(clips: [clip("hallway_long", order: 0)],
                            aspectRatios: [.vertical9x16, .square1x1, .wide16x9],
                            resolution: .uhd4K)

        let task = Task {
            try await renderer.export(project: proj, template: template, brand: brand,
                                       music: nil, narration: nil, settings: proj.exportSettings, progress: { _ in })
        }
        try await Task.sleep(nanoseconds: 400_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation to surface as an error")
        } catch {
            // Expected — CancellationError or RenderError.cancelled.
        }

        let after = try orphanExportFiles()
        XCTAssertEqual(before, after, "Cancelled export left orphan temp files behind.")
    }

    private func orphanExportFiles() throws -> Set<String> {
        let dir = FileManager.default.temporaryDirectory
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        return Set(names.filter { $0.hasPrefix("listingreel_") })
    }

    // MARK: - 6. Preview — step 6 (spec §6, preview must reflect the real render)

    func testPreviewComposerProducesAPlayableItem() async throws {
        let template = DefaultTemplateRepository().template(id: "classic")!
        let composer = PreviewComposer(resolver: AVAssetResolver())
        let item = try await composer.makePreviewItem(
            project: project(clips: [clip("living_room_portrait", order: 0)]),
            template: template, brand: brand, music: nil)
        XCTAssertNotNil(item.videoComposition)
        XCTAssertFalse(item.videoComposition?.instructions.isEmpty ?? true)
        let duration = try await item.asset.load(.duration)
        XCTAssertGreaterThan(duration.seconds, 0)
    }
}
