extends Node2D
## Core board logic: grid data, state machine, swap/gravity/fill/cascade orchestration.
## Grid is column-major: grid[col][row], where row 0 is the top.

enum BoardState { IDLE, SWAPPING, CHECKING, CLEARING, FALLING, FILLING, SWAP_BACK, ABILITY }

const PIECE_SCENE: PackedScene = preload("res://scenes/piece.tscn")

var state: BoardState = BoardState.IDLE
var grid: Array = []  # Array[Array[int]] - column-major, stores PieceType ints
var piece_nodes: Array = []  # Array[Array[Sprite2D]] - mirrors grid, holds piece nodes
var cascade_level: int = 0

@export var match_finder: Node
@export var piece_animator: Node
@export var board_input: Node


func _ready() -> void:
	_init_grid()
	_spawn_initial_pieces()
	EventBus.swap_requested.connect(_on_swap_requested)


func _init_grid() -> void:
	grid.clear()
	piece_nodes.clear()
	for col in range(GameConfig.GRID_COLS):
		grid.append([])
		piece_nodes.append([])
	for col in range(GameConfig.GRID_COLS):
		for row in range(GameConfig.GRID_ROWS):
			var piece_type: int = _get_random_piece_no_match(col, row)
			grid[col].append(piece_type)
			piece_nodes[col].append(null)


func _get_random_piece_no_match(col: int, row: int) -> int:
	var available: Array[int] = []
	for i in range(PieceData.PIECE_COUNT):
		available.append(i)

	# Check horizontal (left 2)
	if col >= 2:
		if grid[col - 1][row] == grid[col - 2][row]:
			var exclude: int = grid[col - 1][row]
			available.erase(exclude)

	# Check vertical (up 2)
	if row >= 2:
		if grid[col][row - 1] == grid[col][row - 2]:
			var exclude: int = grid[col][row - 1]
			available.erase(exclude)

	return available[randi() % available.size()]


func _spawn_initial_pieces() -> void:
	for col in range(GameConfig.GRID_COLS):
		for row in range(GameConfig.GRID_ROWS):
			_create_piece_node(col, row, grid[col][row])


func _create_piece_node(col: int, row: int, piece_type: int) -> Sprite2D:
	var piece: Sprite2D = PIECE_SCENE.instantiate()
	add_child(piece)
	piece.setup(col, row, piece_type)
	piece.position = grid_to_pixel(col, row)
	piece_nodes[col][row] = piece
	return piece


func grid_to_pixel(col: int, row: int) -> Vector2:
	return Vector2(
		GameConfig.BOARD_OFFSET_X + col * GameConfig.CELL_SIZE + GameConfig.CELL_SIZE / 2.0,
		GameConfig.BOARD_OFFSET_Y + row * GameConfig.CELL_SIZE + GameConfig.CELL_SIZE / 2.0
	)


func pixel_to_grid(pixel_pos: Vector2) -> Vector2i:
	var col: int = floori((pixel_pos.x - GameConfig.BOARD_OFFSET_X) / GameConfig.CELL_SIZE)
	var row: int = floori((pixel_pos.y - GameConfig.BOARD_OFFSET_Y) / GameConfig.CELL_SIZE)
	return Vector2i(col, row)


func is_valid_cell(col: int, row: int) -> bool:
	return col >= 0 and col < GameConfig.GRID_COLS and row >= 0 and row < GameConfig.GRID_ROWS


func are_adjacent(col1: int, row1: int, col2: int, row2: int) -> bool:
	return absi(col1 - col2) + absi(row1 - row2) == 1


# --- State Machine ---

func _on_swap_requested(from_col: int, from_row: int, to_col: int, to_row: int) -> void:
	if state != BoardState.IDLE:
		return
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	if not is_valid_cell(from_col, from_row) or not is_valid_cell(to_col, to_row):
		return
	if not are_adjacent(from_col, from_row, to_col, to_row):
		return

	state = BoardState.SWAPPING
	cascade_level = 0
	GameManager.start_cascade()
	await _do_swap(from_col, from_row, to_col, to_row)

	state = BoardState.CHECKING
	var matches: Array = match_finder.find_matches(grid)

	if matches.is_empty():
		# No match — swap back
		state = BoardState.SWAP_BACK
		await _do_swap(to_col, to_row, from_col, from_row)
		state = BoardState.IDLE
		EventBus.swap_failed.emit()
	else:
		# Valid swap
		EventBus.swap_completed.emit()
		await _process_matches(matches)


