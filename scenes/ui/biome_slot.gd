extends Control
## Single biome slot for trail camera placement.

@onready var _biome_name: Label = %BiomeName
@onready var _status_label: Label = %StatusLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _action_btn: Button = %ActionButton
@onready var _duration_row: HBoxContainer = %DurationRow
@onready var _result_label: Label = %ResultLabel

var _biome: String = ""
var _action_callable: Callable


func setup(biome: String) -> void:
	_biome = biome
	_biome_name.text = TrailCameraSystem.BIOME_NAMES.get(biome, biome)
	update_state()


func update_state() -> void:
	# Clear duration buttons
	for child in _duration_row.get_children():
		child.queue_free()

	# Disconnect previous action callback
	if _action_callable.is_valid() and _action_btn.pressed.is_connected(_action_callable):
		_action_btn.pressed.disconnect(_action_callable)

	if TrailCameraSystem.is_camera_ready(_biome):
		_status_label.text = "READY!"
		_status_label.modulate = Color(0.3, 1.0, 0.3)
		_timer_label.text = ""
		_action_btn.text = "Collect!"
		_action_btn.visible = true
		_duration_row.visible = false
		_action_callable = func() -> void: _collect()
		_action_btn.pressed.connect(_action_callable)
	elif TrailCameraSystem.is_camera_active(_biome):
		_status_label.text = "Active"
		_status_label.modulate = Color(1.0, 0.8, 0.2)
		_action_btn.visible = false
		_duration_row.visible = false
	else:
		_status_label.text = "Empty"
		_status_label.modulate = Color(0.5, 0.5, 0.5)
		_timer_label.text = ""
		_action_btn.text = "Place Camera"
		_action_btn.visible = false  # Hidden until duration selected
		_duration_row.visible = true

		for hours: int in [4, 6, 8]:
			var btn := Button.new()
			btn.text = "%dh" % hours
			btn.custom_minimum_size = Vector2(55, 30)
			btn.add_theme_font_size_override("font_size", 12)
			var captured_hours: int = hours
			btn.pressed.connect(func() -> void: _place(captured_hours))
			_duration_row.add_child(btn)


func update_timer() -> void:
	if TrailCameraSystem.is_camera_active(_biome) and not TrailCameraSystem.is_camera_ready(_biome):
		var remaining: float = TrailCameraSystem.get_time_remaining(_biome)
		var hours: int = floori(remaining / 3600.0)
		var minutes: int = floori(fmod(remaining, 3600.0) / 60.0)
		var seconds: int = floori(fmod(remaining, 60.0))
		_timer_label.text = "%d:%02d:%02d" % [hours, minutes, seconds]
	elif TrailCameraSystem.is_camera_ready(_biome):
		# Camera just became ready, refresh the slot
		if _status_label.text != "READY!":
			update_state()


func _place(hours: int) -> void:
	TrailCameraSystem.place_camera(_biome, hours)
	update_state()


func _collect() -> void:
	var rewards: Dictionary = TrailCameraSystem.collect_camera(_biome)
	if rewards.is_empty():
		return

	var text: String = "+%d Fragments" % rewards["fragments"]
	if rewards["coins"] > 0:
		text += " +%d Coins" % rewards["coins"]
	if rewards["free_pull"]:
		text += " +Free Pull!"
	_result_label.text = text
	_result_label.visible = true

	update_state()
