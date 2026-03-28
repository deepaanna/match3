extends Node
## Handles ability activation when player taps a fully-charged team portrait.

var _board: Node2D = null
var _mana_system: Node = null


func setup(board: Node2D, mana_system: Node) -> void:
	_board = board
	_mana_system = mana_system


func try_activate_ability(cryptid_id: String) -> void:
	if not _board or not _mana_system:
		return
	if _board.state != _board.BoardState.IDLE:
		return
	if GameManager.state != GameManager.GameState.PLAYING:
		return
	if not _mana_system.is_mana_full(cryptid_id):
		return

	var cryptid: CryptidData = CryptidDatabase.get_cryptid(cryptid_id)
	if not cryptid:
		return

	_mana_system.consume_mana(cryptid_id)
	EventBus.ability_activated.emit(cryptid_id)

	match cryptid.ability_type:
		CryptidData.AbilityType.CLEAR_ROW:
			_activate_clear_row(cryptid.ability_power)
		CryptidData.AbilityType.CLEAR_COLUMN:
			_activate_clear_column(cryptid.ability_power)
		CryptidData.AbilityType.CLEAR_AREA:
			_activate_clear_area(cryptid.ability_power)
		CryptidData.AbilityType.CONVERT_TILES:
			_activate_convert(cryptid)
		CryptidData.AbilityType.SCORE_BOOST:
			_activate_score_boost(cryptid.ability_power)
		CryptidData.AbilityType.EXTRA_MOVES:
			_activate_extra_moves(cryptid.ability_power)
		CryptidData.AbilityType.SHIELD:
			_activate_shield()

	EventBus.ability_resolved.emit(cryptid_id)


func _activate_clear_row(power: int) -> void:
	# Collect all positions from 'power' random rows into one batch
	var all_positions: Array[Vector2i] = []
	var rows_used: Array[int] = []
	for _i in range(power):
		var row: int = randi() % GameConfig.GRID_ROWS
		while rows_used.has(row):
			row = randi() % GameConfig.GRID_ROWS
		rows_used.append(row)
		var positions: Array[Vector2i] = _board.get_row_positions(row)
		all_positions.append_array(positions)
		EventBus.row_cleared.emit(row)
	_board.execute_ability_clear(all_positions)


func _activate_clear_column(power: int) -> void:
	# Collect all positions from 'power' random columns into one batch
	var all_positions: Array[Vector2i] = []
	var cols_used: Array[int] = []
	for _i in range(power):
		var col: int = randi() % GameConfig.GRID_COLS
		while cols_used.has(col):
			col = randi() % GameConfig.GRID_COLS
		cols_used.append(col)
		var positions: Array[Vector2i] = _board.get_column_positions(col)
		all_positions.append_array(positions)
		EventBus.column_cleared.emit(col)
	_board.execute_ability_clear(all_positions)


func _activate_clear_area(power: int) -> void:
	var center_col: int = randi_range(power, GameConfig.GRID_COLS - 1 - power)
	var center_row: int = randi_range(power, GameConfig.GRID_ROWS - 1 - power)
	var positions: Array[Vector2i] = _board.get_area_positions(center_col, center_row, power)
	EventBus.area_cleared.emit(center_col, center_row, power)
	_board.execute_ability_clear(positions)


func _activate_convert(cryptid: CryptidData) -> void:
	var target_type: int = cryptid.base_cryptid
	var positions: Array[Vector2i] = _board.get_random_positions_of_type(-1, cryptid.ability_power, target_type)
	EventBus.pieces_converted.emit(positions, target_type)
	_board.execute_ability_convert(positions, target_type)


func _activate_score_boost(power: int) -> void:
	GameManager.add_score(power)


func _activate_extra_moves(power: int) -> void:
	GameManager.grant_extra_moves(power)
	EventBus.extra_moves_granted.emit(power)


func _activate_shield() -> void:
	GameManager.activate_shield()
	EventBus.shield_activated.emit()
