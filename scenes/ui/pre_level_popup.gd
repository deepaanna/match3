extends Control
## Pre-level popup: shows level info, star thresholds, team selector, start button.

signal start_expedition(level_number: int)
signal popup_closed()

const TEAM_SELECTOR_SCENE: PackedScene = preload("res://scenes/ui/team_selector.tscn")

@onready var _title_label: Label = %TitleLabel
@onready var _region_label: Label = %RegionLabel
@onready var _flavor_label: Label = %FlavorLabel
@onready var _star_info: Label = %StarInfo
@onready var _moves_label: Label = %MovesLabel
@onready var _energy_label: Label = %EnergyLabel
@onready var _team_row: HBoxContainer = %TeamRow
@onready var _leader_skill_label: Label = %LeaderSkillLabel
@onready var _start_button: Button = %StartButton
@onready var _back_button: Button = %BackButton

var _level_data: LevelData = null
var _team_buttons: Array[Button] = []


func setup(level: int) -> void:
	_level_data = LevelData.get_level(level)

	if not is_node_ready():
		await ready

	_populate()


func _populate() -> void:
	_title_label.text = "Level %d" % _level_data.level_number

	var region: RegionData = RegionData.get_region_for_level(_level_data.level_number)
	if region:
		_region_label.text = region.display_name
		_region_label.visible = true
	else:
		_region_label.visible = false

	# Feature Trickle: show discovery flavor text with glow when discovery is pending
	var pending_disc: Dictionary = {}
	if _level_data.discovery_id != "":
		if not PlayerData.has_seen_discovery(_level_data.discovery_id):
			pending_disc = LevelData.DISCOVERIES.get(_level_data.discovery_id, {})

	if not pending_disc.is_empty():
		_flavor_label.text = pending_disc["text"]
		_flavor_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.9))
		_flavor_label.visible = true
	elif _level_data.flavor_text != "":
		_flavor_label.text = _level_data.flavor_text
		_flavor_label.visible = true
	else:
		_flavor_label.visible = false

	_star_info.text = "★ %d pts  ★★ %d pts  ★★★ %d pts" % [
		_level_data.star_1_score, _level_data.star_2_score, _level_data.star_3_score
	]
	_moves_label.text = "Moves: %d" % _level_data.max_moves

	# Show goal description
	var goal_text: String = _get_goal_description()
	if goal_text != "":
		_moves_label.text += "\n" + goal_text
	_energy_label.text = "Energy Cost: 1 ♥ (You have: %d)" % PlayerData.energy
	_energy_label.modulate = Color(1.0, 0.3, 0.3) if PlayerData.energy <= 0 else Color(0.7, 0.7, 0.7)

	_refresh_team_buttons()
	_update_leader_skill()

	# Disable start if player has no energy
	if PlayerData.energy <= 0:
		_start_button.disabled = true
		_start_button.text = "No Energy"
	_start_button.pressed.connect(func() -> void: start_expedition.emit(_level_data.level_number))
	_back_button.pressed.connect(func() -> void: popup_closed.emit())


func _refresh_team_buttons() -> void:
	# Clear existing team buttons
	for btn in _team_buttons:
		btn.queue_free()
	_team_buttons.clear()

	for i in range(3):
		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(120, 125)
		var cid: String = PlayerData.active_team[i]
		if cid != "":
			var c: CryptidData = CryptidDatabase.get_cryptid(cid)
			if c:
				var ability_desc: String = CryptidData.get_ability_description(c.ability_type, c.ability_power)
				slot_btn.text = c.variant_name + "\n" + PieceData.get_piece_name(c.base_cryptid) + "\n" + ability_desc
			else:
				slot_btn.text = "Empty"
		else:
			slot_btn.text = "Empty"
		slot_btn.add_theme_font_size_override("font_size", 11)
		var slot_idx: int = i
		slot_btn.pressed.connect(func() -> void: _open_team_selector(slot_idx))
		_team_row.add_child(slot_btn)
		_team_buttons.append(slot_btn)


func _update_leader_skill() -> void:
	var leader_cid: String = PlayerData.active_team[0]
	if leader_cid != "":
		var leader_c: CryptidData = CryptidDatabase.get_cryptid(leader_cid)
		if leader_c:
			var leader_desc: String = CryptidData.get_leader_description(leader_c.leader_skill_type, leader_c.leader_skill_value)
			if leader_desc != "":
				_leader_skill_label.text = "Leader Skill: %s" % leader_desc
				_leader_skill_label.visible = true
				return
	_leader_skill_label.visible = false


func _get_goal_description() -> String:
	var params: Dictionary = _level_data.goal_params
	match _level_data.goal_type:
		LevelData.GoalType.SCORE:
			return ""
		LevelData.GoalType.COLLECT:
			var type_name: String = PieceData.get_piece_name(params.get("type", 0))
			return "Goal: Collect %d %s pieces" % [params.get("count", 15), type_name]
		LevelData.GoalType.CLEAR_OBSTACLES:
			var parts: Array[String] = []
			if params.has("ice"):
				parts.append("%d ice" % params["ice"])
			if params.has("web"):
				parts.append("%d webs" % params["web"])
			return "Goal: Clear " + ", ".join(parts)
		LevelData.GoalType.CHARGE_MANA:
			return "Goal: Charge mana %d times" % params.get("charges", 5)
		LevelData.GoalType.MIXED:
			var parts: Array[String] = []
			if params.has("count") and params.has("type"):
				var type_name: String = PieceData.get_piece_name(params["type"])
				parts.append("collect %d %s" % [params["count"], type_name])
			if params.has("ice"):
				parts.append("clear %d ice" % params["ice"])
			if params.has("web"):
				parts.append("clear %d webs" % params["web"])
			if params.has("score"):
				parts.append("score %d" % params["score"])
			return "Goals: " + ", ".join(parts)
	return ""


func _open_team_selector(slot: int) -> void:
	var selector: Control = TEAM_SELECTOR_SCENE.instantiate()
	selector.cryptid_selected.connect(func(cid: String) -> void:
		PlayerData.set_team_slot(slot, cid)
		_refresh_team_buttons()
		_update_leader_skill()
	)
	add_child(selector)
