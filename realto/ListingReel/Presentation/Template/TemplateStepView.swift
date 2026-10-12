import SwiftUI

/// Step 2 — Pick a template style.
struct TemplateStepView: View {
    @Bindable var model: EditorFlowModel
    let coordinator: AppCoordinator

    var body: some View {
        StepScaffold(route: .template) {
            SectionHeader(title: "Choose a style",
                          subtitle: "Each style sets fonts, colors, pacing, and transitions.")

            VStack(spacing: Theme.Spacing.m) {
                ForEach(model.templates) { template in
                    templateCard(template)
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", systemImage: "arrow.right", accessibilityID: "Continue") {
                coordinator.advance(from: .template)
            }
        }
    }

    private func templateCard(_ template: Template) -> some View {
        let selected = model.project.templateID == template.id
        return Button {
            model.selectTemplate(template)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                swatch(template)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(template.displayName)
                        .font(.headline).foregroundStyle(Theme.Palette.textPrimary)
                    Text(template.summary)
                        .font(.caption).foregroundStyle(Theme.Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.Palette.accent : Theme.Palette.textSecondary)
            }
            .padding(Theme.Spacing.m)
            .cardSurface()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(selected ? Theme.Palette.accent : .clear, lineWidth: 2)
            )
        }
    }

    private func swatch(_ template: Template) -> some View {
        RoundedRectangle(cornerRadius: Theme.Radius.control)
            .fill(Color(hex: template.colorTokens.backgroundHex))
            .frame(width: 64, height: 64)
            .overlay {
                Text("Aa")
                    .font(.title3.bold())
                    .foregroundStyle(Color(hex: template.colorTokens.accentHex))
            }
    }
}
