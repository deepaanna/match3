extends Node
## Handles click/swipe input for piece selection and swap requests.

var _selected_col: int = -1
var _selected_row: int = -1
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO

@onready var board: Node2D = get_parent()


func _to_local(viewport_pos: Vector2) -> Vector2:
	return board.get_global_transform().affine_inverse() * viewport_pos


func _unhandled_input(event: InputEvent) -> void:
	if board.state != board.BoardState.IDLE:
		return
	if GameManager.state != GameManager.GameState.PLAYING:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _is_dragging:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		_drag_start = _to_local(event.position)
		_is_dragging = true

		var cell: Vector2i = board.pixel_to_grid(_drag_start)
		if not board.is_valid_cell(cell.x, cell.y):
			_deselect()
			return

		if _selected_col >= 0 and _selected_row >= 0:
			# Second click — attempt swap
			if board.are_adjacent(_selected_col, _selected_row, cell.x, cell.y):
				var from_col: int = _selected_col
				var from_row: int = _selected_row
				_deselect()
				EventBus.swap_requested.emit(from_col, from_row, cell.x, cell.y)
			else:
				# Select new piece instead
				_select(cell.x, cell.y)
		else:
			# First click — select
			_select(cell.x, cell.y)
	else:
		_is_dragging = false


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var local_pos: Vector2 = _to_local(event.position)
	var drag_delta: Vector2 = local_pos - _drag_start
	if drag_delta.length() < GameConfig.MIN_SWIPE_DISTANCE:
		return

	_is_dragging = false

	var cell: Vector2i = board.pixel_to_grid(_drag_start)
	if not board.is_valid_cell(cell.x, cell.y):
		return

	# Determine swipe direction (dominant axis)
	var direction: Vector2i
	if absf(drag_delta.x) > absf(drag_delta.y):
		direction = Vector2i(1 if drag_delta.x > 0 else -1, 0)
	else:
		direction = Vector2i(0, 1 if drag_delta.y > 0 else -1)

	var target_col: int = cell.x + direction.x
	var target_row: int = cell.y + direction.y

	if board.is_valid_cell(target_col, target_row):
		_deselect()
		EventBus.swap_requested.emit(cell.x, cell.y, target_col, target_row)


func _select(col: int, row: int) -> void:
	_deselect()
	_selected_col = col
	_selected_row = row
	var piece: Sprite2D = board.piece_nodes[col][row]
	if piece:
		piece.set_selected(true)
	EventBus.piece_selected.emit(col, row)


func _deselect() -> void:
	if _selected_col >= 0 and _selected_row >= 0:
		var piece: Sprite2D = board.piece_nodes[_selected_col][_selected_row]
		if piece:
			piece.set_selected(false)
	_selected_col = -1
	_selected_row = -1
	EventBus.piece_deselected.emit()
