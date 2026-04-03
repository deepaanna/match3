extends Node
## Debug menu for testing. Toggle with F12.

var _canvas_layer: CanvasLayer = null
var _panel: PanelContainer = null
var _visible: bool = false

# Section collapse state
var _collapsed: Dictionary = {}

const SCENES: Dictionary = {
	"Home": "res://scenes/home_screen.tscn",
	"Map": "res://scenes/map_screen.tscn",
	"Game": "res://scenes/game_screen.tscn",
	"Result": "res://scenes/result_screen.tscn",
	"Investigation": "res://scenes/investigation_screen.tscn",
	"Field Guide": "res://scenes/field_guide_screen.tscn",
	"Trail Camera": "res://scenes/trail_camera_screen.tscn",
	"Shop": "res://scenes/ui/shop_screen.tscn",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			_toggle()
			get_viewport().set_input_as_handled()


func _toggle() -> void:
	if _visible:
		_hide_menu()
	else:
		_show_menu()


func _show_menu() -> void:
	_visible = true
	_build_ui()


func _hide_menu() -> void:
	_visible = false
	if _canvas_layer:
		_canvas_layer.queue_free()
		_canvas_layer = null
		_panel = null


func _build_ui() -> void:
	if _canvas_layer:
		_canvas_layer.queue_free()

	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 200
	add_child(_canvas_layer)

	# Dimmed background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas_layer.add_child(bg)

	# Main panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.anchor_left = 0.02
	_panel.anchor_right = 0.98
	_panel.anchor_top = 0.02
	_panel.anchor_bottom = 0.98
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	_canvas_layer.add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	# Title bar
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "DEBUG MENU"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 30)
	close_btn.pressed.connect(_hide_menu)
	title_row.add_child(close_btn)

	_add_separator(vbox)

	# --- Sections ---
	_build_currencies_section(vbox)
	_build_testing_section(vbox)
	_build_energy_section(vbox)
	_build_progression_section(vbox)
	_build_collection_section(vbox)
	_build_gacha_section(vbox)
	_build_game_state_section(vbox)
	_build_tutorial_section(vbox)
	_build_navigation_section(vbox)
	_build_danger_section(vbox)


# ==================== UI Helpers ====================

func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	parent.add_child(sep)


func _add_section(parent: Control, section_title: String) -> VBoxContainer:
	var section_id: String = section_title
	if not _collapsed.has(section_id):
		_collapsed[section_id] = false

	var header := Button.new()
	header.text = ("v " if not _collapsed[section_id] else "> ") + section_title
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.15, 0.15, 0.18)
	header_style.content_margin_left = 6
	header_style.content_margin_top = 4
	header_style.content_margin_bottom = 4
	header.add_theme_stylebox_override("normal", header_style)
	parent.add_child(header)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	content.visible = not _collapsed[section_id]
	parent.add_child(content)

	var sid: String = section_id
	header.pressed.connect(func() -> void:
		_collapsed[sid] = not _collapsed[sid]
		content.visible = not _collapsed[sid]
		header.text = ("v " if content.visible else "> ") + sid
	)
	return content


func _add_label(parent: Control, text: String, color: Color = Color.WHITE, font_size: int = 13) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)
	return lbl


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _make_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	return row


func _row_btn(row: HBoxContainer, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 32)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(callback)
	row.add_child(btn)


func _add_spin_row(parent: Control, label_text: String, value: int, callback: Callable, min_val: int = 0, max_val: int = 99999) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.custom_minimum_size = Vector2(120, 0)
	row.add_child(lbl)

	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value = value
	spin.step = 1
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.add_theme_font_size_override("font_size", 12)
	row.add_child(spin)

	var apply_btn := Button.new()
	apply_btn.text = "Set"
	apply_btn.custom_minimum_size = Vector2(50, 30)
	apply_btn.add_theme_font_size_override("font_size", 12)
	apply_btn.pressed.connect(func() -> void: callback.call(int(spin.value)))
	row.add_child(apply_btn)

	return spin


# ==================== Sections ====================

