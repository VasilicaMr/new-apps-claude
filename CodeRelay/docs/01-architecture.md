# 01 · Clean architecture

Both apps follow the same layering. Dependencies point **inwards** only:

```
Presentation (SwiftUI Views + @Observable ViewModels)
        │ depends on
        ▼
Domain (Entities, Repository/Service protocols, Use cases, pure reducers)
        ▲ implemented by
        │
Data (Network, Persistence/Keychain, Apple Intelligence, Demo, Claude process)
        │
App (composition root: the only place that names concrete Data types)
```

**RelayKit** is the *shared kernel*. It holds the wire protocol, which both apps must agree on: message enums, framing, PSK crypto, and the Claude stream-json parser. Domain code imports it for the protocol value types (`SessionSummary`, `ClaudeEvent`, …). That's a deliberate trade-off: the protocol *is* the domain language shared by the two apps.

## iOS app (`CodeRelay/`)
```
App/            CodeRelayApp (entry), AppContainer (DI / composition root)
Domain/
  Entities/     SavedHost, HostEndpoint, DiscoveredHost, ConnectionState, RelayError, TranscriptItem
  Repositories/ HostRepository, DeviceIdentityProviding, HostConnection, HostConnecting,
                HostDiscovering, AIAssistant (+ AIAvailability)
  UseCases/     PairHostUseCase, ConnectHostUseCase, TranscriptReducer (pure state machine)
Data/
  Network/      NetworkHostConnector (TLS-PSK NWConnection), BonjourHostDiscovery (NWBrowser)
  Persistence/  DefaultsHostRepository (+Keychain), KeychainDeviceIdentity
  AI/           FoundationModelsAssistant
  Demo/         DemoHostConnector (fully simulated host)
Presentation/
  Theme/        colors, mono fonts, button styles, cards
  Hosts/        HostsView + HostsViewModel, PairingView
  Workspace/    WorkspaceView + WorkspaceViewModel (owns the live connection), NewSessionView
  Session/      SessionView + SessionViewModel, TranscriptRow, ComposerView
  Settings/, Onboarding/
```

## Mac host (`CodeRelayHost/`)
```
App/            CodeRelayHostApp (MenuBarExtra + Settings), HostContainer
Domain/
  Entities/     PairedDevice, HostSettings, ClaudeInstallation, SessionRecord
  Repositories/ PairedDeviceRepository, HostSettingsRepository, SessionRecordRepository, ClaudeLocating
  UseCases/     ProjectAccessPolicy (which folders a phone may open, with symlink-escape protection)
Data/
  Claude/       ClaudeLocator (finds binary + login-shell PATH), ClaudeProcess (stdin/stdout pipes)
  Server/       RelayServer (NWListener + Bonjour), ClientLink
  Persistence/  UserDefaults + Keychain + Application Support JSON
Application/    HostEngine (orchestrates everything, @Observable for UI), SessionController
Presentation/   MenuBarContentView, HostSettingsView
```

## Rules we follow
* Views never touch the network or storage. They call ViewModel methods.
* ViewModels depend on **protocols** (`HostConnecting`, `AIAssistant`, …) that `AppContainer` injects. This keeps the Demo host and test fakes drop-in.
* Business rules that matter for safety (`ProjectAccessPolicy`, `TranscriptReducer`, frame parsing) are pure and unit-tested.
* Concurrency: the UI and networking run on the main actor or main queue. The traffic is tiny, so this keeps state race-free without locks. The Claude CLI's pipes are read on background threads and hopped to main.

## Regenerating the project
The `.xcodeproj` is generated. Never edit it by hand. Change `project.yml`, then run `xcodegen`.
