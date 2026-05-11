# Cryptid Clash — Systems Design

> Last updated: 2026-05-10  
> Companion to ARCHITECTURE.md (code structure). This document covers *how* each system works from a design and mechanics perspective.

---

## Table of Contents

1. [Core Match-3 System](#1-core-match-3-system)
2. [Cascade & Scoring System](#2-cascade--scoring-system)
3. [Obstacle System](#3-obstacle-system)
4. [Booster System](#4-booster-system)
5. [Goal & Objective System](#5-goal--objective-system)
6. [Mana & Ability System](#6-mana--ability-system)
7. [Team & Leader Skill System](#7-team--leader-skill-system)
8. [Progression System](#8-progression-system)
9. [Collection & Gacha System](#9-collection--gacha-system)
10. [Economy System](#10-economy-system)
11. [Monetization System](#11-monetization-system)
12. [UI System](#12-ui-system)
13. [Audio System](#13-audio-system)
14. [Animation System](#14-animation-system)
15. [Input System](#15-input-system)
16. [Scene Management System](#16-scene-management-system)
17. [Save & Persistence System](#17-save--persistence-system)
18. [Tutorial & Discovery System](#18-tutorial--discovery-system)
19. [Daily Engagement Systems](#19-daily-engagement-systems)
20. [Analytics System](#20-analytics-system)
21. [Debug System](#21-debug-system)

---

## 1. Core Match-3 System

### Overview
Standard match-3 mechanic: swap adjacent pieces, clear 3+ of the same color, repeat until out of moves or goals met.

### Grid
- **Size:** 8 columns × 8 rows (64 cells)
- **Piece types:** 3–6 colors active per level (set by `LevelData.num_colors`)
- **Data model:** Column-major 2D array `grid[col][row]`, row 0 at top
- **Visual model:** `piece_nodes[col][row]` mirrors the data array exactly — Sprite2D nodes positioned by `grid_to_pixel(col, row)`

### Piece Colors

| Index | Cryptid | Color |
|---|---|---|
| 0 | Bigfoot | Brown |
| 1 | Mothman | Red |
| 2 | Nessie | Blue |
| 3 | Chupacabra | Green |
| 4 | Yeti | White |
| 5 | Jersey Devil | Purple |

### Swapping
- Player selects a piece, then selects an **adjacent** piece (no diagonal)
- Swap animates (0.2s), then match check runs
- If no match forms: swap reverses with a reject shake animation — **no move is consumed**
- If match forms: swap commits, move is consumed, match processing begins
- Web obstacles block swapping: neither of the two pieces involved may sit on a web cell

### Match Detection
Two-pass scan (horizontal, then vertical) finding runs of 3+ same-color pieces. Pieces in both a horizontal and vertical run are counted in both groups (L/T shapes). The match finder returns rich group data (size, direction, piece type, positions) used for booster creation decisions.

### Initial Board Setup
1. Fill grid with random pieces
2. Heuristic re-roll: if placing a piece would immediately create 3-in-a-row, try other colors (up to all colors)
3. Second-pass resolution: re-roll any remaining matches
4. Result: a board with no existing matches at game start

### Deadlock Detection
After every board settle, all adjacent swap pairs are tested. If none produce a match, the board is deadlocked:
- **First shuffle per level:** free, plays automatically with a toast notification
- **Subsequent shuffles:** a modal popup appears; player pays 10 coins to shuffle (or shuffles free if they can't afford it)
- Post-shuffle matches are processed immediately before play resumes
- Up to 10 shuffle attempts before giving up (pathological edge case guard)
- Navigation away (quit/home) unblocks any pending shuffle confirmation

### Cascade Safety
When the board fills from the top after clearing, fills are normally random. After **3 natural cascades** in a row, new pieces are placed using a conflict-aware algorithm (`_get_safe_type`) that checks all 6 potential 3-in-a-row patterns around the target cell and excludes conflicting colors. This prevents runaway cascade loops while still allowing dramatic natural chains.

---

## 2. Cascade & Scoring System

### Cascade Flow
Each cascade is one full cycle of: match → clear → gravity → fill → re-check. If new matches form after fill, the cycle repeats with `cascade_level` incrementing.

```
Swap → Match(cascade=0) → Clear → Fall → Fill → Match(cascade=1) → ... → No match → Settle
```

### Score Formula
```
base_points  = MATCH_BASE_SCORE + (match_size - 3) × EXTRA_PIECE_BONUS
             = 50 + (count - 3) × 25

final_score  = base_points × cascade_multiplier × leader_score_multiplier
```

**Cascade multiplier:**
- Starts at `1.0` every time a new swap is made
- Increments by `+0.5` for each cascade level (`increment_cascade()`)
- Resets to `1.0` on board settle

| Cascade Level | Multiplier |
|---|---|
| 0 (initial match) | ×1.0 |
| 1 | ×1.5 |
| 2 | ×2.0 |
| 3 | ×2.5 |

**Booster score bonuses:**
- Creating a booster: +100 points
- Activating a booster via match: +200 points

### Cascade Label
A large multiplier label (`x1.5`, `x2.0`, etc.) pops in and scales down during active cascades. It hides 0.5s after the board settles.

### Screen Shake
- Booster activation: medium shake
- Cascade level ≥ 3: large shake
- Cascade level ≥ 1: small shake

### Move Consumption
- A move is consumed when `EventBus.swap_completed` fires (i.e., only on valid swaps)
- Shield ability: skips move consumption on one swap, then deactivates
- Granted extra moves (ability, continue after game over): added directly to `moves_remaining`

---

## 3. Obstacle System

Two obstacle types: Ice and Web. Both are rendered in `Board._draw()` behind the piece layer.

### Ice

| Property | Value |
|---|---|
| Visual | Blue-white rectangle with opacity based on HP; crack lines appear at HP=1 |
| Damage trigger | The piece **sitting on** the ice cell is cleared (any source: match, ability, booster) |
| HP | 1 or 2 (set per cell in LevelData) |
| On destroy | Emits `obstacle_cleared(col, row, ICE)` → GameManager advances ice sub-goal |
| Introduced | Level 4 |

**Ice HP visual:**
- HP 2: opacity 0.4 (solid)
- HP 1: opacity 0.25 + two diagonal crack lines drawn across the cell

### Web

| Property | Value |
|---|---|
| Visual | Crossed diagonals + crosshair lines + small knot circles at intersections |
| Damage trigger | A piece in an **adjacent** (non-web) cell is cleared |
| HP | Always 1 |
| Blocks | Swaps — neither piece in a swap may sit on a web cell |
| On destroy | Emits `obstacle_cleared(col, row, WEB)` → GameManager advances web sub-goal |
| Introduced | Level 7 |

**Web adjacency logic:** Only non-web adjacent cells can damage the web. This prevents a web being double-damaged in a single frame (e.g., from two adjacent pieces being cleared simultaneously).

### HP Safety
Obstacle HP is floored at 0: `obstacle_hp = max(obstacle_hp - 1, 0)`. A cell at HP=0 is treated as destroyed immediately (`obstacle_grid` set to NONE). Subsequent damage calls on that cell return early via the `has_obstacle()` guard.

---

## 4. Booster System

Boosters are special pieces created from large matches. They are **persistent** — they stay on the board as modified piece nodes until they are included in a future match.

### Booster Creation

| Shape | Booster Created | Visual |
|---|---|---|
| 4-in-a-row (horizontal) | LINE_H | Left/right arrows + chevrons |
| 4-in-a-row (vertical) | LINE_V | Up/down arrows |
| L-shape, T-shape, or cross (H+V intersection) | AREA_BOMB | 8-point starburst + center circle |
| 5-in-a-row (any direction) | COLOR_BOMB | 5-pointed rainbow star |

**Booster placement rule:** The new booster replaces the piece at the swap destination, not the swap origin. This lets players intentionally place boosters where they want them.

**Visual indicator:** When a booster is created, a radial flash appears at its board position, and the piece plays a grow-and-settle animation (0.35s). Persistent boosters also breathe (scale pulse) and glow (alpha pulse) continuously.

### Booster Activation
A booster activates when it is included in any match (it counts as a regular piece of its color, but the booster effect triggers in addition to the normal clear).

| Booster | Effect |
|---|---|
| LINE_H | Clears the entire row |
| LINE_V | Clears the entire column |
| AREA_BOMB | Clears a 3×3 area (radius 1) centered on the booster |
| COLOR_BOMB | Clears all pieces on the board matching the booster's piece color |

### Chain Reactions
Booster activations are collected via BFS before clearing. If an activated booster's effect hits another booster, that booster is also queued for activation. The full chain resolves before any pieces are cleared, producing dramatic multi-booster explosions in a single visual sequence.

### Mana from Boosters
Cleared pieces — including those cleared by booster chains — generate mana charges. A booster clearing 16 pieces of one color generates mana for those 16 pieces (at 3 pips since count > 4), charging cryptid mana bars significantly.

---

## 5. Goal & Objective System

Every level has one goal type. Progress is tracked by GameManager and displayed in the HUD.

### Goal Types

| Type | Win Condition | Tracking |
|---|---|---|
| SCORE | Reach star_1_score by the time moves run out | Star thresholds checked at game end |
| COLLECT | Clear N pieces of a specific color | `pieces_collected` signal per match |
| CLEAR_OBSTACLES | Destroy N ice tiles and/or N web tiles | `obstacle_cleared` signal per cell |
| CHARGE_MANA | Trigger `mana_full` N times | `mana_full` signal counts |
| MIXED | Any combination of sub-goals | All sub-goals tracked simultaneously |

### SCORE Goal Behaviour
Score goals do **not** track a sub-goal dict entry. The level ends when moves run out, then the star rating is checked. A player with 0 stars at that point gets game over; ≥1 star completes the level.

### COLLECT Goal Filtering
The `goal_params` dict may contain a `"type"` key (PieceType int). If present, only pieces of that color advance the goal. If absent (e.g., "collect any 20 pieces"), all piece types count.

### Goal Completion
When all sub-goals in `_goals` reach their targets:
1. `_goals_met = true`
2. `EventBus.all_goals_completed()` fires → HUD flashes all goal labels green
3. On next board settle: `_check_end_condition()` detects completion → triggers victory

### Early Completion Bonus
If goals are met before moves run out and `LevelData.moves_bonus == true`, remaining moves are converted into boosters via the victory detonation sequence (equivalent to Candy Crush's "Sugar Crush"). Each leftover move spawns a random booster on the board, all detonate for bonus score.

### HUD Goal Display
Each active sub-goal gets its own Label under the star progress bar:
```
Collect Blue: 7/15
Break Ice: 3/6   ✓
```
Completed sub-goals turn green and show a checkmark.

---

## 6. Mana & Ability System

### Mana Charging
Every piece cleared generates mana for the cryptid whose `base_cryptid` (color) matches that piece type. Pips charged per match event:

| Match Size | Pips |
|---|---|
| 3 | 1 |
| 4 | 2 |
| 5+ | 3 |

Pips are applied to **all** pieces cleared in the full set (including booster chain extras), not just the original match. Mana charging fires **before** pieces are visually cleared.

Leader skill `MANA_MULTIPLIER` scales the pip amount: `effective_pips = round(pips × multiplier)`.

### Mana Bar States
Each team cryptid has a bar showing `current / max` (e.g., 3/6). When full:
- `mana_full(cryptid_id)` signal fires
- "READY" label appears on portrait
- `CHARGE_MANA` goal sub-goal advances
- Portrait tap activates the ability

### Ability Activation Guards
All must be satisfied:
1. Board state = IDLE (prevents activation mid-cascade)
2. GameManager state = PLAYING (prevents activation after game over)
3. Mana bar full for that cryptid

### Ability Types

| Ability | Effect | `power` Meaning |
|---|---|---|
| CLEAR_ROW | Clears `power` random rows | Number of rows to clear |
| CLEAR_COLUMN | Clears `power` random columns | Number of columns to clear |
| CLEAR_AREA | Clears `(2×power+1)²` area from random center | Radius |
| CONVERT_TILES | Converts `power` non-matching pieces to cryptid's color | Number of tiles |
| SCORE_BOOST | Awards points directly | Point amount |
| EXTRA_MOVES | Grants bonus moves | Move count |
| SHIELD | Next swap costs no move | — |

Ability clears trigger a full gravity/fill/cascade cycle identical to a normal match. They can trigger cascades, charge mana, damage obstacles, and advance goals.

### Shield Indicator
When shield is active, the `moves_remaining` label tints **cyan**. It resets to default color on the next `swap_completed` signal (whether or not the shield was used — shields are consumed on the first swap).

### Mana Reset
Mana bars reset to zero on `game_started` and `team_changed`. There is no carry-over between levels.

---

## 7. Team & Leader Skill System

### Team Composition
- 3 slots: `active_team[0]` = leader, `[1]` and `[2]` = support
- Each slot holds a cryptid_id string pointing to a collected cryptid
- Default team: Bigfoot Scout, Mothman Observer, Nessie Pup
- Team can be changed from the pre-level popup (TeamSelector modal)

### Leader Slot
The cryptid in slot 0 provides passive bonuses via `LeaderSkillSystem`:

| Skill Type | Effect | Applied By |
|---|---|---|
| SCORE_MULTIPLIER | Multiplies all match/ability points | `GameManager.add_score()` |
| MANA_MULTIPLIER | Multiplies mana pips per clear | `ManaSystem._on_mana_charged()` |
| EXTRA_STARTING_MOVES | Grants bonus moves at level start | `GameManager.start_game()` |

Support cryptids (slots 1 and 2) provide no passive bonuses — only their active abilities.

### Changing Team
Team changes mid-session reset all mana bars (to prevent exploiting a charged bar). Pre-level popup is the intended team-change location.

### Team Panel UI
The team panel sits at Y=730 (near bottom of screen) showing 3 portrait buttons side by side. Each portrait shows:
- Element color circle
- Cryptid name
- "Match [element]" hint text in element color
- Ability description
- Mana progress bar (ProgressBar 0.0–1.0)
- Current/max pips text (e.g., "3/6")
- "READY" label when full (hidden otherwise)

Tapping a portrait when mana is full → ability activates. Tapping when not full → shake animation + brief "NOT READY" flash.

---

## 8. Progression System

### Level Progression
- 30 levels across 2 regions (15 each) implemented
- 4 additional planned regions (Scotland, Puerto Rico, Himalayas, Pine Barrens) with framework in place
- Levels gate sequentially: completing level N unlocks level N+1
- `PlayerData.highest_level_completed` tracks furthest progress
- Stars are stored per-level: `level_stars["level_number"] = stars` (1–3, never downgraded)

### Star Ratings
Each level has three score thresholds defined in LevelData:
```
star_1_score  → ★☆☆ (minimum pass)
star_2_score  → ★★☆
star_3_score  → ★★★
```
A result with 0 stars = game over (no completion recorded). The level must be retried.

### Total Stars
`PlayerData.total_stars` is the sum of best stars across all completed levels. This is the unlock currency for regions.

### Region Unlocks

| Region | Star Requirement |
|---|---|
| Pacific Northwest | 0 (always open) |
| Point Pleasant | 15 |
| Scotland | 35 |
| Puerto Rico | 60 |
| Himalayas | 90 |
| Pine Barrens | 125 |

Locked regions show a `🔒 N★` label on their region tab.

### Level Difficulty Curve
Levels follow a sawtooth pattern within each 15-level region:
- Easy opener (1–2)
- Rising difficulty (3–8)
- Mid-region challenge (9)
- Slight ease (10 "boss" with pre-placed boosters to feel powerful)
- Rising again (11–14)
- Region finale boss (15) with mixed goals + obstacles + pre-boosters

### Credibility (XP Rank)
Awarded on every level completion: `10 + stars × 5` XP.

| Rank | XP Threshold | Unlock Purpose |
|---|---|---|
| Curious Tourist | 0 | — |
| Amateur Investigator | 100 | — |
| Field Researcher | 350 | — |
| Seasoned Tracker | 750 | — |
| Expert Cryptozoologist | 1500 | — |
| Master Investigator | 3000 | — |
| Renowned Authority | 5500 | — |
| Legendary Tracker | 10000 | — |

Rank doubles as the XP source for the Battle Pass: `credibility_xp / XP_PER_TIER (50)` = current Battle Pass tier.

---

## 9. Collection & Gacha System

### Cryptid Collection
30 unique cryptids: 6 base types × 5 rarities. Each base type corresponds to a piece color, meaning a cryptid's rarity determines its ability power — higher rarity = more powerful ability of the same type.

### Rarity Tiers

| Rarity | Pull Weight | Research Data on Duplicate |
|---|---|---|
| Common | 60% | 5 |
| Uncommon | 25% | 10 |
| Rare | 10% | 15 |
| Epic | 4% | 20 |
| Legendary | 1% | 25 |

### Gacha (Investigation Screen)
Called "Investigate a Sighting" in-game — thematically framed as sending evidence for a field report.

| Pull Type | Cost | Guaranteed |
|---|---|---|
| Single Pull | 100 Fragments | — |
| Multi Pull (×10) | 900 Fragments | — |

**Pity system:**
- Pull 29 without a Rare+ result → pull 30 guarantees Rare or better, resets pity
- Pull 89 without an Epic+ result → pull 90 guarantees Epic or better, resets epic pity
- Pity counters persist across sessions in PlayerData (`pity_rare`, `pity_epic`)

### Duplicates
If a pull lands on an already-owned cryptid, no second copy is added to the collection. Instead, Research Data is granted (`5 × (rarity + 1)`). Research Data has no current in-game use but is tracked as a future-use currency.

### Collection Viewer (Field Guide)
Grid of all 30 cryptids. Collected: full card with rarity color border, element circle, name, ability, and leader skill. Uncollected: silhouette card showing only the name. Filter buttons: All + one per element type.

### Reveal Animation
Each pull shows a full-screen rarity glow background (color matches rarity) that fades in over 0.5s, then the cryptid card slides in. Multi-pulls show "1/10", "2/10" etc. with a Next button.

---

## 10. Economy System

### Currencies

| Currency | Earn | Spend | Display |
|---|---|---|---|
| Evidence Fragments | Level completion, daily login, trail cameras, daily login, discoveries | Gacha pulls | All screens via CurrencyBar |
| Cryptid Coins | Level completion (8–18/level), trail cameras (20% chance) | Shuffle (10), continue after loss (50) | CurrencyBar |
| Research Data | Duplicate gacha pulls | Not yet spendable | CurrencyBar |

### Fragment Earn Rates (Level Completion)
```
base      = 10 + stars × 5   →  ★: 15,  ★★: 20,  ★★★: 25
first-clear bonus = +15       →  ★: 30,  ★★: 35,  ★★★: 40
```

### Energy System
Energy gates how often the player can attempt levels.

| Property | Value |
|---|---|
| Max energy | 5 hearts |
| Regen rate | 1 heart per 25 minutes |
| Cost per attempt | 1 heart |
| Regen while offline | Yes — calculated on next app open |
| Timer behavior | Timer only starts (or resets) when going from FULL to non-full; partial progress is preserved when spending from a non-full state |

**Energy at zero:** Start button disabled. Two options appear in the pre-level popup:
- "Buy Energy" → shop
- "Watch Ad" → +1 heart (rewarded ad)

**Energy display:** Row of 5 heart icons (red = full, gray = empty) with a countdown timer showing seconds until next regen.

### Coin Spending
- **Shuffle:** 10 coins (modal appears when no valid moves; free if player can't afford it)
- **Continue after loss:** 50 coins for +5 moves (game over popup option)

---

## 11. Monetization System

### Rewarded Ads (via AdPlacement)
Three placement contexts:

| Placement ID | Context | Reward |
|---|---|---|
| `extra_moves` | Game over popup | +3 moves |
| `double_fragments` | Result screen | Doubles fragment reward |
| `free_energy` | Shop / out-of-energy state | +1 heart |

`AdPlacement` is a static class with a stub that immediately calls the callback (simulates ad watched). Replace the stub body with a real ad SDK call (AdMob, IronSource, etc.) when integrating.

### In-App Purchases (via ShopSystem)
Three energy packs — stub implementation (prints to console):

| Pack | Price | Energy | Fragments |
|---|---|---|---|
| Energy Surge | $1.99 | 25 | 50 |
| Cryptid Awakening | $4.99 | 80 | 150 |
| Expedition Pack | $9.99 | 200 | 400 |

### Starter Pack
A one-time popup shown after level 5 completion (first time only):
- Trigger: `PlayerData.highest_level_completed >= 5` and not yet shown
- Delay: 1.5s after result screen loads
- Offer: $4.99 Researcher's Kit (coins, rare cryptids, energy)
- Expires: 48 hours after first display
- `PlayerData.starter_pack_shown` prevents re-showing; `starter_pack_purchased` tracks conversion

### Battle Pass (Field Pass)
30-tier free track. Premium track exists in the data model but is not gated behind a paywall in the current build.

- XP source: `credibility_xp` from level completions
- XP per tier: 50
- Reward milestones (free track): tiers 0, 2, 4, 6, 9, 11, 14, 17, 19, 22, 24, 27, 29
- Reward milestones (premium track): tiers 0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 29
- Reward types: fragments, coins, energy hearts
- Claimed rewards stored in `PlayerData.tutorial_hints_shown` under `"bp_free_claimed"` / `"bp_premium_claimed"` keys

---

## 12. UI System

### Design Language
- **Viewport:** 540×960 portrait
- **Renderer:** Mobile
- **Stretch:** canvas_items, keep_width
- **Theme:** Dark backgrounds (Color 0.05–0.1, 0.1–0.15, 0.15–0.2 range), teal/cyan accents, gold highlights for important rewards
- **Fonts:** Default Godot font, sizes 8–48px depending on context

### Scene Hierarchy Model
Each screen is a `Control` or `Node2D` scene that owns its own layout. No shared scene trees between screens — everything is instantiated fresh on scene load.

UI components are preloaded scenes (`PackedScene`) instantiated programmatically rather than placed in `.tscn` files where possible. This keeps scenes lean and logic in GDScript.

### Programmatic UI
Most UI is built in `_ready()` via `add_child()` rather than in the Godot editor. This trades editor visibility for:
- Easier conditional layout (e.g., show/hide energy options based on state)
- Simpler parameterisation (no need to set properties via editor inspector)
- All layout logic readable in one place

### Common UI Components

| Component | File | Purpose |
|---|---|---|
| CurrencyBar | `scenes/ui/currency_bar.gd` | Horizontal fragment/coin/research display; auto-updates via EventBus |
| EnergyDisplay | `scenes/ui/energy_display.gd` | 5-heart row with regen countdown; updates every frame for timer |
| LevelNode | `scenes/ui/level_node.gd` | Map level button; locked/unlocked/completed states with star display |
| TeamPortrait | `scenes/ui/team_portrait.gd` | Cryptid button with mana bar; shake, pulse, ready label |
| TeamPanel | `scenes/ui/team_panel.gd` | 3-portrait row at bottom of game screen |
| CryptidCard | `scenes/ui/cryptid_card.gd` | Collected/uncollected card with rarity border |
| PreLevelPopup | `scenes/ui/pre_level_popup.gd` | Level summary + team editor before play |
| TeamSelector | `scenes/ui/team_selector.gd` | Filterable grid for assigning cryptids to team slots |
| GameOverPopup | `scenes/ui/game_over_popup.gd` | Continue (coins/ad) or give up |
| StarterPackPopup | `scenes/ui/starter_pack_popup.gd` | One-time IAP offer with 48h countdown |
| AdPlacement | `scenes/ui/ad_placement.gd` | Static ad stub (replace with real SDK) |
| BiomeSlot | `scenes/ui/biome_slot.gd` | Trail camera slot (empty / active / ready states) |
| ShopScreen | `scenes/ui/shop_screen.gd` | Energy packs + free ad card |
| BattlePassScreen | `scenes/ui/battle_pass_screen.gd` | 30-tier reward grid with claim buttons |

### Navigation Bar Pattern
Home, Map, Field Guide, Investigation, and Trail Camera screens each render a bottom navigation row with buttons to the other main screens. Navigation is direct (`SceneManager.change_scene()`), not stacked.

### Modal Pattern
Modals (TeamSelector, PreLevelPopup, StarterPackPopup, DailyLoginPopup, ShufflePopup) are added as children of the current screen with a full-rect semi-transparent overlay behind them. They are freed on dismiss/confirm.

### Overlay Layers

| Layer | Purpose |
|---|---|
| Default (0) | Game board, pieces, board UI |
| 50 | Celebration layer (result screen) |
| 100 | Scene transition fade overlay (SceneManager) |
| 200 | Debug menu |

---

## 13. Audio System

### Architecture
- 8 pooled `AudioStreamPlayer` nodes for SFX (prevents clipping on rapid concurrent sounds)
- 1 dedicated `AudioStreamPlayer` for music (one track at a time)
- All streams loaded on demand from disk and cached in `_sfx_cache` dict
- Supported formats: `.ogg`, `.wav`

### Auto-Triggered SFX

| Event Signal | SFX File |
|---|---|
| `swap_completed` | `swap` |
| `swap_failed` | `swap_fail` |
| `matches_cleared` | `match` |
| `piece_selected` | `select` |
| `ability_activated` | `ability_activate` |
| `mana_full` | `mana_full` |
| `investigation_result` | `gacha_reveal` |
| `camera_collected` | `camera_collect` |

### Music Tracks

| Screen/Event | Track |
|---|---|
| Home screen | `menu_theme` |
| Gameplay | `gameplay_theme` |
| Level complete | `victory_theme` |
| Game over | `defeat_theme` |

AudioManager skips re-triggering if the requested music is already playing (`_current_music_name` guard).

### SFX Pool Behavior
The 8 SFX players are iterated in round-robin to find a free player. If all 8 are busy, the oldest (first in list) is interrupted. This ensures sounds always play even during intensive cascade sequences.

### Adding New Audio
1. Drop `.ogg` or `.wav` into `res://assets/audio/sfx/` or `res://assets/audio/music/`
2. Emit `EventBus.play_sfx("filename_without_extension")` or `EventBus.play_music("filename")`
3. No code changes required

---

## 14. Animation System

### Board Animations
All board animations are async coroutines in `PieceAnimator`. Callers `await` them, which naturally serialises the state machine.

| Animation | Duration | Easing | Detail |
|---|---|---|---|
| Swap | 0.2s | QUAD OUT | Simultaneous on both pieces |
| Reject shake | 0.16s | — | 4-step horizontal oscillation ±8px |
| Clear | 0.3s | — | Scale→0 + alpha→0 simultaneously; spawns 6 particle squares |
| Clear particles | 0.25–0.45s | QUAD OUT | 6 colored squares radiate outward and fade |
| Fall | 0.1–0.4s | CUBIC OUT | Duration = max(0.1, distance × 0.12) |
| Spawn | 0.3s | CUBIC OUT | Enters from above board, falls to position |
| Booster create | 0.35s | BACK OUT | Grows to 1.4× then settles back |
| Shuffle | 0.4s | QUAD IN_OUT | All pieces simultaneously |
| Hint pulse | looping | SINE | Scale 1.0↔1.1 on two hint pieces |
| Screen shake | 0.25s | — | Positional offsets with exponential decay |

### Piece Animations
Pieces run their own continuous looping animations when they have a booster:
- **Glow pulse:** `modulate.a` oscillates 0.6↔1.0 on a 0.7s loop
- **Scale pulse:** scale breathes 1.0↔1.03 on a 1.2s loop

### UI Animations
All UI tweens are created with `create_tween()` on the node that owns them, so they are automatically stopped if that node is freed.

| UI Animation | Where | Detail |
|---|---|---|
| Score bounce | GameScreen | Score label pops to 1.2× then back on each change |
| Star reveal | ResultScreen | 3 stars fade in sequentially (0.3s apart), earned stars bounce |
| Ability banner | GameScreen | Slides in from top, holds 1s, fades out |
| Cascade label | GameScreen | Pops in at 1.5× on each cascade, shrinks to 1× |
| Shield tint | GameScreen | Instant tint on moves label (cyan); instant reset on swap |
| Portrait pulse | TeamPortrait | Element circle pops to 1.1× when mana is charged |
| Not-ready shake | TeamPortrait | Horizontal shake + brief "NOT READY" flash |
| Celebration cards | ResultScreen | Stagger entrance (0.2s per card), leader floats + glows on loop |
| Celebration particles | ResultScreen | GPU burst particles (gold) + mist (teal); intensity scales with stars |
| Scene transition | SceneManager | ColorRect fade to black (0.2s out, 0.2s in) |
| Daily login popup | DailyLoginSystem | Auto-dismisses after 3.5s |

### VFX Flash Overlays
Short-lived `ColorRect` nodes added as children of `BoardContainer` or the screen root:
- **Ability flash:** Full-screen white (alpha 0.35), fades in 0.4s
- **Row clear:** Yellow horizontal bar at cleared row, fades 0.4s
- **Column clear:** Blue vertical bar at cleared column, fades 0.4s
- **Area clear:** Orange square at cleared area, expands +8px and fades 0.5s
- **Booster create:** Yellow radial flash at booster cell, expands 30% and fades 0.5s

---

## 15. Input System

### Input Handling
Implemented in `BoardInput` as a child node of the Board. All input is consumed here; no other node processes board touch.

### Click-to-Swap
1. Click piece A → selected (scale highlight starts)
2. Click adjacent piece B → `swap_requested(A, B)` emitted
3. Click non-adjacent piece → deselect A, select B instead
4. Click empty/same piece → deselect

### Swipe-to-Swap
1. Press down on piece A → record start position
2. Move finger/cursor beyond 40px threshold
3. Release → determine dominant axis (|dx| vs |dy|)
4. Emit `swap_requested(A, adjacent_in_dominant_direction)`

### Input Guards
Board input is gated by:
- `GameManager.state == PLAYING` (no input during pause, game over, level complete)
- `Board.state == IDLE` (no input during animations)

These checks happen in `BoardInput` before emitting and in `Board._on_swap_requested` as a second guard.

### Platform
Input works identically for mouse (`InputEventMouseButton`, `InputEventMouseMotion`) and touch (`InputEventScreenTouch`, `InputEventScreenDrag`). Godot 4's input system handles both transparently.

---

## 16. Scene Management System

### Scene Graph
Each screen is a standalone scene loaded and unloaded completely. There is no persistent scene tree between screens except for the 5 autoload singletons.

### Transition Flow
```
SceneManager.change_scene(path, duration=0.4)
  1. Guard: if already transitioning, return
  2. ResourceLoader.load_threaded_request(path)   ← non-blocking
  3. Tween overlay alpha 0→1 (0.2s)
  4. Poll ResourceLoader until LOADED
  5. get_tree().change_scene_to_packed(resource)
  6. Tween overlay alpha 1→0 (0.2s)
```

The overlay is a `ColorRect` on a `CanvasLayer` (layer 100) parented to the SceneManager node. It uses `PROCESS_MODE_ALWAYS` so transitions work correctly even when the tree is paused.

### Instant Transitions
`change_scene_instant(path)` is available for cases where fade is undesirable (e.g., returning to the main menu from a paused state where the overlay is already black).

### Boot Preloading
`BootScreen` calls `ResourceLoader.load_threaded_request()` for all 7 main scenes before transitioning to home. After boot, `change_scene()` calls hit the cache immediately (sub-frame) rather than loading from disk, keeping transitions under the 0.4s fade.

---

## 17. Save & Persistence System

### Format
JSON file at `user://player_save.json`. Human-readable for debugging. All fields use primitive types (int, float, string, bool, dict, array).

### Complete Schema
```json
{
  "evidence_fragments":    500,
  "cryptid_coins":         150,
  "research_data":         20,
  "collected_cryptids": {
    "bigfoot_scout": { "level": 1, "duplicates": 0 }
  },
  "active_team":           ["bigfoot_scout", "mothman_observer", "nessie_pup"],
  "highest_level_completed": 7,
  "level_stars":           { "1": 3, "2": 2, "3": 3 },
  "total_stars":           8,
  "credibility_xp":        180,
  "energy":                3,
  "last_energy_time":      1715000000.0,
  "pity_rare":             12,
  "pity_epic":             34,
  "starter_pack_shown":    true,
  "starter_pack_purchased": false,
  "tutorial_completed":    false,
  "tutorial_hints_shown": {
    "first_match":         true,
    "disc_cascade_first":  true,
    "bp_free_claimed":     [0, 2, 4],
    "bp_premium_claimed":  []
  },
  "trail_cameras": {
    "pacific_nw": { "placed_time": 1715000000.0, "duration_hours": 8 }
  },
  "login_streak":          3,
  "last_login_day":        19842
}
```

### Save Triggers
Saves are written synchronously (no async) via `FileAccess.open(SAVE_PATH, FileAccess.WRITE)`:

| Event | Trigger |
|---|---|
| Energy spent or refilled | Immediately in `use_energy()` / `refill_energy()` |
| Currency earned/spent | Immediately in `add_fragments()`, `spend_coins()`, etc. |
| Level completed | In `record_level_complete()` |
| Hint/discovery shown | In `mark_hint_shown()` |
| Gacha pull | In `add_cryptid()` and after pity update |
| Daily login | In `check_daily_login()` |
| Trail camera placed/collected | In `TrailCameraSystem` |

### Load
On app start, `PlayerData._ready()` calls `load_data()` which reads the JSON file, applies all fields with `.get()` defaults for missing keys (safe forward-compatibility), then calls `_regen_energy()` to catch up any offline regen.

### Energy Regen Offline
`last_energy_time` stores the Unix timestamp of the last energy state change (when it was last below max). On load:
```
elapsed  = now - last_energy_time
gained   = floor(elapsed / 1500)   # 1 heart per 1500s (25 min)
energy   = min(energy + gained, 5)
last_energy_time = now - (elapsed mod 1500)   # preserve partial progress
```

### Multi-Use of `tutorial_hints_shown`
This dictionary is overloaded as a general-purpose persistent flag store:
- `"hint_id"` = true → shown tutorial hints
- `"disc_id"` = true → triggered discovery moments
- `"bp_free_claimed"` = Array[int] → claimed Battle Pass free tier indices
- `"bp_premium_claimed"` = Array[int] → claimed Battle Pass premium tier indices

---

## 18. Tutorial & Discovery System

### Hint System
Context-sensitive hints appear after 30s of inactivity (cooldown) or on specific game events. Hints are never shown twice (`PlayerData.tutorial_hints_shown` flag).

### 9 Predefined Hints

| Hint ID | Style | Trigger | Level Gate |
|---|---|---|---|
| first_match | Pulse | board_ready | L1 only |
| cascade_intro | Arrow | matches_cleared (cascade ≥ 1) | L2+ |
| collect_intro | Whisper | board_ready with COLLECT goal | L3+ |
| match_4_tip | Silhouette | matches_cleared (4+ pieces) | — |
| ice_intro | Arrow | board_ready with ICE obstacles | L4+ |
| web_intro | Silhouette | board_ready with WEB obstacles | L7+ |
| booster_tip | Pulse | persistent_booster_created | — |
| mana_intro | Whisper | mana_full | — |
| ability_ready | Arrow | mana_full | — |

### Hint Styles
- **Pulse:** Two pieces of the best valid swap pulse with a scale animation, directing attention
- **Arrow:** Directional indicator between the two swap pieces
- **Whisper:** Semi-transparent text overlay over the board
- **Silhouette:** Dark dimmed panel with centered explanatory text

### Discovery System (Feature Trickle)
One-time full-screen popups revealing a mechanic for the first time. Triggered by specific `LevelData.discovery_id` strings. Each discovery:
1. Checks `PlayerData.tutorial_hints_shown["disc_" + id]` — skip if already seen
2. Queues at high priority (jumps the hint queue)
3. Shows a styled modal with the level's `flavor_text`
4. Grants a small reward (fragments, XP, or extra moves)
5. Marks `"disc_" + id` in `tutorial_hints_shown`

### Discovery IDs

| ID | Mechanic | Typical Level |
|---|---|---|
| cascade_first | First cascade | L2 |
| ice_first | Ice obstacles | L4 |
| booster_first | Persistent boosters | L5–6 |
| mana_first | Mana bars | L3 |
| combo_first | Multi-booster chain | L8+ |
| persistent_booster | Booster survives round | L6 |

### Queue & Cooldown
- Cooldown: 30s between any hints
- Discoveries bypass cooldown and jump the queue
- If a discovery is pending and a regular hint fires, discovery plays first
- Between queued items: 0.5s gap

---

## 19. Daily Engagement Systems

### Daily Login Streak

**Logic:**
1. On each app launch, `DailyLoginSystem.check_and_show(parent)` is called from HomeScreen
2. Current day = `floori(Time.get_unix_time_from_system() / 86400)`
3. If `current_day > last_login_day`: new day detected
4. If `current_day - last_login_day == 1`: consecutive → increment streak
5. If gap > 1: streak resets to 1
6. Show reward popup if new day

**7-Day Reward Cycle:**

| Day in Cycle | Fragments | Energy | Title |
|---|---|---|---|
| 1 (day 0) | +20 | +1 | "Welcome back, investigator!" |
| 2 (day 1) | +20 | +1 | "Another day in the field!" |
| 3 (day 2) | +20 | +1 | "Steady progress!" |
| 4 (day 3) | +35 | +2 | "Dedication rewarded!" |
| 5 (day 4) | +35 | +2 | "Almost a full week!" |
| 6 (day 5) | +50 | +3 | "Expert investigator streak!" |
| 7 (day 6) | +100 | Full refill | "LEGENDARY STREAK! One full week!" |

Streak counter is shown in the popup (e.g., "Day 5 streak!"). Popup auto-dismisses after 3.5s or on tap.

### Trail Camera System
Passive idle reward system — cameras earn resources while the app is closed.

**Flow:**
1. Player visits Trail Camera screen
2. Each biome slot shows: Empty / Active (with countdown) / Ready (collect button)
3. Player places camera for 4, 8, 12, or 24 hours
4. Camera runs in real time (uses Unix timestamp comparison)
5. On collection, rewards are calculated and granted

**Reward Calculation:**
```
fragments  = duration_hours × random_int(5, 12)
coins      = 20% chance → random_int(10, 30)
free_pull  = 5%  chance → grants 100 fragments (one gacha pull)
```

**6 Biomes** (match the 6 regions):
- Pacific Northwest, Point Pleasant, Scotland, Puerto Rico, Himalayas, Pine Barrens

All 6 biomes are always available for camera placement regardless of region unlock status.

**UI States per slot:**
- Empty: biome name + duration selector (4h/8h/12h/24h) + Place button
- Active: biome name + `StatusLabel = "Active"` (yellow) + countdown timer
- Ready: biome name + `StatusLabel = "READY!"` (green) + Collect button + reward preview

Timer updates every frame (`_process` in `trail_camera_screen.gd` calls `update_timer()` on each slot).

### Battle Pass (Field Pass)
30-tier progression track driven by `credibility_xp`. One XP source: level completions (`10 + stars × 5`).

- **XP per tier:** 50 (tier = `floor(credibility_xp / 50)`)
- **Free track rewards:** 13 milestone tiers (mix of fragments, coins, energy)
- **Premium track:** Data defined but not paywalled in current build
- **Claiming:** Rewards claimed manually by tapping unlocked tier cells; claimed state stored in `tutorial_hints_shown`
- **XP bar:** Shows current tier progress and XP to next tier

---

## 20. Analytics System

### Event Tracking
`AnalyticsManager` connects to EventBus and logs structured events. Current implementation prints to console — replace `_log_event(name, params)` body with a real SDK (Firebase Analytics, GameAnalytics, Unity Analytics, etc.).

### Auto-Tracked Events

| Event Name | Trigger | Key Parameters |
|---|---|---|
| `level_started` | `game_started` | level, moves, goal_type |
| `level_completed` | `level_completed` | level, score, stars |
| `game_over` | `game_over` | level, score, stars |
| `ability_activated` | `ability_activated` | cryptid_id |
| `shuffle_used` | `shuffle_used` | — |
| `daily_login` | `daily_login_reward` | streak |
| `gacha_pull` | `investigation_result` | cryptid_id, rarity |
| `energy_empty` | `energy_empty` | — |
| `battle_pass_xp` | `battle_pass_xp_gained` | amount |

### Custom Events
Any system can emit custom analytics via:
```gdscript
EventBus.analytics_event.emit("custom_event_name", {"key": value})
```

---

## 21. Debug System

`DebugMenu` (autoload, layer 200) toggled with **F12** or via the semi-transparent DBG button on HomeScreen.

### Sections

| Section | Capabilities |
|---|---|
| Build | Toggle `is_testing_build` (energy bypass) |
| Currencies | Add/set fragments, coins, research data |
| Energy | Refill to max, set to 0, skip regen timer |
| Progression | Set highest level, batch-complete L1–30, unlock all regions, set credibility XP |
| Collection | Grant cryptids by rarity (1 of each), clear entire collection, set slot 0 as leader |
| Gacha | Set pity to 29/89 (one pull from guarantee), reset pity, free 10-pull |
| Game State | Add score, add moves, force win, force lose, activate shield, set cascade multiplier |
| Tutorial | Mark tutorial done, reset all hints, show/clear specific hints |
| Navigation | Direct jump to any scene |
| Danger Zone | Reset: all data, stars only, progression only, flags only |

All actions rebuild the debug panel immediately so values are accurate after each action. The debug button on HomeScreen has 40% opacity to be unobtrusive in screenshots.

---

## Extensibility Quick Reference

| To add... | Change these files |
|---|---|
| New piece color | `PieceData` (enum + color + name), `CryptidDatabase` (5 new cryptids), `LevelData` (include in num_colors) |
| New obstacle type | `LevelData.ObstacleType`, `Board._draw()`, `Board.damage_obstacle()`, `Board._process_obstacle_damage()` |
| New ability type | `CryptidData.AbilityType`, `AbilitySystem.try_activate_ability()` match block |
| New booster type | `PieceData.BoosterType`, `Board._determine_boosters()`, `Board._get_booster_effect()`, `Piece._draw()`, `PieceAnimator` |
| New leader skill | `CryptidData.LeaderSkillType`, `LeaderSkillSystem` (new getter), call site in affected system |
| New goal type | `LevelData.GoalType`, `GameManager._init_goals()`, `GameManager._advance_goal()` or new signal handler |
| New region | `RegionData.get_all_regions()`, `LevelData.CATALOG` (15 new levels) |
| New cryptid | `CryptidDatabase._init_database()` |
| New discovery | `LevelData.DISCOVERIES` dict entry, assign `discovery_id` in level definition |
| Real ads | Implement `AdPlacement.show_rewarded()` with actual ad SDK |
| Real IAP | Replace `ShopSystem.purchase_pack()` print with actual IAP SDK call |
| Real analytics | Replace `AnalyticsManager._log_event()` body with actual SDK call |
| New SFX | Drop `.ogg` into `res://assets/audio/sfx/`, emit `EventBus.play_sfx("name")` |
| New music | Drop `.ogg` into `res://assets/audio/music/`, emit `EventBus.play_music("name")` |
