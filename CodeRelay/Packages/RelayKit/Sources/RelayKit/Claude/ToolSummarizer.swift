import Foundation

/// Produces a one-line, human-readable description of a tool call,
/// e.g. `Bash(git status)` → "git status".
public enum ToolSummarizer {
    public static let maxOutputLength = 4_000

    private static let preferredKeys = [
        "command", "file_path", "path", "pattern", "url", "query", "description", "prompt", "notebook_path"
    ]

    public static func summary(toolName: String, input: [String: Any]) -> String {
        for key in preferredKeys {
            if let value = input[key] as? String, !value.isEmpty {
                return singleLine(value)
            }
        }
        if let firstString = input.values.compactMap({ $0 as? String }).first {
            return singleLine(firstString)
        }
        return toolName
    }

    public static func detail(input: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: input),
              let pretty = try? JSONSerialization.data(withJSONObject: object,
                                                       options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: pretty, encoding: .utf8) else { return "" }
        return truncate(string)
    }

    public static func truncate(_ text: String) -> String {
        guard text.count > maxOutputLength else { return text }
        return String(text.prefix(maxOutputLength)) + "\n… (\(text.count - maxOutputLength) more characters)"
    }

    private static func singleLine(_ text: String) -> String {
        let line = text.replacingOccurrences(of: "\n", with: " ⏎ ")
        return line.count > 160 ? String(line.prefix(160)) + "…" : line
    }
}
