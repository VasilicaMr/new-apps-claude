import PhotosUI
import SwiftData
import SwiftUI

/// "How much did you earn?" — shown when a shift ends, or to add/edit an entry.
struct EarningForm: View {
    let shift: Shift?
    var editing: Earning?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.money) private var money
    @Environment(ProStore.self) private var pro
    @State private var date: Date
    @State private var platform: Platform
    @State private var fares: Double
    @State private var tips: Double
    @State private var bonus: Double
    @State private var trips: Int
    @State private var distanceKm: Double
    @State private var destination: String
    @State private var cashCollected: Double
    @State private var note: String
    @State private var screenshotItem: PhotosPickerItem?
    @State private var showingPicker = false
    @State private var showingPaywall = false
    /// Opens the photo picker as the form appears (after a shift, or from Upload).
    private let scanOnAppear: Bool
    @State private var scan = ScanState.idle
    @State private var report: ScanReport?
    @AppStorage(SettingsKeys.useAppleIntelligence) private var useAppleIntelligence = true

    private enum ScanState: Equatable {
        case idle, reading
        case done(ScreenshotEarnings)
        case failed(String)
    }

    private let onSave: (() -> Void)?

    /// - Parameters:
    ///   - scanScreenshot: opens the photo picker right away.
    ///   - prefilled: a screenshot already read (Home → Needs you → Review).
    ///   - onSave: called after saving.
    init(shift: Shift?, editing: Earning? = nil, scanScreenshot: Bool = false,
         prefilled: ScreenshotEarnings? = nil, onSave: (() -> Void)? = nil) {
        self.shift = shift
        self.editing = editing
        self.onSave = onSave
        scanOnAppear = scanScreenshot
        _scan = State(initialValue: prefilled.map { .done($0) } ?? .idle)
        _date = State(initialValue: editing?.date ?? shift?.start ?? prefilled?.date ?? .now)
        _platform = State(initialValue: editing?.platform ?? prefilled?.platform ?? .uber)
        _fares = State(initialValue: editing?.fares ?? prefilled.map { $0.fares ?? $0.total ?? 0 } ?? 0)
        _tips = State(initialValue: editing?.tips ?? prefilled?.tips ?? 0)
        _bonus = State(initialValue: editing?.bonus ?? prefilled?.bonus ?? 0)
        _trips = State(initialValue: editing?.trips ?? prefilled?.trips ?? 0)
        _distanceKm = State(initialValue: editing?.distanceKm ?? prefilled?.distanceKm ?? 0)
        _destination = State(initialValue: editing?.destination ?? prefilled?.destination ?? "")
        _cashCollected = State(initialValue: editing?.cashCollected ?? prefilled?.cashCollected ?? 0)
        _note = State(initialValue: editing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if let shift, editing == nil {
                    Section {
                        LabeledContent("Shift", value: "\(Formatters.duration(shift.duration)) · \(shift.distanceKm.kilometers)")
                    }
                }
                if editing == nil {
                    scanSection
                }
                Section {
                    Picker("App", selection: $platform) {
                        ForEach(Platform.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    AmountField(title: "Fares", value: $fares, currencyCode: money.currencyCode)
                    AmountField(title: "Tips", value: $tips, currencyCode: money.currencyCode)
                    AmountField(title: "Bonus / promotions", value: $bonus, currencyCode: money.currencyCode)
                    Stepper("Trips: \(trips)", value: $trips, in: 0...200)
                } footer: {
                    Text("Total \(money.string(fares + tips + bonus, decimals: true)). Use what the app paid you after its commission.")
                }
                Section {
                    AmountField(title: "Cash collected", value: $cashCollected, currencyCode: money.currencyCode)
                } footer: {
                    if cashCollected > 0 {
                        Text("Already in your pocket and part of the total above. The app pays out \(money.string(max(0, fares + tips + bonus - cashCollected), decimals: true)).")
                    } else {
                        Text("Cash passengers paid you in the car. It's part of the total, not extra.")
                    }
                }
                Section {
                    AmountField(title: "Kilometers", value: $distanceKm)
                    TextField("Destination", text: $destination)
                        .textContentType(.fullStreetAddress)
                } footer: {
                    Text("Kilometers are added to the shift and the car's odometer.")
                }
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note", text: $note, axis: .vertical)
                }
            }
            .fleetBackground()
            .navigationTitle(editing == nil ? "What did you earn?" : "Edit earnings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(editing == nil && shift != nil ? "Later" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(fares + tips + bonus <= 0)
                }
            }
        }
        .presentationDetents([.large])
        .photosPicker(isPresented: $showingPicker, selection: $screenshotItem, matching: .images)
        .sheet(isPresented: $showingPaywall, onDismiss: { if pro.isPro { showingPicker = true } }) { PaywallSheet() }
        .onAppear { if scanOnAppear && scan == .idle { pickScreenshot() } }
        .onChange(of: screenshotItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    scan = .failed(String(localized: "Couldn't open that image."))
                    return
                }
                await read(data)
                screenshotItem = nil
            }
        }
        #if DEBUG
        // `-debugScanImage <path>` scans a file at launch, for testing without the photo picker.
        .task {
            if let path = UserDefaults.standard.string(forKey: "debugScanImage"), let data = FileManager.default.contents(atPath: path) {
                await read(data)
            }
        }
        #endif
    }

    // MARK: - Screenshot

    private var scanSection: some View {
        Section {
            Button(action: pickScreenshot) {
                HStack(spacing: 12) {
                    Image(systemName: "text.viewfinder")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Read from screenshot").font(.body.weight(.medium))
                        Text("Take a screenshot of the trip or earnings screen in Uber or Bolt, then pick it here.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if scan == .reading { ProgressView() }
                }
            }
            .buttonStyle(.plain)
            .disabled(scan == .reading)
            .accessibilityIdentifier("earnings.scan")

            switch scan {
            case .idle, .reading:
                EmptyView()
            case let .done(result):
                scanResult(result)
            case let .failed(message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        } footer: {
            if let left = allowance.remaining(isPro: pro.isPro) {
                Text("Read on this iPhone. The screenshot isn't saved or sent anywhere. \(left) free reads left this month.")
            } else {
                Text("Read on this iPhone. The screenshot isn't saved or sent anywhere.")
            }
        }
    }

    private func scanResult(_ result: ScreenshotEarnings) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(result.source == .appleIntelligence ? "Filled in with Apple Intelligence" : "Filled in from the screenshot text",
                  systemImage: result.source == .appleIntelligence ? "apple.intelligence" : "text.magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text(result.total.map { String(localized: "Total on screen: \(money.string($0, decimals: true)). Check the numbers below before saving.") }
                 ?? String(localized: "Check the numbers below before saving."))
                .font(.caption)
                .foregroundStyle(.secondary)
            if result.scope == .week {
                Label("This looks like a weekly summary, not a single shift.", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if report == nil {
                Button("Numbers wrong? Save a report", systemImage: "exclamationmark.bubble") {
                    let report = ScanReport(result: result)
                    context.insert(report)
                    self.report = report
                }
                .font(.caption.weight(.medium))
                .buttonStyle(.borderless)
                .padding(.top, 2)
                .accessibilityIdentifier("earnings.reportMisread")
            } else {
                Label("Report saved. Fix the numbers below and tap Save; your corrections are added to it.", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }

    private var allowance: ScreenshotAllowance { ScreenshotAllowance() }

    /// Free drivers have a few reads a month; after that the paywall opens instead, and the picker once they're Pro.
    private func pickScreenshot() {
        if allowance.canRead(isPro: pro.isPro) {
            showingPicker = true
        } else {
            showingPaywall = true
        }
    }

    private func read(_ data: Data) async {
        scan = .reading
        do {
            let result = try await EarningsScreenshotScanner(useAppleIntelligence: useAppleIntelligence).scan(data)
            guard !result.isEmpty else {
                scan = .failed(String(localized: "No earnings found. Use a screenshot of the earnings screen that shows the amounts."))
                return
            }
            if !pro.isPro { allowance.recordRead() }
            apply(result)
            withAnimation { scan = .done(result) }
        } catch {
            scan = .failed(error.localizedDescription)
        }
    }

    private func apply(_ result: ScreenshotEarnings) {
        if let platform = result.platform { self.platform = platform }
        fares = result.fares ?? result.total ?? 0
        tips = result.tips ?? 0
        bonus = result.bonus ?? 0
        if let trips = result.trips { self.trips = trips }
        if let km = result.distanceKm { distanceKm = km }
        if let destination = result.destination { self.destination = destination }
        if let cash = result.cashCollected { cashCollected = cash }
        // A shift's own date wins; otherwise use the date on screen if it's plausible.
        if shift == nil, let screenDate = result.date, screenDate <= .now,
           screenDate > Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .distantPast {
            date = screenDate
        }
    }

    private func save() {
        report?.corrected = ScreenshotEarnings(platform: platform, total: fares + tips + bonus, fares: fares, tips: tips,
                                               bonus: bonus, trips: trips, distanceKm: distanceKm,
                                               destination: destination.isEmpty ? nil : destination,
                                               cashCollected: cashCollected > 0 ? cashCollected : nil).summary
        let trimmedDestination = destination.trimmingCharacters(in: .whitespaces)
        if let editing {
            context.addKilometers(distanceKm - editing.distanceKm, to: editing.shift)
            editing.date = date
            editing.platform = platform
            editing.fares = fares
            editing.tips = tips
            editing.bonus = bonus
            editing.trips = trips
            editing.distanceKm = distanceKm
            editing.destination = trimmedDestination
            editing.cashCollected = cashCollected
            editing.note = note
        } else {
            context.insert(Earning(date: date, platform: platform, fares: fares, tips: tips, bonus: bonus,
                                   trips: trips, distanceKm: distanceKm, destination: trimmedDestination,
                                   cashCollected: cashCollected, note: note, shift: shift))
            context.addKilometers(distanceKm, to: shift)
        }
        try? context.save()
        onSave?()
        dismiss()
    }
}
