import Foundation

/// One parsed line of `claude -p --output-format stream-json` output.
public enum ClaudeOutput: Equatable {
    case event(ClaudeEvent)
    /// The CLI asks the host (us) whether a tool may run.
    /// `input` is the raw JSON tool input, echoed back as `updatedInput` on allow.
    case permissionRequest(requestID: String, toolName: String, input: Data)
    case controlResponse(requestID: String)
}

/// Translates raw CLI stream-json lines into `ClaudeOutput` values.
/// Unknown line types are ignored so newer CLI versions don't break the app.
public enum ClaudeStreamParser {
    public static func parse(line: Data) -> [ClaudeOutput] {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let type = object["type"] as? String else { return [] }

        switch type {
        case "system":
            return parseSystem(object)
        case "assistant":
            return parseAssistant(object)
        case "user":
            return parseToolResults(object)
        case "stream_event":
            return parseStreamEvent(object)
        case "result":
            let isError = (object["is_error"] as? Bool) ?? false
            var outputs: [ClaudeOutput] = []
            if isError, let message = object["result"] as? String, !message.isEmpty {
                outputs.append(.event(.notice(message)))
            }
            outputs.append(.event(.turnCompleted(isError: isError,
                                                 costUSD: object["total_cost_usd"] as? Double,
                                                 durationMS: object["duration_ms"] as? Int)))
            return outputs
        case "control_request":
            guard let requestID = object["request_id"] as? String,
                  let request = object["request"] as? [String: Any],
                  request["subtype"] as? String == "can_use_tool" else { return [] }
            let toolName = (request["tool_name"] as? String) ?? "Tool"
            let inputObject = (request["input"] as? [String: Any]) ?? [:]
            let input = (try? JSONSerialization.data(withJSONObject: inputObject)) ?? Data("{}".utf8)
            return [.permissionRequest(requestID: requestID, toolName: toolName, input: input)]
        case "control_response":
            let response = object["response"] as? [String: Any]
            guard let requestID = response?["request_id"] as? String else { return [] }
            return [.controlResponse(requestID: requestID)]
        default:
            return []
        }
    }

    private static func parseSystem(_ object: [String: Any]) -> [ClaudeOutput] {
        switch object["subtype"] as? String {
        case "init":
            return [.event(.started(model: object["model"] as? String,
                                    cwd: object["cwd"] as? String,
                                    claudeSessionID: object["session_id"] as? String))]
        case "permission_denied":
            let message = (object["message"] as? String) ?? "Permission denied."
            return [.event(.notice(message))]
        default:
            return []
        }
    }

    private static func parseAssistant(_ object: [String: Any]) -> [ClaudeOutput] {
        guard let message = object["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return [] }
        return content.compactMap { block in
            switch block["type"] as? String {
            case "text":
                guard let text = block["text"] as? String, !text.isEmpty else { return nil }
                return .event(.text(text))
            case "tool_use":
                let name = (block["name"] as? String) ?? "Tool"
                let input = (block["input"] as? [String: Any]) ?? [:]
                return .event(.toolUse(id: (block["id"] as? String) ?? UUID().uuidString,
                                       name: name,
                                       summary: ToolSummarizer.summary(toolName: name, input: input)))
            default:
                return nil
            }
        }
    }

    private static func parseToolResults(_ object: [String: Any]) -> [ClaudeOutput] {
        guard let message = object["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else { return [] }
        return content.compactMap { block in
            guard block["type"] as? String == "tool_result" else { return nil }
            return .event(.toolResult(toolUseID: (block["tool_use_id"] as? String) ?? "",
                                      output: ToolSummarizer.truncate(flattenText(block["content"])),
                                      isError: (block["is_error"] as? Bool) ?? false))
        }
    }

    private static func parseStreamEvent(_ object: [String: Any]) -> [ClaudeOutput] {
        guard let event = object["event"] as? [String: Any] else { return [] }
        switch event["type"] as? String {
        case "content_block_delta":
            let delta = event["delta"] as? [String: Any]
            guard delta?["type"] as? String == "text_delta",
                  let text = delta?["text"] as? String else { return [] }
            return [.event(.textDelta(text))]
        case "content_block_start":
            let block = event["content_block"] as? [String: Any]
            return block?["type"] as? String == "thinking" ? [.event(.thinking)] : []
        default:
            return []
        }
    }

    private static func flattenText(_ value: Any?) -> String {
        if let string = value as? String { return string }
        if let blocks = value as? [[String: Any]] {
            return blocks.compactMap { $0["text"] as? String }.joined(separator: "\n")
        }
        return ""
    }
}

/// Builds the JSON lines the host writes to the CLI's stdin.
public enum ClaudeInput {
    public static func userMessage(_ text: String) -> Data {
        line(["type": "user", "message": ["role": "user", "content": text]])
    }

    public static func initialize(requestID: String) -> Data {
        line(["type": "control_request", "request_id": requestID,
              "request": ["subtype": "initialize"]])
    }

    public static func interrupt(requestID: String) -> Data {
        line(["type": "control_request", "request_id": requestID,
              "request": ["subtype": "interrupt"]])
    }

    public static func allow(requestID: String, input: Data) -> Data {
        let inputObject = (try? JSONSerialization.jsonObject(with: input)) ?? [String: Any]()
        return controlResponse(requestID: requestID,
                               response: ["behavior": "allow", "updatedInput": inputObject])
    }

    public static func deny(requestID: String, message: String) -> Data {
        controlResponse(requestID: requestID, response: ["behavior": "deny", "message": message])
    }

    private static func controlResponse(requestID: String, response: [String: Any]) -> Data {
        line(["type": "control_response",
              "response": ["subtype": "success", "request_id": requestID, "response": response]])
    }

    private static func line(_ object: [String: Any]) -> Data {
        var data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
        data.append(0x0A)
        return data
    }
}
