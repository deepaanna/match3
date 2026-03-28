extends Control

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/SubtitleLabel

var _can_skip: bool = false


func _ready() -> void:
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 0.8)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func() -> void: _can_skip = true)
	tween.tween_interval(2.0)
	tween.tween_callback(_go_to_boot)


func _unhandled_input(event: InputEvent) -> void:
	if _can_skip and (event is InputEventMouseButton or event is InputEventScreenTouch):
		if event.is_pressed():
			_can_skip = false
			_go_to_boot()


func _go_to_boot() -> void:
	SceneManager.change_scene("res://scenes/boot_screen.tscn")
