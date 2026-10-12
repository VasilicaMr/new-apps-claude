# 02 · Protocol & security

## Transport
* TCP, default port **52734**, advertised via Bonjour as `_coderelay._tcp` with TXT `id=<hostID>`.
* **TLS 1.2 with pre-shared keys** (`TLS_PSK_WITH_AES_128_GCM_SHA256`) via Network.framework. This follows Apple's *"Building a custom peer-to-peer protocol"* sample. See `RelayKit/Security/TLSParameters.swift`.
* Framing: `[UInt32 big-endian length][JSON]`, max 8 MB per frame (`FrameCodec`).

## Pairing
1. On the Mac: **Pair a device** generates a random 6-digit code, valid for **120 s** and **single use**.
2. The host restarts its listener with an extra PSK: identity `coderelay-pairing`, key `HKDF-SHA256(code, salt "CodeRelay-pairing-v1")`.
3. The phone connects with that PSK. A wrong code fails the TLS handshake, which is covered by the `TLSLoopbackTests` integration test.
4. The phone sends `hello(deviceID)` and then `pair`. The host generates a random **256-bit device key**, stores it in the Keychain, and replies `paired(hostID, key)` over the encrypted channel.
5. From then on the phone connects with identity = its `deviceID` and key = the device key, which it stores in its own Keychain.

Revoking a device in Host → Settings → Devices deletes its key and restarts the listener, so that key no longer works.

### Known limitation
A 6-digit code has ~20 bits of entropy. An attacker on the same LAN who records the pairing handshake *during the 2-minute window* could brute-force the code offline. Mitigations: the window is short, codes are single-use, and pairing only runs when you click the button. A future version can switch pairing to a PAKE (e.g. SPAKE2) or to QR-code transfer of a full-entropy key (see roadmap).

## Authorization rules (host)
* Until `hello` names a **paired** device, the only accepted messages are `hello`, `pair`, and `ping`.
* `startSession` is accepted only for folders inside a configured workspace root. Paths are canonicalised and symlinks resolved (`ProjectAccessPolicy`, unit-tested against `..` and symlink escapes).
* The `bypassPermissions` mode needs an explicit confirmation on the phone.

## Messages (`RelayKit/Protocol/Messages.swift`)
Client → Host: `hello, pair, listProjects, listSessions, startSession, attach, prompt, permissionDecision, interrupt, renameSession, closeSession, ping`

Host → Client: `welcome, paired, projects, sessions, sessionStarted, history, event, sessionClosed, error, pong`

`event` carries a normalized `ClaudeEvent`, so the phone never parses CLI internals: `started, userPrompt, textDelta, text, thinking, toolUse, toolResult, permissionRequested, permissionResolved, turnCompleted, notice, processExited`

Bump `relayProtocolVersion` for any breaking change. The host rejects mismatched clients with a clear error.

## How the host talks to Claude Code
Per session the host runs:
```
claude -p --input-format stream-json --output-format stream-json --verbose \
       --include-partial-messages --permission-prompt-tool stdio [--permission-mode …] [--resume <id>]
```
* User prompts go to stdin as `{"type":"user","message":{"role":"user","content":"…"}}`.
* On start the host sends a `control_request` `initialize`.
* Permission prompts arrive as `control_request` / `can_use_tool`. The host answers with a `control_response` `{behavior: allow, updatedInput}` or `{behavior: deny, message}`.
* Interrupt is a `control_request` `interrupt`.
* `ClaudeStreamParser` ignores unknown line types, so newer CLI versions degrade gracefully.
