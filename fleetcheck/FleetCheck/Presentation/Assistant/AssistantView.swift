import SwiftUI

/// Ask anything about earnings, costs and papers, or add entries by typing or dictating.
struct AssistantView: View {
    @Environment(Assistant.self) private var assistant
    @Environment(AppNavigation.self) private var navigation
    @State private var input = ""
    @State private var showingGuide = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if assistant.messages.isEmpty {
                            welcome
                        }
                        ForEach(assistant.messages) { message in
                            MessageBubble(message: message) { action in assistant.undo(action, in: message) }
                                .id(message.id)
                        }
                        if assistant.isResponding, assistant.messages.last?.isStreaming != true {
                            ProgressView().padding(.leading, 8).id("thinking")
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: assistant.messages) { _, messages in
                    withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("Ask")
            .navigationSubtitle(AppleIntelligence.status == .available && assistant.usesAppleIntelligence
                                ? "Apple Intelligence · on this iPhone" : "Quick answers · on this iPhone")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("What can I ask?", systemImage: "questionmark.circle") { showingGuide = true }
                }
                if !assistant.messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New conversation", systemImage: "square.and.pencil") { assistant.clear() }
                    }
                }
            }
            .sheet(isPresented: $showingGuide) { AskGuideView { question in
                showingGuide = false
                Task { await assistant.send(question) }
            } }
            .task { assistant.prewarm() }
            .onAppear(perform: handlePending)
            .onChange(of: navigation.pendingQuestion) { _, _ in handlePending() }
            .onChange(of: navigation.pendingSuggestion) { _, _ in handlePending() }
            .onChange(of: navigation.focusAsk) { _, focus in if focus { inputFocused = true; navigation.focusAsk = false } }
        }
    }

    private func handlePending() {
        if let suggestion = navigation.pendingSuggestion {
            navigation.pendingSuggestion = nil
            assistant.ask(suggestion.command, title: suggestion.title)
        }
        if let question = navigation.pendingQuestion {
            navigation.pendingQuestion = nil
            Task { await assistant.send(question) }
        }
        if navigation.focusAsk {
            inputFocused = true
            navigation.focusAsk = false
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .gradientCard(Theme.voiceGradient, cornerRadius: 20, shadow: Theme.blue.opacity(0.30))
                Text("Ask about your money, or just tell me what happened.")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("\"How much did I make this week?\" · \"fuel $40 38 L at Shell\" · \"uber 420 tips 30\"")
                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Instant answers")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.inkSecondary)
                    .textCase(.uppercase)
                FlowLayout(spacing: 8) {
                    ForEach(SuggestedQuestion.all) { suggestion in
                        Button {
                            assistant.ask(suggestion.command, title: suggestion.title)
                        } label: {
                            Label {
                                Text(suggestion.title).foregroundStyle(Theme.ink)
                            } icon: {
                                Image(systemName: suggestion.symbol).foregroundStyle(Theme.blue)
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Theme.cardBackground, in: .capsule)
                            .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 1))
                            .shadow(color: Theme.cardShadow, radius: 6, y: 2)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if !assistant.messages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SuggestedQuestion.all) { suggestion in
                            Button(suggestion.title) { assistant.ask(suggestion.command, title: suggestion.title) }
                                .buttonStyle(CapsuleButtonStyle(filled: false, compact: true))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            HStack(spacing: 10) {
                TextField("Ask or add…", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.cardBackground, in: .rect(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.blue.opacity(0.20), lineWidth: 1))
                    .accessibilityIdentifier("ask.input")
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.voiceGradient, in: .circle)
                        .shadow(color: Theme.blue.opacity(0.30), radius: 6, y: 3)
                }
                .buttonStyle(PressableStyle())
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || assistant.isResponding)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func send() {
        let text = input
        input = ""
        Task { await assistant.send(text) }
    }
}

private struct MessageBubble: View {
    let message: Assistant.Message
    let undo: (Assistant.Message.Action) -> Void

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            if !message.text.isEmpty || message.isStreaming {
                Text(verbatim: message.text.isEmpty ? "…" : message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .foregroundStyle(message.role == .user ? .white : Theme.ink)
                    .background(message.role == .user ? AnyShapeStyle(Theme.shiftGradient) : AnyShapeStyle(Theme.cardBackground),
                                in: .rect(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(message.role == .user ? Theme.gradientStroke : Theme.cardStroke, lineWidth: 1))
                    .shadow(color: message.role == .user ? Theme.blue.opacity(0.20) : Theme.cardShadow, radius: 8, y: 3)
                    .textSelection(.enabled)
            }
            ForEach(message.actions) { action in
                HStack(spacing: 10) {
                    IconBadge(symbol: action.undone ? "arrow.uturn.backward" : "checkmark",
                              tint: action.undone ? Theme.inkSecondary : Theme.positive, size: 30)
                    Text(action.undone ? String(localized: "Undone: \(action.title)") : action.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .strikethrough(action.undone)
                    Spacer(minLength: 8)
                    if !action.undone {
                        Button("Undo") { undo(action) }
                            .buttonStyle(CapsuleButtonStyle(filled: false, compact: true))
                    }
                }
                .card(padding: 12)
            }
            if message.usedAppleIntelligence && !message.isStreaming {
                Label("Apple Intelligence", systemImage: "apple.intelligence")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .padding(message.role == .user ? .leading : .trailing, 40)
    }
}

/// Wraps chips onto as many lines as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = [([], 0, 0)]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(([index], size.width, size.height))
            } else {
                rows[rows.count - 1].indices.append(index)
                rows[rows.count - 1].width = needed
                rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            }
        }
        return rows
    }
}

/// "What can I ask?" — examples by topic; tapping one asks it.
struct AskGuideView: View {
    let ask: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let topics: [(title: String, symbol: String, examples: [String])] = [
        (String(localized: "Money"), "banknote", [
            String(localized: "How much did I make this week?"), String(localized: "What was my net per hour last month?"),
            String(localized: "Compare this week with last week"), String(localized: "How much did Bolt pay me this month?"),
        ]),
        (String(localized: "Costs"), "cart", [
            String(localized: "How much did I spend on fuel this month?"), String(localized: "What's my cost per km?"),
            String(localized: "Show my last 5 expenses"),
        ]),
        (String(localized: "Add by talking"), "waveform", [
            String(localized: "fuel $40 38 L at Shell"), String(localized: "uber 420 tips 30 bonus 50, 18 trips"),
            String(localized: "car wash $12 yesterday"), String(localized: "parking $5"),
        ]),
        (String(localized: "Car & papers"), "car", [
            String(localized: "When is my ITP due?"), String(localized: "What's due in the next month?"),
            String(localized: "How many km until the oil change?"),
        ]),
        (String(localized: "Advice"), "lightbulb", [
            String(localized: "Which day pays best?"), String(localized: "How can I earn more per hour?"),
            String(localized: "Which shifts are missing earnings?"),
        ]),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Type or dictate (tap the mic on the keyboard). With Apple Intelligence you can ask in your own words, in English, Romanian or French. Every number comes from your own data on this iPhone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(topics, id: \.title) { topic in
                    Section {
                        ForEach(topic.examples, id: \.self) { example in
                            Button(example) { ask(example) }
                        }
                    } header: {
                        Label(topic.title, systemImage: topic.symbol)
                    }
                }
                Section {
                    Label("Say \"Hey Siri, ask DriveCap\" to ask without opening the app.", systemImage: "mic.circle")
                        .font(.subheadline)
                }
            }
            .fleetBackground()
            .navigationTitle("What can I ask?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
