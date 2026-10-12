# 05 · Apple Intelligence

Yes, CodeRelay uses Apple Intelligence, through the **Foundation Models** framework (iOS 26+). The model runs **on-device**: free, private, and available offline. It complements Claude rather than replacing it. Claude does the coding on the Mac, and the on-device model helps *you* drive it from a small screen.

| Feature | Trigger | Implementation |
|---|---|---|
| **Refine prompt** | ✨ wand in the composer | Rewrites dictated or rough notes into a precise instruction, keeping file names and identifiers |
| **Explain permission** | "Explain" on a permission card | Two sentences on what the tool call does, plus any risk (deleting, network, pushing) |
| **Follow-up suggestions** | Automatically after each turn | `@Generable FollowUpSuggestions` with `.count(3)` guided generation, shown as chips |
| **Auto-title** | After the first turn | `@Generable SessionTitle` → `renameSession` sent to the host |
| **Summarize session** | Session menu | 3–6 bullets in a shareable sheet |

Code: `Data/AI/FoundationModelsAssistant.swift`, behind the `AIAssistant` domain protocol.

## Availability
`SystemLanguageModel.default.availability` is checked on every use:
* `.available` → features are shown.
* `deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady` → features are **hidden**, and Settings shows the reason. The app is fully usable without Apple Intelligence.

## Context-window discipline
The on-device model has a small context window (about 4K tokens). Inputs are clipped to the **last 6,000 characters** of a plain-text transcript (`TranscriptReducer.plainText(limit:)`), and every call uses a fresh `LanguageModelSession`.

## Testing note
Foundation Models needs Apple-silicon hardware with Apple Intelligence turned on. The dev Mac used here is Intel, so AI features show as "unavailable" in its simulator. Test them on a real iPhone 15 Pro or later, or an M-series iPad.
