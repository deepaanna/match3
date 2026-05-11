# Cryptid Clash — Software Architecture

> Last updated: 2026-05-10

---

## Table of Contents

1. [Project Layout](#1-project-layout)
2. [Autoload Singletons](#2-autoload-singletons)
3. [Board Engine](#3-board-engine)
4. [Data Layer](#4-data-layer)
5. [Gameplay Systems](#5-gameplay-systems)
6. [Screen Scenes](#6-screen-scenes)
7. [Key Signal Chains](#7-key-signal-chains)
8. [Persistence Schema](#8-persistence-schema)
9. [Design Patterns Summary](#9-design-patterns-summary)

---

## 1. Project Layout

```
Cryptid Clash/
├── scripts/
│   ├── autoload/       ← Global singletons (EventBus, GameManager, PlayerData, SceneManager, AudioManager, DebugMenu)
│   ├── board/          ← Board engine (Board, BoardInput, MatchFinder, PieceAnimator)
│   ├── data/           ← Static data classes (PieceData, GameConfig, LevelData, CryptidData, CryptidDatabase, RegionData, CredibilityData)
│   └── systems/        ← Runtime systems (ManaSystem, AbilitySystem, LeaderSkillSystem, GachaSystem, TrailCameraSystem, DailyLoginSystem, AnalyticsManager, TutorialManager, ShopSystem)
└── scenes/
    ├── *.gd            ← Screen controllers (splash, boot, home, map, game, result, field_guide, investigation, trail_camera)
    ├── piece.gd        ← Single board piece visual
    └── ui/             ← Reusable UI components (team_panel, team_portrait, cryptid_card, currency_bar, energy_display, level_node, pre_level_popup, team_selector, starter_pack_popup, game_over_popup, shop_screen, battle_pass_screen, biome_slot, ad_placement)
```

---

## 2. Autoload Singletons

Five globals registered in Godot project settings, always available. Load order matters — EventBus is first so all other singletons can connect to it in their own `_ready()`.

```
EventBus  →  GameManager  →  PlayerData  →  SceneManager  →  AudioManager
```

---

### EventBus
**`scripts/autoload/event_bus.gd`**

Pure signal hub — no logic, no state. Every cross-system communication goes through here. ~50 signals organised into groups:

| Group | Key Signals |
|---|---|
| Game state | `game_started`, `game_paused/resumed`, `game_over(score, stars)`, `level_completed(score, stars)` |
| Board | `swap_requested/completed/failed`, `matches_found/cleared`, `board_settled`, `pieces_fell/spawned` |
| Obstacles | `obstacle_damaged(col, row, hp)`, `obstacle_cleared(col, row, type)` |
| Mana/Ability | `mana_charged(piece_type, amount)`, `mana_full(cryptid_id)`, `ability_activated/resolved` |
| Goals | `pieces_collected(type, count)`, `goal_progress_updated(id, cur, tgt)`, `goal_completed(id)`, `all_goals_completed` |
| Progression | `level_selected(n)`, `credibility_changed`, `star_total_changed` |
| Collection | `cryptid_obtained(id, is_new)`, `fragments/coins_changed` |
| Energy | `energy_changed`, `energy_empty`, `energy_refilled` |
| Monetization | `energy_refill_requested`, `rewarded_ad_requested(type)`, `reward_doubled` |
| Boosters/VFX | `persistent_booster_created(col, row, type)`, `vfx_request(effect, pos)` |
| UI/Shuffle | `no_moves_detected(is_free)`, `shuffle_confirmed`, `shuffle_used` |
| Discovery | `discovery_moment(id, flavor_text)`, `tutorial_hint_show/dismiss` |
| Analytics | `analytics_event(name, params)` |
| Daily | `daily_login_reward(streak, reward)` |

---

### GameManager
**`scripts/autoload/game_manager.gd`**

Owns the game loop. Everything that changes during a play session lives here.

**State machine:**
```
IDLE  →  PLAYING  →  PAUSED  →  PLAYING
                  ↓
              GAME_OVER
                  ↓
           LEVEL_COMPLETE
```

**Per-session data:**

| Variable | Purpose |
|---|---|
| `score` | Running score for the level |
| `moves_remaining` | Decrements on each valid swap (shield skips decrement) |
| `cascade_multiplier` | Starts at 1.0, +0.5 per cascade level, resets on board settle |
| `current_level` / `current_level_data` | Level number and LevelData resource |
| `_shield_active` | If true, next swap costs no move (emits `shield_activated` on set) |
| `_goals` | `{goal_id: {current, target}}` — tracks sub-goal progress |
| `_goals_met` | True once all sub-goals complete |
| `last_reward_fragments/coins` | Read by ResultScreen for reward display |

**Goal types** (`LevelData.GoalType`):

| Type | How Tracked |
|---|---|
| SCORE | Via star threshold at moves end; no sub-goal dict entry |
| COLLECT | `pieces_collected` signal filtered by piece type |
| CLEAR_OBSTACLES | `obstacle_cleared` signal filtered by ice/web |
| CHARGE_MANA | `mana_full` signal, counts each trigger |
| MIXED | Any combination of the above sub-goals |

**Score flow:**
```
add_score(base_points)
  × cascade_multiplier          ← increments +0.5 per cascade level
  × leader_skill_score_mult     ← from LeaderSkillSystem
  = final_points added to score
```

**End condition** (checked on every `board_settled`):
1. Non-score goals all met → `_complete_level_with_bonus()` → victory detonation if moves remain, else `_record_completion(stars)`
2. Moves hit zero → score → star rating → record (≥1 star) or game over (0 stars)

**Rewards on completion:**
- Fragments: `10 + stars × 5`, plus `+15` first-clear bonus
- Coins: `[0, 8, 12, 18][stars]`
- Credibility XP: `10 + stars × 5`

---

### PlayerData
**`scripts/autoload/player_data.gd`**

All persistent player state. Saves to `user://player_save.json` as JSON.

| Group | Variables |
|---|---|
| Currencies | `evidence_fragments`, `cryptid_coins`, `research_data` |
| Collection | `collected_cryptids` (id→{level, duplicates}), `active_team` [3 ids] |
| Progression | `highest_level_completed`, `level_stars` (level→stars), `total_stars`, `credibility_xp` |
| Energy | `energy` (0–5), `last_energy_time` (Unix float) |
| Gacha pity | `pity_rare` (soft cap 30), `pity_epic` (hard cap 90) |
| Flags | `starter_pack_shown/purchased`, `tutorial_completed`, `tutorial_hints_shown` (id→true) |
| Trail cameras | `trail_cameras` (biome_id→{placed_time, duration_hours}) |
| Login | `login_streak`, `last_login_day` (Unix day integer) |

**Energy regen logic:**
- 25 min per heart (`ENERGY_REGEN_SECONDS = 1500`)
- On load: `_regen_energy()` catches up any hearts earned offline
- On spend from full: regen timer starts fresh
- On spend while regenerating: timer is preserved (partial progress kept)
- `get_energy_regen_remaining()` → seconds until next heart

**Save triggers:** after energy change, every currency transaction, every level completion, after hints shown, on scene transition.

---

### SceneManager
**`scripts/autoload/scene_manager.gd`**

Threaded scene loading with fade-to-black overlay.

```
change_scene(path, duration=0.4)
  → ResourceLoader.load_threaded_request(path)
  → Fade overlay in (CanvasLayer layer=100)
  → Poll until loaded
  → get_tree().change_scene_to_packed()
  → Fade overlay out
```

---

### AudioManager
**`scripts/autoload/audio_manager.gd`**

Pool of 8 `AudioStreamPlayer` nodes for concurrent SFX, plus 1 dedicated music player.

- Streams loaded on demand and cached in `_sfx_cache` dict
- SFX path: `res://assets/audio/sfx/<name>.ogg`
- Music path: `res://assets/audio/music/<name>.ogg`
- Auto-connects to EventBus: swap, match, select, ability, mana_full, gacha reveals, camera collect

---

### DebugMenu
**`scripts/autoload/debug_menu.gd`**

Toggle with F12. CanvasLayer at layer 200. Collapsible sections with live rebuild on action.

Sections: currency injection, energy override, level/progression control, collection management, gacha pity manipulation, mid-game cheats (score, moves, shield, cascade), tutorial reset, scene jumper, and danger-zone save wipes.

---

## 3. Board Engine

The board is a `Node2D` child of `BoardContainer` inside GameScreen. It owns match logic, cascade orchestration, obstacle management, and booster creation.

### Board
**`scripts/board/board.gd`**

**Grid data model:**
- `grid[col][row]` → PieceType int (column-major, row 0 = top, 8×8)
- `piece_nodes[col][row]` → Sprite2D node (mirrors grid exactly)
- `obstacle_grid[col][row]` → ObstacleType (NONE / ICE / WEB)
- `obstacle_hp[col][row]` → int (HP per obstacle cell)

**State machine:**
```
IDLE
  → SWAPPING   (await swap animation)
      ↓ match?
  No  → SWAP_BACK → IDLE
  Yes → CHECKING
      → CLEARING   (clear matched pieces + booster chains)
      → FALLING    (gravity)
      → FILLING    (spawn new pieces)
      → CHECKING   (cascade loop, cascade_level++)
          ↓ no more matches
      → IDLE  (via _settle_board)

ABILITY  (during cryptid ability execution — bypasses normal flow)
```

**Initialization sequence:**
1. `_load_level_config()` — sets `_num_colors` from LevelData (3–6)
2. `_init_grid()` — fills grid with random pieces, places obstacles and pre-set boosters, avoids initial 3-matches via `_get_random_piece_no_match()`
3. `_resolve_initial_matches()` — second pass to re-roll any remaining matches
4. `_spawn_initial_pieces()` — creates Sprite2D nodes for every cell

**Swap handling (`_on_swap_requested`):**
1. Guards: state must be IDLE, GameManager must be PLAYING, cells must be valid and adjacent
2. Web check: both cells must be web-free
3. `state = SWAPPING`, start cascade tracking
4. `await _do_swap()` — swaps data + nodes, awaits animation
5. Re-check `GameManager.state` (game may have ended during the animation)
6. Find match groups — if none: swap back + reject animation; if match: proceed

**Match processing (`_process_match_groups`):**
1. Flatten all matched positions
2. Activate any boosters in the match set (chain-react via BFS queue)
3. Emit mana charges for full clear set (before clearing)
4. Emit piece collection counts per type
5. Determine new boosters to create (4-match → line, 5-match → color bomb, L/T/cross → area bomb)
6. Exclude booster-creation spots from clearing
7. Damage obstacles adjacent to cleared positions
8. `await _clear_pieces()` — animate out, return to pool
9. Emit `matches_cleared(count, cascade_level)` → GameManager scores points
10. Screen shake (scales with cascade depth and booster activations)
11. Create new boosters with creation animation
12. `await _apply_gravity()` → pieces fall into gaps
13. `await _fill_empty()` → spawn new pieces from top
14. Find new match groups; if found: `cascade_level++`, recurse. If not: `_settle_board()`

**Cascade safety:** after 3 natural cascades (`_natural_cascade_count`), `_fill_empty()` uses `_get_safe_type()` instead of random. `_get_safe_type` checks all 6 conflict patterns (left-left, right-right, left-right, up-up, down-down, up-down) and excludes conflicting types.

**Booster system:**

| Match Shape | Booster Created | Effect When Matched |
|---|---|---|
| 4 in a row (H) | LINE_H | Clears entire row |
| 4 in a row (V) | LINE_V | Clears entire column |
| L / T / cross shape | AREA_BOMB | Clears 3×3 area |
| 5 in a row | COLOR_BOMB | Clears all pieces of same color |

Boosters are **persistent** — they remain on the board as a special piece until they appear in a future match. Chain reactions activate via BFS through `_collect_booster_activations()`.

**Obstacle damage:**

| Obstacle | Damage Trigger |
|---|---|
| ICE | When the piece sitting on the ice cell is cleared |
| WEB | When a piece in an adjacent (non-web) cell is cleared; prevents double-damage on same-frame clears |

**Deadlock detection (`_ensure_valid_board`):**
- After every board settle, `has_valid_moves()` tests all adjacent swap pairs
- If no valid moves: first shuffle per level is free (auto with toast), subsequent shuffles await `shuffle_confirmed` signal (coin cost)
- Quit/Home always emit `shuffle_confirmed` first to unblock any pending await
- Up to 10 shuffle attempts; post-shuffle matches are processed immediately

**Hint system:**
- `_hint_timer` increments only when board is IDLE and GameManager is PLAYING
- After `HINT_IDLE_DELAY` (5s): `_show_hint()` pulses the two pieces of a valid swap
- Timer resets on any board activity

**Coordinate math:**
- `grid_to_pixel(col, row)` → `Vector2(BOARD_OFFSET_X + col * CELL_SIZE, BOARD_OFFSET_Y + row * CELL_SIZE)`
- `pixel_to_grid(pos)` → `Vector2i(floori(...), floori(...))` — uses `floori()` not `int()` to handle negative coords correctly

---

### BoardInput
**`scripts/board/board_input.gd`**

Translates mouse/touch events into `swap_requested` signals.

- **Click:** select piece; click adjacent piece → emit `swap_requested`
- **Swipe:** track press position; on release with min distance 40px → dominant axis determines swap direction
- Deselects on invalid tap; re-selects on tap of a different piece

---

### MatchFinder
**`scripts/board/match_finder.gd`**

Two-pass grid scanner (horizontal then vertical).

- `find_match_groups(grid)` → `Array[{positions, size, direction, piece_type}]` — used for booster creation detection (direction matters)
- `find_matches(grid)` → `Array[Vector2i]` (deduplicated flat list) — used for move validation

---

### PieceAnimator
**`scripts/board/piece_animator.gd`**

All board tweens. Every function is `async` and resolves after the animation completes.

| Function | Duration | Description |
|---|---|---|
| `animate_swap` | 0.2s | Quad ease between two world positions |
| `animate_reject` | 0.16s | Horizontal shake (±8px, 4 steps) |
| `animate_clear` | 0.3s | Scale→0 + alpha→0; spawns 6 burst particle squares |
| `animate_fall` | 0.1–0.4s | Cubic ease; duration = max(MIN, dist × PER_CELL) |
| `animate_spawn` | 0.3s | Pieces fall in from above the board |
| `animate_booster_create` | 0.35s | Pulse grow ×1.4, back-ease settle to 1.0 |
| `animate_shuffle` | 0.4s | All pieces quad-ease to new positions simultaneously |
| `animate_hint` | looping | Scale pulse ×1.1 on two pieces |
| `animate_shake` | 0.25s | Positional shake with decay on a node |

---

### Piece
**`scenes/piece.gd`** (`extends Sprite2D`)

Single board piece visual.

**State:**
- `piece_type` (PieceType int)
- `booster_type` (BoosterType int)
- `grid_col`, `grid_row` (current position in grid)
- `is_selected`

**Texture:** One shared 64×64 procedural circle with antialiased edges, colored via `self_modulate`.

**Booster overlay (`_draw`):** rendered on top of the circle each frame:
- All boosters: two white concentric arc rings (glow effect)
- LINE_H: left/right arrows with chevrons
- LINE_V: up/down arrows
- AREA_BOMB: 8-point starburst + solid center circle
- COLOR_BOMB: 5-pointed rainbow star

**Booster animations (looping):**
- Glow pulse: `modulate.a` oscillates dim↔bright every 0.7s
- Scale pulse: gentle breathing 1.0↔1.03 every 1.2s

---

## 4. Data Layer

All data classes are pure GDScript with no scene dependency.

### PieceData
**`scripts/data/piece_data.gd`**

```
PieceType:   NONE, BIGFOOT(0), MOTHMAN(1), NESSIE(2), CHUPACABRA(3), YETI(4), JERSEY_DEVIL(5)
BoosterType: NONE, LINE_H, LINE_V, AREA_BOMB, COLOR_BOMB
Colors:      Brown,  Red,     Blue,   Green,       White,  Purple
```

---

### GameConfig
**`scripts/data/game_config.gd`**

All magic numbers in one place:

| Category | Key Constants |
|---|---|
| Grid | `GRID_COLS=8`, `GRID_ROWS=8`, `CELL_SIZE=60`, `BOARD_OFFSET_X=30`, `BOARD_OFFSET_Y=240` |
| Timing | `SWAP_DURATION=0.2`, `CLEAR_DURATION=0.3`, `FALL_DURATION_PER_CELL=0.12`, `FALL_MIN=0.1`, `SPAWN_DURATION=0.3` |
| Scoring | `MATCH_BASE_SCORE=50`, `EXTRA_PIECE_BONUS=25`, `CASCADE_MULTIPLIER_INCREMENT=0.5`, `BOOSTER_CREATE_SCORE=100`, `BOOSTER_ACTIVATE_SCORE=200` |
| Boosters | `AREA_BOMB_RADIUS=1`, min match sizes per booster type |
| Shake | `SHAKE_SMALL`, `SHAKE_MEDIUM`, `SHAKE_LARGE` intensity values |
| UI | `TEAM_PANEL_Y=730`, `HINT_IDLE_DELAY=5.0` |

---

### LevelData
**`scripts/data/level_data.gd`**

Resource class — one instance per level.

```gdscript
var level_number:  int
var max_moves:     int
var star_1_score:  int
var star_2_score:  int
var star_3_score:  int
var num_colors:    int          # 3–6
var goal_type:     GoalType
var goal_params:   Dictionary   # varies by goal type
var obstacles:     Array        # [{col, row, type, hp}]
var pre_boosters:  Array        # [{col, row, booster_type}]
var moves_bonus:   bool         # enable victory detonation on early completion
var region_id:     String
var flavor_text:   String
var discovery_id:  String       # one-time feature trickle trigger
```

**30 hard-coded levels:**
- Pacific Northwest (1–15): introduces ice (L4), webs (L7), mixed goals (L10 boss), escalating difficulty
- Point Pleasant (16–30): higher color count, more obstacles, complex mixed goals, bosses at L20/L25/L30
- `get_level(n)` returns from catalog or generates safe defaults for n > 30

**Discovery system:** One-time popups bound to specific `discovery_id` strings. IDs: `cascade_first`, `ice_first`, `booster_first`, `mana_first`, `combo_first`, `persistent_booster`. Each has themed flavor text and a small reward (fragments, XP, extra moves).

---

### CryptidData
**`scripts/data/cryptid_data.gd`**

One resource per cryptid variant.

```gdscript
var cryptid_id:          String   # e.g. "bigfoot_alpha"
var display_name:        String   # "Bigfoot"
var variant_name:        String   # "Alpha"
var base_cryptid:        int      # PieceType — which piece color charges this cryptid's mana
var rarity:              int      # 0 COMMON … 4 LEGENDARY
var ability_type:        int      # AbilityType enum
var mana_cost:           int      # pips to fill the mana bar
var ability_power:       int      # rows/radius/tiles/points (depends on ability_type)
var leader_skill_type:   int      # NONE / SCORE_MULT / MANA_MULT / EXTRA_MOVES
var leader_skill_value:  float
var flavor_text:         String
```

**Ability types:**

| Type | Effect | `power` Meaning |
|---|---|---|
| CLEAR_ROW | Clears `power` random rows | number of rows |
| CLEAR_COLUMN | Clears `power` random columns | number of columns |
| CLEAR_AREA | Clears `(2×power+1)²` area | radius |
| CONVERT_TILES | Converts `power` non-matching pieces to cryptid color | tile count |
| SCORE_BOOST | `GameManager.add_score(power)` | points |
| EXTRA_MOVES | `GameManager.grant_extra_moves(power)` | move count |
| SHIELD | Next swap costs no move | — |

**Leader skill types:**

| Type | Applied By |
|---|---|
| SCORE_MULTIPLIER | `GameManager.add_score()` |
| MANA_MULTIPLIER | `ManaSystem._on_mana_charged()` |
| EXTRA_STARTING_MOVES | `GameManager.start_game()` |

---

### CryptidDatabase
**`scripts/data/cryptid_database.gd`**

Lazy-initialised static registry of all 30 cryptids.

| Base (Color) | Common | Uncommon | Rare | Epic | Legendary |
|---|---|---|---|---|---|
| Bigfoot (Brown) | Scout | Tracker | Elder | Alpha | Ancient |
| Mothman (Red) | Observer | Herald | Prophet | Dread | Doom |
| Nessie (Blue) | Pup | Swimmer | Guardian | Leviathan | Primordial |
| Chupacabra (Green) | Lurker | Stalker | Hunter | Nightmare | Devourer |
| Yeti (White) | Cub | Nomad | Sentinel | Avalanche | Abominable |
| Jersey Devil (Purple) | Imp | Fiend | Terror | Infernal | 13th Child |

Starter team: `bigfoot_scout`, `mothman_observer`, `nessie_pup`.

---

### RegionData
**`scripts/data/region_data.gd`**

| Region | Levels | Stars Required |
|---|---|---|
| Pacific Northwest | 1–15 | 0 (always unlocked) |
| Point Pleasant | 16–30 | 15 |
| Scotland | 31–45 | 35 |
| Puerto Rico | 46–60 | 60 |
| Himalayas | 61–75 | 90 |
| Pine Barrens | 76–90 | 125 |

---

### CredibilityData
**`scripts/data/credibility_data.gd`**

| XP Threshold | Rank |
|---|---|
| 0 | Curious Tourist |
| 100 | Amateur Investigator |
| 350 | Field Researcher |
| 750 | Seasoned Tracker |
| 1500 | Expert Cryptozoologist |
| 3000 | Master Investigator |
| 5500 | Renowned Authority |
| 10000 | Legendary Tracker |

---

## 5. Gameplay Systems

All systems are instantiated as child Nodes by `GameScreen._setup_systems()`. They are **not autoloads** — they only exist for the duration of active gameplay.

---

### ManaSystem
**`scripts/systems/mana_system.gd`**

Tracks one mana bar per active team cryptid.

- Internal state: `mana_bars` dict → `{cryptid_id: {current, max}}`
- Listens to `mana_charged(piece_type, pips)` — charges any cryptid whose `base_cryptid == piece_type`
- Pip formula: match-3 = 1 pip, match-4 = 2 pips, match-5+ = 3 pips
- Applies leader skill mana multiplier before adding
- Emits `mana_full(cryptid_id)` on first full charge (one-shot per charge cycle)
- `consume_mana(id)` resets bar to 0
- Resets on `game_started` and `team_changed`

---

### AbilitySystem
**`scripts/systems/ability_system.gd`**

Handles ability activation when a player taps a ready portrait.

**Guard chain in `try_activate_ability`:**
1. Board state must be `IDLE`
2. `GameManager.state` must be `PLAYING`
3. `ManaSystem.is_mana_full(cryptid_id)` must be true

**Execution flow:**
```
consume_mana()
emit ability_activated(cryptid_id)
match ability_type:
  CLEAR_ROW/COL  → get row/col positions → board.execute_ability_clear()
  CLEAR_AREA     → random center (clamped to valid range) → board.execute_ability_clear()
  CONVERT_TILES  → board.get_random_positions_of_type() → board.execute_ability_convert()
  SCORE_BOOST    → GameManager.add_score()
  EXTRA_MOVES    → GameManager.grant_extra_moves()
  SHIELD         → GameManager.activate_shield()  [emits shield_activated]
emit ability_resolved(cryptid_id)
```

`execute_ability_clear()` and `execute_ability_convert()` on the board trigger their own gravity/fill/cascade cycle, identical to normal match processing.

---

### LeaderSkillSystem
**`scripts/systems/leader_skill_system.gd`**

Passive bonuses from team slot 0 (the leader). Refreshes on `game_started` and `team_changed`.

| Getter | Used By |
|---|---|
| `get_score_multiplier()` → float | `GameManager.add_score()` |
| `get_mana_multiplier()` → float | `ManaSystem._on_mana_charged()` |
| `get_extra_starting_moves()` → int | `GameManager.start_game()` |

---

### GachaSystem
**`scripts/systems/gacha_system.gd`** (static class)

| Pull | Cost |
|---|---|
| Single | 100 fragments |
| Multi (×10) | 900 fragments |

**Rarity weights:** Common 60%, Uncommon 25%, Rare 10%, Epic 4%, Legendary 1%

**Pity:** Rare guaranteed every 30 pulls, Epic every 90 pulls. Pity counters stored in PlayerData and persist across sessions. Duplicate pulls grant Research Data equal to `5 × (rarity_index + 1)`.

---

### TrailCameraSystem
**`scripts/systems/trail_camera_system.gd`** (static class)

- `place_camera(biome_id, hours)` — records `placed_time` and `duration_hours` in PlayerData
- `collect_camera(biome_id)` — calculates reward: `hours × rand(5,12)` fragments, 20% chance of 10–30 coins, 5% chance of a free gacha pull
- UI queries: `is_camera_active()`, `is_camera_ready()`, `get_time_remaining()`

---

### DailyLoginSystem
**`scripts/systems/daily_login_system.gd`**

- Checks Unix day integer on each app open (`day = floori(unix_time / 86400)`)
- Streak increments if login is consecutive (same or next day), resets otherwise
- 7-day reward cycle:

| Day(s) | Fragments | Energy |
|---|---|---|
| 0–2 | +20 | +1 |
| 3–4 | +35 | +2 |
| 5 | +50 | +3 |
| 6 | +100 | full refill |

- Emits `daily_login_reward(streak, reward_dict)`

---

### TutorialManager
**`scripts/systems/tutorial_manager.gd`**

Context-sensitive hint system with queueing and cooldown (30s between hints).

**Hint styles:** Pulse (highlights pieces), Arrow (directional), Whisper (semi-transparent text overlay), Silhouette (dark panel with text).

**9 predefined hints:**

| Hint ID | Trigger | Level Gate |
|---|---|---|
| first_match | board_ready | L1 |
| cascade_intro | matches_cleared (cascade ≥ 1) | L2+ |
| collect_intro | board_ready with COLLECT goal | L3+ |
| match_4_tip | matches_cleared (4+ match) | — |
| ice_intro | board_ready with ICE obstacles | L4+ |
| web_intro | board_ready with WEB obstacles | L7+ |
| booster_tip | persistent_booster_created | — |
| mana_intro | mana_full | — |
| ability_ready | mana_full | — |

**Feature trickle (discoveries):** One-time full-screen popups for first mechanic encounters. Persisted via `PlayerData.tutorial_hints_shown` with `"disc_"` prefix. Each discovery grants a small reward and themed flavor text. Discoveries jump the hint queue when triggered.

---

### AnalyticsManager
**`scripts/systems/analytics_manager.gd`**

Listens to EventBus and logs structured events to console (placeholder — replace `_log_event()` body with real SDK call).

Auto-tracked: `level_started`, `level_completed`, `game_over`, `ability_activated`, `shuffle_used`, `daily_login`, `gacha_pull`, `energy_empty`, `battle_pass_xp`.

---

### ShopSystem
**`scripts/systems/shop_system.gd`**

Three energy packs (IAP placeholder — replace `purchase_pack()` print with real SDK):

| Pack | Price | Energy | Fragments |
|---|---|---|---|
| Energy Surge | $1.99 | 25 | 50 |
| Cryptid Awakening | $4.99 | 80 | 150 |
| Expedition Pack | $9.99 | 200 | 400 |

Rewarded ads via `AdPlacement.show_rewarded(placement, callback)`:
- `extra_moves` → 3 bonus moves (game over popup)
- `double_fragments` → doubles level rewards (result screen)
- `free_energy` → 1 energy heart (shop screen)

---

## 6. Screen Scenes

### Navigation Flow

```
splash_screen
    → boot_screen  (preloads all scenes)
        → home_screen
            ├── map_screen
            │       └── pre_level_popup
            │               └── game_screen
            │                       └── result_screen
            ├── field_guide_screen
            ├── investigation_screen
            ├── trail_camera_screen
            ├── shop_screen
            └── battle_pass_screen
```

---

### GameScreen
**`scenes/game_screen.gd`**

The most complex scene — orchestrates all gameplay systems.

**Setup sequence (`_ready`):**
1. Instantiate and `add_child`: ManaSystem, LeaderSkillSystem, AbilitySystem
2. Wire AbilitySystem: `ability_system.setup(board, mana_system)`
3. Register leader system with GameManager: `GameManager.set_leader_skill_system(leader_system)`
4. Instantiate TeamPanel, call `team_panel.setup(mana_system)`
5. Instantiate TutorialManager, call `tutorial_manager.setup(board, self)`
6. Connect all EventBus signals
7. Build star progress bar and goal progress labels
8. Spawn ambient mist particles behind the board

**HUD elements:**
- Score label (with bounce animation on change)
- Moves label (tints cyan when shield is active, resets on `swap_completed`)
- Level label
- Pause button + overlay (Resume / Quit)
- Cascade multiplier label (visible only during active cascades)
- Star progress bar with threshold markers (★ / ★★ / ★★★)
- Goal progress labels (one per sub-goal, turns green on completion)

**VFX handlers:**
- `_on_row_cleared` / `_on_column_cleared` / `_on_area_cleared` → brief coloured flash rect at cleared zone
- `_on_persistent_booster_created` → radial flash at booster's board position
- `_on_vfx_request("ability_flash")` → full-screen white flash
- `_on_screen_shake_requested(intensity)` → delegates to `PieceAnimator.animate_shake`

**Shuffle popup:** Modal dialog blocks board until player confirms (or quits). Coin cost if player can afford it, free otherwise. Quit/Home emit `shuffle_confirmed` before transitioning to prevent board hanging.

**Failure popup:** Shows on game over — offers 5-move continue for 50 coins or 3-move continue via rewarded ad.

---

### ResultScreen
**`scenes/result_screen.gd`**

**Victory path:**
1. Main UI hidden (`VBoxContainer.modulate.a = 0`)
2. `_play_celebration(star_rating)` — spawns team cryptid cards with glow + particle burst
3. Await 2.5s, then `_fade_in_results()` — fades out celebration, fades in UI
4. Looping tweens (float, glow) killed before `_celebration_layer.queue_free()`

**Result display:** final score, star thresholds, animated 3-star reveal (0.3s stagger + bounce).

**Rewards section:** fragment + coin amounts. Double rewards button shows if fragments > 0 and ad not yet watched (`_doubled` flag prevents re-use).

**Starter pack check:** delayed 1.5s popup for new players after level 5 — guarded by `is_instance_valid(self)` to handle fast navigation away.

---

### Other Screens

| Screen | Purpose |
|---|---|
| `splash_screen` | Animated title, auto-advances to boot after 2.5s |
| `boot_screen` | Preloads all scene resources with progress bar + flavor text |
| `home_screen` | Main menu hub; checks daily login on ready |
| `map_screen` | World map with region tabs, level node grid, star/rank display |
| `field_guide_screen` | Cryptid collection viewer with element filters |
| `investigation_screen` | Gacha pull interface with pity display and animated reveals |
| `trail_camera_screen` | 6-biome slot grid; place/collect cameras |

---

## 7. Key Signal Chains

### Level Start
```
map_screen: level node pressed(n)
  → pre_level_popup.open(n)
  → player presses Start
  → EventBus.level_selected(n)
  → GameManager._on_level_selected(n)
      → PlayerData.use_energy()
      → GameManager.start_game(n)
          → sets state = PLAYING
          → inits goals, emits game_started
  → SceneManager.change_scene("game_screen")
  → GameScreen._ready()
      → systems instantiated and wired
      → Board._ready() → deferred: EventBus.board_ready
          → TutorialManager first hints
          → ManaSystem._reset_mana()
```

### Match and Cascade
```
BoardInput: touch/click release
  → EventBus.swap_requested(from_col, from_row, to_col, to_row)
  → Board._on_swap_requested()
      → [guards: IDLE, PLAYING, valid, adjacent, web-free]
      → state = SWAPPING, await _do_swap()
      → [re-check GameManager.state]
      → state = CHECKING, MatchFinder.find_match_groups()
      → if no match: swap back + reject animation → IDLE
      → if match: EventBus.swap_completed() → GameManager uses move (or shield consumed)
      → Board._process_match_groups()
          → _collect_booster_activations()     [BFS chain activation]
          → _emit_mana_charges()               [→ ManaSystem → mana_full?]
          → _emit_piece_collections()          [→ GameManager goal tracking]
          → _process_obstacle_damage()         [→ obstacle_cleared signals]
          → await _clear_pieces()
          → EventBus.matches_cleared(count, cascade_level)
              → GameManager.add_score()        [cascade + leader multipliers]
          → EventBus.screen_shake_requested()
          → [create new boosters]
          → await _apply_gravity()
          → await _fill_empty()
          → state = CHECKING, find_match_groups()
          → if match: cascade_level++, recurse _process_match_groups
          → else: _settle_board()
              → _ensure_valid_board()          [shuffle if deadlocked]
              → state = IDLE
              → EventBus.board_settled()
                  → GameManager._check_end_condition()
                  → [win / lose / continue]
```

### Ability Activation
```
TeamPanel: portrait pressed
  → team_panel.cryptid_tapped(cryptid_id)
  → GameScreen._on_cryptid_tapped(cryptid_id)
  → AbilitySystem.try_activate_ability(cryptid_id)
      → [guards: board IDLE, game PLAYING, mana full]
      → ManaSystem.consume_mana(cryptid_id)
      → EventBus.ability_activated(cryptid_id)   [GameScreen shows banner]
      → [execute ability on board]
      → EventBus.ability_resolved(cryptid_id)
```

### Level Complete
```
GameManager._check_end_condition()
  → are_goals_met() == true
  → _complete_level_with_bonus()
      → if moves_bonus and moves > 0:
          → EventBus.victory_detonation_requested(leftover_moves)
          → Board: spawns random boosters, detonates sequentially
          → EventBus.victory_detonation_finished(bonus_score)
          → GameManager._on_victory_detonation_finished()
      → GameManager._record_completion(stars)
          → PlayerData.record_level_complete()
          → PlayerData.add_fragments() / add_coins() / add_credibility_xp()
          → EventBus.level_completed(score, stars)
              → GameScreen._on_level_completed()
                  → [0.8s delay]
                  → SceneManager.change_scene("result_screen")
                      → ResultScreen._ready()
                      → [celebration → fade → results display]
```

---

## 8. Persistence Schema

**File:** `user://player_save.json`

```json
{
  "evidence_fragments": 500,
  "cryptid_coins": 150,
  "research_data": 20,
  "collected_cryptids": {
    "bigfoot_scout":    { "level": 1, "duplicates": 0 },
    "mothman_observer": { "level": 1, "duplicates": 2 }
  },
  "active_team": ["bigfoot_scout", "mothman_observer", "nessie_pup"],
  "highest_level_completed": 7,
  "level_stars": { "1": 3, "2": 2, "3": 3, "4": 1 },
  "total_stars": 9,
  "credibility_xp": 180,
  "energy": 3,
  "last_energy_time": 1715000000.0,
  "pity_rare": 12,
  "pity_epic": 34,
  "starter_pack_shown": true,
  "starter_pack_purchased": false,
  "tutorial_completed": false,
  "tutorial_hints_shown": {
    "first_match": true,
    "disc_cascade_first": true
  },
  "trail_cameras": {
    "pacific_nw": { "placed_time": 1715000000.0, "duration_hours": 8 }
  },
  "login_streak": 3,
  "last_login_day": 19842
}
```

**Save triggers:** energy change, every currency transaction, every level completion, hint shown, scene transition.

---

## 9. Design Patterns Summary

| Pattern | Where Applied |
|---|---|
| **Signal bus** | EventBus decouples all cross-system communication; no direct node references between systems |
| **State machine** | Board (8 states: IDLE/SWAPPING/CHECKING/CLEARING/FALLING/FILLING/SWAP_BACK/ABILITY), GameManager (5 states) |
| **Object pool** | Piece Sprite2D nodes reused across cascade sequences via `_acquire_piece()` / `_release_piece()` |
| **Dependency injection** | AbilitySystem and TutorialManager receive board/mana references at setup time, not via autoload |
| **Data-driven levels** | LevelData resource drives every level's rules, goals, obstacles, and boosters — no logic in level definitions |
| **Progressive feature trickle** | Discovery system gates new mechanics behind one-time reveal popups with rewards |
| **Deferred event checking** | Goals checked only on specific signals (not per-frame); end condition checked only on board settle |
| **Threaded loading** | SceneManager uses `ResourceLoader.load_threaded_request` for smooth transitions |
| **Cascade safety cap** | `_natural_cascade_count` prevents runaway cascade loops; safe fill used after 3 natural cascades |
| **Leader composition** | Leader slot (team[0]) applies passive multipliers to score, mana, and starting moves across systems |

---

## 10. Extensibility Reference

| Feature | What to Add/Change |
|---|---|
| New obstacle type | `LevelData.ObstacleType` enum + `Board._draw()` + `Board.damage_obstacle()` |
| New ability type | `CryptidData.AbilityType` enum + `AbilitySystem.try_activate_ability()` match block |
| New booster type | `PieceData.BoosterType` enum + `Board._determine_boosters()` + `Board._get_booster_effect()` + `Piece._draw()` |
| New leader skill | `CryptidData.LeaderSkillType` enum + `LeaderSkillSystem` getter + call site in the relevant system |
| Real IAP | Replace print statements in `ShopSystem.purchase_pack()` |
| Real analytics | Replace `AnalyticsManager._log_event()` body with SDK call |
| Real ads | Implement `AdPlacement.show_rewarded()` with real ad network SDK |
| New region | Add entry to `RegionData` + levels to `LevelData.CATALOG` |
| New cryptid | Add to `CryptidDatabase._init_database()` |
