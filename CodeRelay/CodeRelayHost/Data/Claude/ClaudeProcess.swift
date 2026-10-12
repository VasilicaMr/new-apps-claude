import Foundation
import RelayKit

/// One long-lived `claude -p --input-format stream-json` child process.
/// All callbacks are delivered on the main queue.
final class ClaudeProcess {
    var onOutput: ((ClaudeOutput) -> Void)?
    var onExit: ((Int32, String) -> Void)?

    private let process = Process()
    private let stdin = Pipe()
    private let stdout = Pipe()
    private let stderr = Pipe()
    private var lineBuffer = Data()
    private var stderrTail = ""

    init(installation: ClaudeInstallation, workingDirectory: String,
         permissionMode: PermissionMode, resumeSessionID: String?) {
        var arguments = ["-p",
                         "--input-format", "stream-json",
                         "--output-format", "stream-json",
                         "--verbose",
                         "--include-partial-messages"]
        switch permissionMode {
        case .ask:
            arguments += ["--permission-prompt-tool", "stdio"]
        case .acceptEdits:
            arguments += ["--permission-prompt-tool", "stdio", "--permission-mode", "acceptEdits"]
        case .plan:
            arguments += ["--permission-prompt-tool", "stdio", "--permission-mode", "plan"]
        case .bypassPermissions:
            arguments += ["--dangerously-skip-permissions"]
        }
        if let resumeSessionID {
            arguments += ["--resume", resumeSessionID]
        }

        process.executableURL = installation.executable
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.environment = installation.environment
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
    }

    var isRunning: Bool { process.isRunning }

    func start() throws {
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            DispatchQueue.main.async { self?.consume(data) }
        }
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let text = String(data: handle.availableData, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                guard let self else { return }
                self.stderrTail = String((self.stderrTail + text).suffix(2_000))
            }
        }
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self else { return }
                self.stdout.fileHandleForReading.readabilityHandler = nil
                self.stderr.fileHandleForReading.readabilityHandler = nil
                self.onExit?(process.terminationStatus, self.stderrTail)
            }
        }
        try process.run()
        write(ClaudeInput.initialize(requestID: UUID().uuidString))
    }

    func write(_ line: Data) {
        guard process.isRunning else { return }
        try? stdin.fileHandleForWriting.write(contentsOf: line)
    }

    func terminate() {
        guard process.isRunning else { return }
        try? stdin.fileHandleForWriting.close()
        process.terminate()
    }

    private func consume(_ data: Data) {
        lineBuffer.append(data)
        while let newline = lineBuffer.firstIndex(of: 0x0A) {
            let line = lineBuffer[lineBuffer.startIndex..<newline]
            lineBuffer = Data(lineBuffer[(newline + 1)...])
            guard !line.isEmpty else { continue }
            for output in ClaudeStreamParser.parse(line: Data(line)) {
                onOutput?(output)
            }
        }
    }
}
