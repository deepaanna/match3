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
var last_reward_fragments: int = 0

# Goal tracking
var _goals: Dictionary = {}  # goal_id -> {current, target}
var _goals_met: bool = false
const MOVES_BONUS_SCORE: int = 50  # Bonus per remaining move when goals met early


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.pause_pressed.connect(_on_pause_pressed)
	EventBus.resume_pressed.connect(_on_resume_pressed)
	EventBus.quit_pressed.connect(_on_quit_pressed)
	EventBus.replay_pressed.connect(_on_replay_pressed)
	EventBus.home_pressed.connect(_on_home_pressed)
	EventBus.swap_completed.connect(_on_swap_completed)
	EventBus.matches_cleared.connect(_on_matches_cleared)
	EventBus.board_settled.connect(_on_board_settled)
	EventBus.level_selected.connect(_on_level_selected)
	EventBus.pieces_collected.connect(_on_pieces_collected)
	EventBus.obstacle_cleared.connect(_on_obstacle_cleared)
	EventBus.mana_full.connect(_on_mana_full_for_goal)
	EventBus.victory_detonation_finished.connect(_on_victory_detonation_finished)


func set_leader_skill_system(system: Node) -> void:
	_leader_skill_system = system


func start_game(level: int = 1) -> void:
	current_level = level
	current_level_data = LevelData.get_level(level)
	score = 0
	moves_remaining = current_level_data.max_moves
	cascade_multiplier = 1.0
	_shield_active = false
	_goals_met = false
	last_reward_fragments = 0

	# Apply leader skill extra moves
	if _leader_skill_system and _leader_skill_system.has_method("get_extra_starting_moves"):
		moves_remaining += _leader_skill_system.get_extra_starting_moves()

	# Initialize goal tracking
	_init_goals()

	state = GameState.PLAYING
	EventBus.score_changed.emit(score)
	EventBus.moves_changed.emit(moves_remaining)
	EventBus.game_started.emit()


func _init_goals() -> void:
	_goals.clear()
	if not current_level_data:
		return

	var params: Dictionary = current_level_data.goal_params
	var goal_type: int = current_level_data.goal_type

	match goal_type:
		LevelData.GoalType.SCORE:
			# Score-only: no trackable sub-goals, star threshold is the win condition
			pass
		LevelData.GoalType.COLLECT:
			_goals["collect"] = {"current": 0, "target": params.get("count", 15)}
		LevelData.GoalType.CLEAR_OBSTACLES:
			if params.has("ice"):
				_goals["ice"] = {"current": 0, "target": params["ice"]}
			if params.has("web"):
				_goals["web"] = {"current": 0, "target": params["web"]}
		LevelData.GoalType.CHARGE_MANA:
			_goals["mana"] = {"current": 0, "target": params.get("charges", 5)}
		LevelData.GoalType.MIXED:
			if params.has("count") and params.has("type"):
				_goals["collect"] = {"current": 0, "target": params["count"]}
			if params.has("ice"):
				_goals["ice"] = {"current": 0, "target": params["ice"]}
			if params.has("web"):
				_goals["web"] = {"current": 0, "target": params["web"]}
			if params.has("score"):
				_goals["score"] = {"current": 0, "target": params["score"]}
			if params.has("charges"):
				_goals["mana"] = {"current": 0, "target": params["charges"]}

	# Emit initial progress for all goals
	for goal_id: String in _goals:
		var g: Dictionary = _goals[goal_id]
		EventBus.goal_progress_updated.emit(goal_id, g["current"], g["target"])


func _advance_goal(goal_id: String, amount: int) -> void:
	if not _goals.has(goal_id):
		return
	var g: Dictionary = _goals[goal_id]
	g["current"] = mini(g["current"] + amount, g["target"])
	EventBus.goal_progress_updated.emit(goal_id, g["current"], g["target"])
	if g["current"] >= g["target"]:
		EventBus.goal_completed.emit(goal_id)
	_check_all_goals()


