import XCTest
@testable import CodeRelay_Host

final class ProjectAccessPolicyTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("app/.git"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("lib"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".hidden"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testListsRootAndVisibleChildren() {
        let projects = ProjectAccessPolicy(roots: [root.path]).listProjects()
        XCTAssertEqual(Set(projects.map(\.name)), [root.lastPathComponent, "app", "lib"])
        XCTAssertEqual(projects.first { $0.name == "app" }?.isGitRepository, true)
    }

    func testAllowsOnlyPathsInsideRoots() {
        let policy = ProjectAccessPolicy(roots: [root.path])
        XCTAssertTrue(policy.isAllowed(root.appendingPathComponent("app").path))
        XCTAssertFalse(policy.isAllowed(root.appendingPathComponent("app/../..").path))
        XCTAssertFalse(policy.isAllowed("/etc"))
        XCTAssertFalse(policy.isAllowed(root.path + "-sibling"))
    }

    func testSymlinkEscapeIsRejected() throws {
        let link = root.appendingPathComponent("escape")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "/usr")
        XCTAssertFalse(ProjectAccessPolicy(roots: [root.path]).isAllowed(link.path))
    }
}