func _process_matches(matches: Array) -> void:
	# Clear matched pieces
	state = BoardState.CLEARING
	var match_count: int = matches.size()
	EventBus.matches_found.emit(matches)

	# Count piece types before clearing for mana charging
	_emit_mana_charges(matches)

	await _clear_pieces(matches)
	EventBus.matches_cleared.emit(match_count, cascade_level)

	# Apply gravity
	state = BoardState.FALLING
	await _apply_gravity()

	# Fill empty spaces
	state = BoardState.FILLING
	await _fill_empty()

	# Check for cascades
	state = BoardState.CHECKING
	var new_matches: Array = match_finder.find_matches(grid)
	if not new_matches.is_empty():
		cascade_level += 1
		GameManager.increment_cascade()
		await _process_matches(new_matches)
	else:
		state = BoardState.IDLE
		EventBus.board_settled.emit()


func _emit_mana_charges(matched_positions: Array) -> void:
	## Count piece types in matched set and emit mana charges.
	## match-3 = 1 pip, match-4 = 2 pips, match-5+ = 3 pips
	var type_counts: Dictionary = {}  # piece_type -> count
	for pos: Vector2i in matched_positions:
		var pt: int = grid[pos.x][pos.y]
		if pt >= 0:
			type_counts[pt] = type_counts.get(pt, 0) + 1

	for pt: int in type_counts:
		var count: int = type_counts[pt]
		var pips: int
		if count <= 3:
			pips = 1
		elif count == 4:
			pips = 2
		else:
			pips = 3
		EventBus.mana_charged.emit(pt, pips)


func _do_swap(col1: int, row1: int, col2: int, row2: int) -> void:
	# Swap data
	var temp_type: int = grid[col1][row1]
	grid[col1][row1] = grid[col2][row2]
	grid[col2][row2] = temp_type

	var temp_node: Sprite2D = piece_nodes[col1][row1]
	piece_nodes[col1][row1] = piece_nodes[col2][row2]
	piece_nodes[col2][row2] = temp_node

	# Update node grid references
	if piece_nodes[col1][row1]:
		piece_nodes[col1][row1].grid_col = col1
		piece_nodes[col1][row1].grid_row = row1
	if piece_nodes[col2][row2]:
		piece_nodes[col2][row2].grid_col = col2
		piece_nodes[col2][row2].grid_row = row2

	# Animate
	await piece_animator.animate_swap(
		piece_nodes[col1][row1], grid_to_pixel(col1, row1),
		piece_nodes[col2][row2], grid_to_pixel(col2, row2)
	)


func _clear_pieces(matched_positions: Array) -> void:
	var pieces_to_clear: Array[Sprite2D] = []
	for pos: Vector2i in matched_positions:
		var piece: Sprite2D = piece_nodes[pos.x][pos.y]
		if piece and not pieces_to_clear.has(piece):
			pieces_to_clear.append(piece)
			grid[pos.x][pos.y] = PieceData.PieceType.NONE
			piece_nodes[pos.x][pos.y] = null

	await piece_animator.animate_clear(pieces_to_clear)

	# Free cleared pieces
	for piece: Sprite2D in pieces_to_clear:
		piece.queue_free()


func _apply_gravity() -> void:
	var movements: Array = []  # [{piece, target_pos, col, new_row}]

	for col in range(GameConfig.GRID_COLS):
		var write_row: int = GameConfig.GRID_ROWS - 1
		for read_row in range(GameConfig.GRID_ROWS - 1, -1, -1):
			if grid[col][read_row] != PieceData.PieceType.NONE:
				if read_row != write_row:
					# Move piece down
					grid[col][write_row] = grid[col][read_row]
					grid[col][read_row] = PieceData.PieceType.NONE

					var piece: Sprite2D = piece_nodes[col][read_row]
					piece_nodes[col][read_row] = null
					piece_nodes[col][write_row] = piece

					if piece:
						piece.grid_col = col
						piece.grid_row = write_row
						movements.append({
							"piece": piece,
							"target": grid_to_pixel(col, write_row),
							"distance": write_row - read_row
						})
				write_row -= 1

	if not movements.is_empty():
		await piece_animator.animate_fall(movements)
		EventBus.pieces_fell.emit()


