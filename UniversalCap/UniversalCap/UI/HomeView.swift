import SwiftUI
import SwiftData
import AppIntents
import StoreKit

// MARK: - Filter

enum CaptureFilter: String, CaseIterable {
    case all = "All"
    case thoughts = "Thoughts"
    case expenses = "Expenses"
    case tasks = "Tasks"

    var icon: String {
        switch self {
        case .all:      return "square.stack.fill"
        case .thoughts: return "lightbulb.fill"
        case .expenses: return "dollarsign.circle.fill"
        case .tasks:    return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .all:      return .primary
        case .thoughts: return .purple
        case .expenses: return .green
        case .tasks:    return .blue
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @Query(sort: \Thought.createdAt, order: .reverse)  private var thoughts: [Thought]
    @Query(sort: \Expense.createdAt, order: .reverse)  private var expenses: [Expense]
    @Query(sort: \UCTask.createdAt, order: .reverse)   private var tasks: [UCTask]
    @Environment(\.modelContext) private var context

    @State private var filter: CaptureFilter = .all
    @State private var showPaywall = false
    @State private var store = StoreKitManager.shared
    @State private var searchText = ""
    @State private var editingThought: Thought? = nil
    @State private var editingExpense: Expense? = nil
    @State private var editingTask: UCTask? = nil
    @State private var showManageCategories = false

    private var showProBanner: Bool { !store.isPro }

    private var freeHistoryCutoff: Date {
        Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    }

    // MARK: Greeting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    statsRow
                    if showProBanner { proBanner }
                    filterBar
                    captureList
                }
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        if store.isPro {
                            ShareLink(
                                item: ExportManager.generateCSV(
                                    thoughts: thoughts, expenses: expenses, tasks: tasks),
                                subject: Text("UniversalCap Export"),
                                message: Text("Exported \(thoughts.count + expenses.count + tasks.count) captures")
                            ) {
                                Label("Export CSV", systemImage: "square.and.arrow.up")
                            }
                            Button { showManageCategories = true } label: {
                                Label("Manage Categories", systemImage: "tag")
                            }
                        } else {
                            Button { showPaywall = true } label: {
                                Label("Export CSV  —  Pro", systemImage: "square.and.arrow.up")
                            }
                            Button { showPaywall = true } label: {
                                Label("Custom Categories  —  Pro", systemImage: "tag")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if !store.isPro {
                            Button {
                                showPaywall = true
                            } label: {
                                Text("Pro")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        LinearGradient(colors: [.purple, .blue],
                                                       startPoint: .leading,
                                                       endPoint: .trailing)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                        SiriTipView(intent: UniversalCaptureIntent(), isVisible: .constant(true))
                            .scaleEffect(0.85)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .interactiveDismissDisabled(false)
            }
            .sheet(item: $editingThought) { EditThoughtSheet(thought: $0) }
            .sheet(item: $editingExpense) { EditExpenseSheet(expense: $0) }
            .sheet(item: $editingTask)    { EditTaskSheet(task: $0) }
            .sheet(isPresented: $showManageCategories) { ManageCategoriesView() }
            .searchable(text: $searchText, prompt: "Search captures")
            .task { writeWidgetData() }
            .onChange(of: thoughts.count) { writeWidgetData() }
            .onChange(of: expenses.count) { writeWidgetData() }
            .onChange(of: tasks.count)    { writeWidgetData() }
        }
    }

    // MARK: Pro Banner

    private var proBanner: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    LinearGradient(colors: [.purple, .blue],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Unlock Pro")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("ONE-TIME")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .clipShape(Capsule())
                    }
                    Text("Unlimited history · CSV export · custom categories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                                       startPoint: .leading, endPoint: .trailing),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: Stats Row

    private var statsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatCard(
                    value: "\(thoughts.count)",
                    label: "Thoughts",
                    icon: "lightbulb.fill",
                    color: .purple
                )
                StatCard(
                    value: totalExpenses,
                    label: "Spent",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                StatCard(
                    value: "\(tasks.filter { !$0.isCompleted }.count)",
                    label: "Open tasks",
                    icon: "checkmark.circle.fill",
                    color: .blue
                )
            }
            .padding(.horizontal, 16)
        }
    }

    private var totalExpenses: String {
        let total = expenses.reduce(0.0) { $0 + $1.amount }
        return String(format: "%.0f", total)
    }

    private var filteredThoughts: [Thought] {
        searchText.isEmpty ? thoughts :
            thoughts.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredExpenses: [Expense] {
        searchText.isEmpty ? expenses :
            expenses.filter {
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                $0.note.localizedCaseInsensitiveContains(searchText)
            }
    }

    private var filteredTasks: [UCTask] {
        searchText.isEmpty ? tasks :
            tasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    // Free tier: only last 30 days
    private var displayThoughts: [Thought] {
        store.isPro ? filteredThoughts : filteredThoughts.filter { $0.createdAt >= freeHistoryCutoff }
    }
    private var displayExpenses: [Expense] {
        store.isPro ? filteredExpenses : filteredExpenses.filter { $0.createdAt >= freeHistoryCutoff }
    }
    private var displayTasks: [UCTask] {
        store.isPro ? filteredTasks : filteredTasks.filter { $0.createdAt >= freeHistoryCutoff }
    }
    private var hiddenCount: Int {
        guard !store.isPro else { return 0 }
        return filteredThoughts.filter { $0.createdAt < freeHistoryCutoff }.count
             + filteredExpenses.filter { $0.createdAt < freeHistoryCutoff }.count
             + filteredTasks.filter    { $0.createdAt < freeHistoryCutoff }.count
    }

    // MARK: Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CaptureFilter.allCases, id: \.self) { f in
                    FilterPill(filter: f, isSelected: filter == f) {
                        withAnimation(.spring(response: 0.3)) { filter = f }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Capture List

    @ViewBuilder
    private var captureList: some View {
        let isEmpty = filteredEmpty
        if isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 12) {
                if filter == .all || filter == .tasks {
                    ForEach(displayTasks) { task in
                        TaskCard(task: task,
                                 onToggle: { toggleTask(task) },
                                 onDelete: { delete(task) },
                                 onEdit:   { editingTask = task })
                            .padding(.horizontal, 16)
                    }
                }
                if filter == .all || filter == .expenses {
                    ForEach(displayExpenses) { expense in
                        ExpenseCard(expense: expense,
                                    onDelete: { delete(expense) },
                                    onEdit:   { editingExpense = expense })
                            .padding(.horizontal, 16)
                    }
                }
                if filter == .all || filter == .thoughts {
                    ForEach(displayThoughts) { thought in
                        ThoughtCard(thought: thought,
                                    onDelete: { delete(thought) },
                                    onEdit:   { editingThought = thought })
                            .padding(.horizontal, 16)
                    }
                }
                if hiddenCount > 0 {
                    historyLimitBanner
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private var filteredEmpty: Bool {
        switch filter {
        case .all:      return displayThoughts.isEmpty && displayExpenses.isEmpty && displayTasks.isEmpty
        case .thoughts: return displayThoughts.isEmpty
        case .expenses: return displayExpenses.isEmpty
        case .tasks:    return displayTasks.isEmpty
        }
    }

    // MARK: History Limit Banner

    private var historyLimitBanner: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
                Text("\(hiddenCount) older \(hiddenCount == 1 ? "capture" : "captures") hidden")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text("Unlock History")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple)
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.purple.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 48)
            ZStack {
                Circle()
                    .fill(filter.color.opacity(0.1))
                    .frame(width: 96, height: 96)
                Image(systemName: filter.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(filter.color)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(spacing: 8) {
                Text(emptyTitle)
                    .font(.title3.bold())
                Text(emptySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            if !store.isPro {
                Button { showPaywall = true } label: {
                    Label("Unlock Pro — one-time purchase", systemImage: "star.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(colors: [.purple, .blue],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyTitle: String {
        switch filter {
        case .all:      return "Nothing captured yet"
        case .thoughts: return "No thoughts yet"
        case .expenses: return "No expenses yet"
        case .tasks:    return "No tasks yet"
        }
    }

    private var emptySubtitle: String {
        switch filter {
        case .all:      return "Open Shortcuts and say\n\"Capture with UniversalCap\""
        case .thoughts: return "Say \"Note an idea with UniversalCap\""
        case .expenses: return "Say \"Track spending with UniversalCap\""
        case .tasks:    return "Say \"Remind me with UniversalCap\""
        }
    }

    // MARK: Actions

    private func writeWidgetData() {
        WidgetDataWriter.write(thoughts: thoughts, expenses: expenses, tasks: tasks)
    }

    private func toggleTask(_ task: UCTask) {
        withAnimation(.spring(response: 0.3)) {
            task.isCompleted.toggle()
            try? context.save()
            if task.isCompleted {
                NotificationScheduler.cancel(for: task)
            } else {
                NotificationScheduler.schedule(for: task)
            }
        }
    }

    private func delete<T: PersistentModel>(_ item: T) {
        withAnimation {
            if let task = item as? UCTask { NotificationScheduler.cancel(for: task) }
            context.delete(item)
            try? context.save()
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 120)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Filter Pill

private struct FilterPill: View {
    let filter: CaptureFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption.bold())
                Text(filter.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : filter.color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? filter.color : filter.color.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Thought Card

private struct ThoughtCard: View {
    let thought: Thought
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.purple)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(thought.content)
                    .font(.body)
                    .lineLimit(4)
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text(thought.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Expense Card

private struct ExpenseCard: View {
    let expense: Expense
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.green)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(expense.category)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text("\(expense.currency) \(expense.amount, format: .number.precision(.fractionLength(2)))")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.green)
                }
                if !expense.note.isEmpty {
                    Text(expense.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text(expense.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Task Card

private struct TaskCard: View {
    let task: UCTask
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.blue)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .lineLimit(3)
                    Spacer()
                    Button(action: onToggle) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(task.isCompleted ? Color.blue : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
                if let due = task.dueDate {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Text(due.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(due < Date() && !task.isCompleted ? .red : .secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(task.isCompleted ? 0.6 : 1)
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(action: onToggle) {
                Label(task.isCompleted ? "Mark Incomplete" : "Mark Complete",
                      systemImage: task.isCompleted ? "circle" : "checkmark.circle.fill")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
