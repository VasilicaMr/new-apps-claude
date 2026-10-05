import SwiftUI

struct TVPlansView: View {
    let coordinator: TVAppCoordinator

    @State private var sessions: [GameSession] = []
    @State private var editingPlan: GamePlan?

    private var store: GamePlansStore { coordinator.plans }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plans")
                        .font(.system(size: 76, weight: .heavy, design: .rounded))
                    Text("Build a game-night habit. Days fill in automatically when you finish a matching game.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    editingPlan = GamePlan()
                } label: {
                    Label("New Plan", systemImage: "plus.circle.fill")
                }

                if store.plans.isEmpty {
                    ContentUnavailableView(
                        "No plans yet",
                        systemImage: "calendar.badge.plus",
                        description: Text("Try “Family Game Night — once a week”.")
                    )
                } else {
                    ForEach(store.plans) { plan in
                        Button {
                            store.toggleToday(plan)
                        } label: {
                            TVPlanCard(plan: plan, progress: plan.progress(sessions: sessions))
                        }
                        .buttonStyle(.card)
                        .contextMenu {
                            Button {
                                editingPlan = plan
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                store.delete(plan)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    Text("Click a plan to tick today · Hold to edit or delete")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 30)
        }
        // Reload when a game finishes, so new games fill in their squares.
        .task(id: coordinator.liveSessionID) {
            sessions = (try? await coordinator.container.fetchSessionsUseCase.execute()) ?? []
        }
        .sheet(item: $editingPlan) { plan in
            TVPlanEditorView(plan: plan, store: store, gameTitles: gameTitles)
                .tvThemed()
        }
    }

    /// "Any game" options: the family's own games, then home games, then sports.
    private var gameTitles: [String] {
        var seen = Set<String>()
        let all = coordinator.customGames.games.map(\.name)
            + HouseGameCatalog.all.map(\.name)
            + SportCategory.allCases.flatMap(\.sports).map(\.displayName)
        return all.filter { seen.insert($0).inserted }
    }
}

private struct TVPlanCard: View {
    let plan: GamePlan
    let progress: PlanProgress

    var body: some View {
        HStack(alignment: .top, spacing: 50) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: plan.symbol)
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(.green)
                Text(plan.name)
                    .font(.title3.bold())
                    .lineLimit(2)
                Text("\(plan.gameTitle ?? "Any game") · \(plan.timesPerWeek)× a week")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(min(progress.thisWeek, plan.timesPerWeek)) of \(plan.timesPerWeek) this week")
                    .font(.headline)
                Label("\(progress.streak)-week streak", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(progress.streak > 0 ? .orange : .secondary)
                if progress.isDoneToday {
                    Label("Played today", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                }
            }
            .frame(width: 440, alignment: .leading)

            TVPlanGrid(doneDays: progress.doneDays)
        }
        .padding(36)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// HabitKit-style grid: one column per week, one square per day, oldest on the left.
struct TVPlanGrid: View {
    let doneDays: Set<Date>
    var weeks = 26

    private let calendar = Calendar.current

    var body: some View {
        let today = calendar.startOfDay(for: .now)
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let firstWeek = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeek) ?? thisWeek

        HStack(spacing: 6) {
            ForEach(0..<weeks, id: \.self) { week in
                VStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { weekday in
                        let day = calendar.date(byAdding: .day, value: week * 7 + weekday, to: firstWeek) ?? today
                        RoundedRectangle(cornerRadius: 5)
                            .fill(color(for: day, today: today))
                            .frame(width: 26, height: 26)
                    }
                }
            }
        }
    }

    private func color(for day: Date, today: Date) -> Color {
        if day > today { return .clear }
        return doneDays.contains(day) ? .green : TVTheme.Colors.surface
    }
}
