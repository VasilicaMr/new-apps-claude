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

    init(editing: Expense? = nil) {
        self.editing = editing
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
                            Text("\(money.string(amount / liters, decimals: true)) per \(category == .charging ? "kWh" : "liter")")
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
                    let photoTitle = receipt == nil ? "Add photo" : "Replace photo"
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photoTitle, systemImage: "photo.badge.plus")
                    }
                    TextField("Note (station, garage…)", text: $note, axis: .vertical)
                }
            }
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
            .onChange(of: photoItem) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                    receipt = ReceiptImage.compress(data)
                }
            }
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
        // A pump receipt's odometer reading is more accurate than GPS, so it corrects the car.
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
