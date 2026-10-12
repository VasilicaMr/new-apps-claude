import XCTest
@testable import RelayKit

final class FrameCodecTests: XCTestCase {
    func testRoundTripAcrossChunkBoundaries() throws {
        let messages: [ClientMessage] = [
            .hello(deviceID: "d1", deviceName: "iPhone", protocolVersion: relayProtocolVersion),
            .prompt(sessionID: "s1", text: String(repeating: "x", count: 10_000)),
            .ping
        ]
        var stream = Data()
        for message in messages { stream.append(try FrameCodec.encode(message)) }

        var decoder = FrameDecoder()
        var payloads: [Data] = []
        var index = stream.startIndex
        while index < stream.endIndex {
            let end = min(index + 777, stream.endIndex)
            payloads += try decoder.append(Data(stream[index..<end]))
            index = end
        }

        XCTAssertEqual(payloads.count, 3)
        let decoded = try payloads.map { try FrameCodec.makeDecoder().decode(ClientMessage.self, from: $0) }
        guard case .prompt(_, let text) = decoded[1] else { return XCTFail("expected prompt") }
        XCTAssertEqual(text.count, 10_000)
    }

    func testRejectsOversizedFrame() {
        var decoder = FrameDecoder()
        let header = Data([0x7F, 0xFF, 0xFF, 0xFF])
        XCTAssertThrowsError(try decoder.append(header))
    }

    func testHostMessageRoundTrip() throws {
        let summary = SessionSummary(id: "s", claudeSessionID: "c", projectPath: "/tmp/app", title: "Fix bug",
                                     permissionMode: .ask, createdAt: Date(timeIntervalSince1970: 0), isRunning: true)
        let frame = try FrameCodec.encode(HostMessage.sessionStarted(summary))
        var decoder = FrameDecoder()
        let payload = try XCTUnwrap(try decoder.append(frame).first)
        guard case .sessionStarted(let decoded) = try FrameCodec.makeDecoder().decode(HostMessage.self, from: payload)
        else { return XCTFail("wrong case") }
        XCTAssertEqual(decoded, summary)
        XCTAssertEqual(decoded.projectName, "app")
    }
}

final class PairingCryptoTests: XCTestCase {
    func testCodeIsSixDigits() {
        let code = PairingCrypto.generatePairingCode()
        XCTAssertEqual(code.count, 6)
        XCTAssertTrue(code.allSatisfy(\.isNumber))
    }

    func testKeyDerivationIgnoresFormatting() {
        XCTAssertEqual(PairingCrypto.pairingKey(for: "123 456"), PairingCrypto.pairingKey(for: "123456"))
        XCTAssertNotEqual(PairingCrypto.pairingKey(for: "123456"), PairingCrypto.pairingKey(for: "123457"))
        XCTAssertEqual(PairingCrypto.pairingKey(for: "000000").count, 32)
    }

    func testDeviceKeysAreRandom() {
        XCTAssertNotEqual(PairingCrypto.generateDeviceKey(), PairingCrypto.generateDeviceKey())
    }
}

final class ClaudeStreamParserTests: XCTestCase {
    private func parse(_ json: String) -> [ClaudeOutput] {
        ClaudeStreamParser.parse(line: Data(json.utf8))
    }

    func testInit() {
        let outputs = parse(#"{"type":"system","subtype":"init","cwd":"/p","session_id":"abc","model":"claude-x"}"#)
        XCTAssertEqual(outputs, [.event(.started(model: "claude-x", cwd: "/p", claudeSessionID: "abc"))])
    }

    func testAssistantTextAndToolUse() {
        let outputs = parse(#"""
        {"type":"assistant","message":{"content":[
          {"type":"text","text":"Running tests"},
          {"type":"tool_use","id":"t1","name":"Bash","input":{"command":"swift test"}}]}}
        """#.replacingOccurrences(of: "\n", with: ""))
        XCTAssertEqual(outputs, [
            .event(.text("Running tests")),
            .event(.toolUse(id: "t1", name: "Bash", summary: "swift test"))
        ])
    }

    func testToolResultWithBlockContent() {
        let outputs = parse(#"{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":[{"type":"text","text":"ok"}],"is_error":true}]}}"#)
        XCTAssertEqual(outputs, [.event(.toolResult(toolUseID: "t1", output: "ok", isError: true))])
    }

    func testTextDelta() {
        let outputs = parse(#"{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"Hel"}}}"#)
        XCTAssertEqual(outputs, [.event(.textDelta("Hel"))])
    }

    func testResult() {
        let outputs = parse(#"{"type":"result","subtype":"success","is_error":false,"total_cost_usd":0.25,"duration_ms":1200}"#)
        XCTAssertEqual(outputs, [.event(.turnCompleted(isError: false, costUSD: 0.25, durationMS: 1200))])
    }

    func testPermissionRequest() throws {
        let outputs = parse(#"{"type":"control_request","request_id":"r9","request":{"subtype":"can_use_tool","tool_name":"Write","input":{"file_path":"/a.txt"}}}"#)
        guard case .permissionRequest(let id, let tool, let input) = try XCTUnwrap(outputs.first) else {
            return XCTFail("expected permission request")
        }
        XCTAssertEqual(id, "r9")
        XCTAssertEqual(tool, "Write")
        XCTAssertTrue(ToolSummarizer.detail(input: input).contains("/a.txt"))
    }

    func testUnknownLinesAreIgnored() {
        XCTAssertEqual(parse(#"{"type":"rate_limit_event"}"#), [])
        XCTAssertEqual(parse("not json"), [])
    }

    func testAllowEchoesInput() throws {
        let line = ClaudeInput.allow(requestID: "r1", input: Data(#"{"command":"ls"}"#.utf8))
        XCTAssertEqual(line.last, 0x0A)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: line) as? [String: Any])
        let response = try XCTUnwrap(object["response"] as? [String: Any])
        let inner = try XCTUnwrap(response["response"] as? [String: Any])
        XCTAssertEqual(inner["behavior"] as? String, "allow")
        XCTAssertEqual((inner["updatedInput"] as? [String: Any])?["command"] as? String, "ls")
    }
}
