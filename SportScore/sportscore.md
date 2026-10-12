# ScoreCap — Product & Technical Requirements

**Platform**: iOS 26+ (iPhone, iPad) · tvOS 26+ (Apple TV)  
**Language**: Swift 6  
**UI**: SwiftUI  
**Architecture**: Clean Architecture + Coordinator Pattern  
**Database**: SwiftData (no Core Data)  
**Widget**: WidgetKit + App Intents  
**Auth**: None — fully local, no login required  
**Sync**: Optional CloudKit via SwiftData shared container  

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Architecture Overview](#2-architecture-overview)
3. [Coordinator Pattern](#3-coordinator-pattern)
4. [Data Layer — SwiftData Models](#4-data-layer--swiftdata-models)
5. [Domain Layer — Entities & Use Cases](#5-domain-layer--entities--use-cases)
6. [Presentation Layer — ViewModels & Views](#6-presentation-layer--viewmodels--views)
7. [Sport Scoring Engines](#7-sport-scoring-engines)
8. [Widget Extension](#8-widget-extension)
9. [iOS 26 Specific Features](#9-ios-26-specific-features)
10. [Feature Requirements by Sport](#10-feature-requirements-by-sport)
11. [Apple TV App](#11-apple-tv-app)

The full list of games players can pick (48 sports, 38 home games, custom games) is in [`games.md`](games.md#games-playable-in-scorecap).

---

## 1. Project Structure

```
SportScore/
├── App/
│   ├── ScoreCapApp.swift
│   ├── AppContainer.swift             DI root — builds all dependencies
│   └── AppCoordinator.swift           Root coordinator
│
├── Core/
│   ├── Extensions/
│   ├── Haptics/
│   ├── Theme/                         Tokens, typography, Liquid Glass helpers
│   └── Utils/
│
├── Data/
│   ├── Models/                        SwiftData @Model classes
│   │   ├── PlayerModel.swift
│   │   ├── GameSessionModel.swift
│   │   ├── ScoreFrameModel.swift
│   │   └── ScoreEntryModel.swift
│   ├── Repositories/                  Concrete implementations
│   │   ├── PlayerRepositoryImpl.swift
│   │   ├── SessionRepositoryImpl.swift
│   │   └── ScoreRepositoryImpl.swift
│   └── Persistence/
│       ├── PersistenceContainer.swift SwiftData ModelContainer factory
│       └── SharedStore.swift          App Group container for widgets
│
├── Domain/
│   ├── Entities/                      Pure Swift structs (no SwiftData)
│   │   ├── Player.swift
│   │   ├── GameSession.swift
│   │   ├── ScoreFrame.swift
│   │   ├── ScoreEntry.swift
│   │   └── SportType.swift
│   ├── Repositories/                  Protocols only
│   │   ├── PlayerRepository.swift
│   │   ├── SessionRepository.swift
│   │   └── ScoreRepository.swift
│   ├── UseCases/
│   │   ├── Player/
│   │   │   ├── CreatePlayerUseCase.swift
│   │   │   ├── FetchPlayersUseCase.swift
│   │   │   └── DeletePlayerUseCase.swift
│   │   ├── Session/
│   │   │   ├── StartSessionUseCase.swift
│   │   │   ├── EndSessionUseCase.swift
│   │   │   ├── FetchSessionsUseCase.swift
│   │   │   └── DeleteSessionUseCase.swift
│   │   └── Score/
│   │       ├── AddScoreEntryUseCase.swift
│   │       ├── UndoLastEntryUseCase.swift
│   │       └── ComputeScoreUseCase.swift
│   └── Engines/                       Sport-specific scoring logic (pure)
│       ├── ScoringEngine.swift        Protocol
│       ├── Precision/
│       ├── CueSports/
│       ├── Bowling/
│       ├── Racket/
│       ├── CardTile/
│       ├── MindSports/
│       ├── IceOutdoor/
│       └── PubParlour/
│
├── Presentation/
│   ├── Coordinators/
│   │   ├── AppCoordinator.swift
│   │   ├── HomeCoordinator.swift
│   │   ├── SessionCoordinator.swift
│   │   └── HistoryCoordinator.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   ├── Sports/
│   │   ├── SportListView.swift
│   │   └── SportListViewModel.swift
│   ├── Session/
│   │   ├── SessionSetupView.swift
│   │   ├── SessionSetupViewModel.swift
│   │   ├── LiveScoreView.swift
│   │   ├── LiveScoreViewModel.swift
│   │   └── ScoreEntryViews/           Per-sport entry UI components
│   ├── History/
│   │   ├── HistoryView.swift
│   │   ├── HistoryViewModel.swift
│   │   ├── SessionDetailView.swift
│   │   └── SessionDetailViewModel.swift
│   ├── Players/
│   │   ├── PlayersView.swift
│   │   └── PlayersViewModel.swift
│   └── Stats/
│       ├── StatsView.swift
│       └── StatsViewModel.swift
│
├── TV/                                Apple TV presentation layer (shares Domain/Data/Core/view models)
│   ├── App/                           ScoreCapTVApp, TVAppCoordinator + TVRootView (tabs)
│   └── Presentation/
│       ├── Components/                TVTheme (tokens), TVGrid (eager grid), TVNumberPadView
│       ├── Home/                      Play tab: Your Games, Home Game Night, Sports
│       ├── HomeGames/                 Custom game editor, CustomGamesViewModel
│       ├── Session/                   Setup, full-screen scoreboard, per-sport entry views
│       ├── Plans/  History/  Players/  Stats/  Premium/
│
├── TVUITests/                         Siri Remote UI tests for every Apple TV screen and pop-up
│
└── WidgetExtension/
    ├── ScoreCapWidget.swift
    ├── ScoreTimelineProvider.swift
    ├── WidgetViews/
    │   ├── SmallScoreWidget.swift
    │   ├── MediumScoreWidget.swift
    │   ├── LargeScoreWidget.swift
    │   └── LockScreenWidget.swift
    └── Intents/
        ├── IncrementScoreIntent.swift
        └── SelectSessionIntent.swift
```

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                 Presentation Layer               │
│  Coordinators → ViewModels (@Observable) → Views│
└────────────────────┬────────────────────────────┘
                     │ calls
┌────────────────────▼────────────────────────────┐
│                  Domain Layer                    │
│  Use Cases → Repository Protocols → Engines      │
└────────────────────┬────────────────────────────┘
                     │ implements
┌────────────────────▼────────────────────────────┐
│                   Data Layer                     │
│  SwiftData Models → Repository Impls → SharedStore│
└─────────────────────────────────────────────────┘
```

**Rules:**
- Domain layer has zero imports of SwiftData, SwiftUI, or UIKit.
- Data layer depends on Domain (implements its protocols), never the reverse.
- Presentation depends on Domain use cases only — never on Data directly.
- Engines are pure functions: `(session, newEntry) → ScoringResult`. No side effects.

---

## 3. Coordinator Pattern

### Base Protocol

```swift
// Domain-agnostic coordinator contract
@MainActor
protocol Coordinator: AnyObject {
    var navigationPath: NavigationPath { get set }
    func start()
}
```

### Navigation Destinations

Each coordinator owns a `Route` enum:

```swift
enum SessionRoute: Hashable {
    case setup(SportType)
    case live(sessionID: UUID)
    case result(sessionID: UUID)
}

enum HomeRoute: Hashable {
    case sportList
    case players
    case history
    case stats
}
```

### Coordinator Implementation

```swift
@Observable
@MainActor
final class SessionCoordinator: Coordinator {
    var navigationPath = NavigationPath()
    private let container: AppContainer

    func start() { push(.setup(.darts)) }

    func push(_ route: SessionRoute) {
        navigationPath.append(route)
    }

    func pop() {
        navigationPath.removeLast()
    }

    @ViewBuilder
    func view(for route: SessionRoute) -> some View {
        switch route {
        case .setup(let sport):
            SessionSetupView(
                viewModel: SessionSetupViewModel(
                    sport: sport,
                    startSession: container.startSessionUseCase
                ),
                coordinator: self
            )
        case .live(let id):
            LiveScoreView(
                viewModel: LiveScoreViewModel(
                    sessionID: id,
                    addEntry: container.addScoreEntryUseCase,
                    computeScore: container.computeScoreUseCase,
                    undo: container.undoLastEntryUseCase
                ),
                coordinator: self
            )
        case .result(let id):
            SessionResultView(sessionID: id)
        }
    }
}
```

### Root NavigationStack wiring

```swift
struct SessionRootView: View {
    @State var coordinator: SessionCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            coordinator.view(for: .setup(.darts))
                .navigationDestination(for: SessionRoute.self) { route in
                    coordinator.view(for: route)
                }
        }
    }
}
```

### AppContainer — Dependency Injection Root

```swift
@MainActor
final class AppContainer {
    // Persistence
    let modelContainer: ModelContainer = PersistenceContainer.make()

    // Repositories (lazy singletons)
    lazy var playerRepo: PlayerRepository =
        PlayerRepositoryImpl(container: modelContainer)
    lazy var sessionRepo: SessionRepository =
        SessionRepositoryImpl(container: modelContainer)
    lazy var scoreRepo: ScoreRepository =
        ScoreRepositoryImpl(container: modelContainer)

    // Use Cases (new instance per call is fine — they are stateless)
    var startSessionUseCase: StartSessionUseCase {
        StartSessionUseCase(sessionRepo: sessionRepo)
    }
    var addScoreEntryUseCase: AddScoreEntryUseCase {
        AddScoreEntryUseCase(scoreRepo: scoreRepo)
    }
    var computeScoreUseCase: ComputeScoreUseCase {
        ComputeScoreUseCase(engineFactory: ScoringEngineFactory())
    }
    var undoLastEntryUseCase: UndoLastEntryUseCase {
        UndoLastEntryUseCase(scoreRepo: scoreRepo)
    }
    var fetchPlayersUseCase: FetchPlayersUseCase {
        FetchPlayersUseCase(playerRepo: playerRepo)
    }

    // Coordinators
    lazy var appCoordinator = AppCoordinator(container: self)
}
```

---

## 4. Data Layer — SwiftData Models

```swift
import SwiftData
import Foundation

// MARK: - Player

@Model
final class PlayerModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var avatarData: Data?
    var createdAt: Date
    @Relationship(deleteRule: .nullify) var sessions: [GameSessionModel]

    init(id: UUID = .init(), name: String) {
        self.id = id
        self.name = name
        self.createdAt = .now
        self.sessions = []
    }
}

// MARK: - GameSession

@Model
final class GameSessionModel {
    @Attribute(.unique) var id: UUID
    var sportRawValue: String          // SportType.rawValue
    var variant: String?
    var startedAt: Date
    var endedAt: Date?
    var isActive: Bool
    var metadataJSON: Data?            // sport-specific config
    @Relationship(deleteRule: .cascade) var frames: [ScoreFrameModel]
    @Relationship(deleteRule: .nullify) var players: [PlayerModel]
    var winnerID: UUID?

    init(id: UUID = .init(), sport: SportType, variant: String? = nil) {
        self.id = id
        self.sportRawValue = sport.rawValue
        self.variant = variant
        self.startedAt = .now
        self.isActive = true
        self.frames = []
        self.players = []
    }
}

// MARK: - ScoreFrame

@Model
final class ScoreFrameModel {
    @Attribute(.unique) var id: UUID
    var frameIndex: Int
    var playerID: UUID
    var subtotal: Int
    var timestamp: Date
    @Relationship(deleteRule: .cascade) var entries: [ScoreEntryModel]
    @Relationship(deleteRule: .nullify) var session: GameSessionModel?

    init(id: UUID = .init(), frameIndex: Int, playerID: UUID) {
        self.id = id
        self.frameIndex = frameIndex
        self.playerID = playerID
        self.subtotal = 0
        self.timestamp = .now
        self.entries = []
    }
}

// MARK: - ScoreEntry

@Model
final class ScoreEntryModel {
    @Attribute(.unique) var id: UUID
    var value: Int
    var label: String?
    var metadataJSON: Data?            // per-throw detail (e.g. dart segment)
    var timestamp: Date
    @Relationship(deleteRule: .nullify) var frame: ScoreFrameModel?

    init(id: UUID = .init(), value: Int, label: String? = nil) {
        self.id = id
        self.value = value
        self.label = label
        self.timestamp = .now
    }
}
```

### Persistence Container

```swift
enum PersistenceContainer {
    static func make() -> ModelContainer {
        let schema = Schema([
            PlayerModel.self,
            GameSessionModel.self,
            ScoreFrameModel.self,
            ScoreEntryModel.self
        ])
        let config = ModelConfiguration(
            "SportScore",
            schema: schema,
            groupContainer: .identifier("group.com.yourapp.sportscore"), // App Group for widget
            cloudKitDatabase: .automatic                                   // optional iCloud sync
        )
        return try! ModelContainer(for: schema, configurations: [config])
    }
}
```

---

## 5. Domain Layer — Entities & Use Cases

### Entities (pure Swift, no framework imports)

```swift
struct Player: Identifiable, Hashable {
    let id: UUID
    var name: String
    var avatarData: Data?
}

struct GameSession: Identifiable {
    let id: UUID
    let sport: SportType
    var variant: String?
    var players: [Player]
    var frames: [ScoreFrame]
    var isActive: Bool
    var startedAt: Date
    var endedAt: Date?
    var winnerID: UUID?
}

struct ScoreFrame: Identifiable {
    let id: UUID
    let playerID: UUID
    let frameIndex: Int
    var entries: [ScoreEntry]
    var subtotal: Int
}

struct ScoreEntry: Identifiable {
    let id: UUID
    let value: Int
    var label: String?
    var metadata: [String: AnyCodable]?
}
```

### Repository Protocols

```swift
protocol PlayerRepository {
    func fetchAll() async throws -> [Player]
    func save(_ player: Player) async throws
    func delete(id: UUID) async throws
}

protocol SessionRepository {
    func fetchAll() async throws -> [GameSession]
    func fetchActive() async throws -> [GameSession]
    func save(_ session: GameSession) async throws
    func delete(id: UUID) async throws
}

protocol ScoreRepository {
    func addEntry(_ entry: ScoreEntry, toFrameID: UUID) async throws
    func undoLastEntry(inSessionID: UUID, forPlayerID: UUID) async throws -> ScoreEntry?
    func fetchFrames(forSessionID: UUID) async throws -> [ScoreFrame]
}
```

### Use Cases

```swift
// Start Session
struct StartSessionUseCase {
    let sessionRepo: SessionRepository

    func execute(sport: SportType, variant: String?, players: [Player]) async throws -> GameSession {
        let session = GameSession(
            id: UUID(), sport: sport, variant: variant,
            players: players, frames: [], isActive: true, startedAt: .now
        )
        try await sessionRepo.save(session)
        return session
    }
}

// Add Score Entry
struct AddScoreEntryUseCase {
    let scoreRepo: ScoreRepository

    func execute(entry: ScoreEntry, frameID: UUID) async throws {
        try await scoreRepo.addEntry(entry, toFrameID: frameID)
    }
}

// Compute Score (pure, no async needed)
struct ComputeScoreUseCase {
    let engineFactory: ScoringEngineFactory

    func execute(session: GameSession, newEntry: ScoreEntry) -> ScoringResult {
        let engine = engineFactory.engine(for: session.sport, variant: session.variant)
        return engine.process(entry: newEntry, in: session)
    }
}

// Undo
struct UndoLastEntryUseCase {
    let scoreRepo: ScoreRepository

    func execute(sessionID: UUID, playerID: UUID) async throws -> ScoreEntry? {
        try await scoreRepo.undoLastEntry(inSessionID: sessionID, forPlayerID: playerID)
    }
}
```

---

## 6. Presentation Layer — ViewModels & Views

### ViewModel convention

All ViewModels use `@Observable` (Swift 5.9+ macro, iOS 17+).  
No `@Published`, no `ObservableObject`.

```swift
@Observable
@MainActor
final class LiveScoreViewModel {
    // State
    var session: GameSession
    var currentScores: [UUID: DisplayScore] = [:]
    var isGameOver: Bool = false
    var winner: Player?
    var errorMessage: String?

    // Dependencies (use cases, injected)
    private let addEntry: AddScoreEntryUseCase
    private let computeScore: ComputeScoreUseCase
    private let undo: UndoLastEntryUseCase

    init(sessionID: UUID, ...) { ... }

    func submitEntry(_ entry: ScoreEntry, forPlayer player: Player) async {
        let result = computeScore.execute(session: session, newEntry: entry)
        guard !result.isBust else {
            Haptics.error()
            return
        }
        try? await addEntry.execute(entry: entry, frameID: currentFrameID(for: player))
        currentScores[player.id] = result.displayScore
        isGameOver = result.isGameOver
        winner = result.winner.flatMap { id in session.players.first { $0.id == id } }
        Haptics.impact(.medium)
    }

    func undoLast(for player: Player) async {
        _ = try? await undo.execute(sessionID: session.id, playerID: player.id)
        // recompute scores from frames
    }
}
```

### View convention

Views are **dumb**: they bind to ViewModel state and call ViewModel methods.  
Coordinators are passed via the environment or initializer for navigation.

```swift
struct LiveScoreView: View {
    @State var viewModel: LiveScoreViewModel
    var coordinator: SessionCoordinator

    var body: some View {
        ZStack {
            scoreBoard
            entryPanel
        }
        .onChange(of: viewModel.isGameOver) { _, over in
            if over { coordinator.push(.result(sessionID: viewModel.session.id)) }
        }
    }
}
```

---

## 7. Sport Scoring Engines

### Protocol

```swift
struct ScoringResult {
    var displayScore: DisplayScore
    var isBust: Bool
    var isGameOver: Bool
    var winner: UUID?
    var turnAdvances: Bool
    var notes: String?
}

struct DisplayScore {
    var primary: String       // e.g. "320" or "3-2" or "40-30"
    var secondary: String?    // e.g. "Leg 2 of 3"
    var detail: String?       // e.g. "Highest break: 87"
}

protocol ScoringEngine {
    var sport: SportType { get }
    func process(entry: ScoreEntry, in session: GameSession) -> ScoringResult
    func isGameOver(_ session: GameSession) -> Bool
    func currentScore(for playerID: UUID, in session: GameSession) -> DisplayScore
}

final class ScoringEngineFactory {
    func engine(for sport: SportType, variant: String?) -> any ScoringEngine {
        switch sport {
        case .darts:   return DartsScoringEngine(variant: variant ?? "501")
        case .snooker: return SnookerScoringEngine()
        case .tennis:  return TennisScoringEngine()
        case .bowlingTenPin: return TenPinBowlingScoringEngine()
        // ... all sports
        }
    }
}
```

---

### Category: Precision & Aiming

#### Darts (`DartsScoringEngine`)
- **Variants**: `501`, `301`, `701`, `Cricket`, `AroundTheClock`, `Shanghai`
- **501/301**:
  - Each player starts at variant value (501, 301)
  - 3 throws per turn; each throw: `segment (1–20, Bull)` × `multiplier (1=single, 2=double, 3=treble)`
  - Running score = start − cumulative hits
  - **Bust**: if score would go below 0, or land on 1, or land on 0 without a double — revert entire turn
  - **Win**: reach exactly 0 with a double (double-out rule, togglable)
  - Track: turn count, checkout suggestions (optional)
- **Cricket**:
  - Numbers in play: 15, 16, 17, 18, 19, 20, Bull
  - Mark a number: 1 hit = 1 mark, 3 marks = closed
  - Once closed by one player: opponent hitting that number scores face value per mark above 3
  - Win: all numbers closed AND equal or higher total score
- **Entry UI**: Segmented dartboard (SVG tap target) or number + multiplier keypad

#### Archery (`ArcheryScoringEngine`)
- Arrow values: Miss(M)=0, 1–10, X=10 (inner gold, tiebreak only)
- 6 arrows per end, configurable ends per round
- Score per end = sum of arrows; running total
- X count tracked separately for tiebreaking
- **Entry UI**: Concentric ring tap target

#### Sport Shooting (`SportShootingScoringEngine`)
- Integer (0–10) or decimal (e.g. 9.8) mode toggle
- 10 shots per series, configurable series count
- Running total; personal best detection
- Penalty per ruleset (configurable deduction)

#### Axe Throwing (`AxeThrowingScoringEngine`)
- **Zones** (WATL default): Bullseye=6, rings=4/3/2/1, Clutch=7
- 5 throws per match, best-of-X matches
- Killshot (optional per org): if declared before throw and hit, override score
- Entry UI: Axe target tap zones

#### Knife Throwing, Slingshot, Blowgun
- Shared `ZoneBasedScoringEngine` with configurable zone values and throw count
- Running total per round; match to configurable point target

---

### Category: Cue Sports

#### Snooker (`SnookerScoringEngine`)
- Ball values: Red=1, Yellow=2, Green=3, Brown=4, Blue=5, Pink=6, Black=7
- Sequence: alternating Red + colour until reds exhausted, then Yellow→Black
- Foul: min 4 pts (or value of ball if higher) awarded to opponent
- **Highest break** tracked per frame
- Frame won when opponent concedes or cannot win mathematically
- Match: best-of-X frames

#### Pool / Billiards (`PoolScoringEngine`)
- **Variants**: `8Ball`, `9Ball`, `10Ball`, `StraightPool`, `OnePocket`
- 8-ball: track solids/stripes assignment; foul rules; 8-ball win/scratch loss
- 9-ball: legal pocket of 9-ball wins; combo/carom allowed
- Straight Pool: count pocketed balls; rack at 1 remaining; match to 150
- Score: game/rack wins; best-of-X series

#### Carom Billiards / Cushion Caroms (`CaromScoringEngine`)
- Count caroms per inning (no pockets)
- 3-Cushion: cue ball must contact 3+ cushions before 2nd object ball
- Match: first to target (e.g. 40); track running average (score ÷ innings)

---

### Category: Bowling Variations

#### Ten-Pin Bowling (`TenPinBowlingScoringEngine`)
- 10 frames; frames 1–9: up to 2 balls; frame 10: up to 3 balls
- **Strike** (X): all 10 first ball → bonus = next 2 balls
- **Spare** (/): remaining pins on 2nd ball → bonus = next 1 ball
- Frame 10: if strike on 1st → 2 more balls; if spare on 2nd → 1 more ball
- Perfect game = 300; detect and celebrate
- Entry UI: tap-to-mark pin diagram (10 pins) or numeric entry

#### Candlepin Bowling (`CandlepinScoringEngine`)
- 3 balls per frame; fallen pins remain on lane (not reset mid-frame)
- No strike/spare bonus — pure pin count per frame
- Max theoretical score: 300

#### Duckpin Bowling (`DuckpinScoringEngine`)
- 3 balls per frame; small rubber-edged ball
- Strike and spare bonuses apply (same math as ten-pin)
- Entry UI: 10-pin tap diagram

#### Nine-Pin Bowling (`NinePinScoringEngine`)
- 2 balls per turn; 9 pins in diamond
- Kingpin (center): knocking with first ball = 9 points; rest of pins = face count
- Team scoring: sum across all players per lane

#### Bocce Ball / Pétanque / Boules (`BocceScoringEngine`)
- **End-based**: after all balls thrown, team closest to pallino/jack scores 1 pt per ball closer than opponent's nearest ball
- Cancellation scoring: only one team scores per end
- Match: first to 13 (bocce/pétanque), configurable
- Optional: notes field to record end outcomes

#### Lawn Bowls (`LawnBowlsScoringEngine`)
- 4 woods per player per end
- Shot count: count bowls closer to jack than opponent's nearest
- Match: configurable ends or points target

#### Skittles (`SkittlesScoringEngine`)
- 9 pins; configurable throws per turn
- Running pin count; legs/round structure

---

### Category: Racket Sports (1v1)

#### Tennis (`TennisScoringEngine`)
- **Point state machine**: 0→15→30→40→Deuce→Advantage→Game
- Deuce: both at 40; Advantage: one point ahead; Game: win from Advantage
- **Set**: first to 6 games, must win by 2; tiebreak at 6-6
- **Tiebreak**: first to 7 pts (win by 2); 10-pt match tiebreak option (configurable)
- **Match**: best of 3 or best of 5 sets (configurable)
- Score display: `"40-30 | 5-4 | 1-0"` (points - games - sets)

#### Padel (`PadelScoringEngine`)
- Identical scoring to Tennis
- Doubles: both players on team share the game-level score entry
- Golden Point option at deuce (no-ad, configurable)

#### Table Tennis (`TableTennisScoringEngine`)
- Rally scoring: any server can score
- Game: first to 11, win by 2; deuce at 10-10 (alternate serves)
- Match: best of 3, 5, or 7 games (configurable)
- Serve: switches every 2 points (every 1 point in deuce)

#### Badminton (`BadmintonScoringEngine`)
- Rally scoring: first to 21, win by 2; cap at 30
- Match: best of 3 games
- Singles or doubles player count (affects serve rotation tracking)

#### Squash (`SquashScoringEngine`)
- **PAR (modern)**: rally scoring, first to 11, win by 2
- **HiHo (classic)**: serve-only scoring, first to 9
- Toggle in session config
- Match: best of 5

#### Racquetball (`RacquetballScoringEngine`)
- Serve-only scoring; first to 15 (games 1–2), tiebreak to 11
- Match: best of 3

#### Pickleball (`PickleballScoringEngine`)
- **Doubles serve sequence**: server 1 → server 2 → side-out; score announced as `"serving-receiving-server#"`
- **Singles**: standard side-out scoring
- Traditional: serve-only; Rally: configurable toggle
- First to 11 (win by 2); match best of 3

---

### Category: Card & Tile

#### Dominoes (`DominoesScoringEngine`)
- **Variants**: `Draw`, `Block`, `MexicanTrain`, `AllFives`
- Round score: sum of pips in all opponents' hands awarded to winner
- All-Fives: score multiples of 5 from open ends after each play
- Match: first to configurable total (e.g. 150)

#### Mahjong (`MahjongScoringEngine`)
- **Variants**: `Chinese` (Fan/Points), `Japanese` (Han/Fu), `American`
- Hand value: base points × 2^doublings (Chinese); Han × Fu table (Japanese)
- Per hand: dealer rotation (East→South→West→North→East), seat winds tracked
- Track: running game score per player, dealer status, bonus tiles (flowers/seasons)

#### Cribbage (`CribbageScoringEngine`)
- **Pegging board**: visual representation 0–121 (go to 121 wins)
- **Peg advancement** per scoring event
- Hand score = 15s (2 pts each) + pairs (2) + triplets (6) + quads (12) + runs + flush (4 or 5) + nobs (1) + nibs (2)
- Crib: alternating dealer; dealer scores crib hand
- Muggins: optional — opponent claims missed points

#### Poker Tournament (`PokerTournamentEngine`)
- Per-player: chip stack (configurable starting stack)
- Blind levels: ante/small blind/big blind with timer per level
- Rebuy/add-on events recorded
- Elimination order tracked (1st out = lowest rank)
- No card simulation; manual stack entry

---

### Category: Mind Sports

#### Chess (`ChessScoringEngine`)
- Result per game: Win=1pt, Draw=0.5pt, Loss=0pt
- Match: cumulative points over N games
- Time format selector: Bullet(1+0), Blitz(3+2/5+0), Rapid(10+0/15+10), Classical
- Optional: basic ELO delta from stored ratings

#### Checkers (`CheckersScoringEngine`)
- Pieces captured: running count per player
- Win condition: opponent has no legal moves or no pieces
- **Variants**: Standard (8×8), International (10×10), Canadian (12×12)

#### Go (`GoScoringEngine`)
- Board sizes: 9×9, 13×13, 19×19
- Capture count per player (running)
- Final score: territory + prisoners + komi (default 6.5, configurable)
- Handicap stones: 0–9

#### Backgammon (`BackgammonScoringEngine`)
- Per game: Normal=1pt, Gammon=2pt, Backgammon=3pt
- Doubling cube: current value (1/2/4/8…64) + owner tracked
- Crawford rule toggle
- Match: first to X points (configurable)

#### Scrabble (`ScrabbleScoringEngine`)
- Per-word play: tile face values + premium square multipliers
- Premium grid: standard board or custom configurable
- Bingo bonus: +50 for all 7 tiles played
- Running total per player
- Challenge flag per word (marks invalid, no auto-removal)

---

### Category: Ice & Outdoor

#### Curling (`CurlingScoringEngine`)
- End-by-end scoring: team with closest stone(s) to centre scores 1pt per stone ahead of opponent's best
- Blank end: no score, hammer retained by same team
- Hammer: awarded to team that did not score (or as set in config for first end)
- Match: 8 or 10 ends (configurable); concession button

#### Horseshoes (`HorseshoesScoringEngine`)
- **Ringer**: 3 pts; **Leaner**: 1 pt (configurable per org)
- Cancellation scoring: subtract opponent's matching score
- Match: first to 21 or 40 (configurable)

#### Cornhole (`CornholeScoringEngine`)
- Hole = 3 pts; Board = 1 pt per bag
- Cancellation: subtract lower from higher each round, net score added
- Match: first to exactly 21 (configurable bust rule: bust → revert to pre-round score, or no bust)

#### Ring Toss (`RingTossScoringEngine`)
- Peg values: configurable (e.g. centre=5, outer rings=3/1)
- Throws per round: configurable
- Running total to match target

#### Disc Golf (`DiscGolfScoringEngine`)
- Hole-by-hole stroke count; par per hole stored in course config
- Score: strokes relative to par (+2=double bogey, −1=birdie, etc.)
- Course library: save courses with hole count + par per hole
- Running cumulative score per player

#### Kubb (`KubbScoringEngine`)
- Per-round: count field kubbs toppled, baseline kubbs re-stacked
- King hit: instant win — flag event
- Round log only (no numeric running score; win-condition driven)

#### Croquet (`CroquetScoringEngine`)
- **Standard (Association)**: hoops per player (1–12 sequence), peg-out wins
- **Golf Croquet**: first player through each hoop scores 1 pt; first to 7 wins

#### Shuffleboard (`ShuffleboardScoringEngine`)
- Puck zones: 1, 2, 3 pts (or configurable)
- Cancellation scoring per round
- Match: first to 15 or 21 (configurable)

---

### Category: Game Room

#### Air Hockey (`AirHockeyScoringEngine`)
- Goal increment per player; first to 7 (configurable)
- Best-of series: track frame wins

#### Foosball (`FoosballScoringEngine`)
- Goal increment; first to 5 or 10 (configurable)
- Best-of series; team (2v2) or solo mode

#### Pinball (`PinballScoringEngine`)
- Machine score: large integer entry (up to 10 digits)
- Machine library: save machine names
- Per-machine high score board (local)
- Tournament mode: rank N plays per machine; cumulative or ranked scoring

#### Arm Wrestling (`ArmWrestlingScoringEngine`)
- Per pull: win/loss for each player
- Left arm and right arm tracked independently
- Best of X pulls; match result: aggregate wins per arm

---

## 8. Widget Extension

### App Group Container (shared between app and widget)

```
App Group ID: group.com.yourapp.sportscore
```

Both the main app and widget extension use `PersistenceContainer.make()` which includes the App Group `ModelConfiguration`. This allows the widget to read live session data without XPC.

### Widget Sizes & Content

| Size | Content |
|---|---|
| `.systemSmall` | Sport icon + 2 player names + current scores |
| `.systemMedium` | Scoreboard with last 3 score entries |
| `.systemLarge` | Full session: all players, per-frame history |
| `.accessoryCircular` | Score total (lock screen / Dynamic Island) |
| `.accessoryRectangular` | Player names + scores (lock screen) |

### TimelineProvider

```swift
struct ScoreTimelineProvider: TimelineProvider {
    typealias Entry = ScoreWidgetEntry

    func placeholder(in context: Context) -> ScoreWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (ScoreWidgetEntry) -> Void) {
        completion(SharedStore.shared.latestEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<ScoreWidgetEntry>) -> Void) {
        let entry = SharedStore.shared.latestEntry() ?? .placeholder
        // Refresh every 5 minutes; live game triggers WidgetCenter.shared.reloadAllTimelines()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
```

### Interactive Widget — App Intent

```swift
struct IncrementScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Point"

    @Parameter(title: "Session") var sessionID: String
    @Parameter(title: "Player") var playerID: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = SharedStore.shared
        store.incrementScore(sessionID: sessionID, playerID: playerID)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
```

### Widget View Example

```swift
struct MediumScoreWidgetView: View {
    let entry: ScoreWidgetEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Label(entry.sportName, systemImage: entry.sportIcon)
                    .font(.caption)
                ForEach(entry.playerScores) { ps in
                    HStack {
                        Text(ps.playerName).font(.headline)
                        Spacer()
                        Text(ps.scoreDisplay).font(.title2.bold())
                        Button(intent: IncrementScoreIntent(
                            sessionID: entry.sessionID,
                            playerID: ps.playerID)
                        ) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .containerBackground(.regularMaterial, for: .widget)
    }
}
```

### Trigger widget refresh from app

```swift
// Call this every time a score changes in the main app
WidgetCenter.shared.reloadAllTimelines()
```

### Live Activities (Dynamic Island)

```swift
struct ScoreActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var scores: [String: String]   // playerName: scoreDisplay
        var sport: String
        var lastEvent: String
    }
    var sessionID: UUID
}

// Start on session begin:
let activity = try Activity.request(
    attributes: ScoreActivityAttributes(sessionID: session.id),
    contentState: .init(scores: [:], sport: session.sport.displayName, lastEvent: "Game started")
)

// Update on every score change:
await activity.update(using: newContentState)

// End on session finish:
await activity.end(dismissalPolicy: .immediate)
```

---

## 9. iOS 26 Specific Features

### Liquid Glass Design

```swift
// Apply to score cards and overlay panels
.glassEffect()

// Tinted glass for team colors
.glassEffect(Glass().tint(teamColor))
```

### @Observable (Swift 5.9+ / iOS 17+, standard by iOS 26)

```swift
@Observable
final class LiveScoreViewModel { ... }

// In View — no @ObservedObject or @StateObject needed:
@State private var viewModel = LiveScoreViewModel(...)
```

### SwiftData `#Predicate` (compile-time safe)

```swift
let activeSessions = try modelContext.fetch(
    FetchDescriptor<GameSessionModel>(
        predicate: #Predicate { $0.isActive == true },
        sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
    )
)
```

### Typed throws (Swift 6)

```swift
enum RepositoryError: Error { case notFound, saveFailed }

func fetchAll() async throws(RepositoryError) -> [Player] { ... }
```

### NavigationStack with typed routes (fully supported)

```swift
NavigationStack(path: $coordinator.navigationPath) {
    rootView
        .navigationDestination(for: SessionRoute.self) { route in
            coordinator.view(for: route)
        }
        .navigationDestination(for: HomeRoute.self) { route in
            coordinator.view(for: route)
        }
}
```

---

## 10. Feature Requirements by Sport

### Global Features (all sports)

| # | Requirement |
|---|---|
| F-01 | Create a named player profile (name + optional avatar) |
| F-02 | Start a session: select sport → variant → players → optional config |
| F-03 | Live scoring UI with sport-specific entry component |
| F-04 | Undo last score entry per player |
| F-05 | Turn/serve rotation enforced by engine |
| F-06 | Win/game-over detection with winner announcement |
| F-07 | End session early with manual winner selection |
| F-08 | View session history (all past sessions, filterable by sport) |
| F-09 | Session detail: per-frame, per-player score breakdown |
| F-10 | Player stats: win rate, avg score, sessions played, win streaks |
| F-11 | Match templates: save recurring setups (same players + sport + config) |
| F-12 | Home Screen Widget: live score + interactive +1 button |
| F-13 | Lock Screen Widget: score summary |
| F-14 | Dynamic Island / Live Activity for active session |
| F-15 | Haptic feedback on each score entry, bust, and game-over |
| F-16 | Export session as PDF or sharable image |
| F-17 | All data local by default; optional iCloud sync (CloudKit toggle in Settings) |
| F-18 | No login, no account required |
| F-19 | Dark mode + Dynamic Type fully supported |
| F-20 | iPad layout: sidebar + detail column |
| F-21 | Home games: 38 built-in card, board, party and video games with default rules |
| F-22 | Custom games: name, icon, winner rule (highest / lowest / count down), scoring style (tally / points), target or start score |
| F-23 | Apple TV app: every screen and pop-up fully usable with the Siri Remote (see §11) |

### Sport-Specific Requirements

| Sport | Key Config Options |
|---|---|
| Darts | Variant (501/301/Cricket/…), double-in toggle, double-out toggle |
| Archery | Arrows per end, ends per round, decimal X scoring |
| Sport Shooting | Integer vs decimal scoring, shots per series, series count, penalty value |
| Axe Throwing | Org ruleset (WATL/NATF), killshot toggle, throws per match |
| Knife/Slingshot/Blowgun | Zone values, throws per round, match length |
| Snooker | Frames in match, colour-safe (accessible mode) |
| Pool/Billiards | Variant (8-ball/9-ball/Straight Pool), racks in match |
| Carom/Cushion | Carom target, average display |
| Ten-Pin Bowling | Perfect game celebration, show running total per frame |
| Candlepin / Duckpin | 3-ball mode, pin persistence rule |
| Bocce/Pétanque | Points to win, measurement notes field |
| Disc Golf | Course name, hole count, par per hole |
| Tennis | Best of 3 or 5, no-ad / golden point toggle, match tiebreak |
| Padel | Doubles pair assignment, golden point toggle |
| Table Tennis | Games in match, serve rotation display |
| Badminton | Singles vs doubles, games in match |
| Squash | Scoring mode (PAR/HiHo), games in match |
| Pickleball | Singles vs doubles, scoring mode toggle |
| Dominoes | Variant, points to win |
| Mahjong | Variant (Chinese/Japanese/American), starting points |
| Cribbage | Muggins toggle, visual peg board |
| Poker | Starting stacks, blind level timer, rebuy option |
| Chess | Time format, number of games in match, ELO tracking |
| Checkers | Board size variant |
| Go | Board size, komi value, handicap stones |
| Backgammon | Match length, Crawford rule toggle |
| Scrabble | Premium grid (standard or custom), challenge flag |
| Curling | Number of ends, hammer first-end assignment |
| Horseshoes | Points to win, ringer/leaner values |
| Cornhole | Bust rule toggle, points to win |
| Disc Golf | Course library, per-hole par |
| Shuffleboard | Zone values, points to win |
| Air Hockey | Points to win, best-of series |
| Foosball | Points to win, 1v1 or 2v2 |
| Pinball | Machine library, high score per machine |
| Arm Wrestling | Pulls per match, left/right arm separate tracking |

---

## 11. Apple TV App

Target `ScoreCapTV` ( same bundle ID as iOS for a universal purchase). Only `TV/` is tvOS-specific; Domain, Data, Core and the view models are shared with iOS.

### Screen map

| Tab / screen | What's on it | Pop-ups |
|---|---|---|
| **Play** (home) | Continue banner, Your Games (Create Custom Game + saved games), Home Game Night (4 categories), Sports (8 categories) | Context menu on a tile (hold Select): Play / Edit / Delete for custom games, Customize Rules… for home games; delete confirmation alert |
| Custom game editor | Left: preview tile, Save & Play, Save, Delete Game. Right: name, icon, winner, scoring, target/start pickers | Picker lists, delete confirmation alert |
| Setup | Left: game info, Edit Game / Customize Rules…, Variant picker, Start. Right: players list, Add new player… | New Player alert (text field), Variant menu |
| Scoreboard (full screen) | Header: Undo, End game / Show result. Tally games: one card per player. Turn games: player strip, entry panel, Switch player | End game menu, player card context menu (−1, Add points…, Undo), number pad, Game Over overlay (View Results, Undo last, See scores, Done) |
| Results | Summary + Resume game, match info and final scores | — |
| **Plans** | New Plan, plan cards with a 26-week habit grid | Plan editor sheet, card context menu (Edit / Delete) |
| **History** | Past games, locked row (free tier) | Row context menu (Delete), Paywall sheet |
| **Players** | Add player, player list | New Player alert, row context menu (Delete) |
| **Stats** | Leaderboard (Premium) and per-game lists side by side | Paywall sheet |

### Focus rules (Siri Remote)

The tvOS focus engine only moves to an item that lies in the direction pressed. These rules keep every button reachable:

1. **Two-column screens** (editor, setup, stats, scoreboard panel): each column is a `.focusSection()`, so left/right always lands in the other column even when the buttons sit at the bottom and the list starts at the top.
2. **Grids use `TVGrid`, never `LazyVGrid`**: a lazy grid doesn't create off-screen tiles, so pressing down finds nothing (this blocked the home screen below "Create Custom Game"). Each home section is also a focus section, so up/down works from any column.
3. **Header rows** (scoreboard Undo / End game) are focus sections, so up from the score buttons reaches them.
4. **Overlays drawn by the app** (Game Over) disable the content behind them and focus their main button; the number pad starts on "1" and is opaque.
5. Context menus and `Menu`s are drawn by tvOS, open with their first item focused, and close with Menu.

### Theme

`TVTheme` (`TV/Presentation/Components/TVTheme.swift`) holds the tokens; every colour adapts to the TV's Light/Dark appearance.

| Token | Use |
|---|---|
| `Radius.button` 18 | All bordered / prominent buttons, applied app-wide with `.tvThemed()` (rounded rectangle, never capsule) |
| `Radius.tile` 16 · `panel` 36 · `sheet` 44 | Player chips and score cards · entry panel and score banners · number pad and Game Over |
| `Colors.surface` / `outline` | Inactive tiles, empty habit squares, snooker "free ball" tile |
| `Colors.scoreboardTop/Bottom` | Scoreboard gradient (light blue in light mode, navy in dark mode) |
| `Colors.popup` / `scrim` | Opaque pop-up background / dimming behind overlays |

Game tiles use the system `.card` style; list rows keep the plain system selection (no extra shape). The accent colour comes from the `AccentColor` asset (green).

### UI tests

`TVUITests/` drives the app with `XCUIRemote` like a user: it moves focus with the arrows, asserts what is focused, and opens every alert, sheet, menu and overlay. The app is launched with `--uitesting`, which uses an in-memory database and an empty plans store.

```bash
xcodegen generate
xcodebuild test -project ScoreCap.xcodeproj -scheme ScoreCapTV \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'
# Screenshots of every screen (also attached to the .xcresult):
TEST_RUNNER_SCREENSHOT_DIR=/tmp/scorecap-shots xcodebuild test ... \
  -only-testing:ScoreCapTVUITests/TVScreenshotTests
```

---

## Deployment Target

- **Minimum iOS version**: iOS 26.0
- **Minimum tvOS version**: tvOS 26.0 (Apple TV app)
- **Swift version**: Swift 6 (strict concurrency)
- **Xcode**: Xcode 18+
- **Supported devices**: iPhone (all sizes) + iPad + Apple TV (HD and 4K)
- **Orientations**: Portrait primary; Landscape supported for Live Score view

---

*End of requirements document.*
