import SwiftUI

struct SportListView: View {
    @State var viewModel: SportListViewModel
    var coordinator: HomeCoordinator

    var body: some View {
        List {
            ForEach(SportCategory.allCases) { category in
                Section {
                    ForEach(category.sports) { sport in
                        Button {
                            coordinator.push(.sessionSetup(sport))
                        } label: {
                            Label(sport.displayName, systemImage: sport.systemImageName)
                                .foregroundStyle(.primary)
                        }
                    }
                } header: {
                    Label(category.rawValue, systemImage: category.systemImageName)
                        .foregroundStyle(Color.forSportCategory(category))
                }
            }
        }
        .navigationTitle("All Sports")
    }
}
