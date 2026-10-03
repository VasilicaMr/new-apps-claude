import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Step 3 — Property details. Rendered into intro/outro cards.
struct PropertyInfoStepView: View {
    @Bindable var model: EditorFlowModel
    let coordinator: AppCoordinator

    @State private var isPickingSheetPhoto = false
    @State private var sheetPhotoItem: PhotosPickerItem?
    @State private var isPickingSheetFile = false
    @State private var isShowingDocumentCamera = false

    var body: some View {
        StepScaffold(route: .propertyInfo) {
            SectionHeader(title: "Property details",
                          subtitle: "These appear on your title and contact cards.")

            if model.canScanListingSheet {
                scanListingSheetCard
            }

            FieldRow(label: "Headline", placeholder: "Just Listed",
                     text: optional($model.project.propertyInfo.headline), accessibilityID: "Headline")
            FieldRow(label: "Address", placeholder: "123 Maple Ave",
                     text: $model.project.propertyInfo.address,
                     accessibilityID: "propertyInfo.addressField")
            FieldRow(label: "Price", placeholder: LocalizedStringKey(pricePlaceholder),
                     text: optional($model.project.propertyInfo.price), accessibilityID: "Price")

            HStack(spacing: Theme.Spacing.m) {
                FieldRow(label: "Beds", placeholder: "3",
                         text: intText($model.project.propertyInfo.beds), keyboard: .numberPad,
                         accessibilityID: "Beds")
                FieldRow(label: "Baths", placeholder: "2",
                         text: doubleText($model.project.propertyInfo.baths), keyboard: .decimalPad,
                         accessibilityID: "Baths")
                FieldRow(label: squareAreaLabel, placeholder: LocalizedStringKey(squareAreaPlaceholder),
                         text: intText($model.project.propertyInfo.squareFeet), keyboard: .numberPad,
                         accessibilityID: "SquareArea")
            }
        } footer: {
            PrimaryButton(title: "Continue", systemImage: "arrow.right", accessibilityID: "Continue") {
                model.autosave()
                coordinator.advance(from: .propertyInfo)
            }
        }
        .photosPicker(isPresented: $isPickingSheetPhoto, selection: $sheetPhotoItem, matching: .images)
        .onChange(of: sheetPhotoItem) { _, newItem in
            guard let newItem else { return }
            sheetPhotoItem = nil
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await model.scanListingSheet(imageData: data)
                }
            }
        }
        .fileImporter(isPresented: $isPickingSheetFile, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            Task { await model.scanListingSheet(imageData: data) }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isShowingDocumentCamera) {
            DocumentCameraView { data in
                Task { await model.scanListingSheet(imageData: data) }
            }
            .ignoresSafeArea()
        }
        #endif
    }

    // MARK: - Scan listing sheet (on-device Apple Intelligence)

    private var scanListingSheetCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Menu {
                #if os(iOS)
                if DocumentCameraView.isSupported {
                    Button("Scan with Camera", systemImage: "doc.viewfinder") {
                        isShowingDocumentCamera = true
                    }
                }
                #endif
                Button("Choose from Photos", systemImage: "photo.on.rectangle") {
                    isPickingSheetPhoto = true
                }
                #if os(macOS)
                Button("Choose Image File…", systemImage: "folder") {
                    isPickingSheetFile = true
                }
                #endif
            } label: {
                HStack(spacing: Theme.Spacing.m) {
                    if model.isScanningListingSheet {
                        ProgressView()
                    } else {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.title2)
                            .foregroundStyle(Theme.Palette.accent)
                    }
                    VStack(alignment: .leading) {
                        Text(model.isScanningListingSheet ? "Reading listing sheet…" : "Scan a listing sheet")
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("Fill in the details from a flyer or MLS printout. Stays on your device.")
                            .font(.caption).foregroundStyle(Theme.Palette.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                }
                .padding(Theme.Spacing.m)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .disabled(model.isScanningListingSheet)
            .accessibilityIdentifier("propertyInfo.scanListingSheet")

            if let message = model.listingSheetScanMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }

    // MARK: - Locale-aware units & currency (auto by locale, not hardcoded to US)

    /// An illustrative example price formatted in the device's current currency —
    /// e.g. "$749,000" in the US, "749 000 €" in France, "749.000 €" in Germany/Spain/Italy.
    private var pricePlaceholder: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.maximumFractionDigits = 0
        return formatter.string(from: 749_000) ?? "$749,000"
    }

    private var squareAreaLabel: LocalizedStringKey {
        Locale.current.measurementSystem == .us ? "Sq Ft" : "m²"
    }

    private var squareAreaPlaceholder: String {
        Locale.current.measurementSystem == .us ? "1850" : "172"
    }

    // MARK: - Optional <-> String bindings

    private func optional(_ source: Binding<String?>) -> Binding<String> {
        Binding(get: { source.wrappedValue ?? "" },
                set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }

    private func intText(_ source: Binding<Int?>) -> Binding<String> {
        Binding(get: { source.wrappedValue.map(String.init) ?? "" },
                set: { source.wrappedValue = Int($0) })
    }

    private func doubleText(_ source: Binding<Double?>) -> Binding<String> {
        Binding(get: { source.wrappedValue.map { String($0) } ?? "" },
                set: { source.wrappedValue = Double($0) })
    }
}
