extends Control

@onready var _field_guide_button: Button = %FieldGuideButton
@onready var _investigate_button: Button = %InvestigateButton
@onready var _cameras_button: Button = %CamerasButton


func _ready() -> void:
	var play_button: Button = $VBoxContainer/PlayButton
	play_button.pressed.connect(_on_play_pressed)

	_field_guide_button.pressed.connect(func() -> void: SceneManager.change_scene("res://scenes/field_guide_screen.tscn"))
	_investigate_button.pressed.connect(func() -> void: SceneManager.change_scene("res://scenes/investigation_screen.tscn"))
	_cameras_button.pressed.connect(func() -> void: SceneManager.change_scene("res://scenes/trail_camera_screen.tscn"))

	# Daily login streak check (deferred so layout is settled first)
	var login_sys := preload("res://scripts/systems/daily_login_system.gd").new()
	add_child(login_sys)
	login_sys.call_deferred("check_and_show", self)


func _on_play_pressed() -> void:
	# Navigate to map screen instead of directly starting game
	SceneManager.change_scene("res://scenes/map_screen.tscn")
