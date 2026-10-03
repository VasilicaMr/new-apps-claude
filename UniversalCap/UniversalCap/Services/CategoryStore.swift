import Foundation
import Observation

@Observable
final class CategoryStore {
    static let shared = CategoryStore()

    let defaults: [String] = ["Food", "Transport", "Shopping", "Health", "Entertainment", "Other"]
    private(set) var custom: [String] = []

    var all: [String] { defaults + custom.filter { !defaults.contains($0) } }

    private init() {
        custom = UserDefaults.standard.stringArray(forKey: "customCategories") ?? []
    }

    func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !all.contains(trimmed) else { return }
        custom.append(trimmed)
        persist()
    }

    func remove(at offsets: IndexSet) {
        custom.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(custom, forKey: "customCategories")
    }
}
