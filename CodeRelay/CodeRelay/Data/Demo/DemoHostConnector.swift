import Foundation
import RelayKit

/// A fully simulated Mac host. Lets App Review, screenshots and curious users
/// experience the app without installing anything on a Mac.
@MainActor
struct DemoHostConnector: HostConnecting {
    func open(_ endpoint: HostEndpoint, credential: HostCredential) async throws -> HostConnection {
        try await Task.sleep(for: .milliseconds(400))
        return DemoHostConnection()
    }
}

@MainActor
final class DemoHostConnection: HostConnection {
    let messages: AsyncStream<HostMessage>
    private let continuation: AsyncStream<HostMessage>.Continuation
    private var sessions: [SessionSummary] = []
    private var histories: [String: [ClaudeEvent]] = [:]
    private var turns: [String: Task<Void, Never>] = [:]
    private var decisions: [String: CheckedContinuation<Bool, Never>] = [:]

    private let host = HostInfo(hostID: SavedHost.demo.id, name: "Demo Mac", claudeVersion: "demo", claudeAvailable: true)
    private let projects = [
        ProjectInfo(path: "/Users/demo/Developer/weather-app", name: "weather-app", isGitRepository: true),
        ProjectInfo(path: "/Users/demo/Developer/api-server", name: "api-server", isGitRepository: true),
        ProjectInfo(path: "/Users/demo/Developer/dotfiles", name: "dotfiles", isGitRepository: false)
    ]

    init() {
        (messages, continuation) = AsyncStream.makeStream(of: HostMessage.self)
    }

    func send(_ message: ClientMessage) {
        switch message {
        case .hello:
            reply(.welcome(host: host, paired: true))
        case .pair:
            reply(.error("The demo host is already paired."))
        case .listProjects:
            reply(.projects(projects))
        case .listSessions:
            reply(.sessions(sessions))
        case .startSession(let path, let mode, _):
            let summary = SessionSummary(id: UUID().uuidString, claudeSessionID: UUID().uuidString, projectPath: path,
                                         title: "New session", permissionMode: mode, createdAt: Date(), isRunning: false)
            sessions.insert(summary, at: 0)
            reply(.sessionStarted(summary))
            reply(.sessions(sessions))
        case .attach(let id):
            reply(.history(sessionID: id, events: histories[id] ?? []))
        case .prompt(let id, let text):
            runTurn(sessionID: id, prompt: text)
        case .permissionDecision(_, let requestID, let allow):
            decisions.removeValue(forKey: requestID)?.resume(returning: allow)
        case .interrupt(let id):
            turns[id]?.cancel()
        case .renameSession(let id, let title):
            updateSession(id) { $0.title = title }
        case .closeSession(let id):
            sessions.removeAll { $0.id == id }
            reply(.sessionClosed(sessionID: id))
        case .ping:
            reply(.pong)
        }
    }

    func close() {
        turns.values.forEach { $0.cancel() }
        continuation.finish()
    }

    private func reply(_ message: HostMessage) {
        continuation.yield(message)
    }

    private func emit(_ sessionID: String, _ event: ClaudeEvent) {
        if case .text = event {
            while case .textDelta = histories[sessionID]?.last { histories[sessionID]?.removeLast() }
        }
        histories[sessionID, default: []].append(event)
        reply(.event(sessionID: sessionID, event: event))
    }

    private func updateSession(_ id: String, _ change: (inout SessionSummary) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        change(&sessions[index])
        reply(.sessions(sessions))
    }

    private func runTurn(sessionID: String, prompt: String) {
        updateSession(sessionID) {
            if $0.title == "New session" { $0.title = String(prompt.prefix(60)) }
            $0.isRunning = true
        }
        emit(sessionID, .userPrompt(prompt))
        let project = sessions.first { $0.id == sessionID }?.projectName ?? "project"
        let firstTurn = !(histories[sessionID] ?? []).contains { if case .turnCompleted = $0 { return true }; return false }

        turns[sessionID] = Task { [weak self] in
            guard let self else { return }
            do {
                if firstTurn {
                    self.emit(sessionID, .started(model: "claude-demo", cwd: "/Users/demo/Developer/\(project)",
                                                  claudeSessionID: UUID().uuidString))
                }
                self.emit(sessionID, .thinking)
                try await Task.sleep(for: .milliseconds(700))
                try await self.stream(sessionID, "I'll look at the project structure first.")
                self.emit(sessionID, .toolUse(id: "ls", name: "Bash", summary: "ls -la"))
                try await Task.sleep(for: .milliseconds(600))
                self.emit(sessionID, .toolResult(toolUseID: "ls",
                                                 output: "README.md\nPackage.swift\nSources/\nTests/",
                                                 isError: false))
                try await self.stream(sessionID, "The entry point is in `Sources/App/main.swift`. I'd like to update it.")

                let request = PermissionPrompt(id: UUID().uuidString, toolName: "Edit",
                                               summary: "Sources/App/main.swift",
                                               detail: "{\n  \"file_path\" : \"Sources/App/main.swift\",\n  \"old_string\" : \"print(\\\"Hello\\\")\",\n  \"new_string\" : \"print(\\\"Hello from CodeRelay\\\")\"\n}")
                self.emit(sessionID, .permissionRequested(request))
                let allowed = await withCheckedContinuation { self.decisions[request.id] = $0 }
                self.emit(sessionID, .permissionResolved(requestID: request.id, allowed: allowed))
                try Task.checkCancellation()

                if allowed {
                    self.emit(sessionID, .toolUse(id: "edit", name: "Edit", summary: "Sources/App/main.swift"))
                    try await Task.sleep(for: .milliseconds(400))
                    self.emit(sessionID, .toolResult(toolUseID: "edit", output: "Updated 1 line.", isError: false))
                    try await self.stream(sessionID, "Done! **main.swift** now prints a friendlier greeting. Want me to run the tests next?")
                } else {
                    try await self.stream(sessionID, "No problem — I left the file unchanged. Tell me how you'd like to proceed.")
                }
                self.emit(sessionID, .turnCompleted(isError: false, costUSD: 0.0123, durationMS: 4_200))
            } catch {
                self.emit(sessionID, .notice("Interrupted."))
                self.emit(sessionID, .turnCompleted(isError: true, costUSD: nil, durationMS: nil))
            }
            self.updateSession(sessionID) { $0.isRunning = false }
        }
    }

    private func stream(_ sessionID: String, _ text: String) async throws {
        var sent = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: false) {
            try await Task.sleep(for: .milliseconds(45))
            let chunk = (sent.isEmpty ? "" : " ") + word
            sent += chunk
            emit(sessionID, .textDelta(chunk))
        }
        emit(sessionID, .text(text))
    }
}
