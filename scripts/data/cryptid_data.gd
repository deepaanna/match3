class_name CryptidData
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

enum AbilityType {
	CLEAR_ROW,
	CLEAR_COLUMN,
	CLEAR_AREA,
	CONVERT_TILES,
	SCORE_BOOST,
	EXTRA_MOVES,
	SHIELD,
}

enum LeaderSkillType {
	NONE,
	SCORE_MULTIPLIER,
	MANA_MULTIPLIER,
	EXTRA_STARTING_MOVES,
}

@export var cryptid_id: String = ""
@export var display_name: String = ""
@export var base_cryptid: PieceData.PieceType = PieceData.PieceType.BIGFOOT
@export var variant_name: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var ability_type: AbilityType = AbilityType.CLEAR_ROW
@export var mana_cost: int = 6
@export var ability_power: int = 1
@export var leader_skill_type: LeaderSkillType = LeaderSkillType.NONE
@export var leader_skill_value: float = 0.0
@export var flavor_text: String = ""

const RARITY_NAMES: Dictionary = {
	Rarity.COMMON: "Common",
	Rarity.UNCOMMON: "Uncommon",
	Rarity.RARE: "Rare",
	Rarity.EPIC: "Epic",
	Rarity.LEGENDARY: "Legendary",
}

const RARITY_COLORS: Dictionary = {
	Rarity.COMMON: Color(0.7, 0.7, 0.7),
	Rarity.UNCOMMON: Color(0.3, 0.8, 0.3),
	Rarity.RARE: Color(0.3, 0.5, 1.0),
	Rarity.EPIC: Color(0.7, 0.3, 0.9),
	Rarity.LEGENDARY: Color(1.0, 0.8, 0.2),
}

const ABILITY_NAMES: Dictionary = {
	AbilityType.CLEAR_ROW: "Row Clear",
	AbilityType.CLEAR_COLUMN: "Column Clear",
	AbilityType.CLEAR_AREA: "Area Clear",
	AbilityType.CONVERT_TILES: "Convert",
	AbilityType.SCORE_BOOST: "Score Boost",
	AbilityType.EXTRA_MOVES: "Extra Moves",
	AbilityType.SHIELD: "Shield",
}


static func get_rarity_name(r: Rarity) -> String:
	return RARITY_NAMES.get(r, "Unknown")


static func get_rarity_color(r: Rarity) -> Color:
	return RARITY_COLORS.get(r, Color.WHITE)


static func get_ability_name(a: AbilityType) -> String:
	return ABILITY_NAMES.get(a, "Unknown")


static func get_ability_description(type: AbilityType, power: int) -> String:
	match type:
		AbilityType.CLEAR_ROW:
			if power <= 1:
				return "Clears 1 random row"
			return "Clears %d random rows" % power
		AbilityType.CLEAR_COLUMN:
			if power <= 1:
				return "Clears 1 random column"
			return "Clears %d random columns" % power
		AbilityType.CLEAR_AREA:
			var size: int = power * 2 + 1
			return "Clears a %dx%d area" % [size, size]
		AbilityType.CONVERT_TILES:
			return "Converts %d pieces to your color" % power
		AbilityType.SCORE_BOOST:
			return "Instantly adds %d points" % power
		AbilityType.EXTRA_MOVES:
			return "Grants %d extra moves" % power
		AbilityType.SHIELD:
			return "Next swap costs no move"
	return "Unknown ability"


static func get_leader_description(type: LeaderSkillType, value: float) -> String:
	match type:
		LeaderSkillType.SCORE_MULTIPLIER:
			return "All scores x%.1f" % value
		LeaderSkillType.MANA_MULTIPLIER:
			var pct: int = roundi((value - 1.0) * 100)
			return "Abilities charge %d%% faster" % pct
		LeaderSkillType.EXTRA_STARTING_MOVES:
			return "+%d starting moves" % roundi(value)
		LeaderSkillType.NONE:
			return ""
	return ""


static func create(id: String, name: String, base: PieceData.PieceType, variant: String,
		r: Rarity, ability: AbilityType, cost: int, power: int,
		leader_type: LeaderSkillType = LeaderSkillType.NONE, leader_val: float = 0.0,
		flavor: String = "") -> CryptidData:
	var data := CryptidData.new()
	data.cryptid_id = id
	data.display_name = name
	data.base_cryptid = base
	data.variant_name = variant
	data.rarity = r
	data.ability_type = ability
	data.mana_cost = cost
	data.ability_power = power
	data.leader_skill_type = leader_type
	data.leader_skill_value = leader_val
	data.flavor_text = flavor
	return data
