import AppIntents
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(ShiftStore.self) private var shiftStore
    @AppStorage(SettingsKeys.currencyCode) private var currencyCode = MoneyFormatter.defaultCurrencyCode
    @AppStorage(SettingsKeys.hasSeenTutorial) private var hasSeenTutorial = true
    @AppStorage(SettingsKeys.useAppleIntelligence) private var useAppleIntelligence = true
    @State private var confirmDelete = false

    private static let currencies = ["RON", "EUR", "USD", "GBP", "PLN", "HUF", "BGN", "MDL"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Money") {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Array(Set(Self.currencies + [currencyCode])).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                }

                Section {
                    NavigationLink { ExportView() } label: {
                        Label("Export to spreadsheet (CSV)", systemImage: "tablecells")
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Everything you log stays on this iPhone. FleetCheck has no account and sends your trips, earnings and location nowhere. Export a CSV for your accountant or a backup.")
                }

                Section {
                    LabeledContent("Status", value: AppleIntelligence.status.description)
                    Toggle("Use for screenshots", isOn: $useAppleIntelligence)
                        .disabled(AppleIntelligence.status != .available)
                } header: {
                    Text("Apple Intelligence")
                } footer: {
                    Text("Understands earnings screenshots from Uber, Bolt and FREENOW, on this iPhone. Without it, FleetCheck still reads the numbers by matching labels like Tips and Promotions.")
                }

                Section {
                    ShortcutsLink()
                        .shortcutsLinkStyle(.automaticOutline)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Siri")
                } footer: {
                    Text("Say \"Start my shift in FleetCheck\", \"End my shift in FleetCheck\" or \"How much did I make today in FleetCheck\" — hands-free while driving.")
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
            .navigationTitle("Settings")
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
                .init(start: $0.start, end: $0.end, distanceKm: $0.distanceKm, movingHours: $0.movingSeconds / 3600,
                      earnings: $0.earningsTotal, note: $0.note)
            })),
            ("earnings", exporter.earnings(earnings.map {
                .init(date: $0.date, platform: $0.platform, fares: $0.fares, tips: $0.tips, bonus: $0.bonus, trips: $0.trips, note: $0.note)
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
