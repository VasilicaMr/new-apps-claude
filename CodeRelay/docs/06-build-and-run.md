# 06 · Build & run

## Requirements
* Xcode 26+ (iOS 26 SDK for Foundation Models), and `xcodegen` (`brew install xcodegen`)
* On the Mac that hosts Claude: Claude Code installed and logged in (`claude` works in Terminal)

## Generate the project
```bash
cd CodeRelay
xcodegen
open CodeRelay.xcodeproj
```
Set your **Team** under Signing for the `CodeRelay` and `CodeRelayHost` targets, or set `DEVELOPMENT_TEAM` in `project.yml`.

## Run the host
1. Scheme **CodeRelayHost** → Run. A `>_` icon appears in the menu bar.
2. Allow the macOS "accept incoming network connections" and Local Network prompts.
3. Settings → Workspaces → **Add Folder…** (e.g. `~/Developer`).

## Run the iPhone app
1. Scheme **CodeRelay** → a real iPhone on the same Wi-Fi (the simulator also works for a host on the same Mac).
2. Allow Local Network access. Your Mac appears under *On this network*.
3. Click **Pair a device** on the Mac, type the code on the phone, and you're in.

## Outside your home network
Install **Tailscale** (or any VPN) on both devices. In the iOS app, use **+ → Add by address…** with the Mac's Tailscale name or IP and port `52734`.

## Command-line builds
```bash
xcodebuild -project CodeRelay.xcodeproj -scheme CodeRelayHost -destination 'platform=macOS' build
xcodebuild -project CodeRelay.xcodeproj -scheme CodeRelay -destination 'generic/platform=iOS Simulator' build
```