func _build_testing_section(parent: Control) -> void:
	var s := _add_section(parent, "Testing Build")
	_add_label(s, "Energy bypass: %s" % ("ON" if GameManager.is_testing_build else "OFF"),
		Color(0.4, 1.0, 0.4) if GameManager.is_testing_build else Color(1.0, 0.4, 0.4))
	var r1 := _make_row(s)
	_row_btn(r1, "Toggle Testing Build", _cmd_toggle_testing)


func _cmd_toggle_testing() -> void:
	GameManager.is_testing_build = not GameManager.is_testing_build
	_rebuild()


func _build_currencies_section(parent: Control) -> void:
	var s := _add_section(parent, "Currencies")
	_add_label(s, "Fragments: %d | Coins: %d | Research: %d" % [
		PlayerData.evidence_fragments, PlayerData.cryptid_coins, PlayerData.research_data
	], Color(0.7, 0.9, 0.7))

	var r1 := _make_row(s)
	_row_btn(r1, "+100 Frags", _cmd_add_frags_100)
	_row_btn(r1, "+1000 Frags", _cmd_add_frags_1000)
	_row_btn(r1, "+10000 Frags", _cmd_add_frags_10000)

	var r2 := _make_row(s)
	_row_btn(r2, "+100 Coins", _cmd_add_coins_100)
	_row_btn(r2, "+1000 Coins", _cmd_add_coins_1000)

	var r3 := _make_row(s)
	_row_btn(r3, "+100 Research", _cmd_add_research_100)
	_row_btn(r3, "+1000 Research", _cmd_add_research_1000)

	_add_spin_row(s, "Set Fragments:", PlayerData.evidence_fragments, _cmd_set_fragments)
	_add_spin_row(s, "Set Coins:", PlayerData.cryptid_coins, _cmd_set_coins)


func _build_energy_section(parent: Control) -> void:
	var s := _add_section(parent, "Energy")
	var regen_secs: float = PlayerData.get_energy_regen_remaining()
	var regen_str: String = "%d:%02d" % [int(regen_secs) / 60, int(regen_secs) % 60]
	_add_label(s, "Energy: %d/%d | Next in: %s" % [
		PlayerData.energy, PlayerData.MAX_ENERGY, regen_str
	], Color(0.7, 0.9, 0.7))

	var r1 := _make_row(s)
	_row_btn(r1, "Refill Energy", _cmd_refill_energy)
	_row_btn(r1, "Set to 0", _cmd_zero_energy)

	var r2 := _make_row(s)
	_row_btn(r2, "+25min (1 heart)", _cmd_skip_25min)
	_row_btn(r2, "+2hr (skip)", _cmd_skip_2hr)


func _build_progression_section(parent: Control) -> void:
	var s := _add_section(parent, "Progression")
	_add_label(s, "Highest Level: %d | Total Stars: %d | Rank: %s (XP: %d)" % [
		PlayerData.highest_level_completed,
		PlayerData.total_stars,
		CredibilityData.get_rank_name(PlayerData.credibility_xp),
		PlayerData.credibility_xp,
	], Color(0.7, 0.9, 0.7))

	_add_spin_row(s, "Set Max Level:", PlayerData.highest_level_completed, _cmd_set_max_level, 0, 90)

	var r1 := _make_row(s)
	_row_btn(r1, "Complete 10 Lvls", _cmd_complete_10)
	_row_btn(r1, "Complete 30 Lvls", _cmd_complete_30)

	var r2 := _make_row(s)
	_row_btn(r2, "All 3-Star", _cmd_all_3star)
	_row_btn(r2, "Unlock All Regions", _cmd_unlock_all_regions)

	_add_spin_row(s, "Set Cred XP:", PlayerData.credibility_xp, _cmd_set_cred_xp, 0, 99999)

	var r3 := _make_row(s)
	_row_btn(r3, "+100 XP", _cmd_add_xp_100)
	_row_btn(r3, "+1000 XP", _cmd_add_xp_1000)
	_row_btn(r3, "Max Rank", _cmd_max_rank)


