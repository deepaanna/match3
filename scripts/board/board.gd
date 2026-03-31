extends Node2D
## Core board logic: grid data, state machine, swap/gravity/fill/cascade orchestration.
## Grid is column-major: grid[col][row], where row 0 is the top.
## Supports booster creation (4-match → line clear, 5-match → color bomb, L/T → area bomb).
## Supports obstacles: ice tiles (damaged on piece clear) and web blockers (prevent swaps).
# PERSISTENT BOOSTERS + VFX + SAVE v1.0

enum BoardState { IDLE, SWAPPING, CHECKING, CLEARING, FALLING, FILLING, SWAP_BACK, ABILITY }

const PIECE_SCENE: PackedScene = preload("res://scenes/piece.tscn")

var state: BoardState = BoardState.IDLE
var grid: Array = []  # Array[Array[int]] - column-major, stores PieceType ints
var piece_nodes: Array = []  # Array[Array[Sprite2D]] - mirrors grid, holds piece nodes
var obstacle_grid: Array = []  # Array[Array[int]] - ObstacleType per cell
var obstacle_hp: Array = []  # Array[Array[int]] - HP per obstacle cell
var cascade_level: int = 0
var _piece_pool: Array[Sprite2D] = []
var _num_colors: int = PieceData.PIECE_COUNT  # How many piece types in play
var _hint_timer: float = 0.0
var _hint_tween: Tween = null
var _free_shuffle_used: bool = false  # First shuffle per level is free
var _shuffle_in_progress: bool = false  # Prevents double-prompting during cascade chains

@export var match_finder: Node
@export var piece_animator: Node
@export var board_input: Node


func _ready() -> void:
	_load_level_config()
	_init_grid()
	_resolve_initial_matches()
	_spawn_initial_pieces()
	EventBus.swap_requested.connect(_on_swap_requested)
	EventBus.victory_detonation_requested.connect(_on_victory_detonation)
	# Deferred so the rest of the scene tree is ready before tutorial triggers
	call_deferred("_emit_board_ready")


func _emit_board_ready() -> void:
	EventBus.board_ready.emit()


func _process(delta: float) -> void:
	if state != BoardState.IDLE:
		_hint_timer = 0.0
		return
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	_hint_timer += delta
	if _hint_timer >= GameConfig.HINT_IDLE_DELAY:
		_hint_timer = -999.0  # Prevent re-triggering until reset
		_show_hint()


func _load_level_config() -> void:
	var level_data: LevelData = GameManager.current_level_data
	if level_data:
		_num_colors = clampi(level_data.num_colors, 3, PieceData.PIECE_COUNT)
	else:
		_num_colors = PieceData.PIECE_COUNT


# --- Drawing (obstacles rendered behind pieces) ---

func _draw() -> void:
	for col in range(GameConfig.GRID_COLS):
		for row in range(GameConfig.GRID_ROWS):
			var obs: int = obstacle_grid[col][row]
			if obs == LevelData.ObstacleType.NONE:
				continue

			var pos: Vector2 = grid_to_pixel(col, row)
			var half: float = GameConfig.CELL_SIZE * 0.5
			var rect := Rect2(pos.x - half, pos.y - half, GameConfig.CELL_SIZE, GameConfig.CELL_SIZE)
			var hp: int = obstacle_hp[col][row]

			if obs == LevelData.ObstacleType.ICE:
				_draw_ice(rect, hp)
			elif obs == LevelData.ObstacleType.WEB:
				_draw_web(rect)


func _draw_ice(rect: Rect2, hp: int) -> void:
	var alpha: float = 0.25 + 0.15 * hp  # Thicker ice = more opaque
	var color := Color(0.5, 0.8, 1.0, alpha)
	draw_rect(rect, color, true)
	# Border
	var border := Color(0.6, 0.9, 1.0, alpha + 0.1)
	draw_rect(rect, border, false, 2.0)
	# Crack lines for damaged ice (hp == 1 when originally 2)
	if hp == 1:
		var cx: float = rect.position.x + rect.size.x * 0.5
		var cy: float = rect.position.y + rect.size.y * 0.5
		var crack_color := Color(0.8, 0.95, 1.0, 0.5)
		draw_line(Vector2(cx - 10, cy - 8), Vector2(cx + 5, cy + 12), crack_color, 1.5)
		draw_line(Vector2(cx + 8, cy - 10), Vector2(cx - 3, cy + 6), crack_color, 1.5)


