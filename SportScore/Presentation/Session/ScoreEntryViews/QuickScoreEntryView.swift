import SwiftUI

/// Big one-tap score buttons with sport-specific presets. Typing is a fallback
/// behind "Custom…", so the keyboard never covers the board in normal play.
struct QuickScoreEntryView: View {
    let sport: SportType
    var variant: String? = nil
    var context: EntryContext = EntryContext()
    /// Fewer columns and a smaller custom row, used in the two-player split layout.
    var compact: Bool = false
    let onSubmit: (ScoreEntry) -> Void

    @State private var isNegative: Bool = false
    @State private var showCustom: Bool = false
    @State private var input: String = ""
    @FocusState private var isFocused: Bool

    private var presets: [QuickPreset] {
        QuickScorePresets.presets(for: sport, variant: variant, context: context)
    }

    private var sign: Int { context.allowsNegative && isNegative ? -1 : 1 }

    private var columnCount: Int {
        if compact { return presets.count > 6 ? 3 : 2 }
        return min(presets.count, 4)
    }

    private var parsedValue: Int? {
        guard let raw = Int(input) else { return nil }
        let value = raw * sign
        if let max = context.maxValue, value > max { return nil }
        return value
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if context.allowsNegative {
                Picker("Sign", selection: $isNegative) {
                    Text("+ Won").tag(false)
                    Text("− Paid").tag(true)
                }
                .pickerStyle(.segmented)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppTheme.Spacing.sm), count: max(columnCount, 1)),
                spacing: AppTheme.Spacing.sm
            ) {
                ForEach(presets) { preset in
                    presetButton(preset)
                }
            }

            if showCustom {
                customRow
            } else {
                Button {
                    showCustom = true
                    isFocused = true
                } label: {
                    Label("Custom…", systemImage: "keyboard")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
                .padding(.top, AppTheme.Spacing.xs)
            }
        }
    }

    private func presetButton(_ preset: QuickPreset) -> some View {
        let value = preset.value < 0 ? preset.value : preset.value * sign
        return Button {
            onSubmit(ScoreEntry(value: value))
        } label: {
            VStack(spacing: 0) {
                Text(QuickScorePresets.format(value))
                    .font(.system(size: compact ? 26 : 30, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if let caption = preset.caption {
                    Text(caption)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 56 : 64)
        }
        .buttonStyle(.borderedProminent)
        .tint(value < 0 ? .red : .accentColor)
        .accessibilityLabel(preset.caption.map { "\(value), \($0)" } ?? "\(value)")
    }

    private var customRow: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            TextField("Score", text: $input)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .font(.title2.monospacedDigit())
                .multilineTextAlignment(.center)
                .padding(AppTheme.Spacing.sm)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                .onChange(of: input) { _, new in
                    let digits = new.filter(\.isNumber)
                    if digits != new { input = digits }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Button("Cancel") { closeCustom() }
                        Spacer()
                        Button("Add", action: submitTyped)
                            .bold()
                            .disabled(parsedValue == nil)
                    }
                }

            Button("Add", action: submitTyped)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(parsedValue == nil)

            Button {
                closeCustom()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Close custom score")
        }
    }

    private func submitTyped() {
        guard let value = parsedValue else { return }
        onSubmit(ScoreEntry(value: value))
        closeCustom()
    }

    private func closeCustom() {
        input = ""
        isFocused = false
        showCustom = false
    }
}
