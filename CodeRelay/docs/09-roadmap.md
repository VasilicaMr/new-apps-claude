# 09 · Roadmap & known gaps

## Must verify before shipping (not verified in the initial build)
1. **End-to-end with a real `claude` process.** The stream-json *output* parsing was checked against real CLI output (v2.1.296). The **permission round-trip over stdio** (`--permission-prompt-tool stdio` + `control_request can_use_tool`) follows the Claude Agent SDK protocol but was not exercised live. Run the manual checklist in `07-testing.md`. If the CLI flag changes, the fix lives in one place: `ClaudeProcess.swift` (arguments) and `ClaudeStreamParser.swift` / `ClaudeInput`.
2. Real-device pairing over Wi-Fi and Tailscale.
3. Apple Intelligence on an eligible device.

## Next features
* **QR pairing**: the Mac shows a QR code with a full-entropy key, which removes the 6-digit brute-force window.
* **Push notifications** when Claude needs permission or finishes while the app is in the background. This needs an APNs relay server or CloudKit-based signalling.
* Live Activity / Dynamic Island showing "Claude is working… 2 permissions pending".
* App Intents / Siri / Shortcuts: "Ask Claude on my Mac to run the tests".
* iPad: `NavigationSplitView` (sessions sidebar plus terminal) and hardware-keyboard shortcuts (⌘↩ send, ⌘. interrupt).
* Image attachments (screenshots → Claude).
* Diff viewer for Edit tool calls.
* StoreKit 2 Pro unlock.
* Raw shell mode (PTY) in addition to Claude sessions.
