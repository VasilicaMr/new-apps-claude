import Foundation
import RelayKit

/// Business rules for which folders a remote device may see and open.
/// Kept free of UI/network code so it is trivially testable.
struct ProjectAccessPolicy {
    let roots: [String]
    private let fileManager = FileManager.default

    /// The roots themselves plus their direct, non-hidden sub-folders.
    func listProjects() -> [ProjectInfo] {
        var seen = Set<String>()
        var projects: [ProjectInfo] = []
        for root in roots.map(Self.canonical) {
            let candidates = [root] + subdirectories(of: root)
            for path in candidates where seen.insert(path).inserted {
                projects.append(ProjectInfo(path: path,
                                            name: (path as NSString).lastPathComponent,
                                            isGitRepository: fileManager.fileExists(atPath: path + "/.git")))
            }
        }
        return projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// True only if `path` is (inside) one of the configured roots, after resolving symlinks.
    func isAllowed(_ path: String) -> Bool {
        let target = Self.canonical(path)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: target, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }
        return roots.map(Self.canonical).contains { root in
            target == root || target.hasPrefix(root.hasSuffix("/") ? root : root + "/")
        }
    }

    static func canonical(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func subdirectories(of root: String) -> [String] {
        let url = URL(fileURLWithPath: root)
        let contents = (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey],
                                                             options: [.skipsHiddenFiles])) ?? []
        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { Self.canonical($0.path) }
    }
}
