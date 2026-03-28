extends Node

enum GameState { IDLE, PLAYING, PAUSED, GAME_OVER, LEVEL_COMPLETE }

var state: GameState = GameState.IDLE
var score: int = 0
var moves_remaining: int = 0
var current_level: int = 1
var cascade_multiplier: float = 1.0
var current_level_data: LevelData = null
var _shield_active: bool = false
var _leader_skill_system: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.play_pressed.connect(_on_play_pressed)
	EventBus.pause_pressed.connect(_on_pause_pressed)
	EventBus.resume_pressed.connect(_on_resume_pressed)
	EventBus.quit_pressed.connect(_on_quit_pressed)
	EventBus.replay_pressed.connect(_on_replay_pressed)
	EventBus.home_pressed.connect(_on_home_pressed)
	EventBus.swap_completed.connect(_on_swap_completed)
	EventBus.matches_cleared.connect(_on_matches_cleared)
	EventBus.board_settled.connect(_on_board_settled)
	EventBus.level_selected.connect(_on_level_selected)


func set_leader_skill_system(system: Node) -> void:
	_leader_skill_system = system


func start_game(level: int = 1) -> void:
	current_level = level
	current_level_data = LevelData.create_default(level)
	score = 0
	moves_remaining = current_level_data.max_moves
	cascade_multiplier = 1.0
	_shield_active = false

	# Apply leader skill extra moves
	if _leader_skill_system and _leader_skill_system.has_method("get_extra_starting_moves"):
		moves_remaining += _leader_skill_system.get_extra_starting_moves()

	state = GameState.PLAYING
	EventBus.score_changed.emit(score)
	EventBus.moves_changed.emit(moves_remaining)
	EventBus.game_started.emit()


func add_score(points: int) -> void:
	var multiplier: float = cascade_multiplier
	# Apply leader skill score multiplier
	if _leader_skill_system and _leader_skill_system.has_method("get_score_multiplier"):
		multiplier *= _leader_skill_system.get_score_multiplier()
	var final_points: int = int(points * multiplier)
	score += final_points
	EventBus.score_changed.emit(score)


func use_move() -> void:
	moves_remaining -= 1
	EventBus.moves_changed.emit(moves_remaining)


func grant_extra_moves(amount: int) -> void:
	moves_remaining += amount
	EventBus.moves_changed.emit(moves_remaining)
	# If we were GAME_OVER, go back to PLAYING
	if state == GameState.GAME_OVER:
		state = GameState.PLAYING


func activate_shield() -> void:
	_shield_active = true


func start_cascade() -> void:
	cascade_multiplier = 1.0


func increment_cascade() -> void:
	cascade_multiplier += GameConfig.CASCADE_MULTIPLIER_INCREMENT
	EventBus.cascade_started.emit(cascade_multiplier)


func _check_end_condition() -> void:
	if state != GameState.PLAYING:
		return
	if moves_remaining <= 0:
		var stars: int = current_level_data.get_star_rating(score)
		if stars > 0:
			state = GameState.LEVEL_COMPLETE
			# Check first-clear BEFORE recording (record overwrites stored stars)
			var old_stars: int = PlayerData.get_level_stars(current_level)
			PlayerData.record_level_complete(current_level, stars)
			# Award evidence fragments: 10 base + 5 per star
			var fragments: int = 10 + stars * 5
			# First-clear bonus: only on first ever completion
			if old_stars == 0:
				fragments += 15
			PlayerData.add_fragments(fragments)
			# Credibility XP
			PlayerData.add_credibility_xp(10 + stars * 5)
			EventBus.level_completed.emit(score, stars)
		else:
			state = GameState.GAME_OVER
			EventBus.game_over.emit(score, stars)


func _on_play_pressed() -> void:
	if not PlayerData.use_energy():
		return
	start_game(current_level)
	SceneManager.change_scene("res://scenes/game_screen.tscn")


func _on_pause_pressed() -> void:
	if state == GameState.PLAYING:
		state = GameState.PAUSED
		EventBus.game_paused.emit()


func _on_resume_pressed() -> void:
	if state == GameState.PAUSED:
		state = GameState.PLAYING
		EventBus.game_resumed.emit()


func _on_quit_pressed() -> void:
	state = GameState.IDLE
	get_tree().paused = false
	SceneManager.change_scene("res://scenes/home_screen.tscn")


func _on_replay_pressed() -> void:
	if not PlayerData.use_energy():
		return
	start_game(current_level)
	SceneManager.change_scene("res://scenes/game_screen.tscn")


func _on_home_pressed() -> void:
	state = GameState.IDLE
	SceneManager.change_scene("res://scenes/home_screen.tscn")


func _on_swap_completed() -> void:
	if state == GameState.PLAYING:
		if _shield_active:
			_shield_active = false
		else:
			use_move()


func _on_matches_cleared(count: int, _cascade_level: int) -> void:
	if state == GameState.PLAYING:
		var points: int = GameConfig.MATCH_BASE_SCORE + (count - 3) * GameConfig.EXTRA_PIECE_BONUS
		add_score(points)


func _on_board_settled() -> void:
	cascade_multiplier = 1.0
	_check_end_condition()


func _on_level_selected(level_number: int) -> void:
	if not PlayerData.use_energy():
		return
	start_game(level_number)
	SceneManager.change_scene("res://scenes/game_screen.tscn")
