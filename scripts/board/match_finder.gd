extends Node
## Scans the grid for horizontal and vertical matches of 3+.
## Returns an Array of Vector2i positions that are part of matches.
## Uses Dictionary as a set for deduplication (handles L/T/cross overlaps).


func find_matches(grid: Array) -> Array:
	var matched: Dictionary = {}  # Vector2i -> bool (used as set)

	# Horizontal scan
	for row in range(GameConfig.GRID_ROWS):
		for col in range(GameConfig.GRID_COLS - 2):
			var piece_type: int = grid[col][row]
			if piece_type == PieceData.PieceType.NONE:
				continue

			if grid[col + 1][row] == piece_type and grid[col + 2][row] == piece_type:
				# Found at least 3 in a row — extend as far as possible
				var end_col: int = col + 2
				while end_col + 1 < GameConfig.GRID_COLS and grid[end_col + 1][row] == piece_type:
					end_col += 1
				for c in range(col, end_col + 1):
					matched[Vector2i(c, row)] = true

	# Vertical scan
	for col in range(GameConfig.GRID_COLS):
		for row in range(GameConfig.GRID_ROWS - 2):
			var piece_type: int = grid[col][row]
			if piece_type == PieceData.PieceType.NONE:
				continue

			if grid[col][row + 1] == piece_type and grid[col][row + 2] == piece_type:
				var end_row: int = row + 2
				while end_row + 1 < GameConfig.GRID_ROWS and grid[col][end_row + 1] == piece_type:
					end_row += 1
				for r in range(row, end_row + 1):
					matched[Vector2i(col, r)] = true

	return matched.keys()
