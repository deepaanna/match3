extends Node
## Handles all piece tween animations: swap, clear, fall, spawn.


func animate_swap(piece_a: Sprite2D, target_a: Vector2, piece_b: Sprite2D, target_b: Vector2) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	if piece_a:
		tween.tween_property(piece_a, "position", target_a, GameConfig.SWAP_DURATION)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if piece_b:
		tween.tween_property(piece_b, "position", target_b, GameConfig.SWAP_DURATION)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func animate_clear(pieces: Array[Sprite2D]) -> void:
	if pieces.is_empty():
		return

	var tween: Tween = create_tween().set_parallel(true)
	for piece: Sprite2D in pieces:
		if piece:
			tween.tween_property(piece, "scale", Vector2.ZERO, GameConfig.CLEAR_DURATION)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(piece, "modulate:a", 0.0, GameConfig.CLEAR_DURATION)
	await tween.finished


func animate_fall(movements: Array) -> void:
	if movements.is_empty():
		return

	var tween: Tween = create_tween().set_parallel(true)
	for move: Dictionary in movements:
		var piece: Sprite2D = move["piece"]
		var target: Vector2 = move["target"]
		var distance: int = move["distance"]
		var duration: float = maxf(
			GameConfig.FALL_MIN_DURATION,
			distance * GameConfig.FALL_DURATION_PER_CELL
		)
		if piece:
			tween.tween_property(piece, "position", target, duration)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished


func animate_spawn(new_pieces: Array) -> void:
	if new_pieces.is_empty():
		return

	var tween: Tween = create_tween().set_parallel(true)
	for spawn: Dictionary in new_pieces:
		var piece: Sprite2D = spawn["piece"]
		var target: Vector2 = spawn["target"]
		var distance: int = spawn["distance"]
		var duration: float = maxf(
			GameConfig.FALL_MIN_DURATION,
			distance * GameConfig.FALL_DURATION_PER_CELL
		) + GameConfig.SPAWN_DURATION * 0.5
		if piece:
			tween.tween_property(piece, "position", target, duration)\
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished
