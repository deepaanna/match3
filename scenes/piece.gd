extends Sprite2D
## Visual representation of a single board piece.

var piece_type: int = PieceData.PieceType.NONE
var grid_col: int = -1
var grid_row: int = -1
var is_selected: bool = false

var _highlight_tween: Tween = null

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
	modulate = PieceData.get_color(type)


func set_type(type: int) -> void:
	piece_type = type
	modulate = PieceData.get_color(type)


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
		scale = Vector2.ONE * base_scale


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
