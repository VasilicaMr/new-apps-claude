import Foundation

/// Locates the `claude` binary and captures the user's login-shell PATH.
/// GUI apps launched from Finder get a minimal PATH, so without this the CLI
/// (and the tools it runs: git, node, swift…) would not be found.
struct ClaudeLocator: ClaudeLocating {
    func locate(override: String?) async -> ClaudeInstallation? {
        await Task.detached(priority: .userInitiated) {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let shellPath = Self.run("/bin/zsh", ["-lc", "printf %s \"$PATH\""]) ?? ""
            let extraDirs = ["\(home)/.local/bin", "\(home)/.claude/local", "/opt/homebrew/bin",
                             "/usr/local/bin", "\(home)/.npm-global/bin", "/usr/bin", "/bin"]
            let pathDirs = (shellPath.split(separator: ":").map(String.init) + extraDirs)
                .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }

            var candidates: [String] = []
            if let override, !override.isEmpty { candidates.append((override as NSString).expandingTildeInPath) }
            candidates += pathDirs.map { "\($0)/claude" }

            guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                return nil
            }

            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = pathDirs.joined(separator: ":")
            environment["TERM"] = "dumb"
            environment["NO_COLOR"] = "1"

            let version = Self.run(path, ["--version"], environment: environment)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return ClaudeInstallation(executable: URL(fileURLWithPath: path), version: version,
                                      environment: environment)
        }.value
    }

    private static func run(_ launchPath: String, _ arguments: [String],
                            environment: [String: String]? = nil) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        if let environment { process.environment = environment }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
