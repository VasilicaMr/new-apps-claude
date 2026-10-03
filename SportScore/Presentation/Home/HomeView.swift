import SwiftUI

struct HomeView: View {
    var coordinator: HomeCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                headerSection
                categoriesSection
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("ScoreCap")
        .navigationBarTitleDisplayMode(.large)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Pick a sport")
                .font(.title2.bold())
            Text("Tap to start tracking")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var categoriesSection: some View {
        ForEach(SportCategory.allCases) { category in
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Label(category.rawValue, systemImage: category.systemImageName)
                    .font(.headline)
                    .foregroundStyle(Color.forSportCategory(category))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: AppTheme.Spacing.sm) {
                    ForEach(category.sports) { sport in
                        SportCardButton(sport: sport) {
                            coordinator.push(.sessionSetup(sport))
                        }
                    }
                }
            }
        }
    }
}

struct SportCardButton: View {
    let sport: SportType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: sport.systemImageName)
                    .font(.title3)
                    .foregroundStyle(Color.forSport(sport))
                Text(sport.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(AppTheme.Spacing.sm)
            .sportScoreCard()
        }
        .buttonStyle(.plain)
    }
}
