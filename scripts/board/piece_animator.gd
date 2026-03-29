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

	# Spawn burst particles at each piece position before shrinking
	for piece: Sprite2D in pieces:
		if piece:
			_spawn_clear_particles(piece.global_position, piece.modulate)

	var tween: Tween = create_tween().set_parallel(true)
	for piece: Sprite2D in pieces:
		if piece:
			tween.tween_property(piece, "scale", Vector2.ZERO, GameConfig.CLEAR_DURATION)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(piece, "modulate:a", 0.0, GameConfig.CLEAR_DURATION)
	await tween.finished


func _spawn_clear_particles(pos: Vector2, color: Color) -> void:
	## Spawn small colored squares that burst outward and fade.
	var particle_count: int = 6
	var parent: Node = get_parent()  # Board node
	if not parent:
		return

	for i in range(particle_count):
		var p := ColorRect.new()
		p.size = Vector2(5, 5)
		p.color = color.lightened(0.3)
		p.position = pos - Vector2(2.5, 2.5)
		p.z_index = 10
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(p)

		var angle: float = (float(i) / particle_count) * TAU + randf_range(-0.3, 0.3)
		var dist: float = randf_range(25.0, 50.0)
		var target: Vector2 = pos + Vector2.from_angle(angle) * dist - Vector2(2.5, 2.5)
		var dur: float = randf_range(0.25, 0.45)

		var t: Tween = p.create_tween().set_parallel(true)
		t.tween_property(p, "position", target, dur)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(p, "modulate:a", 0.0, dur)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(p, "size", Vector2(2, 2), dur)
		t.set_parallel(false)
		t.tween_callback(p.queue_free)


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


func animate_reject(piece_a: Sprite2D, piece_b: Sprite2D) -> void:
	## Quick horizontal shake on both pieces to signal an invalid swap.
	var has_any: bool = false
	for piece: Sprite2D in [piece_a, piece_b]:
		if not piece:
			continue
		has_any = true
		var orig_x: float = piece.position.x
		var t: Tween = create_tween()
		t.tween_property(piece, "position:x", orig_x + 5.0, 0.04)
		t.tween_property(piece, "position:x", orig_x - 5.0, 0.04)
		t.tween_property(piece, "position:x", orig_x + 3.0, 0.04)
		t.tween_property(piece, "position:x", orig_x, 0.04)
	if has_any:
		var wait: Tween = create_tween()
		wait.tween_interval(0.16)
		await wait.finished


func animate_booster_create(pieces: Array[Sprite2D]) -> void:
	## Pulse-grow then settle to signal booster creation.
	if pieces.is_empty():
		return
	for piece: Sprite2D in pieces:
		if not piece:
			continue
		var orig: Vector2 = piece.scale
		var t: Tween = create_tween()
		t.tween_property(piece, "scale", orig * 1.4, GameConfig.BOOSTER_CREATE_DURATION * 0.4)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(piece, "scale", orig, GameConfig.BOOSTER_CREATE_DURATION * 0.6)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var wait: Tween = create_tween()
	wait.tween_interval(GameConfig.BOOSTER_CREATE_DURATION)
	await wait.finished


func animate_shuffle(pieces_and_targets: Array) -> void:
	## Animate all pieces moving to new positions after a board shuffle.
	if pieces_and_targets.is_empty():
		return
	var tween: Tween = create_tween().set_parallel(true)
	for item: Dictionary in pieces_and_targets:
		var piece: Sprite2D = item["piece"]
		var target: Vector2 = item["target"]
		if piece:
			tween.tween_property(piece, "position", target, GameConfig.SHUFFLE_DURATION)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func animate_shake(node: Node2D, intensity: float) -> void:
	## Quick positional shake on a node (typically BoardContainer).
	var orig: Vector2 = node.position
	var t: Tween = create_tween()
	var steps: int = 6
	var step_dur: float = GameConfig.SHAKE_DURATION / steps
	for i in range(steps):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		# Decay intensity over time
		offset *= (1.0 - float(i) / steps)
		t.tween_property(node, "position", orig + offset, step_dur)
	t.tween_property(node, "position", orig, step_dur)
	await t.finished


func animate_hint(piece_a: Sprite2D, piece_b: Sprite2D) -> Tween:
	## Pulse two pieces to hint at a valid swap. Returns the tween so caller can kill it.
	var tween: Tween = create_tween().set_loops()
	if piece_a:
		var base_a: Vector2 = piece_a.scale
		var big_a: Vector2 = base_a * GameConfig.HIGHLIGHT_SCALE
		tween.set_parallel(true)
		tween.tween_property(piece_a, "scale", big_a, GameConfig.HINT_PULSE_DURATION)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if piece_b:
			var base_b: Vector2 = piece_b.scale
			var big_b: Vector2 = base_b * GameConfig.HIGHLIGHT_SCALE
			tween.tween_property(piece_b, "scale", big_b, GameConfig.HINT_PULSE_DURATION)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.set_parallel(false)
		tween.set_parallel(true)
		tween.tween_property(piece_a, "scale", base_a, GameConfig.HINT_PULSE_DURATION)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if piece_b:
			var base_b2: Vector2 = piece_b.scale
			tween.tween_property(piece_b, "scale", base_b2, GameConfig.HINT_PULSE_DURATION)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.set_parallel(false)
	return tween


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
