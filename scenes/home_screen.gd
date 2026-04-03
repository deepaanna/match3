extends Control
# FINAL LAUNCH SPRINT COMPLETE

@onready var _field_guide_button: Button = %FieldGuideButton
@onready var _investigate_button: Button = %InvestigateButton
@onready var _cameras_button: Button = %CamerasButton


func _ready() -> void:
	var play_button: Button = $VBoxContainer/PlayButton
	play_button.pressed.connect(_on_play_pressed)

	_field_guide_button.pressed.connect(func() -> void: SceneManager.change_scene("res://scenes/field_guide_screen.tscn"))
	_investigate_button.pressed.connect(func() -> void: SceneManager.change_scene("res://scenes/investigation_screen.tscn"))
	_cameras_button.pressed.connect(func() -> void: SceneManager.change_scene("res://scenes/trail_camera_screen.tscn"))

	# Update level label to show current progress
	var level_label: Label = $VBoxContainer/LevelLabel
	level_label.text = "Level %d" % (PlayerData.highest_level_completed + 1)

	# Daily login streak check (deferred so layout is settled first)
	var login_sys := preload("res://scripts/systems/daily_login_system.gd").new()
	add_child(login_sys)
	login_sys.call_deferred("check_and_show", self)

	# Battle Pass button (above nav bar)
	_add_battle_pass_button()

	# Shop button (next to Field Pass)
	_add_shop_button()

	# Debug menu button (top-right corner, small and unobtrusive)
	_add_debug_button()

	# Music
	EventBus.play_music.emit("menu_theme")


func _on_play_pressed() -> void:
	SceneManager.change_scene("res://scenes/map_screen.tscn")


func _add_battle_pass_button() -> void:
	var btn := Button.new()
	btn.text = "Field Pass"
	btn.custom_minimum_size = Vector2(140, 40)
	btn.add_theme_font_size_override("font_size", 14)
	btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn.offset_top = -105.0
	btn.offset_bottom = -65.0
	btn.offset_left = -70.0
	btn.offset_right = 70.0
	btn.pressed.connect(func() -> void:
		SceneManager.change_scene("res://scenes/ui/battle_pass_screen.tscn")
	)
	add_child(btn)


func _add_shop_button() -> void:
	var btn := Button.new()
	btn.text = "Shop"
	btn.custom_minimum_size = Vector2(100, 40)
	btn.add_theme_font_size_override("font_size", 14)
	btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn.offset_top = -155.0
	btn.offset_bottom = -115.0
	btn.offset_left = -50.0
	btn.offset_right = 50.0
	btn.pressed.connect(func() -> void:
		ShopSystem.open_shop()
	)
	add_child(btn)


func _add_debug_button() -> void:
	var btn := Button.new()
	btn.text = "DBG"
	btn.custom_minimum_size = Vector2(50, 30)
	btn.add_theme_font_size_override("font_size", 11)
	btn.modulate = Color(1, 1, 1, 0.4)
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_left = -60.0
	btn.offset_right = -5.0
	btn.offset_top = 5.0
	btn.offset_bottom = 35.0
	btn.pressed.connect(_on_debug_pressed)
	add_child(btn)


func _on_debug_pressed() -> void:
	# Simulate F12 press to toggle the DebugMenu autoload
	var event := InputEventKey.new()
	event.keycode = KEY_F12
	event.pressed = true
	Input.parse_input_event(event)
