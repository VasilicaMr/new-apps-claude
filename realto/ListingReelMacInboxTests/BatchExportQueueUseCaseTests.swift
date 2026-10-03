import XCTest
@testable import ListingReel_macOS

/// Pure, fast, device-free — the `VideoRenderer`/persistence/archiving seams
/// are faked, same "testable core" spirit as `DomainTests.swift`. Uses the
/// real `DefaultTemplateRepository`/`DefaultMusicRepository` (bundled, no
/// I/O beyond reading catalog JSON already shipped in the app) rather than
/// hand-building a `Template` fixture.
final class BatchExportQueueUseCaseTests: XCTestCase {

    private final class FakeProjectRepository: ProjectRepository {
        var saved: [Project.ID: Project] = [:]
        func save(_ project: Project) async throws { saved[project.id] = project }
        func fetchAll() async throws -> [Project] { Array(saved.values) }
        func fetch(id: Project.ID) async throws -> Project? { saved[id] }
        func delete(_ id: Project.ID) async throws { saved[id] = nil }
    }

    private final class FakeBrandProfileRepository: BrandProfileRepository {
        func load() async throws -> BrandProfile? { nil }
        func save(_ profile: BrandProfile) async throws {}
        func storeLogo(_ data: Data) async throws -> String { "" }
        func loadLogo(id: String) async throws -> Data? { nil }
    }

    private struct FakeMediaRepository: MediaRepository {
        func requestAuthorization() async -> Bool { true }
        func makeClips(fromLocalIdentifiers ids: [String], startingOrder: Int) -> [MediaClip] { [] }
        func saveToPhotoLibrary(fileURL: URL) async throws {}
    }

    /// Always succeeds — the "one project fails" case in the test below is
    /// produced by giving that project zero clips, which `ExportVideoUseCase`
    /// itself rejects with `.noClips` before ever reaching the renderer.
    private struct FakeVideoRenderer: VideoRenderer {
        func export(project: Project, template: Template, brand: BrandProfile?, music: MusicTrack?,
                   narration: URL?, settings: ExportSettings, progress: @escaping @Sendable (RenderProgress) -> Void) async throws -> [ExportedFile] {
            [ExportedFile(aspectRatio: .vertical9x16, url: URL(fileURLWithPath: "/tmp/fake.mp4"), fileSizeBytes: 1)]
        }
    }

    private final class FakeArchiver: ExportedFileArchiving {
        private(set) var archivedProjectIDs: [Project.ID] = []
        func archive(_ files: [ExportedFile], for project: Project) async throws {
            archivedProjectIDs.append(project.id)
        }
    }

    private final class FakeNotifier: ExportNotifying {
        private(set) var lastSucceeded: Int?
        private(set) var lastFailed: Int?
        func notifyBatchFinished(succeeded: Int, failed: Int) async {
            lastSucceeded = succeeded
            lastFailed = failed
        }
    }

    private func makeQueue(archiver: FakeArchiver, notifier: FakeNotifier) -> BatchExportQueueUseCase {
        let templates = DefaultTemplateRepository()
        let exportUseCase = ExportVideoUseCase(
            renderer: FakeVideoRenderer(),
            templates: templates,
            music: DefaultMusicRepository(),
            brandProfiles: FakeBrandProfileRepository(),
            media: FakeMediaRepository())
        return BatchExportQueueUseCase(
            exportUseCase: exportUseCase,
            manageProjects: ManageProjectsUseCase(repository: FakeProjectRepository(), templates: templates),
            archiver: archiver,
            notifier: notifier)
    }

    func testOneFailingProjectDoesNotAbortTheRestOfTheBatch() async {
        let goodProject = Project(
            clips: [MediaClip(sourceIdentifier: "file:/good.mov", kind: .video, order: 0)],
            templateID: "classic")
        let emptyProject = Project(clips: [], templateID: "classic")   // rejected: RenderError.noClips

        let archiver = FakeArchiver()
        let notifier = FakeNotifier()
        let queue = makeQueue(archiver: archiver, notifier: notifier)

        let outcomes = await queue.run(projects: [emptyProject, goodProject])

        XCTAssertEqual(outcomes.count, 2)
        guard case .failure(.noClips) = outcomes[0].result else {
            return XCTFail("expected the empty project to fail with .noClips")
        }
        guard case .success(let files) = outcomes[1].result else {
            return XCTFail("expected the second, valid project to still render")
        }
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(archiver.archivedProjectIDs, [goodProject.id])
        XCTAssertEqual(notifier.lastSucceeded, 1)
        XCTAssertEqual(notifier.lastFailed, 1)
    }

    func testEmptyBatchStillNotifiesWithZeroCounts() async {
        let archiver = FakeArchiver()
        let notifier = FakeNotifier()
        let queue = makeQueue(archiver: archiver, notifier: notifier)

        let outcomes = await queue.run(projects: [])

        XCTAssertTrue(outcomes.isEmpty)
        XCTAssertEqual(notifier.lastSucceeded, 0)
        XCTAssertEqual(notifier.lastFailed, 0)
    }
}
