extends Node
## Tracks mana bars for each cryptid on the active team.
## Listens to mana_charged signal from board to fill bars.

# cryptid_id -> {current: int, max: int}
var mana_bars: Dictionary = {}


func _ready() -> void:
	EventBus.mana_charged.connect(_on_mana_charged)
	EventBus.game_started.connect(_on_game_started)
	EventBus.team_changed.connect(_on_team_changed)


func _on_game_started() -> void:
	_reset_mana()


func _on_team_changed() -> void:
	_reset_mana()


func _reset_mana() -> void:
	mana_bars.clear()
	var team: Array[CryptidData] = PlayerData.get_team_cryptids()
	for cryptid in team:
		mana_bars[cryptid.cryptid_id] = {"current": 0, "max": cryptid.mana_cost}


func _on_mana_charged(piece_type: int, amount: int) -> void:
	# Get leader skill mana multiplier
	var multiplier: float = 1.0
	var leader_system: Node = get_parent().get_node_or_null("LeaderSkillSystem")
	if leader_system and leader_system.has_method("get_mana_multiplier"):
		multiplier = leader_system.get_mana_multiplier()

	var effective_amount: int = roundi(amount * multiplier)

	# Charge cryptids whose base_cryptid matches the piece_type
	var team: Array[CryptidData] = PlayerData.get_team_cryptids()
	for cryptid in team:
		if cryptid.base_cryptid == piece_type and mana_bars.has(cryptid.cryptid_id):
			var bar: Dictionary = mana_bars[cryptid.cryptid_id]
			var was_full: bool = bar["current"] >= bar["max"]
			bar["current"] = mini(bar["current"] + effective_amount, bar["max"])
			if not was_full and bar["current"] >= bar["max"]:
				EventBus.mana_full.emit(cryptid.cryptid_id)


func is_mana_full(cryptid_id: String) -> bool:
	if not mana_bars.has(cryptid_id):
		return false
	var bar: Dictionary = mana_bars[cryptid_id]
	return bar["current"] >= bar["max"]


func consume_mana(cryptid_id: String) -> bool:
	if not is_mana_full(cryptid_id):
		return false
	mana_bars[cryptid_id]["current"] = 0
	return true


func get_mana_fraction(cryptid_id: String) -> float:
	if not mana_bars.has(cryptid_id):
		return 0.0
	var bar: Dictionary = mana_bars[cryptid_id]
	if bar["max"] <= 0:
		return 0.0
	return float(bar["current"]) / float(bar["max"])
