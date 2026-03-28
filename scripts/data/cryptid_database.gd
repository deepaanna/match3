class_name CryptidDatabase
extends RefCounted

static var _registry: Array[CryptidData] = []
static var _initialized: bool = false


static func _ensure_init() -> void:
	if _initialized:
		return
	_initialized = true
	_build_registry()


static func _build_registry() -> void:
	_registry.clear()
	# 5 variants per base cryptid (6 bases = 30 total)
	# Spread across rarities with different abilities

	# --- BIGFOOT (Brown) ---
	_registry.append(CryptidData.create(
		"bigfoot_scout", "Bigfoot Scout", PieceData.PieceType.BIGFOOT, "Scout",
		CryptidData.Rarity.COMMON, CryptidData.AbilityType.CLEAR_ROW, 8, 1,
		CryptidData.LeaderSkillType.NONE, 0.0,
		"A young sasquatch just learning to navigate the forest."))
	_registry.append(CryptidData.create(
		"bigfoot_tracker", "Bigfoot Tracker", PieceData.PieceType.BIGFOOT, "Tracker",
		CryptidData.Rarity.UNCOMMON, CryptidData.AbilityType.CLEAR_ROW, 7, 1,
		CryptidData.LeaderSkillType.SCORE_MULTIPLIER, 1.1,
		"Experienced in the ways of the woodland, this one leaves the deepest prints."))
	_registry.append(CryptidData.create(
		"bigfoot_elder", "Bigfoot Elder", PieceData.PieceType.BIGFOOT, "Elder",
		CryptidData.Rarity.RARE, CryptidData.AbilityType.CLEAR_AREA, 10, 2,
		CryptidData.LeaderSkillType.SCORE_MULTIPLIER, 1.2,
		"The ancient guardian of the Pacific Northwest forests."))
	_registry.append(CryptidData.create(
		"bigfoot_alpha", "Bigfoot Alpha", PieceData.PieceType.BIGFOOT, "Alpha",
		CryptidData.Rarity.EPIC, CryptidData.AbilityType.CLEAR_AREA, 9, 3,
		CryptidData.LeaderSkillType.SCORE_MULTIPLIER, 1.3,
		"Pack leader whose thundering footsteps shake the ground."))
	_registry.append(CryptidData.create(
		"bigfoot_ancient", "Bigfoot Ancient", PieceData.PieceType.BIGFOOT, "Ancient",
		CryptidData.Rarity.LEGENDARY, CryptidData.AbilityType.CLEAR_AREA, 8, 4,
		CryptidData.LeaderSkillType.SCORE_MULTIPLIER, 1.5,
		"A mythic being older than the oldest trees. Possibly immortal."))

	# --- MOTHMAN (Red) ---
	_registry.append(CryptidData.create(
		"mothman_observer", "Mothman Observer", PieceData.PieceType.MOTHMAN, "Observer",
		CryptidData.Rarity.COMMON, CryptidData.AbilityType.CLEAR_COLUMN, 8, 1,
		CryptidData.LeaderSkillType.NONE, 0.0,
		"Silently watches from the bridge, its red eyes glowing faintly."))
	_registry.append(CryptidData.create(
		"mothman_herald", "Mothman Herald", PieceData.PieceType.MOTHMAN, "Herald",
		CryptidData.Rarity.UNCOMMON, CryptidData.AbilityType.CLEAR_COLUMN, 7, 1,
		CryptidData.LeaderSkillType.MANA_MULTIPLIER, 1.15,
		"Appears before disasters, a warning to those who can read the signs."))
	_registry.append(CryptidData.create(
		"mothman_prophet", "Mothman Prophet", PieceData.PieceType.MOTHMAN, "Prophet",
		CryptidData.Rarity.RARE, CryptidData.AbilityType.SCORE_BOOST, 8, 500,
		CryptidData.LeaderSkillType.MANA_MULTIPLIER, 1.25,
		"Its visions pierce through time itself."))
	_registry.append(CryptidData.create(
		"mothman_dread", "Mothman Dread", PieceData.PieceType.MOTHMAN, "Dread",
		CryptidData.Rarity.EPIC, CryptidData.AbilityType.CLEAR_COLUMN, 7, 2,
		CryptidData.LeaderSkillType.MANA_MULTIPLIER, 1.35,
		"The beating of its wings brings an unshakable sense of dread."))
	_registry.append(CryptidData.create(
		"mothman_doom", "Mothman of Doom", PieceData.PieceType.MOTHMAN, "of Doom",
		CryptidData.Rarity.LEGENDARY, CryptidData.AbilityType.CONVERT_TILES, 9, 5,
		CryptidData.LeaderSkillType.MANA_MULTIPLIER, 1.5,
		"When the Mothman of Doom appears, reality itself bends."))

	# --- NESSIE (Blue) ---
	_registry.append(CryptidData.create(
		"nessie_pup", "Nessie Pup", PieceData.PieceType.NESSIE, "Pup",
		CryptidData.Rarity.COMMON, CryptidData.AbilityType.SHIELD, 10, 1,
		CryptidData.LeaderSkillType.NONE, 0.0,
		"A playful baby plesiosaur, barely visible above the waves."))
	_registry.append(CryptidData.create(
		"nessie_swimmer", "Nessie Swimmer", PieceData.PieceType.NESSIE, "Swimmer",
		CryptidData.Rarity.UNCOMMON, CryptidData.AbilityType.SHIELD, 9, 1,
		CryptidData.LeaderSkillType.EXTRA_STARTING_MOVES, 2.0,
		"Gracefully glides through the murky depths of Loch Ness."))
	_registry.append(CryptidData.create(
		"nessie_guardian", "Nessie Guardian", PieceData.PieceType.NESSIE, "Guardian",
		CryptidData.Rarity.RARE, CryptidData.AbilityType.EXTRA_MOVES, 10, 3,
		CryptidData.LeaderSkillType.EXTRA_STARTING_MOVES, 3.0,
		"Protects the secrets of the deep loch from prying eyes."))
	_registry.append(CryptidData.create(
		"nessie_leviathan", "Nessie Leviathan", PieceData.PieceType.NESSIE, "Leviathan",
		CryptidData.Rarity.EPIC, CryptidData.AbilityType.EXTRA_MOVES, 9, 4,
		CryptidData.LeaderSkillType.EXTRA_STARTING_MOVES, 4.0,
		"A massive creature that makes the entire loch tremble."))
	_registry.append(CryptidData.create(
		"nessie_primordial", "Nessie Primordial", PieceData.PieceType.NESSIE, "Primordial",
		CryptidData.Rarity.LEGENDARY, CryptidData.AbilityType.EXTRA_MOVES, 8, 5,
		CryptidData.LeaderSkillType.EXTRA_STARTING_MOVES, 5.0,
		"The last surviving plesiosaur, older than human civilization."))

	# --- CHUPACABRA (Green) ---
	_registry.append(CryptidData.create(
		"chupa_lurker", "Chupacabra Lurker", PieceData.PieceType.CHUPACABRA, "Lurker",
		CryptidData.Rarity.COMMON, CryptidData.AbilityType.CONVERT_TILES, 9, 3,
		CryptidData.LeaderSkillType.NONE, 0.0,
		"Hides in the brush, waiting for unsuspecting prey."))
	_registry.append(CryptidData.create(
		"chupa_stalker", "Chupacabra Stalker", PieceData.PieceType.CHUPACABRA, "Stalker",
		CryptidData.Rarity.UNCOMMON, CryptidData.AbilityType.CONVERT_TILES, 8, 4,
		CryptidData.LeaderSkillType.SCORE_MULTIPLIER, 1.1,
		"Moves silently through the night, leaving only drained husks behind."))
	_registry.append(CryptidData.create(
		"chupa_hunter", "Chupacabra Hunter", PieceData.PieceType.CHUPACABRA, "Hunter",
		CryptidData.Rarity.RARE, CryptidData.AbilityType.CLEAR_ROW, 7, 1,
		CryptidData.LeaderSkillType.MANA_MULTIPLIER, 1.2,
		"An apex predator of the Caribbean night."))
	_registry.append(CryptidData.create(
		"chupa_nightmare", "Chupacabra Nightmare", PieceData.PieceType.CHUPACABRA, "Nightmare",
		CryptidData.Rarity.EPIC, CryptidData.AbilityType.CONVERT_TILES, 8, 6,
		CryptidData.LeaderSkillType.SCORE_MULTIPLIER, 1.3,
		"Locals speak of this one only in whispers. It hunts the hunters."))
	_registry.append(CryptidData.create(
		"chupa_devourer", "Chupacabra Devourer", PieceData.PieceType.CHUPACABRA, "Devourer",
		CryptidData.Rarity.LEGENDARY, CryptidData.AbilityType.CLEAR_AREA, 8, 4,
		CryptidData.LeaderSkillType.SCORE_MULTIPLIER, 1.5,
		"An unstoppable force of nature that drains the life from everything."))

	# --- YETI (White) ---
	_registry.append(CryptidData.create(
		"yeti_cub", "Yeti Cub", PieceData.PieceType.YETI, "Cub",
		CryptidData.Rarity.COMMON, CryptidData.AbilityType.SCORE_BOOST, 8, 200,
		CryptidData.LeaderSkillType.NONE, 0.0,
		"A fluffy young yeti tumbling through the snow."))
	_registry.append(CryptidData.create(
		"yeti_nomad", "Yeti Nomad", PieceData.PieceType.YETI, "Nomad",
		CryptidData.Rarity.UNCOMMON, CryptidData.AbilityType.SCORE_BOOST, 7, 350,
		CryptidData.LeaderSkillType.EXTRA_STARTING_MOVES, 1.0,
		"Wanders the mountain passes, rarely seen by human eyes."))
	_registry.append(CryptidData.create(
		"yeti_sentinel", "Yeti Sentinel", PieceData.PieceType.YETI, "Sentinel",
		CryptidData.Rarity.RARE, CryptidData.AbilityType.SHIELD, 8, 1,
		CryptidData.LeaderSkillType.EXTRA_STARTING_MOVES, 2.0,
		"Stands eternal guard over the mountain monastery."))
	_registry.append(CryptidData.create(
		"yeti_avalanche", "Yeti Avalanche", PieceData.PieceType.YETI, "Avalanche",
		CryptidData.Rarity.EPIC, CryptidData.AbilityType.CLEAR_AREA, 9, 3,
		CryptidData.LeaderSkillType.SCORE_MULTIPLIER, 1.3,
		"Its roar triggers avalanches that reshape the mountainside."))
	_registry.append(CryptidData.create(
		"yeti_abominable", "The Abominable", PieceData.PieceType.YETI, "Abominable",
		CryptidData.Rarity.LEGENDARY, CryptidData.AbilityType.CLEAR_ROW, 6, 2,
		CryptidData.LeaderSkillType.SCORE_MULTIPLIER, 1.5,
		"The one they all fear. The original. The Abominable Snowman."))

	# --- JERSEY DEVIL (Purple) ---
	_registry.append(CryptidData.create(
		"jdevil_imp", "Jersey Devil Imp", PieceData.PieceType.JERSEY_DEVIL, "Imp",
		CryptidData.Rarity.COMMON, CryptidData.AbilityType.EXTRA_MOVES, 10, 2,
		CryptidData.LeaderSkillType.NONE, 0.0,
		"A mischievous little devil from the Pine Barrens."))
	_registry.append(CryptidData.create(
		"jdevil_fiend", "Jersey Devil Fiend", PieceData.PieceType.JERSEY_DEVIL, "Fiend",
		CryptidData.Rarity.UNCOMMON, CryptidData.AbilityType.EXTRA_MOVES, 9, 2,
		CryptidData.LeaderSkillType.MANA_MULTIPLIER, 1.1,
		"Wings spread wide, it screeches through the Pine Barrens night."))
	_registry.append(CryptidData.create(
		"jdevil_terror", "Jersey Devil Terror", PieceData.PieceType.JERSEY_DEVIL, "Terror",
		CryptidData.Rarity.RARE, CryptidData.AbilityType.CLEAR_COLUMN, 7, 1,
		CryptidData.LeaderSkillType.MANA_MULTIPLIER, 1.2,
		"Townsfolk bolt their doors when this one takes flight."))
	_registry.append(CryptidData.create(
		"jdevil_infernal", "Jersey Devil Infernal", PieceData.PieceType.JERSEY_DEVIL, "Infernal",
		CryptidData.Rarity.EPIC, CryptidData.AbilityType.CONVERT_TILES, 8, 5,
		CryptidData.LeaderSkillType.MANA_MULTIPLIER, 1.35,
		"Fire licks from its hooves as it stalks the midnight forest."))
	_registry.append(CryptidData.create(
		"jdevil_13th", "The 13th Child", PieceData.PieceType.JERSEY_DEVIL, "13th Child",
		CryptidData.Rarity.LEGENDARY, CryptidData.AbilityType.CLEAR_COLUMN, 6, 3,
		CryptidData.LeaderSkillType.MANA_MULTIPLIER, 1.5,
		"Mother Leeds' cursed offspring. The original Jersey Devil."))


static func get_all() -> Array[CryptidData]:
	_ensure_init()
	return _registry.duplicate()


static func get_cryptid(id: String) -> CryptidData:
	_ensure_init()
	for c in _registry:
		if c.cryptid_id == id:
			return c
	return null


static func get_by_rarity(r: CryptidData.Rarity) -> Array[CryptidData]:
	_ensure_init()
	var result: Array[CryptidData] = []
	for c in _registry:
		if c.rarity == r:
			result.append(c)
	return result


static func get_by_element(piece_type: PieceData.PieceType) -> Array[CryptidData]:
	_ensure_init()
	var result: Array[CryptidData] = []
	for c in _registry:
		if c.base_cryptid == piece_type:
			result.append(c)
	return result


static func get_starter_team() -> Array[String]:
	return ["bigfoot_scout", "mothman_observer", "nessie_pup"]
