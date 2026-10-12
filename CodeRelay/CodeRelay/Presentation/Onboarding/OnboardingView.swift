import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [(icon: String, title: String, body: String)] = [
        ("terminal", "Your Mac's Claude Code, in your pocket",
         "CodeRelay connects to Claude Code running on your own Mac. Start sessions, watch Claude work live and steer it from your iPhone or iPad."),
        ("lock.shield", "Private by design",
         "Your phone talks straight to your Mac over an encrypted connection after a one-time pairing code. No servers or accounts in between, and you approve every risky action."),
        ("apple.intelligence", "Smarter with Apple Intelligence",
         "On supported devices, refine rough prompts, get plain-English explanations of permission requests, session summaries and follow-up suggestions, all generated on-device."),
        ("desktopcomputer.and.arrow.down", "Set up your Mac",
         "1. Install Claude Code.\n2. Install CodeRelay Host (free) from coderelay.app.\n3. Add a workspace folder, then click “Pair a device”.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(0..<pages.count, id: \.self) { index in
                    let item = pages[index]
                    VStack(alignment: .leading, spacing: 20) {
                        Spacer()
                        Image(systemName: item.icon)
                            .font(.system(size: 54, weight: .light))
                            .foregroundStyle(index == 2 ? Theme.ai : Theme.accent)
                        Text(item.title)
                            .font(Theme.mono(26, weight: .bold))
                            .foregroundStyle(Theme.text)
                        Text(item.body)
                            .font(Theme.mono(15))
                            .foregroundStyle(Theme.dim)
                            .lineSpacing(4)
                        Spacer()
                        Spacer()
                    }
                    .padding(28)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == pages.count - 1 ? "Get started" : "Next") {
                if page == pages.count - 1 { onFinish() } else { withAnimation { page += 1 } }
            }
            .buttonStyle(AccentButtonStyle())
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
