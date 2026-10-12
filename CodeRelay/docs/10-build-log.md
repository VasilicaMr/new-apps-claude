# 10 · Build log

The record of how v1.0 was built, step by step.

### Step 1: Research the CLI interface
* Looked at the conventions of the existing repo (xcodegen, `com.adaptiveservices` prefix, Swift 5 mode).
* Read `claude --help` (v2.1.296). Chose headless `-p --input-format stream-json --output-format stream-json`, which gives multi-turn structured I/O with no PTY scraping.
* Captured real stream-json output (`system/init`, `assistant`, `user/tool_result`, `result`, `rate_limit_event`) to design the parser.

### Step 2: Shared package `RelayKit`
* Protocol models and message enums, length-prefixed JSON framing, `FramedConnection` over `NWConnection`.
* Pairing crypto (HKDF code → PSK, random device keys), TLS-PSK `NWParameters`, Keychain wrapper.
* `ClaudeStreamParser` + `ClaudeInput` + `ToolSummarizer`.
* Tests: 14 unit tests, plus 2 TLS loopback integration tests added later. **All pass.**

### Step 3: Mac host
* Domain: entities, repository protocols, `ProjectAccessPolicy`.
* Data: `ClaudeLocator`, `ClaudeProcess`, `RelayServer`, persistence.
* Application: `SessionController`, `HostEngine`.
* Presentation: menu bar extra + Settings (General / Workspaces / Devices).
* `project.yml` added and built. **BUILD SUCCEEDED.**

### Step 4: Protocol refinement
* Moved permission prompts *into the event history* (`ClaudeEvent.permissionRequested`), so a reconnecting phone sees pending prompts. Removed the separate message type.

### Step 5: iOS app
* Domain: entities, protocols, `PairHostUseCase`, `ConnectHostUseCase`, `TranscriptReducer`.
* Data: network connector, Bonjour discovery, Keychain-backed storage, Foundation Models assistant, Demo host.
* Presentation: theme, Hosts, Pairing, Workspace, Session (transcript, permission cards, composer), Settings, Onboarding.
* App icon generated with `tools/make_icon.swift`. **BUILD SUCCEEDED** on the first compile.

### Step 6: Tests & verification
* iOS: 7 tests (reducer + full demo turn). Host: 3 tests (path policy). RelayKit: 16. **26/26 pass.**
* TLS-PSK loopback test proves multi-key server acceptance and wrong-code rejection.
* Launched in the iPhone 17 Pro Max simulator; onboarding and the hosts screen render as designed.

### Step 7: Documentation
* This `docs/` folder and `README.md`.
