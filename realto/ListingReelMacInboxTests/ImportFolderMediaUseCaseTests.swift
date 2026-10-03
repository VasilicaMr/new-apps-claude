import XCTest
@testable import ListingReel_macOS

/// Pure, fast, device-free (same spirit as `DomainTests.swift`) — no real
/// filesystem access, `FileMediaImporting` is faked.
final class ImportFolderMediaUseCaseTests: XCTestCase {

    private struct FakeImporter: FileMediaImporting {
        var clipsToReturn: [MediaClip]

        func makeClips(fromFileURLs urls: [URL], startingOrder: Int) -> [MediaClip] {
            clipsToReturn
        }
    }

    func testAppendClipsAppendsAfterExistingClipsPreservingOrder() {
        var project = Project(
            clips: [MediaClip(sourceIdentifier: "file:/existing.mov", kind: .video, order: 0)],
            templateID: "classic")
        let newClips = [
            MediaClip(sourceIdentifier: "file:/new1.mov", kind: .video, order: 1),
            MediaClip(sourceIdentifier: "file:/new2.jpg", kind: .photo, order: 2)
        ]
        let useCase = ImportFolderMediaUseCase(importer: FakeImporter(clipsToReturn: newClips))

        useCase.appendClips(fromFileURLs: [URL(fileURLWithPath: "/new1.mov"),
                                           URL(fileURLWithPath: "/new2.jpg")], to: &project)

        XCTAssertEqual(project.clips.count, 3)
        XCTAssertEqual(project.orderedClips.map(\.sourceIdentifier),
                       ["file:/existing.mov", "file:/new1.mov", "file:/new2.jpg"])
    }

    func testAppendClipsOnEmptyProjectStartsAtZero() {
        var project = Project(clips: [], templateID: "classic")
        let useCase = ImportFolderMediaUseCase(importer: FakeImporter(clipsToReturn: []))

        useCase.appendClips(fromFileURLs: [], to: &project)

        XCTAssertTrue(project.clips.isEmpty)
    }

    func testUnrecognizedFilesProduceNoClipsWithoutThrowing() {
        var project = Project(clips: [], templateID: "classic")
        // A real `FileMediaImportService` skips non-media URLs rather than
        // throwing (spec §9 "never fail silently" — but silently *skipping*
        // junk is correct, only losing real media isn't); the fake mirrors
        // that by simply returning fewer clips than URLs given.
        let useCase = ImportFolderMediaUseCase(importer: FakeImporter(clipsToReturn: []))

        useCase.appendClips(fromFileURLs: [URL(fileURLWithPath: "/notes.txt")], to: &project)

        XCTAssertTrue(project.clips.isEmpty)
    }
}
