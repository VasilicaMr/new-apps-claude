import SwiftData
import SwiftUI

/// Built around uploading earnings: the upload card first, then what's ready to add, the week's money,
/// the Earn smarter tools, the shift, reminders, the brief and recent shifts. New drivers get a 3-step "Get started" list.
struct HomeView: View {
    @Environment(ShiftStore.self) private var shiftStore
    @Environment(AppNavigation.self) private var navigation
    @Environment(BriefStore.self) private var brief
    @Environment(ScreenshotInbox.self) private var inbox
    @Environment(ProStore.self) private var pro
    @Environment(\.money) private var money
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Shift.start, order: .reverse) private var shifts: [Shift]
    @Query private var earnings: [Earning]
    @Query private var expenses: [Expense]
    @Query private var reminders: [Reminder]
    @Query private var cars: [Car]
    @AppStorage(SettingsKeys.useAppleIntelligence) private var useAppleIntelligence = true
    @AppStorage(SettingsKeys.hasSeenUploadGuide) private var hasSeenUploadGuide = false
    @AppStorage(SettingsKeys.hideGettingStarted) private var hideGettingStarted = false

    let data: DriverData

    @State private var addingExpense = false
    @State private var scanningReceipt = false
    @State private var addingManualShift = false
    @State private var showingSettings = false
    @State private var earningsSheet: EarningsSheet?
    @State private var reviewing: ScreenshotInbox.Item?
    @State private var showingGuide = false
    @State private var showingPaywall = false
    #if DEBUG
    @State private var debugPlanTool: PlanTool?
    #endif

    private struct EarningsSheet: Identifiable {
        let id = UUID()
        let shift: Shift?
        let scan: Bool
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // A running shift stays on top so End is always one tap away.
                    if shiftStore.isOnShift { ShiftCard(addingExpense: $addingExpense) }
                    UploadHero(readyCount: inbox.items.count,
                               upload: startUpload,
                               showGuide: { showingGuide = true },
                               addReceipt: { scanningReceipt = true },
                               typeIt: { navigation.ask() })
                    gettingStarted
                    readyToAddSection
                    WeekMoneyCard(stats: weekStats) { navigation.selectedTab = .stats }
                    WithMoneyPlan { EarnSmarterSection(plan: $0, isLocked: !pro.isPro) { showingPaywall = true } }
                    if !shiftStore.isOnShift { ShiftCard(addingExpense: $addingExpense) }
                    remindersSection
                    askBar
                    briefCard
                    recentShiftsSection
                }
                .padding()
            }
            .fleetBackground()
            .navigationTitle(greeting)
            .navigationSubtitle(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Add", systemImage: "plus") {
                        Button("Upload earnings screenshot", systemImage: "text.viewfinder") { startUpload() }
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
            .sheet(isPresented: $showingPaywall) { PaywallSheet() }
            .sheet(item: $earningsSheet) { EarningForm(shift: $0.shift, scanScreenshot: $0.scan) }
            .sheet(isPresented: $showingGuide) {
                UploadGuideView { openPicker() }
            }
            .sheet(item: $reviewing) { item in
                EarningForm(shift: item.shift, prefilled: item.result) { inbox.dismiss(item) }
            }
            .navigationDestination(for: Shift.self) { ShiftDetailView(shift: $0) }
            .navigationDestination(for: PlanTool.self) { tool in
                WithMoneyPlan { plan in
                    switch tool {
                    case .carCost: CarCostView(plan: plan)
                    case .goal: GoalView(plan: plan)
                    case .bestTimes: BestTimesView(plan: plan)
                    }
                }
            }
            #if DEBUG
            .navigationDestination(item: $debugPlanTool) { tool in
                WithMoneyPlan { plan in
                    switch tool {
                    case .carCost: CarCostView(plan: plan)
                    case .goal: GoalView(plan: plan)
                    case .bestTimes: BestTimesView(plan: plan)
                    }
                }
            }
            // `-debugUploadGuide YES` opens the upload steps at launch, `-debugPlanTool goal` an Earn smarter screen,
            // `-debugSettings YES` Settings, for screenshots.
            .onAppear {
                if UserDefaults.standard.bool(forKey: "debugUploadGuide") { showingGuide = true }
                if UserDefaults.standard.bool(forKey: "debugSettings") { showingSettings = true }
                debugPlanTool = switch UserDefaults.standard.string(forKey: "debugPlanTool") {
                case "carCost": .carCost
                case "goal": .goal
                case "bestTimes": .bestTimes
                default: nil
                }
            }
            #endif
            .task(id: dataVersion) { await refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await scanInbox() } }
            }
        }
    }

    /// The first upload explains the steps; after that it goes straight to the photo picker.
    private func startUpload() {
        if hasSeenUploadGuide {
            openPicker()
        } else {
            hasSeenUploadGuide = true
            showingGuide = true
        }
    }

    private func openPicker() {
        // Opening a sheet while the guide is still closing is ignored, so wait for it.
        Task {
            try? await Task.sleep(for: .milliseconds(showingGuide ? 450 : 0))
            earningsSheet = EarningsSheet(shift: shiftStore.activeShift ?? shiftsMissingEarnings.first, scan: true)
        }
    }

    private var weekStats: PeriodStats {
        StatsCalculator().stats(
            in: StatsPeriod.week.interval(containing: .now),
            shifts: shifts.filter { !$0.isActive }.map(\.figures),
            earnings: earnings.map(\.figures), expenses: expenses.map(\.figures))
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: String(localized: "Good morning")
        case 12..<18: String(localized: "Good afternoon")
        default: String(localized: "Good evening")
        }
    }

    /// Changes whenever something is logged (or Pro is bought), so the brief and inbox refresh.
    private var dataVersion: String {
        "\(shifts.count)-\(earnings.count)-\(expenses.count)-\(reminders.count)-\(shiftStore.isOnShift)-\(useAppleIntelligence)-\(pro.isPro)"
    }

    private func refresh() async {
        await brief.refresh(using: data, useAppleIntelligence: useAppleIntelligence)
        await scanInbox()
    }

    /// Finding screenshots in Photos by itself is part of Pro.
    private func scanInbox() async {
        guard pro.isPro else { return }
        await inbox.scanRecent(data: data, useAppleIntelligence: useAppleIntelligence)
    }

    // MARK: - Ask

    private var askBar: some View {
        Button { navigation.ask() } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeat(2))
                    .frame(width: 36, height: 36)
                    .background(Theme.voiceGradient, in: .circle)
                Text("Ask or add anything…")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                Image(systemName: "mic.fill").foregroundStyle(Theme.blue)
            }
            .padding(.leading, 8)
            .padding(.trailing, 18)
            .padding(.vertical, 8)
            .background(Theme.cardBackground, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.blue.opacity(0.25), lineWidth: 1))
            .shadow(color: Theme.blue.opacity(0.12), radius: 10, y: 4)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Ask DriveCap")
        .accessibilityIdentifier("home.ask")
    }

    // MARK: - Get started

    @ViewBuilder
    private var gettingStarted: some View {
        let autoFindOn = pro.isPro && (inbox.hasAccess || !inbox.isEnabled)
        // For free drivers the third step is an optional Pro offer, so it doesn't keep the card open.
        let allDone = !earnings.isEmpty && !expenses.isEmpty && (autoFindOn || !pro.isPro)
        if !hideGettingStarted && !allDone {
            GettingStartedCard(hasEarnings: !earnings.isEmpty, hasCosts: !expenses.isEmpty, autoFindOn: autoFindOn,
                               autoFindNeedsPro: !pro.isPro,
                               upload: startUpload,
                               addCost: { scanningReceipt = true },
                               allowAutoFind: {
                                   if pro.isPro {
                                       Task { await inbox.requestAccess(); await refresh() }
                                   } else {
                                       showingPaywall = true
                                   }
                               },
                               hide: { withAnimation { hideGettingStarted = true } })
        }
    }

    // MARK: - Ready to add

    /// Screenshots already read and shifts still missing their earnings.
    @ViewBuilder
    private var readyToAddSection: some View {
        let missing = shiftsMissingEarnings
        if !inbox.items.isEmpty || !missing.isEmpty || inbox.isScanning {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Ready to add", subtitle: "Check the amount, then tap Add")
                    if inbox.isScanning { ProgressView().controlSize(.small) }
                }
                ForEach(inbox.items) { item in
                    ScreenshotInboxRow(item: item,
                                       add: { inbox.accept(item, data: data) },
                                       review: { reviewing = item },
                                       dismiss: { inbox.dismiss(item) })
                }
                ForEach(missing.prefix(3)) { shift in
                    TaskRow(symbol: "banknote", tint: Theme.warning,
                            title: String(localized: "Earnings for \(shift.start.formatted(.dateTime.weekday(.wide))) shift"),
                            detail: "\(Formatters.duration(shift.duration)) · \(shift.distanceKm.kilometers)",
                            action: "Upload") { earningsSheet = EarningsSheet(shift: shift, scan: true) }
                }
            }
            .card()
        }
    }

    // MARK: - Reminders

    @ViewBuilder
    private var remindersSection: some View {
        let due = dueReminders
        if !due.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Car reminders")
                ForEach(due.prefix(3), id: \.0.id) { reminder, status in
                    TaskRow(symbol: reminder.kind.symbol, tint: Theme.color(for: status.urgency),
                            title: reminder.title, detail: data.dueText(reminder, status),
                            action: "Open") { navigation.selectedTab = .car }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: brief.isWritten ? "apple.intelligence" : "text.alignleft")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Theme.voiceGradient, in: .rect(cornerRadius: 10, style: .continuous))
                SectionHeader(title: "Your brief")
                if brief.isLoading { ProgressView().controlSize(.small) }
            }
            if let text = brief.text {
                Text(text).font(.subheadline).foregroundStyle(Theme.ink)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(brief.insights.prefix(3)) { insight in
                        Label {
                            Text(insight.text).foregroundStyle(Theme.ink)
                        } icon: {
                            Image(systemName: symbol(for: insight.kind)).foregroundStyle(Theme.blue)
                        }
                        .font(.subheadline)
                    }
                }
            }
            Button("Ask more", systemImage: "arrow.right") { navigation.ask(String(localized: "How is my week going and what should I do better?")) }
                .buttonStyle(CapsuleButtonStyle(filled: false, compact: true))
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

    @ViewBuilder
    private var recentShiftsSection: some View {
        let finished = shifts.filter { !$0.isActive }.prefix(5)
        if !finished.isEmpty {
            VStack(spacing: 0) {
                SectionHeader(title: "Recent shifts").padding(.bottom, 8)
                ForEach(Array(finished)) { shift in
                    NavigationLink(value: shift) { ShiftRow(shift: shift) }
                        .buttonStyle(.plain)
                    if shift.id != finished.last?.id { Divider().overlay(Theme.cardStroke) }
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
    let action: LocalizedStringKey
    let perform: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            Button(action, action: perform)
                .buttonStyle(CapsuleButtonStyle(tint: tint, filled: false, compact: true))
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
                IconBadge(symbol: item.result.source == .appleIntelligence ? "apple.intelligence" : "text.viewfinder",
                          tint: Theme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(item.result.platform?.title ?? String(localized: "Earnings")) · \(money.string(item.result.total ?? 0, decimals: true))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text(detail).font(.caption).foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                Button("Dismiss", systemImage: "xmark", action: dismiss)
                    .labelStyle(.iconOnly)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(width: 28, height: 28)
                    .background(Theme.wash, in: .circle)
                    .buttonStyle(.borderless)
            }
            HStack(spacing: 8) {
                Button("Add", systemImage: "checkmark", action: add)
                    .buttonStyle(CapsuleButtonStyle(compact: true))
                    .accessibilityIdentifier("inbox.add")
                Button("Review", action: review)
                    .buttonStyle(CapsuleButtonStyle(filled: false, compact: true))
            }
            .padding(.leading, 48)
        }
    }

    private var detail: String {
        var parts = [String(localized: "Screenshot from \(item.takenAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")]
        if let trips = item.result.trips { parts.append(String(localized: "\(trips) trips")) }
        if item.result.scope == .week { parts.append(String(localized: "weekly summary")) }
        if let shift = item.shift { parts.append(String(localized: "for \(shift.start.formatted(.dateTime.weekday(.wide))) shift")) }
        return parts.joined(separator: " · ")
    }
}
