extends Node
## Reads the leader cryptid (team slot 0) and provides passive bonuses.

var _leader: CryptidData = null


func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.team_changed.connect(_on_team_changed)


func _on_game_started() -> void:
	_refresh_leader()


func _on_team_changed() -> void:
	_refresh_leader()


func _refresh_leader() -> void:
	_leader = null
	if PlayerData.active_team[0] != "":
		_leader = CryptidDatabase.get_cryptid(PlayerData.active_team[0])


func get_score_multiplier() -> float:
	if _leader and _leader.leader_skill_type == CryptidData.LeaderSkillType.SCORE_MULTIPLIER:
		return _leader.leader_skill_value
	return 1.0


func get_mana_multiplier() -> float:
	if _leader and _leader.leader_skill_type == CryptidData.LeaderSkillType.MANA_MULTIPLIER:
		return _leader.leader_skill_value
	return 1.0


func get_extra_starting_moves() -> int:
	if _leader and _leader.leader_skill_type == CryptidData.LeaderSkillType.EXTRA_STARTING_MOVES:
		return roundi(_leader.leader_skill_value)
	return 0
