import Foundation

@Observable
@MainActor
final class SportListViewModel {
    var searchText: String = ""

    var filteredCategories: [SportCategory] {
        if searchText.isEmpty {
            return SportCategory.allCases
        }
        return SportCategory.allCases.filter { category in
            category.sports.contains { $0.displayName.localizedCaseInsensitiveContains(searchText) }
        }
    }

    func sports(in category: SportCategory) -> [SportType] {
        if searchText.isEmpty { return category.sports }
        return category.sports.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }
}
