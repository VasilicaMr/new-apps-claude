import Foundation
import RelayKit

/// Pure state machine that folds `ClaudeEvent`s into transcript rows.
/// Used both for live events and for replaying history after a reconnect.
struct TranscriptReducer: Equatable {
    private(set) var items: [TranscriptItem] = []
    private(set) var isWorking = false
    private(set) var model: String?
    private(set) var totalCostUSD: Double = 0
    /// Increments on every change, including in-place streaming updates (drives auto-scroll).
    private(set) var revision = 0

    private var nextID = 0

    var pendingPermissions: [PermissionPrompt] {
        items.compactMap {
            if case .permission(let prompt, .pending) = $0.kind { return prompt }
            return nil
        }
    }

    mutating func reset() {
        self = TranscriptReducer()
    }

    mutating func apply(_ event: ClaudeEvent) {
        defer { revision += 1 }
        switch event {
        case .started(let model, let cwd, _):
            self.model = model
            let folder = cwd.map { ($0 as NSString).lastPathComponent } ?? ""
            append(.system([model, folder].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")))
        case .userPrompt(let text):
            append(.user(text))
            isWorking = true
        case .textDelta(let delta):
            isWorking = true
            if let last = items.indices.last, case .assistant(let text, true) = items[last].kind {
                items[last].kind = .assistant(text + delta, isStreaming: true)
            } else {
                append(.assistant(delta, isStreaming: true))
            }
        case .text(let text):
            if let last = items.indices.last, case .assistant(_, true) = items[last].kind {
                items[last].kind = .assistant(text, isStreaming: false)
            } else {
                append(.assistant(text, isStreaming: false))
            }
        case .thinking:
            isWorking = true
        case .toolUse(let id, let name, let summary):
            finishStreaming()
            items.append(TranscriptItem(id: "tool-\(id)", kind: .tool(name: name, summary: summary, output: nil, isError: false)))
        case .toolResult(let toolUseID, let output, let isError):
            if let index = items.lastIndex(where: { $0.id == "tool-\(toolUseID)" }),
               case .tool(let name, let summary, _, _) = items[index].kind {
                items[index].kind = .tool(name: name, summary: summary, output: output, isError: isError)
            }
        case .permissionRequested(let prompt):
            finishStreaming()
            items.append(TranscriptItem(id: "perm-\(prompt.id)", kind: .permission(prompt, state: .pending)))
        case .permissionResolved(let requestID, let allowed):
            setPermission(id: requestID, state: allowed ? .allowed : .denied)
        case .turnCompleted(let isError, let cost, let duration):
            finishStreaming()
            isWorking = false
            totalCostUSD += cost ?? 0
            append(.turnSummary(isError: isError, costUSD: cost, durationMS: duration))
        case .notice(let message):
            append(.notice(message))
        case .processExited(let code):
            finishStreaming()
            isWorking = false
            expirePendingPermissions()
            if code != 0 { append(.notice("Claude exited with code \(code). Send a message to resume.")) }
        }
    }

    /// Optimistic local update so the card reacts instantly; the host confirms with `permissionResolved`.
    mutating func markPermission(id: String, allowed: Bool) {
        setPermission(id: id, state: allowed ? .allowed : .denied)
        revision += 1
    }

    /// Plain-text rendering used as Apple Intelligence input.
    func plainText(limit: Int) -> String {
        let lines: [String] = items.compactMap {
            switch $0.kind {
            case .user(let text): return "USER: \(text)"
            case .assistant(let text, _): return "CLAUDE: \(text)"
            case .tool(let name, let summary, _, let isError): return "TOOL \(name)(\(summary))\(isError ? " failed" : "")"
            case .notice(let text): return "NOTE: \(text)"
            default: return nil
            }
        }
        return String(lines.joined(separator: "\n").suffix(limit))
    }

    private mutating func append(_ kind: TranscriptItem.Kind) {
        nextID += 1
        items.append(TranscriptItem(id: "item-\(nextID)", kind: kind))
    }

    private mutating func finishStreaming() {
        if let last = items.indices.last, case .assistant(let text, true) = items[last].kind {
            items[last].kind = .assistant(text, isStreaming: false)
        }
    }

    private mutating func setPermission(id: String, state: TranscriptItem.PermissionState) {
        guard let index = items.lastIndex(where: { $0.id == "perm-\(id)" }),
              case .permission(let prompt, _) = items[index].kind else { return }
        items[index].kind = .permission(prompt, state: state)
    }

    private mutating func expirePendingPermissions() {
        for prompt in pendingPermissions { setPermission(id: prompt.id, state: .expired) }
    }
}
