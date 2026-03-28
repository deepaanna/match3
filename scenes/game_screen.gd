extends Control

@onready var score_label: Label = $HUD/HBoxContainer/ScoreLabel
@onready var moves_label: Label = $HUD/HBoxContainer/MovesLabel
@onready var level_label: Label = $HUD/HBoxContainer/LevelLabel
@onready var pause_button: Button = $HUD/PauseButton
@onready var pause_overlay: Control = $PauseOverlay
@onready var cascade_label: Label = $CascadeLabel
@onready var star_progress_bar: ProgressBar = $StarProgress/ProgressBar
@onready var star_1_label: Label = $StarProgress/Star1
@onready var star_2_label: Label = $StarProgress/Star2
@onready var star_3_label: Label = $StarProgress/Star3
@onready var goal_label: Label = $StarProgress/GoalLabel

var _score_tween: Tween = null
var _banner_tween: Tween = null
var _cascade_tween: Tween = null
var _ending: bool = false
var _mana_system: Node = null
var _ability_system: Node = null
var _leader_skill_system: Node = null
var _team_panel: Control = null
var _failure_popup: Control = null

const TEAM_PANEL_SCENE: PackedScene = preload("res://scenes/ui/team_panel.tscn")
const GAME_OVER_POPUP_SCENE: PackedScene = preload("res://scenes/ui/game_over_popup.tscn")


func _ready() -> void:
	# Allow this screen to process while paused (for pause overlay buttons)
	process_mode = Node.PROCESS_MODE_ALWAYS

	pause_overlay.visible = false
	cascade_label.visible = false

	# Instantiate systems
	_setup_systems()

	# Connect signals
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.moves_changed.connect(_on_moves_changed)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.cascade_started.connect(_on_cascade_started)
	EventBus.board_settled.connect(_on_board_settled)

	pause_button.pressed.connect(func() -> void: EventBus.pause_pressed.emit())
	$PauseOverlay/VBoxContainer/ResumeButton.pressed.connect(
		func() -> void: EventBus.resume_pressed.emit()
	)
	$PauseOverlay/VBoxContainer/QuitButton.pressed.connect(
		func() -> void: EventBus.quit_pressed.emit()
	)

	EventBus.ability_activated.connect(_on_ability_activated)

	# Initialize labels
	level_label.text = "Level %d" % GameManager.current_level
	_on_score_changed(GameManager.score)
	_on_moves_changed(GameManager.moves_remaining)

	# Setup star progress bar
	_setup_star_progress()


func _setup_systems() -> void:
	# ManaSystem
	var ManaSystemScript: GDScript = preload("res://scripts/systems/mana_system.gd")
	_mana_system = ManaSystemScript.new()
	_mana_system.name = "ManaSystem"
	add_child(_mana_system)

	# LeaderSkillSystem
	var LeaderSkillScript: GDScript = preload("res://scripts/systems/leader_skill_system.gd")
	_leader_skill_system = LeaderSkillScript.new()
	_leader_skill_system.name = "LeaderSkillSystem"
	add_child(_leader_skill_system)
	GameManager.set_leader_skill_system(_leader_skill_system)

	# AbilitySystem
	var AbilityScript: GDScript = preload("res://scripts/systems/ability_system.gd")
	_ability_system = AbilityScript.new()
	_ability_system.name = "AbilitySystem"
	add_child(_ability_system)

	# Get board reference and setup ability system
	var board: Node2D = $BoardContainer/Board
	_ability_system.setup(board, _mana_system)

	# Team panel — must add to tree before setup() so @onready vars resolve
	_team_panel = TEAM_PANEL_SCENE.instantiate()
	_team_panel.position = Vector2(0, GameConfig.TEAM_PANEL_Y)
	add_child(_team_panel)
	_team_panel.setup(_mana_system)
	_team_panel.cryptid_tapped.connect(_on_cryptid_tapped)


func _on_cryptid_tapped(cryptid_id: String) -> void:
	if _ability_system:
		_ability_system.try_activate_ability(cryptid_id)


