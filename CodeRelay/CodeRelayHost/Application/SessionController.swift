import Foundation
import RelayKit

/// Owns one Claude conversation: its CLI process, event history (for phones
/// that reconnect) and pending permission prompts.
@MainActor
final class SessionController {
    private(set) var summary: SessionSummary
    private(set) var history: [ClaudeEvent] = []
    private var pending: [String: (prompt: PermissionPrompt, input: Data)] = [:]
    private var process: ClaudeProcess?
    private let installation: () -> ClaudeInstallation?

    var onEvent: ((ClaudeEvent) -> Void)?
    var onSummaryChange: ((SessionSummary) -> Void)?

    private static let historyLimit = 1_500

    init(summary: SessionSummary, installation: @escaping () -> ClaudeInstallation?) {
        self.summary = summary
        self.installation = installation
    }

    func send(prompt text: String) {
        if summary.title == "New session" {
            summary.title = String(text.prefix(60))
            onSummaryChange?(summary)
        }
        record(.userPrompt(text))
        guard ensureProcess() else { return }
        process?.write(ClaudeInput.userMessage(text))
    }

    func decide(requestID: String, allow: Bool) {
        guard let entry = pending.removeValue(forKey: requestID) else { return }
        process?.write(allow
                       ? ClaudeInput.allow(requestID: requestID, input: entry.input)
                       : ClaudeInput.deny(requestID: requestID, message: "The user denied this action from their phone."))
        record(.permissionResolved(requestID: requestID, allowed: allow))
    }

    func interrupt() {
        process?.write(ClaudeInput.interrupt(requestID: UUID().uuidString))
        record(.notice("Interrupted."))
    }

    func rename(_ title: String) {
        summary.title = title
        onSummaryChange?(summary)
    }

    func close() {
        process?.terminate()
        process = nil
        setRunning(false)
    }

    // MARK: - Process

    private func ensureProcess() -> Bool {
        if let process, process.isRunning { return true }
        guard let installation = installation() else {
            record(.notice("Claude Code CLI was not found on this Mac. Install it and open CodeRelay Host settings."))
            return false
        }
        let process = ClaudeProcess(installation: installation,
                                    workingDirectory: summary.projectPath,
                                    permissionMode: summary.permissionMode,
                                    resumeSessionID: summary.claudeSessionID)
        process.onOutput = { [weak self] output in self?.handle(output) }
        process.onExit = { [weak self] code, stderr in self?.processExited(code: code, stderr: stderr) }
        do {
            try process.start()
            self.process = process
            setRunning(true)
            return true
        } catch {
            record(.notice("Could not start Claude: \(error.localizedDescription)"))
            return false
        }
    }

    private func handle(_ output: ClaudeOutput) {
        switch output {
        case .event(let event):
            if case .started(_, _, let claudeSessionID?) = event, claudeSessionID != summary.claudeSessionID {
                summary.claudeSessionID = claudeSessionID
                onSummaryChange?(summary)
            }
            record(event)
        case .permissionRequest(let requestID, let toolName, let input):
            let toolInput = (try? JSONSerialization.jsonObject(with: input) as? [String: Any]) ?? [:]
            let prompt = PermissionPrompt(id: requestID, toolName: toolName,
                                          summary: ToolSummarizer.summary(toolName: toolName, input: toolInput),
                                          detail: ToolSummarizer.detail(input: input))
            pending[requestID] = (prompt, input)
            record(.permissionRequested(prompt))
        case .controlResponse:
            break
        }
    }

    private func processExited(code: Int32, stderr: String) {
        process = nil
        // Prompts can never be answered once the process is gone.
        pending.removeAll()
        if code != 0, !stderr.isEmpty {
            record(.notice(stderr.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        record(.processExited(code: code))
        setRunning(false)
    }

    private func setRunning(_ running: Bool) {
        guard summary.isRunning != running else { return }
        summary.isRunning = running
        onSummaryChange?(summary)
    }

    private func record(_ event: ClaudeEvent) {
        // Streaming deltas are only useful live; once the full text arrives, drop them.
        if case .text = event {
            while case .textDelta = history.last { history.removeLast() }
        }
        history.append(event)
        if history.count > Self.historyLimit {
            history.removeFirst(history.count - Self.historyLimit)
        }
        onEvent?(event)
    }
}