func _build_collection_section(parent: Control) -> void:
	var s := _add_section(parent, "Collection")
	_add_label(s, "Collected: %d/30 | Team: %s" % [
		PlayerData.get_collection_count(),
		", ".join(PlayerData.active_team),
	], Color(0.7, 0.9, 0.7))

	var r1 := _make_row(s)
	_row_btn(r1, "All Common", _cmd_grant_common)
	_row_btn(r1, "All Uncommon", _cmd_grant_uncommon)

	var r2 := _make_row(s)
	_row_btn(r2, "All Rare", _cmd_grant_rare)
	_row_btn(r2, "All Epic", _cmd_grant_epic)

	var r3 := _make_row(s)
	_row_btn(r3, "All Legendary", _cmd_grant_legendary)
	_row_btn(r3, "ALL (30/30)", _cmd_grant_all)

	var r4 := _make_row(s)
	_row_btn(r4, "Clear Collection", _cmd_clear_collection)

	# Quick team set - legendaries as leader
	_add_label(s, "Set Leader (slot 0):", Color(0.8, 0.8, 0.8), 12)
	var legendaries: Array[CryptidData] = CryptidDatabase.get_by_rarity(CryptidData.Rarity.LEGENDARY)
	var row: HBoxContainer = _make_row(s)
	var count: int = 0
	for c: CryptidData in legendaries:
		if count > 0 and count % 3 == 0:
			row = _make_row(s)
		var cid: String = c.cryptid_id
		_row_btn(row, c.display_name.substr(0, 12), _cmd_set_leader.bind(cid))
		count += 1


func _build_gacha_section(parent: Control) -> void:
	var s := _add_section(parent, "Gacha / Pity")
	_add_label(s, "Rare pity: %d/30 | Epic pity: %d/90" % [
		PlayerData.pity_rare, PlayerData.pity_epic
	], Color(0.7, 0.9, 0.7))

	var r1 := _make_row(s)
	_row_btn(r1, "Rare Pity -> 29", _cmd_pity_rare_29)
	_row_btn(r1, "Epic Pity -> 89", _cmd_pity_epic_89)

	var r2 := _make_row(s)
	_row_btn(r2, "Reset Pity", _cmd_reset_pity)
	_row_btn(r2, "Free 10-Pull Frags", _cmd_free_10pull)


func _build_game_state_section(parent: Control) -> void:
	var s := _add_section(parent, "Game State (In-Level)")
	var state_name: String = "N/A"
	match GameManager.state:
		GameManager.GameState.IDLE: state_name = "IDLE"
		GameManager.GameState.PLAYING: state_name = "PLAYING"
		GameManager.GameState.PAUSED: state_name = "PAUSED"
		GameManager.GameState.GAME_OVER: state_name = "GAME_OVER"
		GameManager.GameState.LEVEL_COMPLETE: state_name = "LEVEL_COMPLETE"

	_add_label(s, "State: %s | Level: %d | Score: %d | Moves: %d" % [
		state_name, GameManager.current_level, GameManager.score, GameManager.moves_remaining
	], Color(0.7, 0.9, 0.7))

	var r1 := _make_row(s)
	_row_btn(r1, "+1000 Score", _cmd_add_score_1000)
	_row_btn(r1, "+5000 Score", _cmd_add_score_5000)

	var r2 := _make_row(s)
	_row_btn(r2, "+5 Moves", _cmd_add_moves_5)
	_row_btn(r2, "+20 Moves", _cmd_add_moves_20)

	var r3 := _make_row(s)
	_row_btn(r3, "Force Win", _cmd_force_win)
	_row_btn(r3, "Force Lose", _cmd_force_lose)

	var r4 := _make_row(s)
	_row_btn(r4, "Activate Shield", _cmd_activate_shield)
	_row_btn(r4, "x3 Cascade", _cmd_x3_cascade)

	_add_spin_row(s, "Jump to Level:", GameManager.current_level, _cmd_jump_to_level, 1, 90)

	var r5 := _make_row(s)
	_row_btn(r5, "Complete All Goals", _cmd_complete_goals)