func _setup_star_progress() -> void:
	var level_data: LevelData = GameManager.current_level_data
	if not level_data:
		level_data = LevelData.create_default(GameManager.current_level)

	var bar_width: float = 520.0  # progress bar width (540 - 20 padding)
	star_progress_bar.max_value = level_data.star_3_score

	# Position star markers at threshold fractions
	var s1_frac: float = float(level_data.star_1_score) / float(level_data.star_3_score)
	var s2_frac: float = float(level_data.star_2_score) / float(level_data.star_3_score)

	star_1_label.position.x = 10.0 + bar_width * s1_frac - 8.0
	star_2_label.position.x = 10.0 + bar_width * s2_frac - 12.0
	star_3_label.position.x = 10.0 + bar_width - 20.0

	goal_label.text = "Goal: %d pts" % level_data.star_1_score


func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score

	# Update star progress bar
	star_progress_bar.value = new_score

	# Pop animation
	if _score_tween:
		_score_tween.kill()
	_score_tween = create_tween()
	score_label.scale = Vector2(1.2, 1.2)
	_score_tween.tween_property(score_label, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_moves_changed(moves_remaining: int) -> void:
	moves_label.text = "Moves: %d" % moves_remaining


func _on_game_paused() -> void:
	pause_overlay.visible = true
	get_tree().paused = true


func _on_game_resumed() -> void:
	get_tree().paused = false
	pause_overlay.visible = false


func _on_level_completed(_final_score: int, _star_rating: int) -> void:
	if _ending:
		return
	_ending = true
	await get_tree().create_timer(0.8).timeout
	SceneManager.change_scene("res://scenes/result_screen.tscn")


func _on_game_over(_final_score: int, _star_rating: int) -> void:
	if _ending:
		return
	# Show failure popup instead of immediate transition
	_show_failure_popup()


func _show_failure_popup() -> void:
	if _failure_popup:
		return

	_failure_popup = GAME_OVER_POPUP_SCENE.instantiate()
	_failure_popup.continue_coins.connect(_on_continue_coins)
	_failure_popup.continue_ad.connect(_on_continue_ad)
	_failure_popup.give_up.connect(_on_give_up)
	add_child(_failure_popup)


func _on_continue_coins() -> void:
	if PlayerData.spend_coins(50):
		GameManager.grant_extra_moves(5)
		EventBus.extra_moves_purchased.emit()
		_remove_failure_popup()


func _on_continue_ad() -> void:
	# Placeholder: ad would play here, then grant moves
	GameManager.grant_extra_moves(5)
	EventBus.ad_watched.emit("continue")
	_remove_failure_popup()


func _on_give_up() -> void:
	_remove_failure_popup()
	_ending = true
	SceneManager.change_scene("res://scenes/result_screen.tscn")


func _remove_failure_popup() -> void:
	if _failure_popup:
		_failure_popup.queue_free()
		_failure_popup = null


func _on_ability_activated(cryptid_id: String) -> void:
	var cryptid: CryptidData = CryptidDatabase.get_cryptid(cryptid_id)
	if not cryptid:
		return

	var desc: String = CryptidData.get_ability_description(cryptid.ability_type, cryptid.ability_power)
	var text: String = "%s: %s!" % [cryptid.display_name, desc]

	# Create banner label
	var banner := Label.new()
	banner.text = text
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 16)
	banner.modulate = Color(1.0, 0.9, 0.2)
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = -30.0
	banner.offset_bottom = 0.0
	banner.offset_left = 10.0
	banner.offset_right = -10.0
	add_child(banner)

	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	# Slide in from top
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(banner, "offset_top", 90.0, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(banner, "offset_bottom", 120.0, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.set_parallel(false)
	# Hold
	_banner_tween.tween_interval(1.0)
	# Fade out
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.3)
	_banner_tween.tween_callback(func() -> void: banner.queue_free())


func _on_cascade_started(multiplier: float) -> void:
	if _cascade_tween:
		_cascade_tween.kill()
	cascade_label.visible = true
	cascade_label.text = "x%.1f" % multiplier

	_cascade_tween = create_tween()
	cascade_label.scale = Vector2(1.5, 1.5)
	_cascade_tween.tween_property(cascade_label, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_board_settled() -> void:
	# Hide cascade label after board settles (cascade sequence ended)
	if cascade_label.visible:
		if _cascade_tween:
			_cascade_tween.kill()
		_cascade_tween = create_tween()
		_cascade_tween.tween_interval(0.5)
		_cascade_tween.tween_callback(func() -> void: cascade_label.visible = false)