func _draw_web(rect: Rect2) -> void:
	var color := Color(0.9, 0.9, 0.9, 0.5)
	var tl: Vector2 = rect.position
	var br: Vector2 = rect.position + rect.size
	var tr: Vector2 = Vector2(br.x, tl.y)
	var bl: Vector2 = Vector2(tl.x, br.y)
	# Crossing diagonals
	draw_line(tl, br, color, 2.0)
	draw_line(tr, bl, color, 2.0)
	# Cross hairs
	var cx: float = (tl.x + br.x) * 0.5
	var cy: float = (tl.y + br.y) * 0.5
	draw_line(Vector2(cx, tl.y), Vector2(cx, br.y), color, 1.5)
	draw_line(Vector2(tl.x, cy), Vector2(br.x, cy), color, 1.5)
	# Small circles at midpoints for web look
	var r: float = 3.0
	draw_arc(Vector2(cx, tl.y + rect.size.y * 0.25), r, 0, TAU, 8, color, 1.0)
	draw_arc(Vector2(cx, tl.y + rect.size.y * 0.75), r, 0, TAU, 8, color, 1.0)


# --- Grid initialisation ---

func _init_grid() -> void:
	grid.clear()
	piece_nodes.clear()
	obstacle_grid.clear()
	obstacle_hp.clear()

	for col in range(GameConfig.GRID_COLS):
		grid.append([])
		piece_nodes.append([])
		obstacle_grid.append([])
		obstacle_hp.append([])

	for col in range(GameConfig.GRID_COLS):
		for row in range(GameConfig.GRID_ROWS):
			var piece_type: int = _get_random_piece_no_match(col, row)
			grid[col].append(piece_type)
			piece_nodes[col].append(null)
			obstacle_grid[col].append(LevelData.ObstacleType.NONE)
			obstacle_hp[col].append(0)

	# Load obstacles from level data
	var level_data: LevelData = GameManager.current_level_data
	if level_data:
		for obs: Dictionary in level_data.obstacles:
			var col: int = obs["col"]
			var row: int = obs["row"]
			if is_valid_cell(col, row):
				obstacle_grid[col][row] = obs["type"]
				obstacle_hp[col][row] = obs["hp"]


func _get_random_piece_no_match(col: int, row: int) -> int:
	var available: Array[int] = []
	for i in range(_num_colors):
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


func _resolve_initial_matches() -> void:
	## Re-roll any matches the per-piece heuristic missed (L/T shapes, cross-column).
	for attempt in range(100):
		var matches: Array = match_finder.find_matches(grid)
		if matches.is_empty():
			return
		for pos: Vector2i in matches:
			grid[pos.x][pos.y] = _get_safe_type(pos.x, pos.y)


func _get_safe_type(col: int, row: int) -> int:
	## Pick a piece type that avoids 3-in-a-row in all four directions.
	var available: Array[int] = []
	for i in range(_num_colors):
		available.append(i)

	# Horizontal: X X ? — two same to the left
	if col >= 2 and grid[col - 1][row] >= 0 and grid[col - 1][row] == grid[col - 2][row]:
		available.erase(grid[col - 1][row])
	# Horizontal: ? X X — two same to the right
	if col <= GameConfig.GRID_COLS - 3 and grid[col + 1][row] >= 0 and grid[col + 1][row] == grid[col + 2][row]:
		available.erase(grid[col + 1][row])
	# Horizontal: X ? X — same on both sides
	if col >= 1 and col <= GameConfig.GRID_COLS - 2 and grid[col - 1][row] >= 0 and grid[col - 1][row] == grid[col + 1][row]:
		available.erase(grid[col - 1][row])

	# Vertical: two same above
	if row >= 2 and grid[col][row - 1] >= 0 and grid[col][row - 1] == grid[col][row - 2]:
		available.erase(grid[col][row - 1])
	# Vertical: two same below
	if row <= GameConfig.GRID_ROWS - 3 and grid[col][row + 1] >= 0 and grid[col][row + 1] == grid[col][row + 2]:
		available.erase(grid[col][row + 1])
	# Vertical: same above and below
	if row >= 1 and row <= GameConfig.GRID_ROWS - 2 and grid[col][row - 1] >= 0 and grid[col][row - 1] == grid[col][row + 1]:
		available.erase(grid[col][row - 1])

	if available.is_empty():
		return randi() % _num_colors
	return available[randi() % available.size()]


