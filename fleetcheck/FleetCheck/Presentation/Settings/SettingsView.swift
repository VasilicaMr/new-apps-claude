import AppIntents
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(ShiftStore.self) private var shiftStore
    @Environment(ScreenshotInbox.self) private var inbox
    @Environment(ProStore.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKeys.autoImportScreenshots) private var autoImportScreenshots = true
    @AppStorage(SettingsKeys.currencyCode) private var currencyCode = MoneyFormatter.defaultCurrencyCode
    @AppStorage(SettingsKeys.hasSeenTutorial) private var hasSeenTutorial = true
    @AppStorage(SettingsKeys.useAppleIntelligence) private var useAppleIntelligence = true
    @State private var confirmDelete = false
    @State private var showingPaywall = false
    @State private var managingSubscription = false
    @State private var language = AppLanguage.chosen ?? ""
    @State private var languageChanged = false
    @Query private var scanReports: [ScanReport]

    private static let currencies = ["RON", "EUR", "USD", "GBP", "PLN", "HUF", "BGN", "MDL"]

    var body: some View {
        NavigationStack {
            Form {
                proSection

                Section {
                    Picker(selection: $language) {
                        Text("Same as iPhone").tag("")
                        ForEach(AppLanguage.supported, id: \.self) { Text(AppLanguage.name($0)).tag($0) }
                    } label: {
                        Label("Language", systemImage: "globe")
                    }
                    .onChange(of: language) {
                        AppLanguage.choose(language)
                        languageChanged = true
                    }
                } footer: {
                    if languageChanged {
                        Text("Close DriveCap and open it again to switch the language.")
                    }
                }

                Section("Money") {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Array(Set(Self.currencies + [currencyCode])).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                }

                Section {
                    if pro.isPro {
                        NavigationLink { ExportView() } label: {
                            Label("Export to spreadsheet (CSV)", systemImage: "tablecells")
                        }
                    } else {
                        Button { showingPaywall = true } label: {
                            HStack {
                                Label("Export to spreadsheet (CSV)", systemImage: "tablecells")
                                Spacer()
                                ProBadge()
                            }
                        }
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Everything you log stays on this iPhone. DriveCap has no account and sends your trips and earnings nowhere. Export a CSV for your accountant or a backup.")
                }

                Section {
                    if pro.isPro {
                        Toggle("Find earnings screenshots", isOn: $autoImportScreenshots)
                    } else {
                        Button { showingPaywall = true } label: {
                            HStack {
                                Text("Find earnings screenshots").foregroundStyle(Theme.ink)
                                Spacer()
                                ProBadge()
                            }
                        }
                    }
                    if pro.isPro && autoImportScreenshots && !inbox.hasAccess {
                        Button("Allow access to screenshots", systemImage: "photo.on.rectangle.angled") {
                            Task {
                                if inbox.authorization == .notDetermined {
                                    await inbox.requestAccess()
                                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                                    await UIApplication.shared.open(url)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Automatic")
                } footer: {
                    Text("When you open DriveCap, it looks at screenshots from the last 3 days and offers the ones that show earnings on Home, ready to add with one tap. After a shift, it goes straight to reading your earnings screenshot.")
                }

                Section {
                    LabeledContent("Status", value: AppleIntelligence.status.description)
                    Toggle("Use Apple Intelligence", isOn: $useAppleIntelligence)
                        .disabled(AppleIntelligence.status != .available)
                    NavigationLink { ScanReportsView() } label: {
                        LabeledContent("Misread reports", value: "\(scanReports.count)")
                    }
                } header: {
                    Text("Apple Intelligence")
                } footer: {
                    Text("Powers the Ask assistant, your daily brief, and reading screenshots and receipts, all on this iPhone. Without it, DriveCap still answers the common questions and reads numbers by matching labels like Tips and TOTAL. When a screenshot is read wrong, tap \"Numbers wrong?\" in the form to keep a report.")
                }

                Section {
                    ShortcutsLink()
                        .shortcutsLinkStyle(.automaticOutline)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Siri")
                } footer: {
                    Text("Say \"Start my shift in DriveCap\", \"End my shift in DriveCap\" or \"How much did I make today in DriveCap\" — hands-free while driving.")
                }

                Section {
                    Button("Show tutorial again", systemImage: "graduationcap") { hasSeenTutorial = false }
                    Button("Delete all data", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        .disabled(shiftStore.isOnShift)
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .fleetBackground()
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showingPaywall) { PaywallSheet() }
            .manageSubscriptionsSheet(isPresented: $managingSubscription)
            .confirmationDialog("Delete all shifts, earnings, expenses and reminders?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    for model in DataStore.models { try? context.delete(model: model) }
                    try? context.save()
                    context.rescheduleReminderNotifications()
                }
            } message: {
                Text("This can't be undone. Export a CSV first if you want a copy.")
            }
        }
    }
}

extension SettingsView {
    @ViewBuilder
    private var proSection: some View {
        Section {
            if pro.isPro {
                Label("DriveCap Pro is active", systemImage: "crown.fill")
                    .foregroundStyle(Theme.ink)
                Button("Manage subscription", systemImage: "creditcard") { managingSubscription = true }
            } else {
                Button { showingPaywall = true } label: {
                    HStack(spacing: 12) {
                        IconBadge(symbol: "crown.fill", tint: Theme.warning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to DriveCap Pro").font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                            Text("Unlimited screenshot reading, Earn smarter and export.")
                                .font(.caption).foregroundStyle(Theme.inkSecondary)
                        }
                    }
                }
                .accessibilityIdentifier("settings.upgrade")
                Button("Restore purchases", systemImage: "arrow.clockwise") { Task { await pro.restore() } }
            }
        } header: {
            Text("DriveCap Pro")
        } footer: {
            if let left = ScreenshotAllowance().remaining(isPro: pro.isPro) {
                Text("Free version: \(left) screenshot reads left this month.")
            }
        }
        .alert("Purchase didn't go through", isPresented: Binding(get: { pro.purchaseError != nil }, set: { if !$0 { pro.purchaseError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pro.purchaseError ?? "")
        }
    }
}

/// Writes three CSV files and offers them to the share sheet (Files, Mail, WhatsApp…).
struct ExportView: View {
    @Environment(\.modelContext) private var context
    @State private var files: [URL] = []

    var body: some View {
        List {
            Section {
                ForEach(files, id: \.self) { url in
                    ShareLink(item: url) {
                        Label(url.lastPathComponent, systemImage: "doc.text")
                    }
                }
                if files.count > 1 {
                    ShareLink(items: files) {
                        Label("Share all", systemImage: "square.and.arrow.up.on.square")
                    }
                }
            } footer: {
                Text("Opens in Numbers, Excel or Google Sheets. Amounts use a dot as decimal separator.")
            }
        }
        .fleetBackground()
        .navigationTitle("Export")
        .task { files = makeFiles() }
    }

    private func makeFiles() -> [URL] {
        let exporter = CSVExporter()
        let shifts = (try? context.fetch(FetchDescriptor<Shift>(sortBy: [SortDescriptor(\.start)]))) ?? []
        let earnings = (try? context.fetch(FetchDescriptor<Earning>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let expenses = (try? context.fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date)]))) ?? []

        let documents: [(String, String)] = [
            ("shifts", exporter.shifts(shifts.map {
                .init(start: $0.start, end: $0.end, distanceKm: $0.distanceKm,
                      earnings: $0.earningsTotal, note: $0.note)
            })),
            ("earnings", exporter.earnings(earnings.map {
                .init(date: $0.date, platform: $0.platform, fares: $0.fares, tips: $0.tips, bonus: $0.bonus, trips: $0.trips,
                      distanceKm: $0.distanceKm, destination: $0.destination, cash: $0.cashCollected, note: $0.note)
            })),
            ("expenses", exporter.expenses(expenses.map {
                .init(date: $0.date, category: $0.category, amount: $0.amount, liters: $0.liters, odometerKm: $0.odometerKm, note: $0.note)
            })),
        ]
        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let directory = FileManager.default.temporaryDirectory.appending(path: "export", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return documents.compactMap { name, csv in
            let url = directory.appending(path: "fleetcheck-\(name)-\(stamp).csv")
            return (try? csv.write(to: url, atomically: true, encoding: .utf8)) != nil ? url : nil
        }
    }
}

/// Reports saved with "Numbers wrong?" in the earnings form, to share so the reading can be improved.
struct ScanReportsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ScanReport.date, order: .reverse) private var reports: [ScanReport]
    @State private var confirmDelete = false

    var body: some View {
        List {
            if !reports.isEmpty {
                Section {
                    ShareLink(item: exportText, preview: SharePreview("DriveCap screenshot reports")) {
                        Label("Share all reports", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Reports contain the text read from your screenshots, not the images. Check them for names or other personal details before sharing.")
                }
            }
            Section {
                ForEach(reports) { report in
                    NavigationLink {
                        ScrollView {
                            Text(report.text)
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .fleetBackground()
                        .navigationTitle(report.date.formatted(date: .abbreviated, time: .shortened))
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline)
                            Text(report.corrected == nil ? "\(report.method) · not corrected" : "\(report.method) · corrected")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in offsets.map { reports[$0] }.forEach(context.delete) }
            }
            if !reports.isEmpty {
                Section {
                    Button("Delete all reports", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .fleetBackground()
        .navigationTitle("Misread reports")
        .overlay {
            if reports.isEmpty {
                ContentUnavailableView("No reports", systemImage: "text.viewfinder",
                                       description: Text("When a screenshot is read wrong, tap \"Numbers wrong?\" in the earnings form. The report shows up here."))
            }
        }
        .confirmationDialog("Delete all reports?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) { reports.forEach(context.delete) }
        }
    }

    private var exportText: String {
        reports.map(\.text).joined(separator: "\n\n==========\n\n")
    }
}
