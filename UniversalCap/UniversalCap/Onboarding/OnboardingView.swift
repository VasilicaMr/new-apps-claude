import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    private let pages = OnboardingPage.all

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen animated gradient background
            pages[currentPage].backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: currentPage)

            // Pages
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom controls
            VStack(spacing: 20) {
                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage
                                  ? Color.white
                                  : Color.white.opacity(0.35))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                    }
                }

                // Primary CTA
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.spring(response: 0.4)) { currentPage += 1 }
                    } else {
                        withAnimation { hasCompletedOnboarding = true }
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                        .font(.headline)
                        .foregroundStyle(pages[currentPage].accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                }
                .padding(.horizontal, 28)
                .animation(.easeInOut(duration: 0.2), value: currentPage)

                // Skip
                if currentPage < pages.count - 1 {
                    Button("Skip for now") {
                        withAnimation { hasCompletedOnboarding = true }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.65))
                } else {
                    Color.clear.frame(height: 20)
                }
            }
            .padding(.bottom, 52)
        }
    }
}

// MARK: - Page View

private struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 48)

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 130, height: 130)
                    Image(systemName: page.icon)
                        .font(.system(size: 58, weight: .medium))
                        .foregroundStyle(Color.white)
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .opacity(appeared ? 1 : 0)
                }
                .padding(.bottom, 32)

                // Title
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .padding(.bottom, 14)

                // Body
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 36)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)

                // Example phrase bubble
                if let example = page.example {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.caption)
                        Text(example)
                            .font(.callout)
                            .italic()
                    }
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                }

                // Numbered steps
                if let steps = page.steps {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 28, height: 28)
                                    Text("\(index + 1)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                                Text(step)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .offset(y: appeared ? 0 : 16)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.75)
                                .delay(0.15 + Double(index) * 0.07),
                                value: appeared
                            )
                        }
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                }

                Spacer(minLength: 140)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
                appeared = true
            }
        }
        .onDisappear { appeared = false }
    }
}

// MARK: - Page Model

struct OnboardingPage {
    let icon: String
    let title: String
    let body: String
    let example: String?
    let steps: [String]?
    let backgroundGradient: LinearGradient
    let accentColor: Color

    static let all: [OnboardingPage] = [
        // 1 — Welcome
        OnboardingPage(
            icon: "waveform.circle.fill",
            title: "Everything captured.\nNothing lost.",
            body: "Your brain is for thinking, not remembering. UniversalCap saves thoughts, expenses, and tasks the moment they happen — no decisions, no wrong apps.",
            example: nil,
            steps: nil,
            backgroundGradient: LinearGradient(
                colors: [Color(red: 0.40, green: 0.49, blue: 0.92),
                         Color(red: 0.46, green: 0.29, blue: 0.64)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            accentColor: Color(red: 0.40, green: 0.49, blue: 0.92)
        ),
        // 2 — Thoughts
        OnboardingPage(
            icon: "lightbulb.fill",
            title: "Catch ideas before\nthey vanish",
            body: "Shower thought. Commute insight. 3am idea. Say it once — it's saved, tagged, and waiting for you.",
            example: "\"Note that I want to try a freemium model\"",
            steps: nil,
            backgroundGradient: LinearGradient(
                colors: [Color(red: 0.58, green: 0.27, blue: 0.73),
                         Color(red: 0.36, green: 0.12, blue: 0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            accentColor: Color(red: 0.58, green: 0.27, blue: 0.73)
        ),
        // 3 — Expenses
        OnboardingPage(
            icon: "dollarsign.circle.fill",
            title: "Know exactly\nwhere it goes",
            body: "Say what you spent. UniversalCap extracts the amount, currency, and category automatically. No receipts. No spreadsheets.",
            example: "\"I spent €12 on lunch\"",
            steps: nil,
            backgroundGradient: LinearGradient(
                colors: [Color(red: 0.07, green: 0.60, blue: 0.56),
                         Color(red: 0.07, green: 0.44, blue: 0.24)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            accentColor: Color(red: 0.07, green: 0.60, blue: 0.44)
        ),
        // 4 — Tasks
        OnboardingPage(
            icon: "checkmark.circle.fill",
            title: "Never drop\nthe ball",
            body: "Capture the to-do the moment it lands in your head. Dates, names, and deadlines are parsed from plain language automatically.",
            example: "\"Remind me to call Ana tomorrow\"",
            steps: nil,
            backgroundGradient: LinearGradient(
                colors: [Color(red: 0.13, green: 0.59, blue: 0.95),
                         Color(red: 0.07, green: 0.33, blue: 0.73)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            accentColor: Color(red: 0.13, green: 0.59, blue: 0.95)
        ),
        // 5 — Siri is ready
        OnboardingPage(
            icon: "waveform.badge.mic",
            title: "Siri is ready.\nNo setup needed.",
            body: "Your capture phrases are live the moment you install. Try any of these right now — Siri routes everything automatically.",
            example: nil,
            steps: [
                "Hey Siri, capture with UniversalCap",
                "Hey Siri, what did I spend today in UniversalCap",
                "Hey Siri, what are my open tasks in UniversalCap",
                "Hey Siri, note an idea with UniversalCap",
            ],
            backgroundGradient: LinearGradient(
                colors: [Color(red: 0.95, green: 0.42, blue: 0.22),
                         Color(red: 0.80, green: 0.18, blue: 0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            accentColor: Color(red: 0.95, green: 0.42, blue: 0.22)
        ),
        // 6 — Shortcuts setup
        OnboardingPage(
            icon: "square.grid.2x2.fill",
            title: "Add to Shortcuts\nin 4 taps",
            body: "Set your own phrases and build automations in the Shortcuts app. Open it once and UniversalCap is everywhere.",
            example: nil,
            steps: [
                "Open the Shortcuts app on your iPhone",
                "Tap the Gallery tab at the bottom",
                "Search UniversalCap in the search bar",
                "Tap any shortcut — then tap Add to Siri to set your own phrase",
            ],
            backgroundGradient: LinearGradient(
                colors: [Color(red: 0.07, green: 0.50, blue: 0.75),
                         Color(red: 0.04, green: 0.28, blue: 0.58)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            accentColor: Color(red: 0.07, green: 0.50, blue: 0.75)
        ),
        // 7 — Ready
        OnboardingPage(
            icon: "checkmark.seal.fill",
            title: "You're all set.\nStart capturing.",
            body: "Everything you think, spend, or need to do — one phrase away. Your data stays on your device, always.",
            example: nil,
            steps: nil,
            backgroundGradient: LinearGradient(
                colors: [Color(red: 0.20, green: 0.10, blue: 0.48),
                         Color(red: 0.10, green: 0.18, blue: 0.58)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            accentColor: Color(red: 0.20, green: 0.10, blue: 0.48)
        ),
    ]
}