func _spawn_initial_pieces() -> void:
	for col in range(GameConfig.GRID_COLS):
		for row in range(GameConfig.GRID_ROWS):
			_create_piece_node(col, row, grid[col][row])

	# Place pre-set boosters from level data (e.g., boss levels)
	var level_data: LevelData = GameManager.current_level_data
	if level_data:
		for b: Dictionary in level_data.pre_boosters:
			var col: int = b["col"]
			var row: int = b["row"]
			if is_valid_cell(col, row) and piece_nodes[col][row]:
				piece_nodes[col][row].set_booster(b["booster_type"])


# --- Piece pool ---

func _create_piece_node(col: int, row: int, piece_type: int) -> Sprite2D:
	var piece: Sprite2D = _acquire_piece()
	piece.setup(col, row, piece_type)
	piece.position = grid_to_pixel(col, row)
	piece_nodes[col][row] = piece
	return piece


func _acquire_piece() -> Sprite2D:
	if not _piece_pool.is_empty():
		var piece: Sprite2D = _piece_pool.pop_back()
		piece.visible = true
		# Reset visual state after clear animation (scale→0, modulate.a→0)
		var base_scale: float = GameConfig.CELL_SIZE * GameConfig.PIECE_SCALE / piece.texture.get_width()
		piece.scale = Vector2.ONE * base_scale
		return piece
	var piece: Sprite2D = PIECE_SCENE.instantiate()
	add_child(piece)
	return piece


func _release_piece(piece: Sprite2D) -> void:
	piece.set_selected(false)
	piece.set_booster(PieceData.BoosterType.NONE)
	piece.visible = false
	_piece_pool.append(piece)


# --- Coordinate helpers ---

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


# --- Obstacle helpers ---

func has_web(col: int, row: int) -> bool:
	return is_valid_cell(col, row) and obstacle_grid[col][row] == LevelData.ObstacleType.WEB


func has_obstacle(col: int, row: int) -> bool:
	return is_valid_cell(col, row) and obstacle_grid[col][row] != LevelData.ObstacleType.NONE


func damage_obstacle(col: int, row: int) -> void:
	if not has_obstacle(col, row):
		return
	obstacle_hp[col][row] -= 1
	if obstacle_hp[col][row] <= 0:
		var obs_type: int = obstacle_grid[col][row]
		obstacle_grid[col][row] = LevelData.ObstacleType.NONE
		obstacle_hp[col][row] = 0
		EventBus.obstacle_cleared.emit(col, row, obs_type)
	else:
		EventBus.obstacle_damaged.emit(col, row, obstacle_hp[col][row])
	queue_redraw()


# --- Valid moves detection, shuffle, and hint ---

func has_valid_moves() -> bool:
	## Check if any adjacent swap would produce a match of 3+.
	for col in range(GameConfig.GRID_COLS):
		for row in range(GameConfig.GRID_ROWS):
			if grid[col][row] == PieceData.PieceType.NONE:
				continue
			# Skip webbed cells
			if has_web(col, row):
				continue
			# Try swap right
			if col + 1 < GameConfig.GRID_COLS and not has_web(col + 1, row):
				_swap_data(col, row, col + 1, row)
				var found: bool = not match_finder.find_matches(grid).is_empty()
				_swap_data(col, row, col + 1, row)
				if found:
					return true
			# Try swap down
			if row + 1 < GameConfig.GRID_ROWS and not has_web(col, row + 1):
				_swap_data(col, row, col, row + 1)
				var found: bool = not match_finder.find_matches(grid).is_empty()
				_swap_data(col, row, col, row + 1)
				if found:
					return true
	return false


