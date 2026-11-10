# Game design: from ShadowMatch to Little Physics Trail

ShadowMatch ("Peekaboo Shapes") is a matching game: drag a picture onto its shadow. Little Physics Trail
keeps everything that made it work for small kids and changes the target from "same shape" to
"same idea".

## Kept from ShadowMatch

| ShadowMatch | Little Physics Trail |
|---|---|
| Journey map: winding road, alternating stops, colored regions, floating decorations | `JourneyMapView` is ported directly. Stops are physics ideas and decorations are the stop's emoji items. |
| Fox marker + pulsing ring that *suggests* the next stop; nothing gated | 🦉 owl marker, same rules: the first unfinished stop is suggested and every stop stays open |
| "Next stop: …!" toast after finishing a pack | Same, spoken aloud |
| Pack intro on first visit (`PackFlowView` → `PackIntroView` → game) | `LessonFlowView` → `BigIdeaView` → `SortGameView` |
| Drag from the card stack, drop on a target, item flies in, wrong target shakes | Same mechanics and preference-key frame tracking; tapping a target also works |
| 3/2/1 stars from mistakes, best per pack + running total | `StarRating` + `CompleteStopUseCase`, same thresholds |
| Nubee design system, confetti, parental gate, read aloud | Copied as-is (`DesignSystem/`) |

## Changed for learning

1. **Targets are categories, not one-to-one matches.** Each stop has 2–3 bins ("Sinks / Floats",
   "Solid / Liquid / Gas"). The child has to *reason* ("is a coin heavy for its size?") rather
   than match a shape.
2. **Every correct drop explains why.** The fact card replaces the card stack and is read aloud.
   The game waits for **Next**, so the child sets the pace and the explanation isn't skipped
   by an auto-advance timer (ShadowMatch advances after 1.6 s).
3. **Wrong answers are safe.** The bin shakes, the narrator says "Hmm, try again!", and the item
   returns. There is no penalty except a lower star count, and the child always finishes.
4. **Big Idea card before play.** It gives the headline, a 2–3 sentence explanation, a preview
   of the bins, and a *try at home with a grown-up* experiment, so learning carries on off-screen.
   It can be reopened mid-game with the 💡 button.
5. **Surprise items on purpose.** Each stop includes at least one item that challenges a common
   intuition: the Moon (no light of its own), the ship (heavy but floats), the skateboard (flat
   but rolls), paper on a fridge magnet. See [CURRICULUM.md](CURRICULUM.md).
6. **Placed items collect in their bins**, so by the end the child sees the whole category at once
   (everything that floats, everything that sinks).
7. **One purchase instead of packs.** See *Monetization* below. Sign in with Apple was left out,
   because a single non-consumable needs no account.

## Monetization: free start, one Full Journey purchase

- **Stops 1–3 are free** (floating, magnets, forces). That is a real, complete taste of the game
  and enough for a parent to judge it. The rule lives in `AccessPolicy.standard`.
- **One non-consumable, family-shareable "Full Journey"** (suggested $3.99) unlocks stops 4–8.
  It's simpler than ShadowMatch's per-pack purchases: one decision, one price, one restore.
- **Kids-category guard-rails** (App Review 1.3 and 3.1, carried over from ShadowMatch):
  - Locked stops are greyed out with a lock. Tapping one opens the parental gate and then a
    grown-up facing page that lists what's included, the price, and Restore Purchases.
  - The owl and the "Next stop" toast **never point at a locked stop**. Once the free stops are
    done, the trail goes quiet instead of nudging.
  - The trail shows no prices or "buy" wording. Those appear only behind the gate.
  - The grown-ups hub shows the purchase status and links to the same page.
- Ask to Buy is handled: a pending purchase shows "Waiting for approval", and the trail unlocks
  by itself once a parent approves (`Transaction.updates`).

## Art

All item art is system emoji, so no asset pipeline is needed and new content is a few lines of
Swift. The only generated image is the app icon (`tools/make_app_icon.py`, same approach as
ShadowMatch's icon script).

## Ideas for later

- A "Try it" mini-simulation per stop (drop items into a SpriteKit water tank, a ramp with friction).
- Mixed-review stop at the end of the trail that pulls items from all stops.
- Difficulty growth like ShadowMatch (2 → 4 targets) by adding a third "it depends" bin for older kids.
