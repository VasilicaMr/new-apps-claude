# UniversalCap

> One phrase to Siri. Everything captured. Nothing lost.

---

## The Problem

Every iPhone user — every single day — has moments where they think something, spend something, remember something, or want to note something. The friction is always the same: **"Which app do I open?"**

The result? Things don't get captured, or they land in the wrong place. Notes has tasks. Reminders has ideas. iMessage has expenses. Everything is scattered.

---

## The Solution

**UniversalCap** is a single-intent capture layer powered by Apple's App Intents framework and an on-device AI classifier.

One Siri phrase: **"Hey Siri, log [anything] in UniversalCap"**

The AI automatically routes what you said to the right place. No decisions required from the user. No app to open.

---

## Core App Intents (MVP)

### 1. `CaptureThoughtIntent`
**Trigger:** "Hey Siri, note that I had an idea about X"  
**Routing:** → Ideas list  
**AI Logic:** Detects reflective/creative language. Tags with topic, timestamps, optionally links to a related project.

### 2. `LogExpenseIntent`
**Trigger:** "Hey Siri, I spent €12 on lunch"  
**Routing:** → Expenses with auto-category  
**AI Logic:** Extracts amount + currency, auto-categorises (food, transport, health, etc.), optionally matches merchant name.

### 3. `AddTaskIntent`
**Trigger:** "Hey Siri, I need to call Ana tomorrow"  
**Routing:** → Tasks with smart scheduling  
**AI Logic:** Extracts action verb, person/entity, and temporal reference. Converts relative time ("tomorrow", "next Monday") to absolute date.

---

## How the AI Routing Works

```
User utterance (raw text)
        │
        ▼
┌───────────────────┐
│  Intent Classifier │  ← on-device ML model (CoreML / Create ML)
│  (thought / expense│
│   / task / unknown)│
└────────┬──────────┘
         │
    ┌────▼────┐
    │ Extractor│  ← entity extraction (NLP): amount, date, person, topic
    └────┬────┘
         │
  ┌──────▼──────┐
  │  Data Router │  → writes to correct local store
  └─────────────┘
         │
    ┌────▼────────────────────────────────┐
    │  Thoughts DB │ Expenses DB │ Tasks DB│
    └─────────────────────────────────────┘
```

All processing happens **on-device**. No data leaves the phone. No server required for MVP.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 |
| UI | SwiftUI |
| App Intents | `AppIntents` framework (iOS 16+) |
| ML Classifier | Create ML (text classifier, trained locally) |
| NLP | Apple `NaturalLanguage` framework |
| Storage | SwiftData (iOS 17+) |
| Siri Integration | `SiriTipView`, `ShortcutsLink` |

> **React Native note:** App Intents is a native iOS framework. It cannot be implemented in JS. If the project is RN-based, the intents must be written as a native Swift module (Swift Package) and bridged. The UI layer can remain in React Native; only the intent handlers need to be native.

---

## Project Structure

```
UniversalCap/
├── App/
│   ├── UniversalCapApp.swift          # Entry point
│   └── AppEnvironment.swift           # DI container
├── Intents/
│   ├── CaptureThoughtIntent.swift
│   ├── LogExpenseIntent.swift
│   └── AddTaskIntent.swift
├── Classifier/
│   ├── IntentClassifier.swift         # CoreML wrapper
│   ├── EntityExtractor.swift          # NL framework wrapper
│   └── UniversalCapClassifier.mlmodel # Trained Create ML model
├── Models/
│   ├── Thought.swift
│   ├── Expense.swift
│   └── Task.swift
├── Storage/
│   └── DataStore.swift                # SwiftData container
├── UI/
│   ├── HomeView.swift                 # Unified feed
│   ├── ThoughtsView.swift
│   ├── ExpensesView.swift
│   └── TasksView.swift
└── Shared/
    └── Extensions.swift
```

---

## App Intent Implementation Pattern

```swift
// Example: LogExpenseIntent.swift
import AppIntents

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log an Expense"
    static var description = IntentDescription("Quickly log a spend without opening the app.")

    @Parameter(title: "What did you spend?")
    var utterance: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let expense = try await ExpenseExtractor.extract(from: utterance)
        await DataStore.shared.save(expense)
        return .result(dialog: "Logged €\(expense.amount) for \(expense.category).")
    }
}
```

---

## MVP Build Plan (4 Weeks)

### Week 1 — Foundation
- [ ] Xcode project setup, SwiftData schema
- [ ] `Thought`, `Expense`, `Task` models
- [ ] Basic SwiftUI home feed (unified timeline)

### Week 2 — Intents
- [ ] `CaptureThoughtIntent` — wire up, test with Shortcuts app
- [ ] `LogExpenseIntent` — amount + currency extraction via NL
- [ ] `AddTaskIntent` — date parsing with `NaturalLanguage`

### Week 3 — AI Classifier
- [ ] Build training dataset (50–100 labelled utterances per class)
- [ ] Train text classifier in Create ML
- [ ] Integrate `IntentClassifier.swift` — auto-route ambiguous input
- [ ] Add `UnknownIntent` fallback (ask user to clarify)

### Week 4 — Polish & Ship
- [ ] Siri phrase suggestions (`SiriTipView` on home screen)
- [ ] Widget: today's captures summary
- [ ] App Store screenshots, privacy policy, TestFlight beta
- [ ] Submit for review

---

## App Store Submission Checklist

- [ ] Bundle ID registered in App Store Connect
- [ ] App icon (1024×1024 + all required sizes)
- [ ] Privacy policy URL (required — app handles personal data)
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) — declare data use
- [ ] Siri usage description in `Info.plist` (`NSSiriUsageDescription`)
- [ ] Age rating: 4+
- [ ] Screenshots for iPhone 6.7" and 6.1"
- [ ] TestFlight external testing (at least 1 week before submission)
- [ ] App Review notes: explain App Intent / Siri usage clearly

---

## Why This Wins

| Signal | Detail |
|---|---|
| **Frequency** | Captures happen 5–10× per day per user |
| **Friction solved** | Eliminates the "which app?" decision entirely |
| **Timing** | App Intents is still underused by indie devs — first mover window open |
| **Moat** | Classifier improves with more utterance variety; hard to replicate quickly |
| **Monetisation** | Free tier: 30-day history, 6 built-in categories. Pro ($7.99 one-time): unlimited history, iCloud sync, CSV export, custom categories, widget |

---

## Monetisation

- **Free:** 6 built-in categories, 30-day capture history
- **Pro — $7.99 (one-time, lifetime):** Unlimited history, iCloud sync across devices, CSV export, custom categories, home screen widget

---

## Competitive Landscape

| App | Gap |
|---|---|
| Notion / Obsidian | Too heavy, no Siri intent layer |
| Apple Reminders | Single-purpose, no AI routing |
| Drafts | Capture only, no classification or routing |
| Copilot / Monarch | Expense only, no cross-category capture |

**UniversalCap is the only app that does cross-category AI routing from a single voice trigger.**

---

## Notes

- Target iOS 17+ to use SwiftData (simplifies persistence significantly)
- `AppIntents` requires iOS 16+; if targeting iOS 16, swap SwiftData for CoreData
- The Create ML classifier needs retraining if you add new categories — design the pipeline to make retraining a one-command operation
- Ship before WWDC 2026 to avoid Apple potentially announcing a native version of this concept