func _build_tutorial_section(parent: Control) -> void:
	var s := _add_section(parent, "Tutorial / Hints")
	var hints_count: int = PlayerData.tutorial_hints_shown.size()
	_add_label(s, "Tutorial done: %s | Hints shown: %d" % [
		"Yes" if PlayerData.tutorial_completed else "No", hints_count
	], Color(0.7, 0.9, 0.7))

	var r1 := _make_row(s)
	_row_btn(r1, "Mark Tutorial Done", _cmd_tutorial_done)
	_row_btn(r1, "Reset Tutorial", _cmd_tutorial_reset)

	var r2 := _make_row(s)
	_row_btn(r2, "Show All Hints", _cmd_hints_show_all)
	_row_btn(r2, "Clear All Hints", _cmd_hints_clear)


func _build_navigation_section(parent: Control) -> void:
	var s := _add_section(parent, "Scene Navigation")
	var row: HBoxContainer = _make_row(s)
	var count: int = 0
	for scene_name: String in SCENES:
		if count > 0 and count % 3 == 0:
			row = _make_row(s)
		var path: String = SCENES[scene_name]
		_row_btn(row, scene_name, _cmd_goto_scene.bind(path))
		count += 1


func _build_danger_section(parent: Control) -> void:
	var s := _add_section(parent, "RESET (Danger)")
	_add_label(s, "These actions cannot be undone!", Color(1.0, 0.4, 0.4), 12)

	var r1 := _make_row(s)
	_row_btn(r1, "Reset ALL Save Data", _cmd_reset_all)
	_row_btn(r1, "Reset Stars Only", _cmd_reset_stars)

	var r2 := _make_row(s)
	_row_btn(r2, "Reset Progression", _cmd_reset_progression)
	_row_btn(r2, "Reset Flags", _cmd_reset_flags)


# ==================== Command callbacks ====================

func _rebuild() -> void:
	if _visible:
		_build_ui()

# --- Currencies ---
func _cmd_add_frags_100() -> void:
	PlayerData.add_fragments(100); _rebuild()

func _cmd_add_frags_1000() -> void:
	PlayerData.add_fragments(1000); _rebuild()

func _cmd_add_frags_10000() -> void:
	PlayerData.add_fragments(10000); _rebuild()

func _cmd_add_coins_100() -> void:
	PlayerData.add_coins(100); _rebuild()

func _cmd_add_coins_1000() -> void:
	PlayerData.add_coins(1000); _rebuild()

func _cmd_add_research_100() -> void:
	PlayerData.add_research_data(100); _rebuild()

func _cmd_add_research_1000() -> void:
	PlayerData.add_research_data(1000); _rebuild()

func _cmd_set_fragments(v: int) -> void:
	PlayerData.evidence_fragments = v
	EventBus.fragments_changed.emit(v)
	PlayerData.save_data(); _rebuild()

func _cmd_set_coins(v: int) -> void:
	PlayerData.cryptid_coins = v
	EventBus.coins_changed.emit(v)
	PlayerData.save_data(); _rebuild()

# --- Energy ---
func _cmd_refill_energy() -> void:
	PlayerData.refill_energy(); _rebuild()

func _cmd_zero_energy() -> void:
	PlayerData.energy = 0
	PlayerData.last_energy_time = Time.get_unix_time_from_system()
	EventBus.energy_changed.emit(0)
	PlayerData.save_data(); _rebuild()

func _cmd_skip_25min() -> void:
	PlayerData.last_energy_time -= PlayerData.ENERGY_REGEN_SECONDS
	PlayerData._regen_energy(); _rebuild()

func _cmd_skip_2hr() -> void:
	PlayerData.last_energy_time -= 7200
	PlayerData._regen_energy(); _rebuild()

# --- Progression ---
func _cmd_set_max_level(v: int) -> void:
	PlayerData.highest_level_completed = v
	PlayerData.save_data(); _rebuild()

func _cmd_complete_10() -> void:
	_set_levels_completed(PlayerData.highest_level_completed + 10); _rebuild()

