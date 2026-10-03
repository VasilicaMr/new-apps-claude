import Foundation

enum ExportManager {

    static func generateCSV(thoughts: [Thought], expenses: [Expense], tasks: [UCTask]) -> String {
        var rows: [String] = [
            "Type,Date,Content,Amount,Currency,Category,Note,DueDate,Completed"
        ]

        for t in thoughts {
            rows.append("Thought,\(iso(t.createdAt)),\"\(esc(t.content))\",,,,,, ")
        }
        for e in expenses {
            rows.append("Expense,\(iso(e.createdAt)),,\(e.amount),\(e.currency),\(e.category),\"\(esc(e.note))\",, ")
        }
        for t in tasks {
            let due = t.dueDate.map { iso($0) } ?? ""
            rows.append("Task,\(iso(t.createdAt)),\"\(esc(t.title))\",,,,, \(due),\(t.isCompleted)")
        }

        return rows.joined(separator: "\n")
    }

    private static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    // Escape double-quotes per RFC 4180
    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\"", with: "\"\"")
    }
}
