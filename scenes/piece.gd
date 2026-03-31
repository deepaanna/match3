extends Sprite2D
## Visual representation of a single board piece. Supports booster overlays.
# PERSISTENT BOOSTERS + VFX + SAVE v1.0

var piece_type: int = PieceData.PieceType.NONE
var booster_type: int = PieceData.BoosterType.NONE
var grid_col: int = -1
var grid_row: int = -1
var is_selected: bool = false

var _highlight_tween: Tween = null
var _booster_glow_tween: Tween = null
var _booster_hold_tween: Tween = null

static var _shared_texture: ImageTexture = null


func _ready() -> void:
	if _shared_texture == null:
		_shared_texture = _create_circle_texture()
	texture = _shared_texture
	var target_size: float = GameConfig.CELL_SIZE * GameConfig.PIECE_SCALE
	var tex_size: float = texture.get_width()
	scale = Vector2.ONE * (target_size / tex_size)


func setup(col: int, row: int, type: int) -> void:
	grid_col = col
	grid_row = row
	piece_type = type
	booster_type = PieceData.BoosterType.NONE
	modulate = PieceData.get_color(type)
	_stop_booster_glow()
	queue_redraw()


func set_type(type: int) -> void:
	piece_type = type
	modulate = PieceData.get_color(type)


func set_booster(type: int) -> void:
	booster_type = type
	if booster_type != PieceData.BoosterType.NONE:
		# Brighten the piece color so boosters stand out
		var base_color: Color = PieceData.get_color(piece_type)
		modulate = base_color.lightened(0.35)
		_start_booster_glow()
	else:
		modulate = PieceData.get_color(piece_type)
		_stop_booster_glow()
	queue_redraw()


func _start_booster_glow() -> void:
	_stop_booster_glow()
	var base_color: Color = PieceData.get_color(piece_type)
	var bright: Color = base_color.lightened(0.65)
	var dim: Color = base_color.lightened(0.35)
	# Color pulse — brighter and slower for persistent "hold" feel
	_booster_glow_tween = create_tween().set_loops()
	_booster_glow_tween.tween_property(self, "modulate", bright, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_booster_glow_tween.tween_property(self, "modulate", dim, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Scale "hold" pulse — gentle breathing that signals persistence
	var base_scale: float = GameConfig.CELL_SIZE * GameConfig.PIECE_SCALE / texture.get_width()
	var hold_up: float = base_scale * 1.08
	var hold_down: float = base_scale * 0.97
	_booster_hold_tween = create_tween().set_loops()
	_booster_hold_tween.tween_property(self, "scale", Vector2.ONE * hold_up, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_booster_hold_tween.tween_property(self, "scale", Vector2.ONE * hold_down, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_booster_glow() -> void:
	if _booster_glow_tween:
		_booster_glow_tween.kill()
		_booster_glow_tween = null
	if _booster_hold_tween:
		_booster_hold_tween.kill()
		_booster_hold_tween = null


func set_selected(selected: bool) -> void:
	is_selected = selected
	if _highlight_tween:
		_highlight_tween.kill()
		_highlight_tween = null

	var base_scale: float = GameConfig.CELL_SIZE * GameConfig.PIECE_SCALE / texture.get_width()

	if selected:
		var highlight: float = base_scale * GameConfig.HIGHLIGHT_SCALE
		_highlight_tween = create_tween().set_loops()
		_highlight_tween.tween_property(self, "scale", Vector2.ONE * highlight, 0.3)
		_highlight_tween.tween_property(self, "scale", Vector2.ONE * base_scale, 0.3)
	else:
		# Don't snap scale on booster pieces — their hold pulse handles it
		if booster_type == PieceData.BoosterType.NONE:
			scale = Vector2.ONE * base_scale


func _draw() -> void:
	if booster_type == PieceData.BoosterType.NONE:
		return

	# Bright glow ring behind the icon — double ring for emphasis
	var glow_color := Color(1, 1, 1, 0.35)
	draw_arc(Vector2.ZERO, 26.0, 0, TAU, 32, glow_color, 5.0)
	var inner_glow := Color(1, 1, 0.8, 0.2)
	draw_arc(Vector2.ZERO, 20.0, 0, TAU, 32, inner_glow, 3.0)

	var c: Color = Color(1, 1, 1, 0.95)

	match booster_type:
		PieceData.BoosterType.LINE_H:
			# Horizontal arrows — thicker lines, more visible
			draw_line(Vector2(-24, 0), Vector2(24, 0), c, 4.0)
			draw_line(Vector2(-24, 0), Vector2(-16, -7), c, 3.0)
			draw_line(Vector2(-24, 0), Vector2(-16, 7), c, 3.0)
			draw_line(Vector2(24, 0), Vector2(16, -7), c, 3.0)
			draw_line(Vector2(24, 0), Vector2(16, 7), c, 3.0)
		PieceData.BoosterType.LINE_V:
			# Vertical arrows
			draw_line(Vector2(0, -24), Vector2(0, 24), c, 4.0)
			draw_line(Vector2(0, -24), Vector2(-7, -16), c, 3.0)
			draw_line(Vector2(0, -24), Vector2(7, -16), c, 3.0)
			draw_line(Vector2(0, 24), Vector2(-7, 16), c, 3.0)
			draw_line(Vector2(0, 24), Vector2(7, 16), c, 3.0)
		PieceData.BoosterType.AREA_BOMB:
			# Starburst — filled center circle + rays
			draw_circle(Vector2.ZERO, 6.0, c)
			for i in range(8):
				var angle: float = i * TAU / 8
				draw_line(
					Vector2.from_angle(angle) * 8.0,
					Vector2.from_angle(angle) * 22.0,
					c, 2.5
				)
		PieceData.BoosterType.COLOR_BOMB:
			# Rainbow star — each line a different color
			var rainbow: Array[Color] = [
				Color(1, 0.3, 0.3), Color(1, 0.7, 0.2), Color(0.3, 1, 0.3),
				Color(0.3, 0.5, 1), Color(0.8, 0.3, 1),
			]
			# Filled white center
			draw_circle(Vector2.ZERO, 5.0, Color(1, 1, 1, 0.8))
			for i in range(5):
				var a1: float = i * TAU / 5 - PI / 2
				var a2: float = (i + 2) * TAU / 5 - PI / 2
				draw_line(
					Vector2.from_angle(a1) * 22.0,
					Vector2.from_angle(a2) * 22.0,
					rainbow[i], 3.0
				)


static func _create_circle_texture() -> ImageTexture:
	var size: int = 64
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(size / 2.0, size / 2.0)
	var radius: float = size / 2.0 - 2.0

	for x in range(size):
		for y in range(size):
			var dist: float = Vector2(x, y).distance_to(center)
			if dist <= radius - 1.0:
				image.set_pixel(x, y, Color.WHITE)
			elif dist <= radius:
				var alpha: float = 1.0 - (dist - (radius - 1.0))
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
			else:
				image.set_pixel(x, y, Color(1, 1, 1, 0))

	return ImageTexture.create_from_image(image)
