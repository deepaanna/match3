extends Node
## Scans the grid for horizontal and vertical matches of 3+.
## find_match_groups() returns structured data (size, direction, positions per group).
## find_matches() returns a flat deduplicated Array[Vector2i] for callers that don't need groups.


func find_match_groups(grid: Array) -> Array:
	## Returns Array of match groups. Each group is a Dictionary:
	## {"positions": Array[Vector2i], "size": int, "direction": String, "piece_type": int}
	var groups: Array = []

	# Horizontal scan
	for row in range(GameConfig.GRID_ROWS):
		var col: int = 0
		while col < GameConfig.GRID_COLS:
			var piece_type: int = grid[col][row]
			if piece_type < 0:
				col += 1
				continue

			var end_col: int = col
			while end_col + 1 < GameConfig.GRID_COLS and grid[end_col + 1][row] == piece_type:
				end_col += 1

			var run: int = end_col - col + 1
			if run >= 3:
				var positions: Array[Vector2i] = []
				for c in range(col, end_col + 1):
					positions.append(Vector2i(c, row))
				groups.append({
					"positions": positions,
					"size": run,
					"direction": "horizontal",
					"piece_type": piece_type
				})

			col = end_col + 1

	# Vertical scan
	for col in range(GameConfig.GRID_COLS):
		var row: int = 0
		while row < GameConfig.GRID_ROWS:
			var piece_type: int = grid[col][row]
			if piece_type < 0:
				row += 1
				continue

			var end_row: int = row
			while end_row + 1 < GameConfig.GRID_ROWS and grid[col][end_row + 1] == piece_type:
				end_row += 1

			var run: int = end_row - row + 1
			if run >= 3:
				var positions: Array[Vector2i] = []
				for r in range(row, end_row + 1):
					positions.append(Vector2i(col, r))
				groups.append({
					"positions": positions,
					"size": run,
					"direction": "vertical",
					"piece_type": piece_type
				})

			row = end_row + 1

	return groups


func find_matches(grid: Array) -> Array:
	## Returns flat Array[Vector2i] of all matched positions (deduplicated).
	var matched: Dictionary = {}
	for group: Dictionary in find_match_groups(grid):
		for pos: Vector2i in group["positions"]:
			matched[pos] = true
	return matched.keys()
