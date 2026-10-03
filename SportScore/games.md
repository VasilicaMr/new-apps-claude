# SportScore — Game Catalog

**Total sports**: 49 (Pool cross-listed in Cue Sports and Pub/Parlour — one engine, two categories)  
**Total categories**: 8  
**Engine protocol**: `ScoringEngine` — see `sportscore.md §7`

---

## Index

| # | Sport | Category | `SportType` case | Engine |
|---|---|---|---|---|
| 01 | Darts | Precision & Aiming | `.darts` | `DartsScoringEngine` |
| 02 | Archery | Precision & Aiming | `.archery` | `ArcheryScoringEngine` |
| 03 | Sport Shooting | Precision & Aiming | `.sportShooting` | `SportShootingScoringEngine` |
| 04 | Axe Throwing | Precision & Aiming | `.axeThrowing` | `AxeThrowingScoringEngine` |
| 05 | Knife Throwing | Precision & Aiming | `.knifeThrowing` | `ZoneBasedScoringEngine` |
| 06 | Slingshot | Precision & Aiming | `.slingshot` | `ZoneBasedScoringEngine` |
| 07 | Blowgun | Precision & Aiming | `.blowgun` | `ZoneBasedScoringEngine` |
| 08 | Billiards / Pool | Cue Sports | `.pool` | `PoolScoringEngine` |
| 09 | Snooker | Cue Sports | `.snooker` | `SnookerScoringEngine` |
| 10 | Carom Billiards | Cue Sports | `.caroms` | `CaromScoringEngine` |
| 11 | Cushion Caroms | Cue Sports | `.cushionCaroms` | `CaromScoringEngine` |
| 12 | Ten-Pin Bowling | Bowling | `.bowlingTenPin` | `TenPinBowlingScoringEngine` |
| 13 | Nine-Pin Bowling | Bowling | `.bowlingNinePin` | `NinePinScoringEngine` |
| 14 | Candlepin Bowling | Bowling | `.bowlingCandlepin` | `CandlepinScoringEngine` |
| 15 | Duckpin Bowling | Bowling | `.bowlingDuckpin` | `DuckpinScoringEngine` |
| 16 | Bocce Ball | Bowling | `.bocce` | `BocceScoringEngine` |
| 17 | Pétanque | Bowling | `.petanque` | `BocceScoringEngine` |
| 18 | Boules | Bowling | `.boules` | `BocceScoringEngine` |
| 19 | Lawn Bowls | Bowling | `.lawnBowls` | `LawnBowlsScoringEngine` |
| 20 | Skittles | Bowling | `.skittles` | `SkittlesScoringEngine` |
| 21 | Table Tennis | Racket | `.tableTennis` | `TableTennisScoringEngine` |
| 22 | Badminton | Racket | `.badminton` | `BadmintonScoringEngine` |
| 23 | Squash | Racket | `.squash` | `SquashScoringEngine` |
| 24 | Racquetball | Racket | `.racquetball` | `RacquetballScoringEngine` |
| 25 | Tennis | Racket | `.tennis` | `TennisScoringEngine` |
| 26 | Padel | Racket | `.padel` | `PadelScoringEngine` |
| 27 | Pickleball | Racket | `.pickleball` | `PickleballScoringEngine` |
| 28 | Dominoes | Card & Tile | `.dominoes` | `DominoesScoringEngine` |
| 29 | Mahjong | Card & Tile | `.mahjong` | `MahjongScoringEngine` |
| 30 | Cribbage | Card & Tile | `.cribbage` | `CribbageScoringEngine` |
| 31 | Poker (Tournament) | Card & Tile | `.pokerTournament` | `PokerTournamentEngine` |
| 32 | Chess | Mind Sports | `.chess` | `ChessScoringEngine` |
| 33 | Checkers | Mind Sports | `.checkers` | `CheckersScoringEngine` |
| 34 | Go | Mind Sports | `.go` | `GoScoringEngine` |
| 35 | Backgammon | Mind Sports | `.backgammon` | `BackgammonScoringEngine` |
| 36 | Scrabble | Mind Sports | `.scrabble` | `ScrabbleScoringEngine` |
| 37 | Curling | Ice & Outdoor | `.curling` | `CurlingScoringEngine` |
| 38 | Horseshoes | Ice & Outdoor | `.horseshoes` | `HorseshoesScoringEngine` |
| 39 | Cornhole | Ice & Outdoor | `.cornhole` | `CornholeScoringEngine` |
| 40 | Ring Toss | Ice & Outdoor | `.ringToss` | `RingTossScoringEngine` |
| 41 | Disc Golf | Ice & Outdoor | `.discGolf` | `DiscGolfScoringEngine` |
| 42 | Kubb | Ice & Outdoor | `.kubb` | `KubbScoringEngine` |
| 43 | Croquet | Ice & Outdoor | `.croquet` | `CroquetScoringEngine` |
| 44 | Shuffleboard | Ice & Outdoor | `.shuffleboard` | `ShuffleboardScoringEngine` |
| 45 | Air Hockey | Pub / Parlour | `.airHockey` | `AirHockeyScoringEngine` |
| 46 | Foosball | Pub / Parlour | `.foosball` | `FoosballScoringEngine` |
| 47 | Pinball | Pub / Parlour | `.pinball` | `PinballScoringEngine` |
| 48 | Arm Wrestling | Pub / Parlour | `.armWrestling` | `ArmWrestlingScoringEngine` |
| —  | Pool (pub context) | Pub / Parlour | `.pool` | `PoolScoringEngine` *(same as #08)* |

---

## Category 1 — Precision & Aiming

### 01 · Darts
| Property | Value |
|---|---|
| Engine | `DartsScoringEngine` |
| Players | 2–8 |
| Variants | `501` · `301` · `701` · `Cricket` · `AroundTheClock` · `Shanghai` |
| Entry UI | SVG dartboard tap target · number + multiplier keypad fallback |
| Win condition | Variant-specific (see below) |
| Scoring unit | Per throw (3 throws = 1 turn) |

**Variant rules**

| Variant | Start | Win | Bust rule |
|---|---|---|---|
| 501 | 501 | Count down to exactly 0 | Below 0, land on 1, or reach 0 without double → revert turn |
| 301 | 301 | Same as 501 | Same as 501 |
| 701 | 701 | Same as 501 | Same as 501 |
| Cricket | — | All 15–20 + Bull closed, score ≥ opponent | No bust — excess marks score face value against open numbers |
| AroundTheClock | — | Hit 1–20 in order + Bull | Miss = no score, no penalty |
| Shanghai | — | Hit single/double/treble of current number; most points after 7 rounds | No bust |

**Config toggles**: double-in, double-out, master-out (treble also valid)

---

### 02 · Archery
| Property | Value |
|---|---|
| Engine | `ArcheryScoringEngine` |
| Players | 1–8 |
| Variants | `Target` · `Field` · `3D` |
| Entry UI | Concentric ring tap target (10 zones + X inner) |
| Win condition | Highest total after all ends |
| Scoring unit | Per arrow (6 arrows per end) |

| Value | Zone |
|---|---|
| X | Inner gold (10 + tiebreak marker) |
| 10 | Gold |
| 9 | Gold outer |
| 8–1 | Rings outward |
| M | Miss = 0 |

**Config**: arrows per end (default 6), ends per round, decimal X display

---

### 03 · Sport Shooting
| Property | Value |
|---|---|
| Engine | `SportShootingScoringEngine` |
| Players | 1–8 |
| Variants | `AirPistol10m` · `AirRifle10m` · `Pistol25m` · `Rifle50m` · `Custom` |
| Entry UI | Numeric keypad (integer or decimal) |
| Win condition | Highest total after all series |
| Scoring unit | Per shot (10 shots per series) |

**Config**: integer vs decimal scoring, shots per series, series count, penalty deduction value

---

### 04 · Axe Throwing
| Property | Value |
|---|---|
| Engine | `AxeThrowingScoringEngine` |
| Players | 2 |
| Variants | `WATL` · `NATF` · `Custom` |
| Entry UI | Axe target tap zones |
| Win condition | Best-of-X matches (most points per match) |
| Scoring unit | Per throw (5 throws per match) |

| Zone (WATL) | Points |
|---|---|
| Bullseye | 6 |
| Ring 1 | 4 |
| Ring 2 | 3 |
| Ring 3 | 2 |
| Ring 4 | 1 |
| Clutch (blue dots) | 7 |

**Config**: org ruleset, killshot/clutch toggle, throws per match, matches in set

---

### 05 · Knife Throwing
### 06 · Slingshot
### 07 · Blowgun
*(All three share `ZoneBasedScoringEngine`)*

| Property | Value |
|---|---|
| Engine | `ZoneBasedScoringEngine` |
| Players | 1–8 |
| Variants | `Custom` (fully configurable zones) |
| Entry UI | Concentric zone tap target |
| Win condition | Highest total after all rounds |
| Scoring unit | Per throw |

**Config**: zone count, points per zone, throws per round, rounds per match, point target

---

## Category 2 — Cue Sports

### 08 · Billiards / Pool
| Property | Value |
|---|---|
| Engine | `PoolScoringEngine` |
| Players | 2 |
| Variants | `8Ball` · `9Ball` · `10Ball` · `StraightPool` · `OnePocket` |
| Entry UI | Ball tap grid · foul/scratch buttons |
| Win condition | Variant-specific |
| Scoring unit | Per rack/game |

| Variant | Win condition |
|---|---|
| 8-Ball | Legally pocket 8-ball after clearing your group |
| 9-Ball | Legally pocket 9-ball (combo/carom allowed) |
| 10-Ball | Same as 9-ball with 10 balls |
| Straight Pool | First to reach target (default 150 balls pocketed) |
| One Pocket | First to pocket 8 balls in designated pocket |

**Config**: racks in match, foul rules toggle, rack-tracking

---

### 09 · Snooker
| Property | Value |
|---|---|
| Engine | `SnookerScoringEngine` |
| Players | 2 |
| Variants | `Standard` · `PowerSnooker` |
| Entry UI | Ball value buttons + foul button |
| Win condition | Win majority of frames in match |
| Scoring unit | Per ball |

| Ball | Points |
|---|---|
| Red | 1 |
| Yellow | 2 |
| Green | 3 |
| Brown | 4 |
| Blue | 5 |
| Pink | 6 |
| Black | 7 |

**Special**: Foul min 4 pts (or ball value if higher) to opponent · Highest break tracked · Colour-safe accessible mode

**Config**: frames in match, colour-safe mode toggle

---

### 10 · Carom Billiards
### 11 · Cushion Caroms (3-Cushion)
*(Both use `CaromScoringEngine`; variant distinguishes the 3-cushion rule)*

| Property | Value |
|---|---|
| Engine | `CaromScoringEngine` |
| Players | 2 |
| Variants | `Straight` (Carom) · `ThreeCushion` |
| Entry UI | Carom count +/- per inning |
| Win condition | First to target caroms (e.g. 40) |
| Scoring unit | Caroms per inning |

**Display**: running average = score ÷ innings (shown alongside total)

**3-Cushion rule**: cue ball must contact 3+ cushions before striking 2nd object ball

---

## Category 3 — Bowling Variations

### 12 · Ten-Pin Bowling
| Property | Value |
|---|---|
| Engine | `TenPinBowlingScoringEngine` |
| Players | 1–6 |
| Variants | `Standard` |
| Entry UI | 10-pin tap diagram + ball count input |
| Win condition | Highest score after 10 frames |
| Scoring unit | Per ball (max 3 in frame 10) |

| Event | Rule |
|---|---|
| Strike (X) | 10 pins frame 1 → bonus = next 2 balls |
| Spare (/) | Remaining pins frame 2 → bonus = next 1 ball |
| Frame 10 | Strike → 2 more balls; Spare → 1 more ball |
| Perfect game | 300 — celebration trigger |

---

### 13 · Nine-Pin Bowling
| Property | Value |
|---|---|
| Engine | `NinePinScoringEngine` |
| Players | 2–6 (team or solo) |
| Variants | `Standard` · `TeamLane` |
| Entry UI | 9-pin diamond diagram |
| Win condition | Highest score |
| Scoring unit | Per ball (2 balls per turn) |

**Kingpin**: knocking center pin on 1st ball = 9 pts; other pins = face count

---

### 14 · Candlepin Bowling
| Property | Value |
|---|---|
| Engine | `CandlepinScoringEngine` |
| Players | 1–6 |
| Variants | `Standard` |
| Entry UI | 10-pin tap diagram (fallen pins stay) |
| Win condition | Highest score after 10 frames |
| Scoring unit | Per ball (3 balls per frame) |

**Key difference**: fallen pins remain on lane; no strike/spare bonus — pure pin count

---

### 15 · Duckpin Bowling
| Property | Value |
|---|---|
| Engine | `DuckpinScoringEngine` |
| Players | 1–6 |
| Variants | `Standard` |
| Entry UI | 10-pin tap diagram |
| Win condition | Highest score after 10 frames |
| Scoring unit | Per ball (3 balls per frame) |

**Key difference from candlepin**: strike/spare bonuses apply (same math as ten-pin)

---

### 16 · Bocce Ball · 17 · Pétanque · 18 · Boules
*(All three share `BocceScoringEngine`; variant label distinguishes them)*

| Property | Value |
|---|---|
| Engine | `BocceScoringEngine` |
| Players | 2 or 4 (2 teams) |
| Variants | `Bocce` · `Petanque` · `Boules` |
| Entry UI | End score input + notes field |
| Win condition | First to 13 (configurable) |
| Scoring unit | Per end |

**Cancellation scoring**: only team with ball(s) closest to pallino/jack scores; 1 pt per ball closer than opponent's nearest

---

### 19 · Lawn Bowls
| Property | Value |
|---|---|
| Engine | `LawnBowlsScoringEngine` |
| Players | 2–4 per team (configurable format) |
| Variants | `Singles` · `Pairs` · `Triples` · `Fours` |
| Entry UI | Shot count input per end |
| Win condition | Configurable ends or first to points target |
| Scoring unit | Per end |

**4 woods per player** · Shot count = bowls closer to jack than opponent's nearest

---

### 20 · Skittles
| Property | Value |
|---|---|
| Engine | `SkittlesScoringEngine` |
| Players | 2–8 |
| Variants | `Alley` · `TableSkittles` · `HoodSkittles` |
| Entry UI | Pin count input (9 pins) |
| Win condition | Highest running total |
| Scoring unit | Per throw |

**Config**: throws per turn, legs per game

---

## Category 4 — Racket Sports (1v1)

### 21 · Table Tennis
| Property | Value |
|---|---|
| Engine | `TableTennisScoringEngine` |
| Players | 2 (singles) or 4 (doubles) |
| Variants | `Singles` · `Doubles` |
| Entry UI | +1 point buttons per player |
| Win condition | Win majority of games in match |
| Scoring unit | Per rally |

First to **11** (win by 2); deuce at 10-10 — alternating single serves in deuce  
Serve: switches every **2 points** (every 1 in deuce)  
**Config**: games in match (3/5/7)

---

### 22 · Badminton
| Property | Value |
|---|---|
| Engine | `BadmintonScoringEngine` |
| Players | 2 (singles) or 4 (doubles) |
| Variants | `Singles` · `Doubles` |
| Entry UI | +1 point buttons per player/team |
| Win condition | Win 2 of 3 games |
| Scoring unit | Per rally |

First to **21** (win by 2); cap at **30** (30-29 is valid, 30-30 = sudden death)

---

### 23 · Squash
| Property | Value |
|---|---|
| Engine | `SquashScoringEngine` |
| Players | 2 |
| Variants | `PAR` (modern) · `HiHo` (classic) |
| Entry UI | +1 point buttons per player |
| Win condition | Best of 5 games |
| Scoring unit | Per rally (PAR) or per serve won (HiHo) |

| Variant | Target | Serve scoring |
|---|---|---|
| PAR | 11, win by 2 | Rally — anyone scores |
| HiHo | 9 | Serve-only |

---

### 24 · Racquetball
| Property | Value |
|---|---|
| Engine | `RacquetballScoringEngine` |
| Players | 2 |
| Variants | `Standard` |
| Entry UI | +1 point button (serving player only) |
| Win condition | Best of 3 games |
| Scoring unit | Per serve won |

Games 1–2: first to **15** · Tiebreak: first to **11**

---

### 25 · Tennis
| Property | Value |
|---|---|
| Engine | `TennisScoringEngine` |
| Players | 2 (singles) or 4 (doubles) |
| Variants | `Singles` · `Doubles` · `MixedDoubles` |
| Entry UI | Point buttons (0/15/30/40/Deuce/Adv) |
| Win condition | Win majority of sets in match |
| Scoring unit | Per point → game → set → match |

**Point state machine**: 0 → 15 → 30 → 40 → Deuce → Advantage → Game  
**Set**: first to 6 games (win by 2); tiebreak at 6-6  
**Tiebreak**: first to 7 pts (win by 2)  
**Score display**: `"40-30 | 5-4 | 1-0"` (points · games · sets)

**Config**: best of 3 or 5 sets, no-ad / golden point toggle, 10-pt match tiebreak toggle

---

### 26 · Padel
| Property | Value |
|---|---|
| Engine | `PadelScoringEngine` |
| Players | 4 (2 teams of 2) |
| Variants | `Standard` |
| Entry UI | Same as tennis; team-level point input |
| Win condition | Same as tennis |
| Scoring unit | Per point → game → set → match |

**Identical scoring to tennis** · Doubles only · Both players on team share game-level score entry

**Config**: golden point toggle at deuce

---

### 27 · Pickleball
| Property | Value |
|---|---|
| Engine | `PickleballScoringEngine` |
| Players | 2 (singles) or 4 (doubles) |
| Variants | `Singles` · `Doubles` |
| Entry UI | +1 per side; serve sequence indicator |
| Win condition | Best of 3 games |
| Scoring unit | Per rally (rally scoring) or per serve won (traditional) |

First to **11** (win by 2) · **Doubles serve sequence**: server 1 → server 2 → side-out  
Score announced as `"serving-receiving-server#"` (e.g. `"7-5-2"`)

**Config**: scoring mode toggle (rally / traditional), singles vs doubles

---

## Category 5 — Card & Tile

### 28 · Dominoes
| Property | Value |
|---|---|
| Engine | `DominoesScoringEngine` |
| Players | 2–4 |
| Variants | `Draw` · `Block` · `MexicanTrain` · `AllFives` |
| Entry UI | Numeric score input per round |
| Win condition | First to configured total (default 150) |
| Scoring unit | Per round |

**Draw / Block / Mexican Train**: round score = sum of pips in all opponents' hands  
**All-Fives**: also score multiples of 5 from open ends after each play

---

### 29 · Mahjong
| Property | Value |
|---|---|
| Engine | `MahjongScoringEngine` |
| Players | 4 |
| Variants | `Chinese` (Fan/Points) · `Japanese` (Han/Fu) · `American` |
| Entry UI | Hand score input; dealer rotation display |
| Win condition | Configurable game total or most points after N rounds |
| Scoring unit | Per hand |

**Chinese**: hand value = base pts × 2^doublings  
**Japanese**: Han × Fu lookup table  
**Tracking**: dealer rotation (East→South→West→North), seat winds, bonus tiles (flowers/seasons)

---

### 30 · Cribbage
| Property | Value |
|---|---|
| Engine | `CribbageScoringEngine` |
| Players | 2 (or 3–4 with partner variant) |
| Variants | `Standard` · `ThreePlayer` · `FourPlayer` |
| Entry UI | Visual peg board (0–121) · score entry per event |
| Win condition | First peg to reach 121 |
| Scoring unit | Per scoring event |

**Hand scoring**: 15s (+2 each) · pairs (+2) · triplets (+6) · quads (+12) · runs · flush (+4/5) · nobs (+1) · nibs (+2)  
**Pegging**: visual 120-hole board; peg advances on every event  
**Config**: Muggins toggle (opponent claims missed points), crib rotation

---

### 31 · Poker (Tournament)
| Property | Value |
|---|---|
| Engine | `PokerTournamentEngine` |
| Players | 2–10 |
| Variants | `Freezeout` · `Rebuy` · `Bounty` |
| Entry UI | Chip stack input; blind level timer |
| Win condition | Last player with chips |
| Scoring unit | Per elimination (rank tracking) |

**Tracking**: chip stacks, blind levels (ante/small/big + timer), rebuy/add-on events, elimination order  
**No card simulation** — manual chip count entry only

---

## Category 6 — Mind Sports

### 32 · Chess
| Property | Value |
|---|---|
| Engine | `ChessScoringEngine` |
| Players | 2 |
| Variants | `Standard` · `Chess960` |
| Entry UI | Win / Draw / Loss result buttons |
| Win condition | Highest cumulative points after N games |
| Scoring unit | Per game (Win=1, Draw=0.5, Loss=0) |

**Time formats**: Bullet 1+0 · Blitz 3+2 / 5+0 · Rapid 10+0 / 15+10 · Classical  
**Config**: games in match, ELO tracking toggle

---

### 33 · Checkers
| Property | Value |
|---|---|
| Engine | `CheckersScoringEngine` |
| Players | 2 |
| Variants | `Standard8x8` · `International10x10` · `Canadian12x12` |
| Entry UI | Capture count input; win/draw/loss result |
| Win condition | Opponent has no legal moves or no pieces |
| Scoring unit | Per game |

---

### 34 · Go
| Property | Value |
|---|---|
| Engine | `GoScoringEngine` |
| Players | 2 |
| Variants | `9x9` · `13x13` · `19x19` |
| Entry UI | Capture count +/- ; final territory score input |
| Win condition | Highest score: territory + prisoners + komi |
| Scoring unit | Per game |

**Config**: komi (default 6.5), handicap stones (0–9), board size

---

### 35 · Backgammon
| Property | Value |
|---|---|
| Engine | `BackgammonScoringEngine` |
| Players | 2 |
| Variants | `Standard` |
| Entry UI | Game result buttons (Normal/Gammon/Backgammon) + doubling cube tracker |
| Win condition | First to X match points (configurable) |
| Scoring unit | Per game |

| Result | Points |
|---|---|
| Normal win | 1 × cube value |
| Gammon | 2 × cube value |
| Backgammon | 3 × cube value |

**Doubling cube**: current value (1/2/4/8…64) + owner tracked  
**Config**: match length, Crawford rule toggle

---

### 36 · Scrabble
| Property | Value |
|---|---|
| Engine | `ScrabbleScoringEngine` |
| Players | 2–4 |
| Variants | `Standard` · `Custom` |
| Entry UI | Numeric word score input; bingo button |
| Win condition | Highest total when bag is empty and a player empties rack |
| Scoring unit | Per word play |

**Bingo bonus**: +50 for using all 7 tiles  
**Config**: premium grid (standard or custom), challenge flag per word  
**Tile face values stored** for manual verification reference

---

## Category 7 — Ice & Outdoor

### 37 · Curling
| Property | Value |
|---|---|
| Engine | `CurlingScoringEngine` |
| Players | 4 per team (2 teams) |
| Variants | `Standard` · `MixedDoubles` |
| Entry UI | End score input per team; blank end button; concede button |
| Win condition | Highest score after 8 or 10 ends |
| Scoring unit | Per end |

**Blank end**: no score recorded; hammer retained by same team  
**Hammer**: passes to team that didn't score last end  
**Config**: ends in match (8/10), hammer assignment for first end

---

### 38 · Horseshoes
| Property | Value |
|---|---|
| Engine | `HorseshoesScoringEngine` |
| Players | 2 or 4 (2 teams) |
| Variants | `Standard` · `TeamPlay` |
| Entry UI | Ringer / Leaner / Point count buttons |
| Win condition | First to 21 or 40 (configurable) |
| Scoring unit | Per round (cancellation scoring) |

| Throw result | Points |
|---|---|
| Ringer | 3 |
| Leaner | 1 (configurable per org) |

**Cancellation**: subtract lower team score from higher; net added to leader

---

### 39 · Cornhole
| Property | Value |
|---|---|
| Engine | `CornholeScoringEngine` |
| Players | 2 or 4 (2 teams) |
| Variants | `Standard` · `TeamPlay` |
| Entry UI | Hole / Board count buttons per team |
| Win condition | First to exactly 21 (configurable) |
| Scoring unit | Per round (cancellation scoring) |

| Bag result | Points |
|---|---|
| Hole | 3 |
| Board | 1 |

**Cancellation per round**: net score after subtracting opponent  
**Config**: bust rule toggle (revert to pre-round score if over 21, or no bust)

---

### 40 · Ring Toss
| Property | Value |
|---|---|
| Engine | `RingTossScoringEngine` |
| Players | 1–8 |
| Variants | `Custom` |
| Entry UI | Zone tap target |
| Win condition | Highest total / first to target |
| Scoring unit | Per throw |

**Config**: zone count, points per peg/zone, throws per round, match target

---

### 41 · Disc Golf
| Property | Value |
|---|---|
| Engine | `DiscGolfScoringEngine` |
| Players | 1–8 |
| Variants | `StrokePlay` · `MatchPlay` |
| Entry UI | Stroke count per hole; par reference display |
| Win condition | Lowest cumulative strokes (stroke play) |
| Scoring unit | Per hole |

**Score display**: strokes relative to par (−2=Eagle, −1=Birdie, E=Par, +1=Bogey, +2=Double Bogey)  
**Course library**: save custom courses with hole count + par per hole  
**Config**: course selection, player count

---

### 42 · Kubb
| Property | Value |
|---|---|
| Engine | `KubbScoringEngine` |
| Players | 2–12 (2 teams) |
| Variants | `Standard` |
| Entry UI | Kubbs-toppled counter per round; King Hit button |
| Win condition | Topple King after clearing all kubbs |
| Scoring unit | Per round (event log, no running numeric score) |

**King Hit**: instant win condition — tap button to record and end session

---

### 43 · Croquet
| Property | Value |
|---|---|
| Engine | `CroquetScoringEngine` |
| Players | 2 or 4 |
| Variants | `Association` · `GolfCroquet` |
| Entry UI | Hoop completion buttons per player |
| Win condition | Variant-specific |
| Scoring unit | Per hoop |

| Variant | Win condition |
|---|---|
| Association | Complete hoops 1–12 in sequence, then peg out |
| Golf Croquet | First player/team through each hoop = 1 pt; first to 7 pts |

---

### 44 · Shuffleboard
| Property | Value |
|---|---|
| Engine | `ShuffleboardScoringEngine` |
| Players | 2 or 4 (2 teams) |
| Variants | `Standard` · `TeamPlay` |
| Entry UI | Zone score input per team |
| Win condition | First to 15 or 21 (configurable) |
| Scoring unit | Per round (cancellation scoring) |

| Zone | Points |
|---|---|
| Zone 1 | 1 |
| Zone 2 | 2 |
| Zone 3 | 3 |

---

## Category 8 — Pub / Parlour

### 45 · Air Hockey
| Property | Value |
|---|---|
| Engine | `AirHockeyScoringEngine` |
| Players | 2 |
| Variants | `Standard` · `BestOf` |
| Entry UI | +1 goal button per player |
| Win condition | First to 7 goals (configurable); best-of series |
| Scoring unit | Per goal |

---

### 46 · Foosball
| Property | Value |
|---|---|
| Engine | `FoosballScoringEngine` |
| Players | 2 (1v1) or 4 (2v2) |
| Variants | `Singles` · `Doubles` |
| Entry UI | +1 goal button per player/team |
| Win condition | First to 5 or 10 goals (configurable); best-of series |
| Scoring unit | Per goal |

---

### 47 · Pinball
| Property | Value |
|---|---|
| Engine | `PinballScoringEngine` |
| Players | 1–8 |
| Variants | `HighScore` · `Tournament` |
| Entry UI | Large integer score input (up to 10 digits) |
| Win condition | Highest score (or cumulative/ranked in tournament) |
| Scoring unit | Per game |

**Machine library**: save named machines  
**Per-machine high score board** stored locally  
**Tournament mode**: rank N plays per machine

---

### 48 · Arm Wrestling
| Property | Value |
|---|---|
| Engine | `ArmWrestlingScoringEngine` |
| Players | 2 |
| Variants | `Standard` · `LeftAndRight` |
| Entry UI | Win / Loss per pull; arm selector (Left/Right) |
| Win condition | Most pulls won (best of X) |
| Scoring unit | Per pull |

**Left/right arm tracked independently** · Aggregate match result per arm

---

### Pool (pub context) — cross-listed from #08
Same `PoolScoringEngine` as Cue Sports entry. Category tag = `Pub/Parlour`.  
No separate engine or `SportType` case — `.pool` with variant `8Ball` is the default pub setup.

---

## `SportType` Enum (Swift)

```swift
enum SportType: String, CaseIterable, Identifiable, Codable {
    // Precision & Aiming
    case darts
    case archery
    case sportShooting
    case axeThrowing
    case knifeThrowing
    case slingshot
    case blowgun

    // Cue Sports
    case pool
    case snooker
    case caroms
    case cushionCaroms

    // Bowling
    case bowlingTenPin
    case bowlingNinePin
    case bowlingCandlepin
    case bowlingDuckpin
    case bocce
    case petanque
    case boules
    case lawnBowls
    case skittles

    // Racket
    case tableTennis
    case badminton
    case squash
    case racquetball
    case tennis
    case padel
    case pickleball

    // Card & Tile
    case dominoes
    case mahjong
    case cribbage
    case pokerTournament

    // Mind Sports
    case chess
    case checkers
    case go
    case backgammon
    case scrabble

    // Ice & Outdoor
    case curling
    case horseshoes
    case cornhole
    case ringToss
    case discGolf
    case kubb
    case croquet
    case shuffleboard

    // Pub / Parlour
    case airHockey
    case foosball
    case pinball
    case armWrestling

    var id: String { rawValue }
}
```

### Category grouping

```swift
extension SportType {
    var category: SportCategory {
        switch self {
        case .darts, .archery, .sportShooting, .axeThrowing,
             .knifeThrowing, .slingshot, .blowgun:
            return .precisionAiming
        case .pool, .snooker, .caroms, .cushionCaroms:
            return .cueSports
        case .bowlingTenPin, .bowlingNinePin, .bowlingCandlepin, .bowlingDuckpin,
             .bocce, .petanque, .boules, .lawnBowls, .skittles:
            return .bowling
        case .tableTennis, .badminton, .squash, .racquetball,
             .tennis, .padel, .pickleball:
            return .racket
        case .dominoes, .mahjong, .cribbage, .pokerTournament:
            return .cardTile
        case .chess, .checkers, .go, .backgammon, .scrabble:
            return .mindSports
        case .curling, .horseshoes, .cornhole, .ringToss,
             .discGolf, .kubb, .croquet, .shuffleboard:
            return .iceOutdoor
        case .airHockey, .foosball, .pinball, .armWrestling:
            return .pubParlour
        }
    }
}

enum SportCategory: String, CaseIterable {
    case precisionAiming = "Precision & Aiming"
    case cueSports       = "Cue Sports"
    case bowling         = "Bowling"
    case racket          = "Racket"
    case cardTile        = "Card & Tile"
    case mindSports      = "Mind Sports"
    case iceOutdoor      = "Ice & Outdoor"
    case pubParlour      = "Pub & Parlour"
}
```

### Shared engines map

```swift
// Sports that share an engine (variant drives rule differences)
// ZoneBasedScoringEngine  →  knifeThrowing, slingshot, blowgun
// BocceScoringEngine      →  bocce, petanque, boules
// CaromScoringEngine      →  caroms, cushionCaroms
// PoolScoringEngine       →  pool (all variants + pub context)
```

---

*Generated from `sportscore.md`. Total unique `SportType` cases: 48. Pool serves both Cue Sports and Pub/Parlour via category tag.*