func find_hint_move() -> Array:
	## Returns [Vector2i, Vector2i] of a valid swap, or empty array if none.
	for col in range(GameConfig.GRID_COLS):
		for row in range(GameConfig.GRID_ROWS):
			if grid[col][row] == PieceData.PieceType.NONE:
				continue
			if has_web(col, row):
				continue
			if col + 1 < GameConfig.GRID_COLS and not has_web(col + 1, row):
				_swap_data(col, row, col + 1, row)
				var found: bool = not match_finder.find_matches(grid).is_empty()
				_swap_data(col, row, col + 1, row)
				if found:
					return [Vector2i(col, row), Vector2i(col + 1, row)]
			if row + 1 < GameConfig.GRID_ROWS and not has_web(col, row + 1):
				_swap_data(col, row, col, row + 1)
				var found: bool = not match_finder.find_matches(grid).is_empty()
				_swap_data(col, row, col, row + 1)
				if found:
					return [Vector2i(col, row), Vector2i(col, row + 1)]
	return []


func _swap_data(col1: int, row1: int, col2: int, row2: int) -> void:
	## Swap grid data only (no nodes, no animation). Used for move validation.
	var tmp: int = grid[col1][row1]
	grid[col1][row1] = grid[col2][row2]
	grid[col2][row2] = tmp


func _show_hint() -> void:
	_kill_hint()
	var hint: Array = find_hint_move()
	if hint.is_empty():
		return
	var a: Vector2i = hint[0]
	var b: Vector2i = hint[1]
	_hint_tween = piece_animator.animate_hint(
		piece_nodes[a.x][a.y], piece_nodes[b.x][b.y]
	)


func _kill_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
		# Reset scales of any hinted pieces (skip boosters — they have their own pulse)
		var base_scale: float = GameConfig.CELL_SIZE * GameConfig.PIECE_SCALE / 64.0
		for col in range(GameConfig.GRID_COLS):
			for row in range(GameConfig.GRID_ROWS):
				var p: Sprite2D = piece_nodes[col][row]
				if p and not p.is_selected and p.booster_type == PieceData.BoosterType.NONE:
					p.scale = Vector2.ONE * base_scale


func _reset_hint_timer() -> void:
	_kill_hint()
	_hint_timer = 0.0


