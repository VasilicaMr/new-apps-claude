import SwiftData
import SwiftUI

/// The main flow: shift, ask anything, what needs you, the AI brief, quick actions and today.
struct HomeView: View {
    @Environment(ShiftStore.self) private var shiftStore
    @Environment(AppNavigation.self) private var navigation
    @Environment(BriefStore.self) private var brief
    @Environment(ScreenshotInbox.self) private var inbox
    @Environment(\.money) private var money
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Shift.start, order: .reverse) private var shifts: [Shift]
    @Query private var earnings: [Earning]
    @Query private var expenses: [Expense]
    @Query private var reminders: [Reminder]
    @Query private var cars: [Car]
    @AppStorage(SettingsKeys.useAppleIntelligence) private var useAppleIntelligence = true

    let data: DriverData

    @State private var addingExpense = false
    @State private var scanningReceipt = false
    @State private var addingManualShift = false
    @State private var showingSettings = false
    @State private var earningsSheet: EarningsSheet?
    @State private var reviewing: ScreenshotInbox.Item?

    private struct EarningsSheet: Identifiable {
        let id = UUID()
        let shift: Shift?
        let scan: Bool
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    askBar
                    ShiftCard(addingExpense: $addingExpense)
                    needsYouSection
                    briefCard
                    quickActions
                    todaySection
                    recentShiftsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(greeting)
            .navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Add", systemImage: "plus") {
                        Button("Earnings from screenshot", systemImage: "text.viewfinder") { earningsSheet = EarningsSheet(shift: nil, scan: true) }
                        Button("Receipt", systemImage: "doc.text.viewfinder") { scanningReceipt = true }
                        Button("Expense", systemImage: "fuelpump") { addingExpense = true }
                        Button("Past shift", systemImage: "clock.arrow.circlepath") { addingManualShift = true }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
            }
            .sheet(isPresented: $addingExpense) { ExpenseForm() }
            .sheet(isPresented: $scanningReceipt) { ExpenseForm(scanReceipt: true) }
            .sheet(isPresented: $addingManualShift) { ManualShiftForm() }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $earningsSheet) { EarningForm(shift: $0.shift, scanScreenshot: $0.scan) }
            .sheet(item: $reviewing) { item in
                EarningForm(shift: item.shift, prefilled: item.result) { inbox.dismiss(item) }
            }
            .navigationDestination(for: Shift.self) { ShiftDetailView(shift: $0) }
            .task(id: dataVersion) { await refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await inbox.scanRecent(data: data, useAppleIntelligence: useAppleIntelligence) } }
            }
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    /// Changes whenever something is logged, so the brief and inbox refresh.
    private var dataVersion: String {
        "\(shifts.count)-\(earnings.count)-\(expenses.count)-\(reminders.count)-\(shiftStore.isOnShift)-\(useAppleIntelligence)"
    }

    private func refresh() async {
        await brief.refresh(using: data, useAppleIntelligence: useAppleIntelligence)
        await inbox.scanRecent(data: data, useAppleIntelligence: useAppleIntelligence)
    }

    // MARK: - Ask

    private var askBar: some View {
        Button { navigation.ask() } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .symbolEffect(.pulse, options: .repeat(2))
                Text("Ask or add anything…")
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "mic.fill").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.cardBackground, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask FleetCheck")
        .accessibilityIdentifier("home.ask")
    }

    // MARK: - Needs you

    @ViewBuilder
    private var needsYouSection: some View {
        let missing = shiftsMissingEarnings
        let due = dueReminders
        let offerPhotoAccess = inbox.isEnabled && inbox.authorization == .notDetermined
        if !inbox.items.isEmpty || !missing.isEmpty || !due.isEmpty || offerPhotoAccess {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Needs you")
                    if inbox.isScanning { ProgressView().controlSize(.small) }
                }
                ForEach(inbox.items) { item in
                    ScreenshotInboxRow(item: item,
                                       add: { inbox.accept(item, data: data) },
                                       review: { reviewing = item },
                                       dismiss: { inbox.dismiss(item) })
                }
                ForEach(missing.prefix(3)) { shift in
                    TaskRow(symbol: "banknote", tint: .orange,
                            title: "Add earnings for \(shift.start.formatted(.dateTime.weekday(.wide)))",
                            detail: "\(Formatters.duration(shift.duration)) · \(shift.distanceKm.kilometers)",
                            action: "Scan") { earningsSheet = EarningsSheet(shift: shift, scan: true) }
                }
                ForEach(due.prefix(2), id: \.0.id) { reminder, status in
                    TaskRow(symbol: reminder.kind.symbol, tint: Theme.color(for: status.urgency),
                            title: reminder.title, detail: data.dueText(reminder, status),
                            action: "Open") { navigation.selectedTab = .car }
                }
                if offerPhotoAccess {
                    TaskRow(symbol: "photo.on.rectangle.angled", tint: Theme.accent,
                            title: "Find earnings screenshots automatically",
                            detail: "Take a screenshot in Uber or Bolt; FleetCheck reads it for you.",
                            action: "Allow") { Task { await inbox.requestAccess(); await refresh() } }
                }
            }
            .card()
        }
    }

    private var shiftsMissingEarnings: [Shift] {
        let since = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        let pendingShiftIDs = Set(inbox.items.compactMap { $0.shift?.persistentModelID })
        return shifts.filter {
            !$0.isActive && $0.start >= since && $0.earnings.isEmpty && $0.duration > 15 * 60 && !pendingShiftIDs.contains($0.persistentModelID)
        }
    }

    private var dueReminders: [(Reminder, ReminderStatus)] {
        let planner = ReminderPlanner()
        let odometer = cars.first?.odometerKm ?? 0
        return reminders.map { ($0, planner.status(of: $0.rule, today: .now, odometerKm: odometer)) }
            .filter { $0.1.urgency > .ok }
            .sorted { $0.1.urgency > $1.1.urgency }
    }

    // MARK: - Brief

    private var briefCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Your brief", systemImage: brief.isWritten ? "apple.intelligence" : "text.alignleft")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                Spacer()
                if brief.isLoading { ProgressView().controlSize(.small) }
            }
            if let text = brief.text {
                Text(text).font(.subheadline)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(brief.insights.prefix(3)) { insight in
                        Label(insight.text, systemImage: symbol(for: insight.kind))
                            .font(.subheadline)
                    }
                }
            }
            Button("Ask more", systemImage: "arrow.right.circle") { navigation.ask("How is my week going and what should I do better?") }
                .font(.subheadline.weight(.medium))
        }
        .card()
    }

    private func symbol(for kind: Insight.Kind) -> String {
        switch kind {
        case .summary: "chart.bar"
        case .trend: "arrow.up.right"
        case .bestDay: "star"
        case .cost: "cart"
        case .missingEarnings: "banknote"
        case .reminder: "bell"
        case .start: "play.circle"
        }
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            QuickActionButton(title: "Scan earnings", subtitle: "Screenshot from Uber/Bolt", symbol: "text.viewfinder") {
                earningsSheet = EarningsSheet(shift: shiftsMissingEarnings.first, scan: true)
            }
            QuickActionButton(title: "Scan receipt", subtitle: "Fuel, wash, service", symbol: "doc.text.viewfinder") {
                scanningReceipt = true
            }
            QuickActionButton(title: "Say it", subtitle: "\"fuel 250 lei 34 L\"", symbol: "waveform") {
                navigation.ask()
            }
            QuickActionButton(title: "My week", subtitle: "vs last week", symbol: "chart.line.uptrend.xyaxis") {
                if let compare = SuggestedQuestion.all.first(where: { $0.command == .compare(.week) }) { navigation.ask(compare) }
            }
        }
    }

    // MARK: - Today

    private var todaySection: some View {
        let stats = StatsCalculator().stats(
            in: StatsPeriod.day.interval(containing: .now),
            shifts: shifts.filter { !$0.isActive }.map(\.figures),
            earnings: earnings.map(\.figures), expenses: expenses.map(\.figures))
        return VStack(spacing: 12) {
            SectionHeader(title: "Today", subtitle: shiftStore.isOnShift ? "Finished shifts only" : nil)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                KPITile(title: "Earned", value: money.string(stats.earnings), symbol: "banknote")
                KPITile(title: "Net after costs", value: money.string(stats.net), symbol: "equal.circle",
                        tint: Theme.color(forNet: stats.net))
                KPITile(title: "Kilometers", value: stats.km.kilometers, symbol: "road.lanes")
                KPITile(title: "Per hour", value: stats.earningsPerHour.map { money.string($0) } ?? "—", symbol: "clock",
                        footnote: stats.hours > 0 ? "over \(Formatters.hours(stats.hours))" : nil)
            }
        }
    }

    @ViewBuilder
    private var recentShiftsSection: some View {
        let finished = shifts.filter { !$0.isActive }.prefix(5)
        if !finished.isEmpty {
            VStack(spacing: 0) {
                SectionHeader(title: "Recent shifts").padding(.bottom, 8)
                ForEach(Array(finished)) { shift in
                    NavigationLink(value: shift) { ShiftRow(shift: shift) }
                        .buttonStyle(.plain)
                    if shift.id != finished.last?.id { Divider() }
                }
            }
            .card()
        }
    }
}

// MARK: - Rows

private struct TaskRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let action: String
    let perform: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            Button(action, action: perform)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}

private struct ScreenshotInboxRow: View {
    let item: ScreenshotInbox.Item
    let add: () -> Void
    let review: () -> Void
    let dismiss: () -> Void
    @Environment(\.money) private var money

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.result.source == .appleIntelligence ? "apple.intelligence" : "text.viewfinder")
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.result.platform?.title ?? "Earnings") · \(money.string(item.result.total ?? 0, decimals: true))")
                        .font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Dismiss", systemImage: "xmark", action: dismiss)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.borderless)
            }
            HStack {
                Button("Add", systemImage: "checkmark", action: add)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("inbox.add")
                Button("Review", action: review)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.leading, 40)
        }
    }

    private var detail: String {
        var parts = ["Screenshot from \(item.takenAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))"]
        if let trips = item.result.trips { parts.append("\(trips) trips") }
        if item.result.scope == .week { parts.append("weekly summary") }
        if let shift = item.shift { parts.append("for \(shift.start.formatted(.dateTime.weekday(.wide))) shift") }
        return parts.joined(separator: " · ")
    }
}

private struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}
