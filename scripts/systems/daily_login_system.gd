extends Node
## Daily Login Streak System v1.0
## Tracks consecutive login days, grants escalating rewards on a 7-day cycle.
## Persistence is handled by PlayerData (login_streak, last_login_day).
## This node provides the streak popup visualization for any parent screen.
##
## Usage: instantiate via GDScript, add as child, call check_and_show(parent).
## Home screen does this automatically in _ready().

const STREAK_TITLES: Array[String] = [
	"Welcome back, investigator!",
	"The trail grows warmer...",
	"Evidence is mounting!",
	"Your reputation precedes you!",
	"The cryptids are restless!",
	"A breakthrough approaches!",
	"Legendary discovery day!",
]


func check_and_show(parent: Control) -> void:
	## Call on scene ready. Shows streak popup if new login day, does nothing otherwise.
	var reward: Dictionary = PlayerData.check_daily_login()
	if reward.is_empty():
		return
	_show_popup(parent, PlayerData.login_streak, reward)


func _show_popup(parent: Control, streak: int, reward: Dictionary) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.03, 0.08, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -160.0
	panel.offset_right = 160.0
	panel.offset_top = -100.0
	panel.offset_bottom = 100.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.12, 0.1, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Title varies by streak day
	var title := Label.new()
	var title_idx: int = clampi((streak - 1) % 7, 0, STREAK_TITLES.size() - 1)
	title.text = STREAK_TITLES[title_idx]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# Streak count
	var streak_label := Label.new()
	streak_label.text = "Streak: %d day%s" % [streak, "s" if streak != 1 else ""]
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_label.add_theme_font_size_override("font_size", 20)
	streak_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(streak_label)

	# Reward detail
	var reward_label := Label.new()
	reward_label.text = reward.get("label", "")
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_font_size_override("font_size", 13)
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(reward_label)

	# Tap to dismiss hint
	var hint := Label.new()
	hint.text = "Tap to dismiss"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hint)

	panel.add_child(vbox)
	overlay.add_child(panel)
	parent.add_child(overlay)

	# Wrap tween in array so the closure captures a mutable reference
	var tween_ref: Array = [null]

	# Tap-to-dismiss: clicking anywhere on overlay closes it immediately
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if tween_ref[0]:
				tween_ref[0].kill()
			var t := parent.create_tween()
			t.tween_property(overlay, "modulate:a", 0.0, 0.3)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			t.tween_callback(overlay.queue_free)
	)

	# Auto-dismiss after delay
	overlay.modulate = Color(1, 1, 1, 0)
	tween_ref[0] = parent.create_tween()
	tween_ref[0].tween_property(overlay, "modulate:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_ref[0].tween_interval(3.5)
	tween_ref[0].tween_property(overlay, "modulate:a", 0.0, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween_ref[0].tween_callback(overlay.queue_free)
	EventBus.play_sfx.emit("discovery")