func _check_all_goals() -> void:
	if _goals_met or _goals.is_empty():
		return
	for goal_id: String in _goals:
		var g: Dictionary = _goals[goal_id]
		if g["current"] < g["target"]:
			return
	# All goals met
	_goals_met = true
	EventBus.all_goals_completed.emit()


func are_goals_met() -> bool:
	if current_level_data and current_level_data.goal_type == LevelData.GoalType.SCORE:
		return false  # Score goals resolve at end of moves
	return _goals_met


func get_goals() -> Dictionary:
	return _goals


func add_score(points: int) -> void:
	var multiplier: float = cascade_multiplier
	# Apply leader skill score multiplier
	if _leader_skill_system and _leader_skill_system.has_method("get_score_multiplier"):
		multiplier *= _leader_skill_system.get_score_multiplier()
	var final_points: int = int(points * multiplier)
	score += final_points
	EventBus.score_changed.emit(score)

	# Track score sub-goal for MIXED levels
	if _goals.has("score"):
		_goals["score"]["current"] = score
		EventBus.goal_progress_updated.emit("score", score, _goals["score"]["target"])
		if score >= _goals["score"]["target"]:
			EventBus.goal_completed.emit("score")
		_check_all_goals()


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

	# Non-score goals: check if all goals met (early completion)
	if are_goals_met():
		_complete_level_with_bonus()
		return

	# Out of moves
	if moves_remaining <= 0:
		var stars: int = current_level_data.get_star_rating(score)
		if stars > 0:
			_record_completion(stars)
		else:
			state = GameState.GAME_OVER
			EventBus.game_over.emit(score, stars)


func _complete_level_with_bonus() -> void:
	# If there are remaining moves, trigger the victory detonation sequence on the board
	if current_level_data.moves_bonus and moves_remaining > 0:
		var leftover: int = moves_remaining
		moves_remaining = 0
		EventBus.moves_changed.emit(0)
		EventBus.victory_detonation_requested.emit(leftover)
		# Board will run the detonation and emit victory_detonation_finished
		# which triggers _on_victory_detonation_finished below
		return

	var stars: int = current_level_data.get_star_rating(score)
	stars = maxi(stars, 1)  # Goals met guarantees at least 1 star
	_record_completion(stars)


func _record_completion(stars: int) -> void:
	state = GameState.LEVEL_COMPLETE
	# Check first-clear BEFORE recording (record overwrites stored stars)
	var old_stars: int = PlayerData.get_level_stars(current_level)
	PlayerData.record_level_complete(current_level, stars)
	# Award evidence fragments: 10 base + 5 per star
	var fragments: int = 10 + stars * 5
	# First-clear bonus: only on first ever completion
	if old_stars == 0:
		fragments += 15
	last_reward_fragments = fragments
	PlayerData.add_fragments(fragments)
	# Credibility XP
	PlayerData.add_credibility_xp(10 + stars * 5)
	EventBus.level_completed.emit(score, stars)


# --- Signal handlers ---

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


func _on_pieces_collected(piece_type: int, count: int) -> void:
	if state != GameState.PLAYING:
		return
	if not current_level_data:
		return
	# Only track if collecting the target type
	var params: Dictionary = current_level_data.goal_params
	if params.has("type") and piece_type == params["type"]:
		_advance_goal("collect", count)


func _on_obstacle_cleared(_col: int, _row: int, obstacle_type: int) -> void:
	if state != GameState.PLAYING:
		return
	if obstacle_type == LevelData.ObstacleType.ICE:
		_advance_goal("ice", 1)
	elif obstacle_type == LevelData.ObstacleType.WEB:
		_advance_goal("web", 1)


func _on_victory_detonation_finished(bonus_score: int) -> void:
	score += bonus_score
	EventBus.score_changed.emit(score)
	var stars: int = current_level_data.get_star_rating(score)
	stars = maxi(stars, 1)
	_record_completion(stars)


func _on_mana_full_for_goal(_cryptid_id: String) -> void:
	if state != GameState.PLAYING:
		return
	_advance_goal("mana", 1)
	EventBus.mana_goal_charged.emit()
