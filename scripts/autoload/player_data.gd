extends Node

const SAVE_PATH: String = "user://player_save.json"
const MAX_ENERGY: int = 5
const ENERGY_REGEN_SECONDS: int = 1500  # 25 minutes

# Currencies
var evidence_fragments: int = 0
var cryptid_coins: int = 0
var research_data: int = 0

# Collection
var collected_cryptids: Dictionary = {}  # cryptid_id -> {level: int, duplicates: int}
var active_team: Array[String] = ["", "", ""]  # 3 cryptid_ids

# Progression
var highest_level_completed: int = 0
var level_stars: Dictionary = {}  # "level_number" -> stars (int)
var total_stars: int = 0

# Credibility
var credibility_xp: int = 0

# Energy
var energy: int = MAX_ENERGY
var last_energy_time: float = 0.0  # Unix timestamp of last energy change

# Gacha pity
var pity_rare: int = 0  # pulls since last Rare+
var pity_epic: int = 0  # pulls since last Epic+

# Flags
var starter_pack_shown: bool = false
var starter_pack_purchased: bool = false
var tutorial_completed: bool = false

# Tutorial hints: hint_id -> true (shown once, never again)
var tutorial_hints_shown: Dictionary = {}

# Trail cameras: biome_id -> {placed_time: float, duration_hours: int}
var trail_cameras: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()
	_regen_energy()


func _regen_energy() -> void:
	if energy >= MAX_ENERGY:
		last_energy_time = Time.get_unix_time_from_system()
		return
	var now: float = Time.get_unix_time_from_system()
	var elapsed: float = now - last_energy_time
	var hearts_to_add: int = floori(elapsed / ENERGY_REGEN_SECONDS)
	if hearts_to_add > 0:
		energy = mini(energy + hearts_to_add, MAX_ENERGY)
		last_energy_time = now - fmod(elapsed, ENERGY_REGEN_SECONDS)
		EventBus.energy_changed.emit(energy)
		save_data()


func get_energy_regen_remaining() -> float:
	if energy >= MAX_ENERGY:
		return 0.0
	var now: float = Time.get_unix_time_from_system()
	var elapsed: float = now - last_energy_time
	return maxf(ENERGY_REGEN_SECONDS - fmod(elapsed, ENERGY_REGEN_SECONDS), 0.0)


func use_energy() -> bool:
	_regen_energy()
	if energy <= 0:
		EventBus.energy_empty.emit()
		return false
	energy -= 1
	last_energy_time = Time.get_unix_time_from_system()
	EventBus.energy_changed.emit(energy)
	save_data()
	return true


func refill_energy() -> void:
	energy = MAX_ENERGY
	last_energy_time = Time.get_unix_time_from_system()
	EventBus.energy_changed.emit(energy)
	EventBus.energy_refilled.emit()
	save_data()


# --- Currencies ---

func add_fragments(amount: int) -> void:
	evidence_fragments += amount
	EventBus.fragments_changed.emit(evidence_fragments)
	save_data()


func spend_fragments(amount: int) -> bool:
	if evidence_fragments < amount:
		return false
	evidence_fragments -= amount
	EventBus.fragments_changed.emit(evidence_fragments)
	save_data()
	return true


func add_coins(amount: int) -> void:
	cryptid_coins += amount
	EventBus.coins_changed.emit(cryptid_coins)
	save_data()


func spend_coins(amount: int) -> bool:
	if cryptid_coins < amount:
		return false
	cryptid_coins -= amount
	EventBus.coins_changed.emit(cryptid_coins)
	save_data()
	return true


func add_research_data(amount: int) -> void:
	research_data += amount
	EventBus.research_data_changed.emit(research_data)
	save_data()


# --- Collection ---

func add_cryptid(cryptid_id: String) -> bool:
	## Returns true if new, false if duplicate
	if collected_cryptids.has(cryptid_id):
		collected_cryptids[cryptid_id]["duplicates"] += 1
		# Award Research Data for dupes
		var cryptid: CryptidData = CryptidDatabase.get_cryptid(cryptid_id)
		if cryptid:
			var rd_amount: int = 5 * (cryptid.rarity + 1)
			add_research_data(rd_amount)
		EventBus.cryptid_obtained.emit(cryptid_id, false)
		save_data()
		return false
	else:
		collected_cryptids[cryptid_id] = {"level": 1, "duplicates": 0}
		EventBus.cryptid_obtained.emit(cryptid_id, true)
		save_data()
		return true


func has_cryptid(cryptid_id: String) -> bool:
	return collected_cryptids.has(cryptid_id)


func get_collection_count() -> int:
	return collected_cryptids.size()


# --- Team ---

func set_team_slot(slot: int, cryptid_id: String) -> void:
	if slot < 0 or slot > 2:
		return
	active_team[slot] = cryptid_id
	EventBus.team_changed.emit()
	save_data()