func _shuffle_board() -> void:
	## Shuffle all non-obstacle piece types and animate to new positions.
	## Preserves booster state — boosters move with their piece type.
	var positions: Array[Vector2i] = []
	var types: Array[int] = []
	var boosters: Array[int] = []
	for col in range(GameConfig.GRID_COLS):
		for row in range(GameConfig.GRID_ROWS):
			if grid[col][row] != PieceData.PieceType.NONE:
				positions.append(Vector2i(col, row))
				types.append(grid[col][row])
				var p: Sprite2D = piece_nodes[col][row]
				boosters.append(p.booster_type if p else PieceData.BoosterType.NONE)

	# Shuffle types + boosters together (Fisher-Yates)
	for i in range(types.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var tmp_t: int = types[i]
		types[i] = types[j]
		types[j] = tmp_t
		var tmp_b: int = boosters[i]
		boosters[i] = boosters[j]
		boosters[j] = tmp_b

	# Reassign and animate
	var movements: Array = []
	for i in range(positions.size()):
		var pos: Vector2i = positions[i]
		grid[pos.x][pos.y] = types[i]
		var piece: Sprite2D = piece_nodes[pos.x][pos.y]
		if piece:
			piece.setup(pos.x, pos.y, types[i])
			if boosters[i] != PieceData.BoosterType.NONE:
				piece.set_booster(boosters[i])
			movements.append({"piece": piece, "target": grid_to_pixel(pos.x, pos.y)})

	await piece_animator.animate_shuffle(movements)


func _settle_board() -> void:
	## Called when cascades end. Checks for deadlock, shuffles if needed, then emits board_settled.
	await _ensure_valid_board()
	_shuffle_in_progress = false
	state = BoardState.IDLE
	_reset_hint_timer()
	EventBus.board_settled.emit()


func _ensure_valid_board() -> void:
	## After board settles, check for valid moves. Shuffle if none exist.
	## First shuffle per level is free (brief dramatic pause). Subsequent shuffles
	## wait for player confirmation via shuffle_confirmed signal (costs coins).
	## Also resolves any accidental post-shuffle matches.
	for attempt in range(10):
		if has_valid_moves():
			return

		# Only prompt the player on the first shuffle of a deadlock chain.
		# Recursive calls from post-shuffle cascades skip the prompt.
		if not _shuffle_in_progress:
			_shuffle_in_progress = true
			if not _free_shuffle_used:
				_free_shuffle_used = true
				EventBus.no_moves_detected.emit(true)
				await get_tree().create_timer(0.8).timeout
			else:
				EventBus.no_moves_detected.emit(false)
				await EventBus.shuffle_confirmed

		await _shuffle_board()
		EventBus.shuffle_used.emit()

		# After shuffle, resolve any matches that formed
		var groups: Array = match_finder.find_match_groups(grid)
		if not groups.is_empty():
			await _process_match_groups(groups)
			return  # _process_match_groups will re-check via cascade


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

	_reset_hint_timer()

	# Web blocks: cannot swap a piece that sits on a web
	if has_web(from_col, from_row) or has_web(to_col, to_row):
		await piece_animator.animate_reject(
			piece_nodes[from_col][from_row],
			piece_nodes[to_col][to_row]
		)
		EventBus.swap_failed.emit()
		return

	state = BoardState.SWAPPING
	cascade_level = 0
	GameManager.start_cascade()
	await _do_swap(from_col, from_row, to_col, to_row)

	state = BoardState.CHECKING
	var groups: Array = match_finder.find_match_groups(grid)

	if groups.is_empty():
		# No match — swap back with reject feedback
		state = BoardState.SWAP_BACK
		await _do_swap(to_col, to_row, from_col, from_row)
		await piece_animator.animate_reject(
			piece_nodes[from_col][from_row],
			piece_nodes[to_col][to_row]
		)
		state = BoardState.IDLE
		EventBus.swap_failed.emit()
	else:
		# Valid swap — process with booster awareness
		EventBus.swap_completed.emit()
		await _process_match_groups(groups, Vector2i(to_col, to_row))


# --- Match processing (with boosters) ---

func _process_match_groups(groups: Array, swap_pos: Vector2i = Vector2i(-1, -1)) -> void:
	state = BoardState.CLEARING

	# Flatten all matched positions
	var all_positions: Array[Vector2i] = _flatten_groups(groups)
	var match_count: int = all_positions.size()
	EventBus.matches_found.emit(all_positions)

	# Activate any boosters caught in the match → extra positions to clear
	var booster_extras: Array[Vector2i] = _collect_booster_activations(all_positions)
	var full_clear: Array[Vector2i] = all_positions.duplicate()
	for pos: Vector2i in booster_extras:
		if not full_clear.has(pos):
			full_clear.append(pos)

	# Emit mana charges for everything being cleared
	_emit_mana_charges(full_clear)

	# Emit collection counts per piece type
	_emit_piece_collections(full_clear)

	# Determine which boosters to create from 4+/5+/cross matches
	var new_boosters: Array = _determine_boosters(groups, swap_pos)

	# Exclude booster-creation spots from clearing (they survive as the new booster)
	var booster_spots: Dictionary = {}
	for b: Dictionary in new_boosters:
		booster_spots[b["pos"]] = true
	var clear_positions: Array[Vector2i] = []
	for pos: Vector2i in full_clear:
		if not booster_spots.has(pos):
			clear_positions.append(pos)

	# Damage obstacles under/adjacent to cleared pieces
	_process_obstacle_damage(clear_positions)

	await _clear_pieces(clear_positions)
	EventBus.matches_cleared.emit(match_count, cascade_level)

	# Screen shake — intensity scales with cascade level and booster activations
	if not booster_extras.is_empty():
		EventBus.screen_shake_requested.emit(GameConfig.SHAKE_MEDIUM)
	elif cascade_level >= 3:
		EventBus.screen_shake_requested.emit(GameConfig.SHAKE_LARGE)
	elif cascade_level >= 1:
		EventBus.screen_shake_requested.emit(GameConfig.SHAKE_SMALL)

	# Bonus score for booster activations
	if not booster_extras.is_empty():
		GameManager.add_score(GameConfig.BOOSTER_ACTIVATE_SCORE)

	# Create the new boosters (persistent — they stay on the board until matched)
	if not new_boosters.is_empty():
		var booster_pieces: Array[Sprite2D] = []
		for b: Dictionary in new_boosters:
			_set_piece_booster(b["pos"], b["booster_type"], b["piece_type"])
			if piece_nodes[b["pos"].x][b["pos"].y]:
				booster_pieces.append(piece_nodes[b["pos"].x][b["pos"].y])
			EventBus.persistent_booster_created.emit(b["pos"].x, b["pos"].y, b["booster_type"])
		await piece_animator.animate_booster_create(booster_pieces)
		GameManager.add_score(GameConfig.BOOSTER_CREATE_SCORE * new_boosters.size())

	# Gravity + fill
	state = BoardState.FALLING
	await _apply_gravity()
	state = BoardState.FILLING
	await _fill_empty()

	# Check for cascades
	state = BoardState.CHECKING
	var new_groups: Array = match_finder.find_match_groups(grid)
	if not new_groups.is_empty():
		cascade_level += 1
		GameManager.increment_cascade()
		await _process_match_groups(new_groups)
	else:
		await _settle_board()


# --- Obstacle damage processing ---

func _process_obstacle_damage(cleared_positions: Array[Vector2i]) -> void:
	## Ice: damaged when a piece sitting on it is cleared.
	## Web: damaged when an adjacent piece is cleared (not the piece on the web itself).
	var ice_damaged: Dictionary = {}  # Track to avoid double-damage in same clear
	var web_damaged: Dictionary = {}

	for pos: Vector2i in cleared_positions:
		# Ice under the cleared piece
		if obstacle_grid[pos.x][pos.y] == LevelData.ObstacleType.ICE:
			if not ice_damaged.has(pos):
				ice_damaged[pos] = true

		# Web: check all 4 neighbors for web tiles
		for offset: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var nx: int = pos.x + offset.x
			var ny: int = pos.y + offset.y
			if is_valid_cell(nx, ny) and obstacle_grid[nx][ny] == LevelData.ObstacleType.WEB:
				var wpos := Vector2i(nx, ny)
				if not web_damaged.has(wpos):
					web_damaged[wpos] = true

	# Apply damage
	for pos: Vector2i in ice_damaged:
		damage_obstacle(pos.x, pos.y)
	for pos: Vector2i in web_damaged:
		damage_obstacle(pos.x, pos.y)


# --- Piece collection tracking ---

func _emit_piece_collections(positions: Array[Vector2i]) -> void:
	var type_counts: Dictionary = {}
	for pos: Vector2i in positions:
		if is_valid_cell(pos.x, pos.y):
			var pt: int = grid[pos.x][pos.y]
			if pt >= 0:
				type_counts[pt] = type_counts.get(pt, 0) + 1
	for pt: int in type_counts:
		EventBus.pieces_collected.emit(pt, type_counts[pt])


# --- Booster logic ---

func _flatten_groups(groups: Array) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var result: Array[Vector2i] = []
	for g: Dictionary in groups:
		for pos: Vector2i in g["positions"]:
			if not seen.has(pos):
				seen[pos] = true
				result.append(pos)
	return result


func _collect_booster_activations(matched_positions: Array[Vector2i]) -> Array[Vector2i]:
	## Find boosters in matched positions and expand their effect areas.
	## Chain-reacts: if a booster's blast hits another booster, that one also fires.
	var extra: Array[Vector2i] = []
	var activated: Dictionary = {}  # pos -> true
	var queue: Array[Vector2i] = []

	for pos: Vector2i in matched_positions:
		var piece: Sprite2D = piece_nodes[pos.x][pos.y]
		if piece and piece.booster_type != PieceData.BoosterType.NONE:
			queue.append(pos)
			activated[pos] = true

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var piece: Sprite2D = piece_nodes[pos.x][pos.y]
		if not piece:
			continue
		var effect: Array[Vector2i] = _get_booster_effect(pos, piece.booster_type, piece.piece_type)
		for epos: Vector2i in effect:
			if activated.has(epos):
				continue
			if not is_valid_cell(epos.x, epos.y):
				continue
			if grid[epos.x][epos.y] == PieceData.PieceType.NONE:
				continue
			extra.append(epos)
			var epiece: Sprite2D = piece_nodes[epos.x][epos.y]
			if epiece and epiece.booster_type != PieceData.BoosterType.NONE:
				queue.append(epos)
				activated[epos] = true

	return extra


func _get_booster_effect(pos: Vector2i, btype: int, ptype: int) -> Array[Vector2i]:
	match btype:
		PieceData.BoosterType.LINE_H:
			return get_row_positions(pos.y)
		PieceData.BoosterType.LINE_V:
			return get_column_positions(pos.x)
		PieceData.BoosterType.AREA_BOMB:
			return get_area_positions(pos.x, pos.y, GameConfig.AREA_BOMB_RADIUS)
		PieceData.BoosterType.COLOR_BOMB:
			return _get_all_of_type(ptype)
	return []


func _get_all_of_type(piece_type: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for col in range(GameConfig.GRID_COLS):
		for row in range(GameConfig.GRID_ROWS):
			if grid[col][row] == piece_type:
				positions.append(Vector2i(col, row))
	return positions


func _determine_boosters(groups: Array, swap_pos: Vector2i) -> Array:
	## Analyse match groups to decide which boosters to create:
	##   L/T/cross (H+V intersection, same color) → AREA_BOMB
	##   5-in-a-row → COLOR_BOMB
	##   4-in-a-row → LINE_H or LINE_V
	var boosters: Array = []

	# Map positions to their group index, split by direction
	var h_pos_to_group: Dictionary = {}
	var v_pos_to_group: Dictionary = {}
	for i in range(groups.size()):
		var g: Dictionary = groups[i]
		if g["direction"] == "horizontal":
			for pos: Vector2i in g["positions"]:
				h_pos_to_group[pos] = i
		else:
			for pos: Vector2i in g["positions"]:
				v_pos_to_group[pos] = i

	# Detect cross-shapes (same position in both H and V group of same colour)
	var used_groups: Dictionary = {}
	for pos: Vector2i in h_pos_to_group:
		if not v_pos_to_group.has(pos):
			continue
		var h_idx: int = h_pos_to_group[pos]
		var v_idx: int = v_pos_to_group[pos]
		if used_groups.has(h_idx) or used_groups.has(v_idx):
			continue
		if groups[h_idx]["piece_type"] != groups[v_idx]["piece_type"]:
			continue
		boosters.append({
			"pos": pos,
			"booster_type": PieceData.BoosterType.AREA_BOMB,
			"piece_type": groups[h_idx]["piece_type"]
		})
		used_groups[h_idx] = true
		used_groups[v_idx] = true

	# Process remaining (non-cross) groups for line clears / color bombs
	for i in range(groups.size()):
		if used_groups.has(i):
			continue
		var g: Dictionary = groups[i]
		if g["size"] >= GameConfig.MATCH_5_BOOSTER:
			boosters.append({
				"pos": _best_booster_pos(g["positions"], swap_pos),
				"booster_type": PieceData.BoosterType.COLOR_BOMB,
				"piece_type": g["piece_type"]
			})
		elif g["size"] >= GameConfig.MATCH_4_BOOSTER:
			var bt: int
			if g["direction"] == "horizontal":
				bt = PieceData.BoosterType.LINE_H
			else:
				bt = PieceData.BoosterType.LINE_V
			boosters.append({
				"pos": _best_booster_pos(g["positions"], swap_pos),
				"booster_type": bt,
				"piece_type": g["piece_type"]
			})

	return boosters


func _best_booster_pos(positions: Array, swap_pos: Vector2i) -> Vector2i:
	## Place booster at the swap destination if it is part of the group, else at the center.
	for pos: Vector2i in positions:
		if pos == swap_pos:
			return pos
	return positions[positions.size() / 2]


func _set_piece_booster(pos: Vector2i, btype: int, ptype: int) -> void:
	var piece: Sprite2D = piece_nodes[pos.x][pos.y]
	if piece:
		piece.set_booster(btype)
	else:
		piece = _create_piece_node(pos.x, pos.y, ptype)
		piece.set_booster(btype)
	grid[pos.x][pos.y] = ptype


# --- Mana charging ---

func _emit_mana_charges(matched_positions: Array) -> void:
	## Count piece types in matched set and emit mana charges.
	## match-3 = 1 pip, match-4 = 2 pips, match-5+ = 3 pips
	var type_counts: Dictionary = {}  # piece_type -> count
	for pos: Vector2i in matched_positions:
		if is_valid_cell(pos.x, pos.y):
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


# --- Swap / clear / gravity / fill animations ---

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
		if not is_valid_cell(pos.x, pos.y):
			continue
		var piece: Sprite2D = piece_nodes[pos.x][pos.y]
		if piece and not pieces_to_clear.has(piece):
			pieces_to_clear.append(piece)
			grid[pos.x][pos.y] = PieceData.PieceType.NONE
			piece_nodes[pos.x][pos.y] = null

	await piece_animator.animate_clear(pieces_to_clear)

	# Return cleared pieces to pool for reuse
	for piece: Sprite2D in pieces_to_clear:
		_release_piece(piece)


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

		# Fill from top — use match-aware random to prevent runaway cascades
		var spawn_row: int = 0
		for row in range(GameConfig.GRID_ROWS):
			if grid[col][row] == PieceData.PieceType.NONE:
				var piece_type: int = _get_safe_type(col, row)
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


# --- Victory detonation ---

func _on_victory_detonation(moves_left: int) -> void:
	## Convert each leftover move into a random booster that detonates on the board.
	## This is the "Sugar Crush" moment — visual fireworks on victory.
	state = BoardState.ABILITY
	_reset_hint_timer()

	var total_bonus: int = 0
	var booster_types: Array[int] = [
		PieceData.BoosterType.LINE_H,
		PieceData.BoosterType.LINE_V,
		PieceData.BoosterType.AREA_BOMB,
	]

	for i in range(moves_left):
		# Pick a random occupied cell
		var candidates: Array[Vector2i] = []
		for col in range(GameConfig.GRID_COLS):
			for row in range(GameConfig.GRID_ROWS):
				if grid[col][row] != PieceData.PieceType.NONE and piece_nodes[col][row]:
					candidates.append(Vector2i(col, row))
		if candidates.is_empty():
			break

		var pos: Vector2i = candidates[randi() % candidates.size()]
		var btype: int = booster_types[randi() % booster_types.size()]
		var ptype: int = grid[pos.x][pos.y]

		# Briefly show the booster on the piece
		var piece: Sprite2D = piece_nodes[pos.x][pos.y]
		if piece:
			piece.set_booster(btype)
		var det_pieces: Array[Sprite2D] = [piece]
		await piece_animator.animate_booster_create(det_pieces)

		# Get effect area and clear it
		var effect: Array[Vector2i] = _get_booster_effect(pos, btype, ptype)
		# Include the booster cell itself
		if not effect.has(pos):
			effect.append(pos)

		# Filter to valid occupied cells
		var to_clear: Array[Vector2i] = []
		for epos: Vector2i in effect:
			if is_valid_cell(epos.x, epos.y) and grid[epos.x][epos.y] != PieceData.PieceType.NONE:
				if not to_clear.has(epos):
					to_clear.append(epos)

		_process_obstacle_damage(to_clear)

		var clear_count: int = to_clear.size()
		total_bonus += GameConfig.BOOSTER_ACTIVATE_SCORE + clear_count * GameConfig.EXTRA_PIECE_BONUS

		await _clear_pieces(to_clear)
		EventBus.screen_shake_requested.emit(GameConfig.SHAKE_MEDIUM)

		# Gravity + fill between each detonation
		await _apply_gravity()
		await _fill_empty()

		# Brief pause between detonations
		if i < moves_left - 1:
			var delay_tween: Tween = create_tween()
			delay_tween.tween_interval(GameConfig.VICTORY_DETONATION_DELAY)
			await delay_tween.finished

	state = BoardState.IDLE
	EventBus.victory_detonation_finished.emit(total_bonus)


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
	_emit_piece_collections(positions)
	_process_obstacle_damage(positions)

	await _clear_pieces(positions)

	state = BoardState.FALLING
	await _apply_gravity()

	state = BoardState.FILLING
	await _fill_empty()

	# Check cascades (boosters can be created from cascades after ability clears)
	state = BoardState.CHECKING
	var new_groups: Array = match_finder.find_match_groups(grid)
	if not new_groups.is_empty():
		cascade_level += 1
		GameManager.increment_cascade()
		await _process_match_groups(new_groups)
	else:
		await _settle_board()


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

	# Check cascades from converted pieces (boosters can be created)
	state = BoardState.CHECKING
	var new_groups: Array = match_finder.find_match_groups(grid)
	if not new_groups.is_empty():
		cascade_level += 1
		GameManager.increment_cascade()
		await _process_match_groups(new_groups)
	else:
		await _settle_board()
