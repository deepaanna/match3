extends Node
## Global signal hub. No logic, just signal declarations.

# Game state signals
signal game_started()
signal game_paused()
signal game_resumed()
signal game_over(final_score: int, star_rating: int)
signal level_completed(final_score: int, star_rating: int)

# Score / moves signals
signal score_changed(new_score: int)
signal moves_changed(moves_remaining: int)
signal cascade_started(multiplier: float)

# Board signals
signal piece_selected(col: int, row: int)
signal piece_deselected()
signal swap_requested(from_col: int, from_row: int, to_col: int, to_row: int)
signal swap_completed()
signal swap_failed()
signal matches_found(matches: Array)
signal matches_cleared(count: int, cascade_level: int)
signal pieces_fell()
signal pieces_spawned()
signal board_settled()

# UI signals
signal play_pressed()
signal pause_pressed()
signal resume_pressed()
signal quit_pressed()
signal replay_pressed()
signal home_pressed()

# Audio signals
signal play_sfx(sfx_name: String)
signal play_music(music_name: String)
signal stop_music()

# --- Mana & Ability signals ---
signal mana_charged(piece_type: int, amount: int)
signal mana_full(cryptid_id: String)
signal ability_activated(cryptid_id: String)
signal ability_resolved(cryptid_id: String)
signal team_changed()

# --- Progression signals ---
signal level_selected(level_number: int)
signal region_unlocked(region_id: String)
signal credibility_changed(new_xp: int)
signal star_total_changed(new_total: int)

# --- Collection / Gacha signals ---
signal cryptid_obtained(cryptid_id: String, is_new: bool)
signal investigation_result(cryptid_id: String, rarity: int)
signal fragments_changed(new_amount: int)
signal coins_changed(new_amount: int)
signal research_data_changed(new_amount: int)

# --- Energy signals ---
signal energy_changed(new_energy: int)
signal energy_empty()
signal energy_refilled()

# --- Monetization signals ---
signal extra_moves_purchased()
signal reward_doubled()
signal ad_watched(placement: String)
signal iap_purchased(product_id: String)

# --- Trail Camera signals ---
signal camera_placed(biome_id: String)
signal camera_collected(biome_id: String)

# --- Obstacle signals ---
signal obstacle_damaged(col: int, row: int, remaining_hp: int)
signal obstacle_cleared(col: int, row: int, obstacle_type: int)

# --- Goal signals ---
signal pieces_collected(piece_type: int, count: int)
signal goal_progress_updated(goal_id: String, current: int, target: int)
signal goal_completed(goal_id: String)
signal all_goals_completed()
signal mana_goal_charged()

# --- Victory signals ---
signal victory_detonation_requested(moves_left: int)
signal victory_detonation_finished(bonus_score: int)

# --- Screen shake signals ---
signal screen_shake_requested(intensity: float)

# --- Tutorial signals ---
signal board_ready()
signal tutorial_hint_show(hint_id: String, text: String, position: Vector2)
signal tutorial_hint_dismiss()

# --- Feature Trickle System v1.0 ---
signal discovery_moment(discovery_id: String, flavor_text: String)

# --- Ability effect signals ---
signal pieces_converted(positions: Array, new_type: int)
signal row_cleared(row: int)
signal column_cleared(col: int)
signal area_cleared(center_col: int, center_row: int, radius: int)
signal extra_moves_granted(amount: int)
signal shield_activated()
