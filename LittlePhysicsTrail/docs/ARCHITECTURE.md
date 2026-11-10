# Architecture

Little Physics Trail uses **clean architecture**: a set of rings where source code dependencies only
point inward. The two inner rings live in a Swift package, so the compiler enforces the rule.
`TrailDomain` cannot import SwiftUI, UIKit or `TrailData`, because the package doesn't let it.

```
┌──────────────────────────────────────────────────────────────┐
│  App target (LittlePhysicsTrail)                                   │
│  ┌────────────────────────────┐  ┌─────────────────────────┐ │
│  │ Presentation               │  │ App / Infrastructure    │ │
│  │ SwiftUI views              │  │ AppContainer (DI root)  │ │
│  │ @Observable view models    │  │ SpeechNarrator, StoreKit│ │
│  └─────────────┬──────────────┘  └──────────┬──────────────┘ │
└────────────────┼────────────────────────────┼────────────────┘
                 ▼                            ▼
        ┌──────────────────┐        ┌──────────────────┐
        │   TrailDomain    │ ◀───── │    TrailData     │
        │ entities, rules, │        │ StopCatalog,     │
        │ protocols,       │        │ UserDefaults     │
        │ use cases        │        │ repositories     │
        └──────────────────┘        └──────────────────┘
```

## Layers

### TrailDomain (innermost, depends on nothing)

| Kind | Types | Notes |
|---|---|---|
| Entities | `JourneyStop`, `BigIdea`, `SortBin`, `SortItem`, `StopTheme` | Content model. `StopTheme` is semantic ("sky"), not a `Color`. |
| Read models | `Journey`, `StopProgress`, `StopResult` | What the trail and the finish screen show. |
| Game rules | `SortSession`, `PlacementOutcome`, `StarRating` | A value type holding the whole game state machine. No timers and no UI, so it is trivially testable. |
| Business rules | `AccessPolicy` | Freemium rule: the first `freeStopCount` (3) stops are free, the rest need the Full Journey. |
| Ports | `StopRepository`, `ProgressRepository`, `SettingsRepository`, `Narrator`, `EntitlementProvider` / `PurchaseService` | Protocols that the outer rings implement. `EntitlementProvider` is the read-only slice that journey building needs. |
| Use cases | `LoadJourneyUseCase`, `CompleteStopUseCase`, `StopIntroUseCase`, `ResetProgressUseCase`, `UnlockJourneyUseCase` | One job each. Small structs that take ports in their initializer. |

### TrailData (implements Domain's ports)

- `StopCatalog` + `StaticStopRepository`: all physics content as Swift values. Being typed, a
  missing field won't compile, and `StopCatalogTests` catches bad bin ids.
- `UserDefaultsProgressRepository`: all keys are prefixed `physics.progress.`, so
  `reset()` can't touch settings.
- `UserDefaultsSettingsRepository`: read-aloud (on by default).

### Presentation (app target)

- **Views** are dumb. They render view-model state and forward user intents. The only state
  they own is gesture and animation state (drag offset, hovered bin, flying).
- **View models** (`@MainActor @Observable`) call use cases, own the `SortSession`, and talk to
  the `Narrator`. They never see `UserDefaults` or `AVSpeechSynthesizer`.
- `DesignSystem/NubeeTheme.swift` is copied from ShadowMatch (palette, chunky buttons, parental
  gate). `StopTheme+Color.swift` is the only place a domain theme becomes a `Color`.

### Purchases

StoreKit never leaks inward. `StoreKitPurchaseService` (Infrastructure) is an `@Observable`
class that implements `PurchaseService`: it loads the product, watches `Transaction.updates`
(Ask to Buy approvals, refunds, other devices) and exposes `ownsFullJourney` and an `offer`
(price). `LoadJourneyUseCase` combines that flag with `AccessPolicy` to mark stops as locked
and to never suggest a locked stop. View models read `ownsFullJourney` through the protocol, so
Observation refreshes the trail as soon as a purchase or restore lands.

### App / Infrastructure (composition root)

`AppContainer` is the only type that knows concrete classes. It builds repositories, wraps them
in use cases and hands out ready view models (`makeJourneyViewModel()`,
`makeLessonViewModel(stop:showIntro:)`, `makeGrownUpsViewModel()`). Views get it from the
environment (`@Environment(\.container)`). `AppContainer.preview()` uses a separate defaults
suite and a muted narrator for previews.

## Data flow: one drop

```
SortGameView      drag ends over the "Floats" bin
  → LessonViewModel.drop(on: "float")
      → SortSession.place(on:)            (Domain rule) → .correct(duck)
      → Narrator.say("Rubber duck. Floats! …")
  ← PlacementOutcome                       view: haptic + fly animation
SortGameView      shows FactCard (viewModel.revealedItem)
  "Next" → LessonViewModel.next() → SortSession.advance()
      last item → CompleteStopUseCase.execute(session) → ProgressRepository
               → phase = .finished(StopResult)
```

## Testing strategy

| Layer | How | Where |
|---|---|---|
| Domain rules and use cases (including the free/locked rule) | XCTest with in-memory test doubles and `FakePurchaseService` | `Tests/TrailDomainTests`, run with `swift test` on macOS in under a second |
| Content and persistence | Catalog guard-rails; UserDefaults with a throwaway suite | `Tests/TrailDataTests` |
| Whole app | UI tests: play stop 1 by tapping bins, locked stop opens the unlock page, `-unlockFullJourney` opens every stop | `LittlePhysicsTrailUITests` |

`-uiTesting` launches from a fresh install and mutes speech. The parental gate opens automatically
in that mode (same convention as ShadowMatch).

## Conventions

- New behaviour goes into Domain first, as a rule or a use case with a test, and gets wired
  through `AppContainer`.
- A view model gets use cases, never repositories directly. The exception is settings, which are
  simple key/value data with no rules.
- Files open with the same header block used in ShadowMatch: file name, module, and one line on *why* the file exists.
