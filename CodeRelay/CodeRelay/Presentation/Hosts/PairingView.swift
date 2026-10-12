import SwiftUI
import RelayKit

/// Enter the 6-digit code shown in the Mac's menu bar.
struct PairingView: View {
    let target: PairingTarget
    let viewModel: HostsViewModel
    let onPaired: (SavedHost) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var address = ""
    @State private var port = String(RelayConstants.defaultPort)
    @FocusState private var focusedField: Field?

    private enum Field { case code, address }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(title)
                        .font(Theme.mono(22, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("On your Mac, open the CodeRelay Host menu bar item and click **Pair a device**. Enter the code it shows.")
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.dim)

                    if case .manual = target { manualFields }

                    CodeEntryField(code: $code)
                        .focused($focusedField, equals: .code)

                    if let error = viewModel.pairingError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(Theme.mono(12))
                            .foregroundStyle(Theme.danger)
                    }

                    Button(action: pair) {
                        if viewModel.isPairing {
                            ProgressView().tint(Theme.background)
                        } else {
                            Text("Pair")
                        }
                    }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(!canPair || viewModel.isPairing)
                    .opacity(canPair ? 1 : 0.5)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                viewModel.pairingError = nil
                focusedField = target.isManual ? .address : .code
            }
        }
        .presentationDetents([.large])
    }

    private var title: String {
        switch target {
        case .discovered(let host): return "Pair with \(host.serviceName)"
        case .manual: return "Add a Mac by address"
        }
    }

    private var manualFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("address")
            HStack {
                TextField("192.168.1.20 or my-mac.tailnet.ts.net", text: $address)
                    .focused($focusedField, equals: .address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                TextField("port", text: $port)
                    .keyboardType(.numberPad)
                    .frame(width: 70)
            }
            .font(Theme.mono(15))
            .padding(12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
            Text("Works across networks with a VPN such as Tailscale.")
                .font(Theme.mono(11))
                .foregroundStyle(Theme.dim)
        }
    }

    private var canPair: Bool {
        guard PairingCrypto.normalize(code: code).count == 6 else { return false }
        if target.isManual { return !address.trimmingCharacters(in: .whitespaces).isEmpty && UInt16(port) != nil }
        return true
    }

    private func pair() {
        let endpoint: HostEndpoint
        switch target {
        case .discovered(let host): endpoint = host.endpoint
        case .manual: endpoint = .manual(host: address.trimmingCharacters(in: .whitespaces), port: UInt16(port) ?? RelayConstants.defaultPort)
        }
        Task {
            if let host = await viewModel.pair(endpoint: endpoint, code: code) {
                onPaired(host)
            }
        }
    }
}

private extension PairingTarget {
    var isManual: Bool {
        if case .manual = self { return true }
        return false
    }
}

/// Six monospaced digit boxes backed by one hidden text field.
struct CodeEntryField: View {
    @Binding var code: String

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .foregroundStyle(.clear)
                .tint(.clear)
                .onChange(of: code) { _, value in
                    let digits = String(PairingCrypto.normalize(code: value).prefix(6))
                    if digits != value { code = digits }
                }
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    let digit = index < code.count ? String(Array(code)[index]) : ""
                    Text(digit)
                        .font(Theme.mono(28, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(index == code.count ? Theme.accent : Theme.border, lineWidth: index == code.count ? 2 : 1))
                    if index == 2 { Text("–").foregroundStyle(Theme.dim) }
                }
            }
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pairing code")
        .accessibilityValue(code)
    }
}
