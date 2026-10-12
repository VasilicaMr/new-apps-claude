import SwiftData
import SwiftUI

/// Everything logged: shifts, earnings and expenses, grouped by month.
struct DiaryView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case shifts = "Shifts", earnings = "Earnings", expenses = "Expenses"
        var id: String { rawValue }
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
                    ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
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
            ContentUnavailableView("No \(kind.rawValue.lowercased()) yet", systemImage: "tray",
                                   description: Text(kind == .shifts ? "Start a shift from the Shift tab." : "Tap + to add one."))
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
                .onDelete { offsets in offsets.map { group.items[$0] }.forEach(context.delete) }
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
            Image(systemName: expense.category.symbol)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.category.title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if expense.receipt != nil {
                Image(systemName: "paperclip").font(.caption).foregroundStyle(.secondary)
            }
            Text(money.string(expense.amount)).font(.subheadline.weight(.semibold))
        }
        .contentShape(.rect)
    }

    private var detail: String {
        var parts = [expense.date.formatted(date: .abbreviated, time: .omitted)]
        if let liters = expense.liters { parts.append("\(liters.formatted()) \(expense.category == .charging ? "kWh" : "L")") }
        if expense.coverageMonths > 0 { parts.append("covers \(expense.coverageMonths) mo") }
        if !expense.note.isEmpty { parts.append(expense.note) }
        return parts.joined(separator: " · ")
    }
}
