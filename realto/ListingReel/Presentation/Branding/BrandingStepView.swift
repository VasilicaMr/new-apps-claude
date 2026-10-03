import SwiftUI
import PhotosUI

/// Step 4 — Confirm branding. Entered once, reused across projects (spec §F5).
struct BrandingStepView: View {
    @Bindable var model: EditorFlowModel
    let coordinator: AppCoordinator

    @State private var logoItem: PhotosPickerItem?

    var body: some View {
        StepScaffold(route: .branding) {
            SectionHeader(title: "Your branding",
                          subtitle: "Saved once and reused. Your next video takes seconds.")

            logoPicker

            FieldRow(label: "Agent name", placeholder: "Jane Realtor", text: $model.brand.agentName,
                     accessibilityID: "branding.agentNameField")
            FieldRow(label: "Phone", placeholder: "(555) 123-4567",
                     text: optional($model.brand.phone), keyboard: .phonePad)
            FieldRow(label: "Brokerage", placeholder: "Blue Door Realty",
                     text: optional($model.brand.brokerage))
            FieldRow(label: "Email", placeholder: "jane@bluedoor.com",
                     text: optional($model.brand.email), keyboard: .emailAddress)
        } footer: {
            PrimaryButton(title: "Save & Continue", systemImage: "arrow.right",
                          isEnabled: model.brand.isComplete, accessibilityID: "Save & Continue") {
                Task {
                    await model.saveBrand()
                    coordinator.advance(from: .branding)
                }
            }
        }
        .onChange(of: logoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await model.setLogo(data: data)
                }
            }
        }
    }

    private var logoPicker: some View {
        PhotosPicker(selection: $logoItem, matching: .images) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: model.brand.logoAssetID == nil ? "photo.badge.plus" : "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(model.brand.logoAssetID == nil ? Theme.Palette.accent : Theme.Palette.success)
                VStack(alignment: .leading) {
                    Text(model.brand.logoAssetID == nil ? "Add logo" : "Logo added")
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("Shown on the contact card")
                        .font(.caption).foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
            }
            .padding(Theme.Spacing.m)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        }
    }

    private func optional(_ source: Binding<String?>) -> Binding<String> {
        Binding(get: { source.wrappedValue ?? "" },
                set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }
}
