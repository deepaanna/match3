extends Node
## Contextual, progressive tutorial hint system.
## Shows one-time thematic hints triggered by game events at specific levels.
## Tracks shown hints in PlayerData so returning players skip repeats.
##
## Hint types:
##   A — Pulsing piece highlight (early match guidance)
##   B — Directional arrow trail (swap/cascade guidance)
##   C — Misty whisper text (mana, abilities, collection)
##   D — Cryptid silhouette tease (obstacles, boosters)

# All hint definitions: id -> {level, text, type, ...}
# "level" = the level at which this hint can first appear (0 = any level)
const HINTS: Dictionary = {
	"first_match": {
		"level": 1,
		"text": "Swap two adjacent cryptids to match 3 in a row!",
		"type": "pulse",  # Type A — pulse the hint move
	},
	"cascade_intro": {
		"level": 1,
		"text": "Chain reactions score bonus points!",
		"type": "whisper",  # Type C
	},
	"collect_intro": {
		"level": 2,
		"text": "Match the target cryptid to collect evidence!",
		"type": "whisper",
	},
	"match_4_tip": {
		"level": 3,
		"text": "Match 4 in a row to create a special booster!",
		"type": "arrow",  # Type B
	},
	"ice_intro": {
		"level": 4,
		"text": "Ice blocks! Clear pieces on top to crack the ice.",
		"type": "silhouette",  # Type D
	},
	"web_intro": {
		"level": 7,
		"text": "Webs trap pieces! Clear adjacent matches to free them.",
		"type": "silhouette",
	},
	"booster_tip": {
		"level": 5,
		"text": "Boosters glow — include them in a match to unleash their power!",
		"type": "silhouette",
	},
	"mana_intro": {
		"level": 1,
		"text": "Matching charges your cryptid's mana. Fill it to unleash abilities!",
		"type": "whisper",
	},
	"ability_ready": {
		"level": 1,
		"text": "Mana full! Tap your cryptid portrait to activate its ability!",
		"type": "whisper",
	},
}

var _board: Node2D = null
var _hint_overlay: Control = null  # Parent for visual hints
var _cooldown_timer: float = 0.0
var _active_hint_id: String = ""
var _active_tween: Tween = null
var _pulse_tween: Tween = null


func setup(board: Node2D, overlay_parent: Control) -> void:
	_board = board
	_hint_overlay = overlay_parent
	_connect_signals()


func _connect_signals() -> void:
	EventBus.board_ready.connect(_on_board_ready)
	EventBus.matches_cleared.connect(_on_matches_cleared)
	EventBus.cascade_started.connect(_on_cascade_started)
	EventBus.obstacle_cleared.connect(_on_obstacle_cleared)
	EventBus.mana_full.connect(_on_mana_full)
	EventBus.goal_progress_updated.connect(_on_goal_progress)
	EventBus.board_settled.connect(_on_board_settled)


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


# --- Trigger handlers ---

func _on_board_ready() -> void:
	var level: int = GameManager.current_level
	# L1: Pulse the first valid move
	if level == 1:
		_try_show("first_match")
	# L4+: Ice intro when level has ice obstacles
	elif _level_has_obstacle(LevelData.ObstacleType.ICE):
		_try_show("ice_intro")
	# L7+: Web intro when level has web obstacles
	elif _level_has_obstacle(LevelData.ObstacleType.WEB):
		_try_show("web_intro")
	# L2: Collect intro
	elif level == 2:
		_try_show("collect_intro")


func _on_matches_cleared(count: int, cascade_level: int) -> void:
	# After first cascade in a game
	if cascade_level >= 1:
		_try_show("cascade_intro")
	# Booster tip: match-4+ means a booster was likely created
	if count >= 4:
		_try_show("match_4_tip")


func _on_cascade_started(_multiplier: float) -> void:
	pass  # cascade_intro handled in matches_cleared