func _fill_empty() -> void:
	var new_pieces: Array = []  # [{piece, target_pos, spawn_offset}]

	for col in range(GameConfig.GRID_COLS):
		var empty_count: int = 0
		for row in range(GameConfig.GRID_ROWS):
			if grid[col][row] == PieceData.PieceType.NONE:
				empty_count += 1

		# Fill from top
		var spawn_row: int = 0
		for row in range(GameConfig.GRID_ROWS):
			if grid[col][row] == PieceData.PieceType.NONE:
				var piece_type: int = randi() % PieceData.PIECE_COUNT
				grid[col][row] = piece_type

				var piece: Sprite2D = _create_piece_node(col, row, piece_type)
				# Start above the board
				piece.position = grid_to_pixel(col, -empty_count + spawn_row)
				spawn_row += 1

				new_pieces.append({
					"piece": piece,
					"target": grid_to_pixel(col, row),
					"distance": empty_count
				})

	if not new_pieces.is_empty():
		await piece_animator.animate_spawn(new_pieces)
		EventBus.pieces_spawned.emit()


# --- Ability helpers ---

func get_row_positions(row: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for col in range(GameConfig.GRID_COLS):
		if grid[col][row] != PieceData.PieceType.NONE:
			positions.append(Vector2i(col, row))
	return positions


func get_column_positions(col: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for row in range(GameConfig.GRID_ROWS):
		if grid[col][row] != PieceData.PieceType.NONE:
			positions.append(Vector2i(col, row))
	return positions


func get_area_positions(center_col: int, center_row: int, radius: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for col in range(center_col - radius, center_col + radius + 1):
		for row in range(center_row - radius, center_row + radius + 1):
			if is_valid_cell(col, row) and grid[col][row] != PieceData.PieceType.NONE:
				positions.append(Vector2i(col, row))
	return positions


func get_random_positions_of_type(exclude_type: int, count: int, _target_type: int) -> Array[Vector2i]:
	## Get 'count' random positions that are NOT the target_type (for conversion)
	var candidates: Array[Vector2i] = []
	for col in range(GameConfig.GRID_COLS):
		for row in range(GameConfig.GRID_ROWS):
			if grid[col][row] != PieceData.PieceType.NONE and grid[col][row] != _target_type:
				candidates.append(Vector2i(col, row))
	candidates.shuffle()
	var result: Array[Vector2i] = []
	for i in range(mini(count, candidates.size())):
		result.append(candidates[i])
	return result


func execute_ability_clear(positions: Array[Vector2i]) -> void:
	if positions.is_empty():
		return
	state = BoardState.ABILITY
	cascade_level = 0
	GameManager.start_cascade()

	# Score the cleared pieces
	var count: int = positions.size()
	var points: int = GameConfig.MATCH_BASE_SCORE + (count - 3) * GameConfig.EXTRA_PIECE_BONUS
	if count > 0:
		GameManager.add_score(maxi(points, GameConfig.MATCH_BASE_SCORE))

	# Emit mana charges for ability clears too
	_emit_mana_charges(positions)

	await _clear_pieces(positions)

	state = BoardState.FALLING
	await _apply_gravity()

	state = BoardState.FILLING
	await _fill_empty()

	# Check cascades
	state = BoardState.CHECKING
	var new_matches: Array = match_finder.find_matches(grid)
	if not new_matches.is_empty():
		cascade_level += 1
		GameManager.increment_cascade()
		await _process_matches(new_matches)
	else:
		state = BoardState.IDLE
		EventBus.board_settled.emit()


func execute_ability_convert(positions: Array[Vector2i], new_type: int) -> void:
	if positions.is_empty():
		return
	state = BoardState.ABILITY
	cascade_level = 0
	GameManager.start_cascade()

	# Recolor pieces
	for pos: Vector2i in positions:
		grid[pos.x][pos.y] = new_type
		var piece: Sprite2D = piece_nodes[pos.x][pos.y]
		if piece:
			piece.set_type(new_type)

	# Check cascades from converted pieces
	state = BoardState.CHECKING
	var new_matches: Array = match_finder.find_matches(grid)
	if not new_matches.is_empty():
		cascade_level += 1
		GameManager.increment_cascade()
		await _process_matches(new_matches)
	else:
		state = BoardState.IDLE
		EventBus.board_settled.emit()
