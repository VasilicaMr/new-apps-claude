# 03 · Mac host (CodeRelay Host)

A menu-bar-only app (`LSUIElement`). It has no Dock icon.

## Menu bar
* Status: listening port, detected Claude Code version, number of connected devices.
* **Pair a device**: shows the 6-digit code with a countdown.
* Running sessions, each with a Stop button.
* Settings… / Quit.

## Settings window
| Tab | What |
|---|---|
| General | Detected `claude` path, optional custom path, "Launch at login" (`SMAppService`) |
| Workspaces | Folders the phone may open. Each folder and its direct sub-folders appear as projects. |
| Devices | Paired devices, with a Revoke button |

## Finding the Claude CLI (`ClaudeLocator`)
GUI apps get a minimal `PATH`. The locator does three things:
1. Reads `PATH` from a login shell (`zsh -lc`).
2. Adds the common install dirs (`~/.local/bin`, `~/.claude/local`, `/opt/homebrew/bin`, `/usr/local/bin`, `~/.npm-global/bin`).
3. Picks the first executable `claude`, unless a custom path is set.

The resulting environment is passed to every `claude` process, so it can find `git`, `node`, `swift`, and so on.

## Sessions (`SessionController`)
* A session is created with `startSession`. The CLI process starts on the **first prompt**.
* The process stays alive between turns, since stream-json input is multi-turn.
* If the process exits, the next prompt restarts it with `--resume <claudeSessionID>`, so the conversation continues.
* History (up to 1,500 events, with streaming deltas compacted) is kept in memory so a phone can `attach` after a reconnect. Session metadata is saved to `~/Library/Application Support/CodeRelayHost/sessions.json`.

## Why not the Mac App Store?
The host has to start a user-installed binary (`claude`) inside arbitrary user folders. The App Sandbox forbids that. So the host is distributed as a **Developer ID-signed, notarized** download (see `08-app-store-release.md`). Only the iOS app goes through the App Store.