func _cmd_complete_30() -> void:
	_set_levels_completed(PlayerData.highest_level_completed + 30); _rebuild()

func _cmd_all_3star() -> void:
	for i in range(1, PlayerData.highest_level_completed + 1):
		PlayerData.record_level_complete(i, 3)
	_rebuild()

func _cmd_unlock_all_regions() -> void:
	_set_levels_completed(90)
	for i in range(1, 91):
		PlayerData.record_level_complete(i, 3)
	_rebuild()

func _cmd_set_cred_xp(v: int) -> void:
	PlayerData.credibility_xp = v
	EventBus.credibility_changed.emit(v)
	PlayerData.save_data(); _rebuild()

func _cmd_add_xp_100() -> void:
	PlayerData.add_credibility_xp(100); _rebuild()

func _cmd_add_xp_1000() -> void:
	PlayerData.add_credibility_xp(1000); _rebuild()

func _cmd_max_rank() -> void:
	var needed: int = maxi(0, 10000 - PlayerData.credibility_xp)
	if needed > 0:
		PlayerData.add_credibility_xp(needed)
	_rebuild()

# --- Collection ---
func _cmd_grant_common() -> void:
	_grant_by_rarity(CryptidData.Rarity.COMMON); _rebuild()

func _cmd_grant_uncommon() -> void:
	_grant_by_rarity(CryptidData.Rarity.UNCOMMON); _rebuild()

func _cmd_grant_rare() -> void:
	_grant_by_rarity(CryptidData.Rarity.RARE); _rebuild()

func _cmd_grant_epic() -> void:
	_grant_by_rarity(CryptidData.Rarity.EPIC); _rebuild()

func _cmd_grant_legendary() -> void:
	_grant_by_rarity(CryptidData.Rarity.LEGENDARY); _rebuild()

func _cmd_grant_all() -> void:
	_grant_all_cryptids(); _rebuild()

func _cmd_clear_collection() -> void:
	PlayerData.collected_cryptids.clear()
	for id: String in CryptidDatabase.get_starter_team():
		PlayerData.collected_cryptids[id] = {"level": 1, "duplicates": 0}
	PlayerData.active_team = CryptidDatabase.get_starter_team().duplicate()
	EventBus.team_changed.emit()
	PlayerData.save_data(); _rebuild()

func _cmd_set_leader(cid: String) -> void:
	if not PlayerData.has_cryptid(cid):
		PlayerData.add_cryptid(cid)
	PlayerData.set_team_slot(0, cid); _rebuild()

# --- Gacha ---
func _cmd_pity_rare_29() -> void:
	PlayerData.pity_rare = 29; PlayerData.save_data(); _rebuild()

func _cmd_pity_epic_89() -> void:
	PlayerData.pity_epic = 89; PlayerData.save_data(); _rebuild()

func _cmd_reset_pity() -> void:
	PlayerData.pity_rare = 0; PlayerData.pity_epic = 0
	PlayerData.save_data(); _rebuild()

func _cmd_free_10pull() -> void:
	PlayerData.add_fragments(maxi(0, 900 - PlayerData.evidence_fragments)); _rebuild()

# --- Game State ---
func _cmd_add_score_1000() -> void:
	if GameManager.state == GameManager.GameState.PLAYING:
		GameManager.add_score(1000)
	_rebuild()

func _cmd_add_score_5000() -> void:
	if GameManager.state == GameManager.GameState.PLAYING:
		GameManager.add_score(5000)
	_rebuild()

func _cmd_add_moves_5() -> void:
	GameManager.grant_extra_moves(5); _rebuild()

func _cmd_add_moves_20() -> void:
	GameManager.grant_extra_moves(20); _rebuild()

func _cmd_force_win() -> void:
	if GameManager.state == GameManager.GameState.PLAYING:
		GameManager.score = 99999
		EventBus.score_changed.emit(GameManager.score)
		GameManager.moves_remaining = 0
		EventBus.moves_changed.emit(0)
		EventBus.board_settled.emit()
	_rebuild()

