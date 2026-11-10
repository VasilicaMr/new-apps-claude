# Adding a stop

A stop is pure data, so adding one needs no UI code.

1. **Write the content** in `Packages/PhysicsTrailCore/Sources/TrailData/Content/StopCatalog.swift`:

   ```swift
   static let electricity = JourneyStop(
       id: "electricity",                       // unique, stable (used in saved progress)
       title: "Zap! Electricity",
       emoji: "⚡️",
       theme: .sun,                              // one of StopTheme's cases
       bigIdea: BigIdea(
           headline: "Electricity needs a loop!",
           explanation: "…2–3 short sentences…",
           tryAtHome: "…a safe experiment with a grown-up…"
       ),
       question: "Does it need electricity?",
       bins: [SortBin(id: "plug", title: "Needs power", emoji: "🔌"),
              SortBin(id: "none", title: "No power", emoji: "🪵")],
       items: [
           item("lamp", "Lamp", "🪔", "plug", "…why, in one or two sentences…"),
           // … 10 items in total
       ],
       finishTitle: "Zap! You did it! 🎉"
   )
   ```

2. **Add it to `StopCatalog.all`** at the position you want on the trail.
   Access depends on **position**: the first `AccessPolicy.standard.freeStopCount` (3) stops are free
   and the rest are part of the Full Journey. Inserting a stop before position 4 changes which stops
   are free, so append new stops unless that change is intended. Then update the App Store
   product description and `LittlePhysicsTrail.storekit`.

3. **Run the guard-rails:** `cd Packages/PhysicsTrailCore && swift test`.
   `StopCatalogTests` checks that:
   - stop ids and item ids are unique
   - there are 2–3 bins (more doesn't fit on a phone) and exactly 10 items
   - every item points at a real bin, every bin is used, and every item has a fact
   - no item reuses its bin's emoji (it would be confusing on screen)

4. **Add a section to [CURRICULUM.md](CURRICULUM.md)** with the goal, any surprises, the experiment and a question to ask.

5. **Check it on a phone in portrait.** Long titles shrink to fit, but keep bin titles to about 12 characters.

## Rules of thumb

- Include **one or two surprise items** that challenge a common belief. These teach the most.
- Keep the bins roughly balanced (for example 5/5 or 4/3/3).
- Avoid items whose answer "depends" (see the accuracy rules in [CURRICULUM.md](CURRICULUM.md)).
- Pick emoji that render clearly at small sizes and look the same on all iOS 17 devices.
- Never change an existing stop's `id`: saved stars are keyed by it.