func get_team_cryptids() -> Array[CryptidData]:
	var team: Array[CryptidData] = []
	for id in active_team:
		if id != "":
			var c: CryptidData = CryptidDatabase.get_cryptid(id)
			if c:
				team.append(c)
	return team


# --- Progression ---

func record_level_complete(level: int, stars: int) -> void:
	var key: String = str(level)
	var old_stars: int = level_stars.get(key, 0)
	if stars > old_stars:
		var star_diff: int = stars - old_stars
		total_stars += star_diff
		level_stars[key] = stars
		EventBus.star_total_changed.emit(total_stars)

	if level > highest_level_completed:
		highest_level_completed = level

	save_data()


func get_level_stars(level: int) -> int:
	return level_stars.get(str(level), 0)


func is_level_unlocked(level: int) -> bool:
	if level <= 1:
		return true
	return highest_level_completed >= level - 1


func is_region_unlocked(region: RegionData) -> bool:
	return total_stars >= region.unlock_star_requirement


func add_credibility_xp(amount: int) -> void:
	var old_rank: int = CredibilityData.get_rank_index(credibility_xp)
	credibility_xp += amount
	var new_rank: int = CredibilityData.get_rank_index(credibility_xp)
	EventBus.credibility_changed.emit(credibility_xp)
	if new_rank > old_rank:
		# Rank up bonus
		add_coins(50 * new_rank)
	save_data()


# --- Tutorial hints ---

func is_hint_shown(hint_id: String) -> bool:
	return tutorial_hints_shown.has(hint_id)


func mark_hint_shown(hint_id: String) -> void:
	if not tutorial_hints_shown.has(hint_id):
		tutorial_hints_shown[hint_id] = true
		save_data()


# === FEATURE TRICKLE SYSTEM v1.0 ===

func has_seen_discovery(discovery_id: String) -> bool:
	return tutorial_hints_shown.has("disc_" + discovery_id)


func mark_discovery_seen(discovery_id: String) -> void:
	mark_hint_shown("disc_" + discovery_id)


# --- Save / Load ---

func save_data() -> void:
	var data: Dictionary = {
		"evidence_fragments": evidence_fragments,
		"cryptid_coins": cryptid_coins,
		"research_data": research_data,
		"collected_cryptids": collected_cryptids,
		"active_team": active_team,
		"highest_level_completed": highest_level_completed,
		"level_stars": level_stars,
		"total_stars": total_stars,
		"credibility_xp": credibility_xp,
		"energy": energy,
		"last_energy_time": last_energy_time,
		"pity_rare": pity_rare,
		"pity_epic": pity_epic,
		"starter_pack_shown": starter_pack_shown,
		"starter_pack_purchased": starter_pack_purchased,
		"tutorial_completed": tutorial_completed,
		"tutorial_hints_shown": tutorial_hints_shown,
		"trail_cameras": trail_cameras,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_init_new_player()
		save_data()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_init_new_player()
		save_data()
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		_init_new_player()
		save_data()
		return

	var data: Dictionary = json.data
	evidence_fragments = data.get("evidence_fragments", 0)
	cryptid_coins = data.get("cryptid_coins", 0)
	research_data = data.get("research_data", 0)
	collected_cryptids = data.get("collected_cryptids", {})
	var loaded_team: Array = data.get("active_team", ["", "", ""])
	active_team = ["", "", ""]
	for i in range(mini(loaded_team.size(), 3)):
		active_team[i] = str(loaded_team[i])
	highest_level_completed = data.get("highest_level_completed", 0)
	level_stars = data.get("level_stars", {})
	total_stars = data.get("total_stars", 0)
	credibility_xp = data.get("credibility_xp", 0)
	energy = data.get("energy", MAX_ENERGY)
	last_energy_time = data.get("last_energy_time", Time.get_unix_time_from_system())
	pity_rare = data.get("pity_rare", 0)
	pity_epic = data.get("pity_epic", 0)
	starter_pack_shown = data.get("starter_pack_shown", false)
	starter_pack_purchased = data.get("starter_pack_purchased", false)
	tutorial_completed = data.get("tutorial_completed", false)
	tutorial_hints_shown = data.get("tutorial_hints_shown", {})
	trail_cameras = data.get("trail_cameras", {})


func _init_new_player() -> void:
	evidence_fragments = 200
	cryptid_coins = 50
	research_data = 0
	# Give starter cryptids
	var starters: Array[String] = CryptidDatabase.get_starter_team()
	for id in starters:
		collected_cryptids[id] = {"level": 1, "duplicates": 0}
	active_team = starters.duplicate()
	highest_level_completed = 0
	level_stars = {}
	total_stars = 0
	credibility_xp = 0
	energy = MAX_ENERGY
	last_energy_time = Time.get_unix_time_from_system()
	pity_rare = 0
	pity_epic = 0
	starter_pack_shown = false
	starter_pack_purchased = false
	tutorial_completed = false
	tutorial_hints_shown = {}
	trail_cameras = {}