func _on_obstacle_cleared(_col: int, _row: int, _obstacle_type: int) -> void:
	pass  # Ice/web intros shown at board_ready, not on clear


func _on_mana_full(_cryptid_id: String) -> void:
	_try_show("ability_ready")


func _on_goal_progress(_goal_id: String, _current: int, _target: int) -> void:
	# First mana charge hint
	if _goal_id == "mana" or _goal_id == "collect":
		pass  # Already handled by board_ready for collect_intro


func _on_board_settled() -> void:
	# Good time to show mana intro if player has charged any mana but hasn't seen hint
	var level: int = GameManager.current_level
	if level <= 3:
		_try_show("mana_intro")
	# Booster tip after first booster appears on the board
	if _board and _board_has_booster():
		_try_show("booster_tip")


# --- Core hint logic ---

func _try_show(hint_id: String) -> void:
	# Already shown (persisted)
	if PlayerData.is_hint_shown(hint_id):
		return
	# Another hint is active
	if _active_hint_id != "":
		return
	# Cooldown
	if _cooldown_timer > 0.0:
		return
	# Hint definition check
	if not HINTS.has(hint_id):
		return

	var hint: Dictionary = HINTS[hint_id]
	var level: int = GameManager.current_level

	# Level gate
	if level < hint.get("level", 0):
		return

	# Show it
	_active_hint_id = hint_id
	PlayerData.mark_hint_shown(hint_id)

	var hint_type: String = hint.get("type", "whisper")
	var text: String = hint.get("text", "")

	match hint_type:
		"pulse":
			_show_pulse_hint(text)
		"arrow":
			_show_arrow_hint(text)
		"silhouette":
			_show_silhouette_hint(text)
		_:
			_show_whisper_hint(text)

	EventBus.tutorial_hint_show.emit(hint_id, text, Vector2.ZERO)


# --- Visual hint implementations ---

func _show_whisper_hint(text: String) -> void:
	## Type C: Semi-transparent text that fades in, holds, fades out.
	var label := _create_hint_label(text, Color(0.7, 0.85, 1.0, 0.0))
	label.position = Vector2(20, 200)
	_hint_overlay.add_child(label)

	_active_tween = _hint_overlay.create_tween()
	_active_tween.tween_property(label, "modulate:a", 0.95, GameConfig.TUTORIAL_HINT_FADE_IN)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_interval(GameConfig.TUTORIAL_HINT_DISPLAY)
	_active_tween.tween_property(label, "modulate:a", 0.0, GameConfig.TUTORIAL_HINT_FADE_OUT)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_active_tween.tween_callback(func() -> void:
		label.queue_free()
		_finish_hint()
	)


func _show_pulse_hint(text: String) -> void:
	## Type A: Show text + pulse the first valid hint move on the board.
	_show_whisper_hint(text)
	# Also pulse pieces if board is available
	if _board and _board.has_method("find_hint_move"):
		var hint_move: Array = _board.find_hint_move()
		if not hint_move.is_empty():
			var a: Vector2i = hint_move[0]
			var b: Vector2i = hint_move[1]
			var piece_a: Sprite2D = _board.piece_nodes[a.x][a.y]
			var piece_b: Sprite2D = _board.piece_nodes[b.x][b.y]
			if piece_a and piece_b and _board.piece_animator:
				_pulse_tween = _board.piece_animator.animate_hint(piece_a, piece_b)


func _show_arrow_hint(text: String) -> void:
	## Type B: Text + a simple animated arrow between two hint-move pieces.
	_show_whisper_hint(text)
	if not _board or not _board.has_method("find_hint_move"):
		return
	var hint_move: Array = _board.find_hint_move()
	if hint_move.is_empty():
		return

	var a: Vector2i = hint_move[0]
	var b: Vector2i = hint_move[1]
	var from_pos: Vector2 = _board.grid_to_pixel(a.x, a.y)
	var to_pos: Vector2 = _board.grid_to_pixel(b.x, b.y)

	# Create a simple arrow using a ColorRect + rotation
	var arrow := _create_arrow_node(from_pos, to_pos)
	_board.add_child(arrow)

	# Fade arrow in and out with the hint
	var t: Tween = _board.create_tween()
	t.tween_property(arrow, "modulate:a", 1.0, GameConfig.TUTORIAL_HINT_FADE_IN)
	t.tween_interval(GameConfig.TUTORIAL_HINT_DISPLAY)
	t.tween_property(arrow, "modulate:a", 0.0, GameConfig.TUTORIAL_HINT_FADE_OUT)
	t.tween_callback(arrow.queue_free)


