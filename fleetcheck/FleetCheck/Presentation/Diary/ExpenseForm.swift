import PhotosUI
import SwiftData
import SwiftUI

struct ExpenseForm: View {
    var editing: Expense?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.money) private var money
    @State private var date: Date
    @State private var category: ExpenseCategory
    @State private var amount: Double
    @State private var coverageMonths: Int
    @State private var liters: Double
    @State private var odometerKm: Double
    @State private var note: String
    @State private var receipt: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var receiptPhotoItem: PhotosPickerItem?
    @State private var showingReceiptPicker = false
    @State private var showingCamera = false
    @State private var scanStatus: ScanStatus = .idle
    @AppStorage(SettingsKeys.useAppleIntelligence) private var useAppleIntelligence = true

    private enum ScanStatus: Equatable {
        case idle, reading
        case done(appleIntelligence: Bool)
        case failed(String)
    }

    /// - Parameter scanReceipt: opens the camera (or photo picker) right away.
    init(editing: Expense? = nil, scanReceipt: Bool = false) {
        self.editing = editing
        let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
        _showingCamera = State(initialValue: scanReceipt && cameraAvailable)
        _showingReceiptPicker = State(initialValue: scanReceipt && !cameraAvailable)
        _date = State(initialValue: editing?.date ?? .now)
        _category = State(initialValue: editing?.category ?? .fuel)
        _amount = State(initialValue: editing?.amount ?? 0)
        _coverageMonths = State(initialValue: editing?.coverageMonths ?? 0)
        _liters = State(initialValue: editing?.liters ?? 0)
        _odometerKm = State(initialValue: editing?.odometerKm ?? 0)
        _note = State(initialValue: editing?.note ?? "")
        _receipt = State(initialValue: editing?.receipt)
    }

    private var isFuel: Bool { category == .fuel }

    var body: some View {
        NavigationStack {
            Form {
                if editing == nil {
                    receiptScanSection
                }
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    AmountField(title: "Amount", value: $amount, currencyCode: money.currencyCode)
                    DatePicker("Date", selection: $date)
                }

                if isFuel || category == .charging {
                    Section {
                        AmountField(title: category == .charging ? "kWh" : "Liters", value: $liters)
                        AmountField(title: "Odometer (km)", value: $odometerKm)
                    } footer: {
                        if liters > 0, amount > 0 {
                            let price = money.string(amount / liters, decimals: true)
                            Text(category == .charging ? "\(price) per kWh" : "\(price) per liter")
                        }
                    }
                }

                Section {
                    Picker("Covers", selection: $coverageMonths) {
                        Text("One-off").tag(0)
                        Text("1 month").tag(1)
                        Text("3 months").tag(3)
                        Text("6 months").tag(6)
                        Text("12 months").tag(12)
                    }
                } footer: {
                    Text("Stats spread a payment that covers several months (insurance, vignette, leasing) evenly over that time.")
                }

                Section("Receipt") {
                    if let receipt, let image = UIImage(data: receipt) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                        Button("Remove photo", role: .destructive) { self.receipt = nil }
                    }
                    let photoTitle = receipt == nil ? String(localized: "Add photo") : String(localized: "Replace photo")
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photoTitle, systemImage: "photo.badge.plus")
                    }
                    TextField("Note (station, garage…)", text: $note, axis: .vertical)
                }
            }
            .fleetBackground()
            .navigationTitle(editing == nil ? "New expense" : "Edit expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(amount <= 0)
                }
            }
            .onChange(of: category) { _, new in
                if editing == nil { coverageMonths = new.defaultCoverageMonths }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { data in Task { await readReceipt(data) } }
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showingReceiptPicker, selection: $receiptPhotoItem, matching: .images)
            .onChange(of: receiptPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) { await readReceipt(data) }
                    receiptPhotoItem = nil
                }
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                    receipt = ReceiptImage.compress(data)
                }
            }
        }
    }

    // MARK: - Receipt scanning

    private var receiptScanSection: some View {
        Section {
            HStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showingCamera = true } label: {
                        Label("Scan receipt", systemImage: "camera.viewfinder").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CapsuleButtonStyle(tint: Theme.positive))
                }
                Button { showingReceiptPicker = true } label: {
                    Label("From photos", systemImage: "photo").frame(maxWidth: .infinity)
                }
                .buttonStyle(CapsuleButtonStyle(tint: Theme.positive, filled: false))
            }
            .disabled(scanStatus == .reading)
            switch scanStatus {
            case .idle:
                EmptyView()
            case .reading:
                Label("Reading receipt…", systemImage: "doc.text.viewfinder").font(.footnote).foregroundStyle(.secondary)
            case let .done(appleIntelligence):
                Label(appleIntelligence ? "Filled in with Apple Intelligence. Check before saving." : "Filled in from the receipt text. Check before saving.",
                      systemImage: appleIntelligence ? "apple.intelligence" : "text.magnifyingglass")
                    .font(.footnote)
                    .foregroundStyle(Theme.accent)
            case let .failed(message):
                Label(message, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.orange)
            }
        } footer: {
            Text("DriveCap reads the total, liters, station and date. The photo is kept as the receipt.")
        }
    }

    private func readReceipt(_ data: Data) async {
        scanStatus = .reading
        receipt = ReceiptImage.compress(data)
        do {
            let result = try await ReceiptScanner(useAppleIntelligence: useAppleIntelligence).scan(data)
            guard let total = result.amount else {
                scanStatus = .failed(String(localized: "Couldn't find the total. Type the amount below."))
                return
            }
            if let found = result.category { category = found }
            amount = total
            if let found = result.liters { liters = found }
            if let vendor = result.vendor, note.isEmpty { note = vendor }
            if let found = result.date, found <= .now, found > Calendar.current.date(byAdding: .month, value: -6, to: .now) ?? .distantPast {
                date = found
            }
            scanStatus = .done(appleIntelligence: result.source == .appleIntelligence)
        } catch {
            scanStatus = .failed(error.localizedDescription)
        }
    }

    private func save() {
        let liters = (isFuel || category == .charging) && liters > 0 ? liters : nil
        let odometer = (isFuel || category == .charging) && odometerKm > 0 ? odometerKm : nil
        if let editing {
            editing.date = date
            editing.category = category
            editing.amount = amount
            editing.coverageMonths = coverageMonths
            editing.liters = liters
            editing.odometerKm = odometer
            editing.note = note
            editing.receipt = receipt
        } else {
            context.insert(Expense(date: date, category: category, amount: amount, coverageMonths: coverageMonths,
                                   liters: liters, odometerKm: odometer, note: note, receipt: receipt))
        }
        // A pump receipt's odometer reading is the real number, so it corrects the car.
        if let odometer {
            let car = context.car()
            if odometer > car.odometerKm {
                car.odometerKm = odometer
                car.odometerUpdatedAt = .now
            }
        }
        try? context.save()
        dismiss()
    }
}

enum ReceiptImage {
    /// Downscales to 1600 px and JPEG 70% so a receipt costs ~200 KB instead of several MB.
    static func compress(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.7)
    }
}

/// The system camera, for photographing a receipt.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                parent.onCapture(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
