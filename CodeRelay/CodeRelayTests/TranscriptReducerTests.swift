import XCTest
import RelayKit
@testable import CodeRelay

final class TranscriptReducerTests: XCTestCase {
    func testStreamingDeltasAreReplacedByFinalText() {
        var reducer = TranscriptReducer()
        reducer.apply(.userPrompt("hi"))
        reducer.apply(.textDelta("Hel"))
        reducer.apply(.textDelta("lo"))
        XCTAssertEqual(reducer.items.last?.kind, .assistant("Hello", isStreaming: true))
        reducer.apply(.text("Hello!"))
        XCTAssertEqual(reducer.items.count, 2)
        XCTAssertEqual(reducer.items.last?.kind, .assistant("Hello!", isStreaming: false))
        XCTAssertTrue(reducer.isWorking)
    }

    func testToolResultAttachesToToolUse() {
        var reducer = TranscriptReducer()
        reducer.apply(.toolUse(id: "t1", name: "Bash", summary: "ls"))
        reducer.apply(.toolResult(toolUseID: "t1", output: "a.txt", isError: false))
        XCTAssertEqual(reducer.items.count, 1)
        XCTAssertEqual(reducer.items[0].kind, .tool(name: "Bash", summary: "ls", output: "a.txt", isError: false))
    }

    func testPermissionLifecycle() {
        var reducer = TranscriptReducer()
        let prompt = PermissionPrompt(id: "p1", toolName: "Edit", summary: "main.swift", detail: "{}")
        reducer.apply(.permissionRequested(prompt))
        XCTAssertEqual(reducer.pendingPermissions, [prompt])
        reducer.apply(.permissionResolved(requestID: "p1", allowed: true))
        XCTAssertTrue(reducer.pendingPermissions.isEmpty)
        XCTAssertEqual(reducer.items[0].kind, .permission(prompt, state: .allowed))
    }

    func testProcessExitExpiresPendingPermissions() {
        var reducer = TranscriptReducer()
        let prompt = PermissionPrompt(id: "p1", toolName: "Bash", summary: "rm -rf build", detail: "{}")
        reducer.apply(.permissionRequested(prompt))
        reducer.apply(.processExited(code: 1))
        XCTAssertEqual(reducer.items[0].kind, .permission(prompt, state: .expired))
        XCTAssertFalse(reducer.isWorking)
    }

    func testTurnCompletedAccumulatesCost() {
        var reducer = TranscriptReducer()
        reducer.apply(.userPrompt("a"))
        reducer.apply(.turnCompleted(isError: false, costUSD: 0.5, durationMS: 10))
        reducer.apply(.userPrompt("b"))
        reducer.apply(.turnCompleted(isError: false, costUSD: 0.25, durationMS: 10))
        XCTAssertEqual(reducer.totalCostUSD, 0.75, accuracy: 0.0001)
        XCTAssertFalse(reducer.isWorking)
    }

    func testPlainTextIsClipped() {
        var reducer = TranscriptReducer()
        reducer.apply(.userPrompt(String(repeating: "x", count: 100)))
        XCTAssertEqual(reducer.plainText(limit: 20).count, 20)
    }
}

@MainActor
final class DemoHostTests: XCTestCase {
    func testDemoSessionRunsAFullTurn() async throws {
        let connection = try await DemoHostConnector().open(.demo, credential: HostCredential(identity: "d", key: Data()))
        connection.send(.hello(deviceID: "d", deviceName: "test", protocolVersion: relayProtocolVersion))
        let paired: Bool = try await connection.awaitMessage { if case .welcome(_, let paired) = $0 { return paired }; return nil }
        XCTAssertTrue(paired)

        connection.send(.startSession(projectPath: "/demo", permissionMode: .ask, resumeClaudeSessionID: nil))
        let session: SessionSummary = try await connection.awaitMessage { if case .sessionStarted(let s) = $0 { return s }; return nil }

        connection.send(.prompt(sessionID: session.id, text: "Update the greeting"))
        let prompt: PermissionPrompt = try await connection.awaitMessage { message in
            if case .event(_, .permissionRequested(let prompt)) = message { return prompt }
            return nil
        }
        connection.send(.permissionDecision(sessionID: session.id, requestID: prompt.id, allow: true))
        let completed: Bool = try await connection.awaitMessage { message in
            if case .event(_, .turnCompleted(let isError, _, _)) = message { return !isError }
            return nil
        }
        XCTAssertTrue(completed)
    }
}
