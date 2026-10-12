# 07 · Testing

| Suite | Command | Covers |
|---|---|---|
| RelayKit (16 tests) | `cd Packages/RelayKit && swift test` | framing across chunk boundaries and oversize frames, Codable round-trips, pairing-key derivation, stream-json parser (init, text, tools, deltas, result, permission request, unknown lines), control responses, **real TLS-PSK loopback** (paired key + pairing code accepted, wrong code rejected) |
| iOS (7 tests) | `xcodebuild … -scheme CodeRelay -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test` | `TranscriptReducer` (streaming, tools, permission lifecycle, expiry, cost), full Demo-host turn including a permission round-trip |
| Host (3 tests) | `xcodebuild … -scheme CodeRelayHost -destination 'platform=macOS' test` | `ProjectAccessPolicy`: listing, `..` escape, sibling-prefix trick, symlink escape |

All 26 pass as of the initial build (see `10-build-log.md`).

## Manual end-to-end checklist (do this before each release)
- [ ] Pair a real iPhone with a real Mac (Bonjour).
- [ ] Pair via manual address over Tailscale.
- [ ] Start a session in **Ask me** mode. Ask Claude to create a file, confirm the permission card appears, then Allow and check the file exists.
- [ ] Deny a permission and confirm Claude continues gracefully.
- [ ] Interrupt a long turn.
- [ ] Lock the phone mid-turn, unlock, and confirm the transcript catches up.
- [ ] Quit Claude (Stop in the menu bar), send another prompt, and confirm it resumes the same conversation.
- [ ] Revoke the device on the Mac and confirm the phone can no longer connect.
- [ ] Apple Intelligence features on an eligible device. Confirm they're hidden on an ineligible one.
