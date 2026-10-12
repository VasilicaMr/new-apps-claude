# 00 · Overview

## What it is
CodeRelay lets you drive **Claude Code** (Anthropic's CLI agent) that is installed on **your own Mac** from an iPhone or iPad. The phone is a remote terminal: you type prompts, watch Claude stream its answer and tool calls live, and approve or deny risky actions (edits, shell commands) with a tap.

## Why a companion app is needed
iOS apps can't run the Claude CLI. They also can't reach a Mac's processes directly. So there are two apps:

* **CodeRelay Host** runs in the Mac menu bar. It listens on the local network, starts one `claude -p` process per session in a folder you allowed, and relays its output.
* **CodeRelay** is the iOS app. It discovers the Mac, pairs once with a 6-digit code, and then works as the terminal UI.

Each user uses their own Mac, their own Claude subscription or API key, and their own network. There is **no server, account, or cloud component**.

## Core features (v1.0)
| Feature | Where |
|---|---|
| Bonjour auto-discovery, plus manual `host:port` (LAN IP, Tailscale) | iOS `Data/Network` |
| One-time pairing code, then a per-device 256-bit key over TLS-PSK | RelayKit `Security` |
| Projects limited to "workspace" folders chosen on the Mac | Host `ProjectAccessPolicy` |
| Multiple concurrent sessions, resume after reconnect (history replay) | Host `SessionController` |
| Live streaming text, collapsible tool calls, cost/duration per turn | iOS `Session` |
| Permission cards: Allow / Deny, with 4 permission modes | both |
| Interrupt Claude mid-turn | both |
| Apple Intelligence: refine prompt, explain permission, summarize, follow-up chips, auto-title | iOS `Data/AI` |
| Built-in **Demo Mac** (simulated) for App Review and first-run | iOS `Data/Demo` |

## Naming / trademark note
"Claude" is an Anthropic trademark. The app name is **CodeRelay** on purpose. In store text, use only descriptive wording like "works with Claude Code". The app shows a non-affiliation disclaimer in Settings → About.