func _cmd_force_lose() -> void:
	if GameManager.state == GameManager.GameState.PLAYING:
		GameManager.score = 0
		EventBus.score_changed.emit(0)
		GameManager.moves_remaining = 0
		EventBus.moves_changed.emit(0)
		EventBus.board_settled.emit()
	_rebuild()

func _cmd_activate_shield() -> void:
	GameManager.activate_shield()
	EventBus.shield_activated.emit(); _rebuild()

func _cmd_x3_cascade() -> void:
	GameManager.cascade_multiplier = 3.0
	EventBus.cascade_started.emit(3.0); _rebuild()

func _cmd_jump_to_level(v: int) -> void:
	_hide_menu()
	if PlayerData.energy <= 0:
		PlayerData.refill_energy()
	GameManager.start_game(v)
	SceneManager.change_scene("res://scenes/game_screen.tscn")

func _cmd_complete_goals() -> void:
	var goals: Dictionary = GameManager.get_goals()
	for goal_id: String in goals:
		var g: Dictionary = goals[goal_id]
		var remaining: int = g["target"] - g["current"]
		if remaining > 0:
			GameManager._advance_goal(goal_id, remaining)
	_rebuild()

# --- Tutorial ---
func _cmd_tutorial_done() -> void:
	PlayerData.tutorial_completed = true; PlayerData.save_data(); _rebuild()

func _cmd_tutorial_reset() -> void:
	PlayerData.tutorial_completed = false
	PlayerData.tutorial_hints_shown.clear()
	PlayerData.save_data(); _rebuild()

func _cmd_hints_show_all() -> void:
	for hint_id: String in ["first_match", "cascade_intro", "collect_intro", "match_4_tip",
			"ice_intro", "web_intro", "booster_tip", "mana_intro", "ability_ready"]:
		PlayerData.mark_hint_shown(hint_id)
	_rebuild()

func _cmd_hints_clear() -> void:
	PlayerData.tutorial_hints_shown.clear(); PlayerData.save_data(); _rebuild()

# --- Navigation ---
func _cmd_goto_scene(path: String) -> void:
	_hide_menu()
	get_tree().paused = false
	SceneManager.change_scene(path)

# --- Danger resets ---
func _cmd_reset_all() -> void:
	PlayerData._init_new_player()
	PlayerData.save_data(); _rebuild()

func _cmd_reset_stars() -> void:
	PlayerData.level_stars.clear()
	PlayerData.total_stars = 0
	EventBus.star_total_changed.emit(0)
	PlayerData.save_data(); _rebuild()

func _cmd_reset_progression() -> void:
	PlayerData.highest_level_completed = 0
	PlayerData.level_stars.clear()
	PlayerData.total_stars = 0
	PlayerData.credibility_xp = 0
	EventBus.star_total_changed.emit(0)
	EventBus.credibility_changed.emit(0)
	PlayerData.save_data(); _rebuild()

func _cmd_reset_flags() -> void:
	PlayerData.starter_pack_shown = false
	PlayerData.starter_pack_purchased = false
	PlayerData.tutorial_completed = false
	PlayerData.tutorial_hints_shown.clear()
	PlayerData.save_data(); _rebuild()


# ==================== Helpers ====================

func _set_levels_completed(up_to: int) -> void:
	up_to = clampi(up_to, 0, 90)
	for i in range(PlayerData.highest_level_completed + 1, up_to + 1):
		PlayerData.record_level_complete(i, 1)
	PlayerData.save_data()


func _grant_by_rarity(rarity: CryptidData.Rarity) -> void:
	var cryptids: Array[CryptidData] = CryptidDatabase.get_by_rarity(rarity)
	for c: CryptidData in cryptids:
		if not PlayerData.has_cryptid(c.cryptid_id):
			PlayerData.add_cryptid(c.cryptid_id)


func _grant_all_cryptids() -> void:
	var all_cryptids: Array[CryptidData] = CryptidDatabase.get_all()
	for c: CryptidData in all_cryptids:
		if not PlayerData.has_cryptid(c.cryptid_id):
			PlayerData.add_cryptid(c.cryptid_id)