func _show_silhouette_hint(text: String) -> void:
	## Type D: Text with a darker background overlay for obstacle/booster hints.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 180.0
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Dark semi-transparent background via StyleBoxFlat
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.15, 0.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	_hint_overlay.add_child(panel)

	# Animate: fade bg + text in together
	panel.modulate = Color(1, 1, 1, 0)
	_active_tween = _hint_overlay.create_tween()
	_active_tween.tween_property(panel, "modulate:a", 1.0, GameConfig.TUTORIAL_HINT_FADE_IN)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Also animate the bg alpha
	_active_tween.parallel().tween_property(style, "bg_color:a", 0.85, GameConfig.TUTORIAL_HINT_FADE_IN)
	_active_tween.tween_interval(GameConfig.TUTORIAL_HINT_DISPLAY)
	_active_tween.tween_property(panel, "modulate:a", 0.0, GameConfig.TUTORIAL_HINT_FADE_OUT)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_active_tween.tween_callback(func() -> void:
		panel.queue_free()
		_finish_hint()
	)


# --- Helpers ---

func _create_hint_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(500, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Add a subtle shadow via outline
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	return label


func _create_arrow_node(from: Vector2, to: Vector2) -> Node2D:
	## Creates a simple arrow drawn between two board positions.
	var node := Node2D.new()
	node.z_index = 15
	node.modulate = Color(1, 1, 1, 0)

	var dir: Vector2 = (to - from).normalized()

	# Line2D children for the shaft and arrowhead
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(1.0, 0.95, 0.5, 0.8)
	line.add_point(from)
	line.add_point(to)
	node.add_child(line)

	# Arrowhead
	var head_size: float = 10.0
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = to
	var left: Vector2 = to - dir * head_size + perp * head_size * 0.5
	var right: Vector2 = to - dir * head_size - perp * head_size * 0.5

	var head := Line2D.new()
	head.width = 3.0
	head.default_color = Color(1.0, 0.95, 0.5, 0.8)
	head.add_point(left)
	head.add_point(tip)
	head.add_point(right)
	node.add_child(head)

	return node


func _finish_hint() -> void:
	_kill_pulse()
	_active_hint_id = ""
	_cooldown_timer = GameConfig.TUTORIAL_HINT_COOLDOWN
	EventBus.tutorial_hint_dismiss.emit()


func _kill_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
		# Reset piece scales
		if _board:
			var base_scale: float = GameConfig.CELL_SIZE * GameConfig.PIECE_SCALE / 64.0
			for col in range(GameConfig.GRID_COLS):
				for row in range(GameConfig.GRID_ROWS):
					var p: Sprite2D = _board.piece_nodes[col][row]
					if p and not p.is_selected:
						p.scale = Vector2.ONE * base_scale


func _level_has_obstacle(obs_type: int) -> bool:
	var level_data: LevelData = GameManager.current_level_data
	if not level_data:
		return false
	for obs: Dictionary in level_data.obstacles:
		if obs.get("type", 0) == obs_type:
			return true
	return false


func _board_has_booster() -> bool:
	if not _board:
		return false
	for col in range(GameConfig.GRID_COLS):
		for row in range(GameConfig.GRID_ROWS):
			var p: Sprite2D = _board.piece_nodes[col][row]
			if p and p.booster_type != PieceData.BoosterType.NONE:
				return true
	return false
