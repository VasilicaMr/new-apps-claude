# CodeRelay

Use **Claude Code running on your own Mac** from your iPhone or iPad over the network, in a terminal-style chat.

```
┌──────────── iPhone / iPad ────────────┐        TLS-PSK / TCP         ┌──────────── Mac ─────────────┐
│ CodeRelay (App Store)                 │  ◄──────────────────────────►│ CodeRelay Host (menu bar)    │
│ • Bonjour discovery / manual address  │   Bonjour _coderelay._tcp    │ • pairing + paired devices   │
│ • terminal transcript, permissions    │   port 52734                 │ • spawns `claude -p` per     │
│ • Apple Intelligence (on-device)      │                              │   session (stream-json)      │
└───────────────────────────────────────┘                              └──────────────────────────────┘
```

| Part | Folder | Platform | Distribution |
|---|---|---|---|
| iOS app | `CodeRelay/` | iOS / iPadOS 26+ | App Store |
| Mac companion | `CodeRelayHost/` | macOS 14+ | Developer ID + notarization (free download) |
| Shared protocol | `Packages/RelayKit/` | both | Swift package |

## Quick start

```bash
cd CodeRelay
xcodegen                     # generates CodeRelay.xcodeproj from project.yml
open CodeRelay.xcodeproj     # run "CodeRelayHost" on the Mac, "CodeRelay" on a phone
```

## Documentation

Each step is documented in `docs/`:

1. [Overview & product](docs/00-overview.md)
2. [Clean architecture](docs/01-architecture.md)
3. [Protocol & security](docs/02-protocol-and-security.md)
4. [Mac host](docs/03-mac-host.md)
5. [iOS app](docs/04-ios-app.md)
6. [Apple Intelligence](docs/05-apple-intelligence.md)
7. [Build & run](docs/06-build-and-run.md)
8. [Testing](docs/07-testing.md)
9. [App Store & release](docs/08-app-store-release.md)
10. [Roadmap & known gaps](docs/09-roadmap.md)
11. [Build log (what was done, step by step)](docs/10-build-log.md)
