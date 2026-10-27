import SwiftData
import SwiftUI

/// Everything logged: shifts, earnings and expenses, grouped by month.
struct DiaryView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case shifts, earnings, expenses
        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .shifts: "Shifts"
            case .earnings: "Earnings"
            case .expenses: "Expenses"
            }
        }

        var emptyTitle: LocalizedStringKey {
            switch self {
            case .shifts: "No shifts yet"
            case .earnings: "No earnings yet"
            case .expenses: "No expenses yet"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.money) private var money
    @Query(sort: \Shift.start, order: .reverse) private var shifts: [Shift]
    @Query(sort: \Earning.date, order: .reverse) private var earnings: [Earning]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var kind = Kind.expenses
    @State private var addingExpense = false
    @State private var addingEarning = false
    @State private var scanningEarning = false
    @State private var editingExpense: Expense?
    @State private var editingEarning: Earning?

    var body: some View {
        NavigationStack {
            List {
                Picker("Show", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                switch kind {
                case .shifts: shiftList
                case .earnings: earningList
                case .expenses: expenseList
                }
            }
            .fleetBackground()
            .navigationTitle("Diary")
            .navigationDestination(for: Shift.self) { ShiftDetailView(shift: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Add", systemImage: "plus") {
                        Button("Expense", systemImage: "fuelpump") { addingExpense = true }
                        Button("Earnings", systemImage: "banknote") { addingEarning = true }
                        Button("Earnings from screenshot", systemImage: "text.viewfinder") { scanningEarning = true }
                    }
                }
            }
            .sheet(isPresented: $addingExpense) { ExpenseForm() }
            .sheet(isPresented: $addingEarning) { EarningForm(shift: nil) }
            .sheet(isPresented: $scanningEarning) { EarningForm(shift: nil, scanScreenshot: true) }
            .sheet(item: $editingExpense) { ExpenseForm(editing: $0) }
            .sheet(item: $editingEarning) { EarningForm(shift: $0.shift, editing: $0) }
            .overlay { emptyState }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let isEmpty = switch kind {
        case .shifts: shifts.isEmpty
        case .earnings: earnings.isEmpty
        case .expenses: expenses.isEmpty
        }
        if isEmpty {
            ContentUnavailableView(kind.emptyTitle, systemImage: "tray",
                                   description: Text(kind == .shifts ? "Start a shift from Home." : "Tap + to add one."))
        }
    }

    private var shiftList: some View {
        ForEach(grouped(shifts.filter { !$0.isActive }, by: \.start), id: \.month) { group in
            Section(header: monthHeader(group.month, total: group.items.reduce(0) { $0 + $1.earningsTotal })) {
                ForEach(group.items) { shift in
                    NavigationLink(value: shift) { ShiftRow(shift: shift) }
                }
                .onDelete { offsets in
                    offsets.map { group.items[$0] }.forEach { shift in
                        shift.earnings.forEach(context.delete)
                        context.delete(shift)
                    }
                }
            }
        }
    }

    private var earningList: some View {
        ForEach(grouped(earnings, by: \.date), id: \.month) { group in
            Section(header: monthHeader(group.month, total: group.items.reduce(0) { $0 + $1.total })) {
                ForEach(group.items) { earning in
                    Button { editingEarning = earning } label: { EarningRow(earning: earning) }
                        .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for earning in offsets.map({ group.items[$0] }) {
                        context.addKilometers(-earning.distanceKm, to: earning.shift)
                        context.delete(earning)
                    }
                }
            }
        }
    }

    private var expenseList: some View {
        ForEach(grouped(expenses, by: \.date), id: \.month) { group in
            Section(header: monthHeader(group.month, total: group.items.reduce(0) { $0 + $1.amount })) {
                ForEach(group.items) { expense in
                    Button { editingExpense = expense } label: { ExpenseRow(expense: expense) }
                        .buttonStyle(.plain)
                }
                .onDelete { offsets in offsets.map { group.items[$0] }.forEach(context.delete) }
            }
        }
    }

    private func monthHeader(_ month: Date, total: Double) -> some View {
        HStack {
            Text(month.formatted(.dateTime.month(.wide).year()))
            Spacer()
            Text(money.string(total))
        }
        .font(.system(.subheadline, design: .rounded, weight: .heavy))
        .foregroundStyle(Theme.ink)
        .textCase(nil)
    }

    private func grouped<T>(_ items: [T], by date: KeyPath<T, Date>) -> [(month: Date, items: [T])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: items) { calendar.dateInterval(of: .month, for: $0[keyPath: date])?.start ?? $0[keyPath: date] }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }
}

struct ExpenseRow: View {
    let expense: Expense
    @Environment(\.money) private var money

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: expense.category.symbol, tint: Theme.positive)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.category.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(1)
            }
            Spacer()
            if expense.receipt != nil {
                Image(systemName: "paperclip").font(.caption.weight(.bold)).foregroundStyle(Theme.inkSecondary)
            }
            Text(money.string(expense.amount))
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
        }
        .contentShape(.rect)
    }

    private var detail: String {
        var parts = [expense.date.formatted(date: .abbreviated, time: .omitted)]
        if let liters = expense.liters { parts.append("\(liters.formatted()) \(expense.category == .charging ? "kWh" : "L")") }
        if expense.coverageMonths > 0 { parts.append(String(localized: "covers \(expense.coverageMonths) months")) }
        if !expense.note.isEmpty { parts.append(expense.note) }
        return parts.joined(separator: " · ")
    }
}
