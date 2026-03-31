class_name LevelData
extends Resource

enum GoalType { SCORE, COLLECT, CLEAR_OBSTACLES, CHARGE_MANA, MIXED }
enum ObstacleType { NONE = 0, ICE = 1, WEB = 2 }

@export var level_number: int = 1
@export var max_moves: int = 20
@export var star_1_score: int = 500
@export var star_2_score: int = 1500
@export var star_3_score: int = 3000
@export var region_id: String = ""
@export var flavor_text: String = ""
@export var discovery_id: String = ""
@export var num_colors: int = 6
@export var goal_type: int = GoalType.SCORE
@export var goal_params: Dictionary = {}
@export var obstacles: Array = []
@export var pre_boosters: Array = []  # [{col, row, booster_type}]
@export var moves_bonus: bool = false


# --- Level catalog (data-driven) ---
# Each entry is keyed by level number. Add new levels here — no code changes needed.
# Keys: moves, colors, goal, goal_params, stars [s1, s2, s3], region, flavor, bonus, obstacles
# Obstacle entries: [col, row, type, hp]

const LEVEL_CATALOG: Dictionary = {
	# L1: Tutorial — pure score, 4 colors, generous. Learn to swap.
	1: {
		"moves": 25, "colors": 4, "goal": GoalType.SCORE,
		"stars": [300, 800, 1200], "region": "pacific_nw",
		"flavor": "Your cryptid-hunting journey begins here!",
		"discovery_id": "cascade_first",
	},
	# L2: Introduce collection goal early while still easy (5 colors, generous target)
	2: {
		"moves": 22, "colors": 5, "goal": GoalType.COLLECT, "bonus": true,
		"goal_params": {"type": 0, "count": 12},  # PieceType.BIGFOOT — ~20% of 5 colors
		"stars": [400, 1000, 1800], "region": "pacific_nw",
		"flavor": "Collect Bigfoot evidence to prove he's real!",
	},
	# L3: Breathing room — score-based, 5 colors, learn to build combos
	3: {
		"moves": 22, "colors": 5, "goal": GoalType.SCORE,
		"stars": [500, 1200, 2200], "region": "pacific_nw",
		"flavor": "Strange tracks spotted deeper in the forest.",
	},
	# L4: Introduce ice (6 tiles, 1 HP) — clear focus, generous moves
	4: {
		"moves": 24, "colors": 5, "goal": GoalType.CLEAR_OBSTACLES, "bonus": true,
		"goal_params": {"ice": 6},
		"stars": [500, 1200, 2000], "region": "pacific_nw",
		"flavor": "Frozen evidence! Break through the ice.",
		"discovery_id": "ice_first",
		"obstacles": [
			[2, 2, ObstacleType.ICE, 1], [5, 2, ObstacleType.ICE, 1],
			[3, 4, ObstacleType.ICE, 1], [4, 4, ObstacleType.ICE, 1],
			[2, 5, ObstacleType.ICE, 1], [5, 5, ObstacleType.ICE, 1],
		],
	},
	# L5: Light mixed — collect + ice. Combines two learned mechanics.
	5: {
		"moves": 22, "colors": 5, "goal": GoalType.MIXED, "bonus": true,
		"goal_params": {"type": 2, "count": 10, "ice": 4},  # PieceType.NESSIE
		"stars": [600, 1400, 2400], "region": "pacific_nw",
		"flavor": "Nessie sightings beneath the ice!",
		"discovery_id": "mana_first",
		"obstacles": [
			[3, 2, ObstacleType.ICE, 1], [4, 2, ObstacleType.ICE, 1],
			[3, 5, ObstacleType.ICE, 1], [4, 5, ObstacleType.ICE, 1],
		],
	},
	# L6: Introduce 6th color alone — score goal, no new obstacle.
	6: {
		"moves": 22, "colors": 6, "goal": GoalType.SCORE,
		"stars": [700, 1600, 2800], "region": "pacific_nw",
		"flavor": "A new creature joins the fray. Adapt!",
		"discovery_id": "booster_first",
	},
	# L7: Introduce webs — now 6 colors are familiar, one new thing at a time.
	7: {
		"moves": 24, "colors": 6, "goal": GoalType.CLEAR_OBSTACLES, "bonus": true,
		"goal_params": {"web": 4},
		"stars": [600, 1400, 2400], "region": "pacific_nw",
		"flavor": "Webs block your path. Clear them out!",
		"obstacles": [
			[1, 3, ObstacleType.WEB, 1], [6, 3, ObstacleType.WEB, 1],
			[1, 5, ObstacleType.WEB, 1], [6, 5, ObstacleType.WEB, 1],
		],
	},
	# L8: 2-HP ice + web mix — difficulty ramp, all mechanics in play.
	8: {
		"moves": 24, "colors": 6, "goal": GoalType.CLEAR_OBSTACLES, "bonus": true,
		"goal_params": {"ice": 4, "web": 3},
		"stars": [700, 1600, 2800], "region": "pacific_nw",
		"flavor": "The creatures are protecting something...",
		"obstacles": [
			[3, 2, ObstacleType.ICE, 2], [4, 2, ObstacleType.ICE, 2],
			[3, 5, ObstacleType.ICE, 2], [4, 5, ObstacleType.ICE, 2],
			[0, 4, ObstacleType.WEB, 1], [7, 4, ObstacleType.WEB, 1],
			[3, 3, ObstacleType.WEB, 1],
		],
	},
	# L9: Mana + collect — gives agency (match the right colors) unlike pure mana goal.
	9: {
		"moves": 22, "colors": 5, "goal": GoalType.MIXED, "bonus": true,
		"goal_params": {"charges": 4, "type": 1, "count": 10},  # PieceType.MOTHMAN
		"stars": [800, 1800, 3200], "region": "pacific_nw",
		"flavor": "Channel the Mothman's energy within!",
	},
	# L10: Region boss — heavy obstacles, mixed goals, pre-placed LINE_H booster at center.
	10: {
		"moves": 30, "colors": 6, "goal": GoalType.MIXED, "bonus": true,
		"goal_params": {"score": 1500, "ice": 6, "web": 2},
		"stars": [1000, 2200, 3800], "region": "pacific_nw",
		"flavor": "Something big lurks here. Prepare yourself!",
		"obstacles": [
			[2, 1, ObstacleType.ICE, 2], [5, 1, ObstacleType.ICE, 2],
			[1, 3, ObstacleType.ICE, 1], [6, 3, ObstacleType.ICE, 1],
			[2, 5, ObstacleType.ICE, 2], [5, 5, ObstacleType.ICE, 2],
			[3, 3, ObstacleType.WEB, 1], [4, 3, ObstacleType.WEB, 1],
		],
		"pre_boosters": [[3, 0, 1], [4, 7, 2]],  # [col, row, BoosterType] — LINE_H, LINE_V
	},
	# L11: Breather after boss — score, 5 colors, ease back in.
	11: {
		"moves": 24, "colors": 5, "goal": GoalType.SCORE,
		"stars": [600, 1400, 2400], "region": "pacific_nw",
		"flavor": "The canopy thins. Something watches from above.",
		"discovery_id": "combo_first",
	},
	# L12: Collect + ice, moderate difficulty.
	12: {
		"moves": 22, "colors": 5, "goal": GoalType.MIXED, "bonus": true,
		"goal_params": {"type": 3, "count": 12, "ice": 4},  # PieceType.CHUPACABRA
		"stars": [700, 1600, 2800], "region": "pacific_nw",
		"flavor": "Chupacabra tracks lead deeper into the frost.",
		"obstacles": [
			[2, 3, ObstacleType.ICE, 1], [5, 3, ObstacleType.ICE, 1],
			[3, 5, ObstacleType.ICE, 2], [4, 5, ObstacleType.ICE, 2],
		],
	},
	# L13: Clear obstacles, ice + web combo.
	13: {
		"moves": 22, "colors": 6, "goal": GoalType.CLEAR_OBSTACLES, "bonus": true,
		"goal_params": {"ice": 6, "web": 3},
		"stars": [800, 1800, 3200], "region": "pacific_nw",
		"flavor": "The forest fights back with ice and web alike.",
		"obstacles": [
			[1, 2, ObstacleType.ICE, 2], [6, 2, ObstacleType.ICE, 2],
			[3, 3, ObstacleType.ICE, 1], [4, 3, ObstacleType.ICE, 1],
			[2, 5, ObstacleType.ICE, 1], [5, 5, ObstacleType.ICE, 1],
			[0, 4, ObstacleType.WEB, 1], [7, 4, ObstacleType.WEB, 1],
			[3, 6, ObstacleType.WEB, 1],
		],
	},
	# L14: Mana charge + collect — demanding goal set.
	14: {
		"moves": 20, "colors": 6, "goal": GoalType.MIXED, "bonus": true,
		"goal_params": {"charges": 3, "type": 4, "count": 10},  # PieceType.YETI
		"stars": [900, 2000, 3600], "region": "pacific_nw",
		"flavor": "The Yeti's presence grows stronger. Channel it!",
	},
	# L15: Region finale — heavy obstacles, mixed goals, pre-placed boosters.
	15: {
		"moves": 28, "colors": 6, "goal": GoalType.MIXED, "bonus": true,
		"goal_params": {"score": 2000, "ice": 8, "web": 4},
		"stars": [1200, 2600, 4200], "region": "pacific_nw",
		"flavor": "The final guardian of this region emerges!",
		"discovery_id": "persistent_booster",
		"obstacles": [
			[1, 1, ObstacleType.ICE, 2], [6, 1, ObstacleType.ICE, 2],
			[2, 3, ObstacleType.ICE, 2], [5, 3, ObstacleType.ICE, 2],
			[1, 5, ObstacleType.ICE, 2], [6, 5, ObstacleType.ICE, 2],
			[3, 2, ObstacleType.ICE, 1], [4, 2, ObstacleType.ICE, 1],
			[0, 3, ObstacleType.WEB, 1], [7, 3, ObstacleType.WEB, 1],
			[3, 4, ObstacleType.WEB, 1], [4, 4, ObstacleType.WEB, 1],
		],
		"pre_boosters": [[3, 0, 1], [4, 7, 2]],
	},
	# ============================
	# REGION 2: Point Pleasant (Levels 16–30)
	# ============================
	# L16: Region opener — score only, 5 colors, generous. Welcome to Point Pleasant.
	16: {
		"moves": 25, "colors": 5, "goal": GoalType.SCORE,
		"stars": [500, 1200, 2000], "region": "point_pleasant",
		"flavor": "The Mothman's homeland. Strange lights fill the sky.",
	},
	# L17: Collect Mothman pieces — thematic tie-in to Point Pleasant.
	17: {
		"moves": 22, "colors": 5, "goal": GoalType.COLLECT, "bonus": true,
		"goal_params": {"type": 1, "count": 14},
		"stars": [600, 1400, 2400], "region": "point_pleasant",
		"flavor": "Mothman feathers litter the bridge. Collect them!",
	},
	# L18: Ice returns with a vengeance — 2-HP from the start.
	18: {
		"moves": 24, "colors": 5, "goal": GoalType.CLEAR_OBSTACLES, "bonus": true,
		"goal_params": {"ice": 8},
		"stars": [700, 1600, 2800], "region": "point_pleasant",
		"flavor": "A bitter cold grips the river valley.",
		"obstacles": [
			[1, 2, ObstacleType.ICE, 2], [6, 2, ObstacleType.ICE, 2],
			[2, 4, ObstacleType.ICE, 2], [5, 4, ObstacleType.ICE, 2],
			[1, 6, ObstacleType.ICE, 1], [6, 6, ObstacleType.ICE, 1],
			[3, 3, ObstacleType.ICE, 1], [4, 3, ObstacleType.ICE, 1],
		],
	},
	# L19: Mixed collect + ice — demanding but rewarding.
	19: {
		"moves": 22, "colors": 6, "goal": GoalType.MIXED, "bonus": true,
		"goal_params": {"type": 0, "count": 12, "ice": 4},
		"stars": [800, 1800, 3200], "region": "point_pleasant",
		"flavor": "Bigfoot sightings near the frozen creek!",
		"obstacles": [
			[2, 2, ObstacleType.ICE, 2], [5, 2, ObstacleType.ICE, 2],
			[2, 5, ObstacleType.ICE, 1], [5, 5, ObstacleType.ICE, 1],
		],
	},
	# L20: Heavy web level — webs everywhere, need strategic adjacent clears.
	20: {
		"moves": 24, "colors": 6, "goal": GoalType.CLEAR_OBSTACLES, "bonus": true,
		"goal_params": {"web": 6},
		"stars": [700, 1600, 2800], "region": "point_pleasant",
		"flavor": "Something has been weaving... everywhere.",
		"obstacles": [
			[1, 2, ObstacleType.WEB, 1], [6, 2, ObstacleType.WEB, 1],
			[2, 4, ObstacleType.WEB, 1], [5, 4, ObstacleType.WEB, 1],
			[1, 6, ObstacleType.WEB, 1], [6, 6, ObstacleType.WEB, 1],
		],
	},
	# L21: Score challenge with 6 colors — no obstacles, pure combo building.
	21: {
		"moves": 20, "colors": 6, "goal": GoalType.SCORE,
		"stars": [900, 2000, 3600], "region": "point_pleasant",
		"flavor": "Red eyes gleam in the darkness. Focus!",
	},
	# L22: Mana charge goal + ice — channeling power under pressure.
	22: {
		"moves": 22, "colors": 5, "goal": GoalType.MIXED, "bonus": true,
		"goal_params": {"charges": 5, "ice": 4},
		"stars": [800, 1800, 3200], "region": "point_pleasant",
		"flavor": "The bridge resonates with cryptid energy.",
		"obstacles": [
			[3, 2, ObstacleType.ICE, 2], [4, 2, ObstacleType.ICE, 2],
			[3, 5, ObstacleType.ICE, 1], [4, 5, ObstacleType.ICE, 1],
		],
	},
	# L23: Breather — collect with generous moves, 5 colors.
	23: {
		"moves": 24, "colors": 5, "goal": GoalType.COLLECT, "bonus": true,
		"goal_params": {"type": 2, "count": 15},
		"stars": [600, 1400, 2400], "region": "point_pleasant",
		"flavor": "A calm stretch of river. Nessie would love this.",
	},
	# L24: Ice + web gauntlet — clearing heavy obstacles.
	24: {
		"moves": 24, "colors": 6, "goal": GoalType.CLEAR_OBSTACLES, "bonus": true,
		"goal_params": {"ice": 6, "web": 4},
		"stars": [900, 2000, 3600], "region": "point_pleasant",
		"flavor": "The old TNT plant hides frozen secrets and tangled webs.",
		"obstacles": [
			[1, 1, ObstacleType.ICE, 2], [6, 1, ObstacleType.ICE, 2],
			[3, 3, ObstacleType.ICE, 1], [4, 3, ObstacleType.ICE, 1],
			[1, 5, ObstacleType.ICE, 2], [6, 5, ObstacleType.ICE, 2],
			[0, 3, ObstacleType.WEB, 1], [7, 3, ObstacleType.WEB, 1],
			[3, 6, ObstacleType.WEB, 1], [4, 6, ObstacleType.WEB, 1],
		],
	},
	# L25: Mini-boss — mixed score + collect + obstacles, pre-placed booster.
	25: {
		"moves": 28, "colors": 6, "goal": GoalType.MIXED, "bonus": true,
		"goal_params": {"score": 1800, "type": 1, "count": 12, "ice": 4},
		"stars": [1000, 2200, 3800], "region": "point_pleasant",
		"flavor": "The Mothman descends. Prove your worth!",
		"obstacles": [
			[2, 2, ObstacleType.ICE, 2], [5, 2, ObstacleType.ICE, 2],
			[2, 5, ObstacleType.ICE, 2], [5, 5, ObstacleType.ICE, 2],
		],
		"pre_boosters": [[3, 0, 3]],  # AREA_BOMB center-top
	},
	# L26: Post-boss breather — easy score, 5 colors.
	26: {
		"moves": 24, "colors": 5, "goal": GoalType.SCORE,
		"stars": [700, 1600, 2800], "region": "point_pleasant",
		"flavor": "The dust settles. Catch your breath, investigator.",
	},
	# L27: Collect Chupacabra + webs — thematic cross-region creature.
	27: {
		"moves": 22, "colors": 6, "goal": GoalType.MIXED, "bonus": true,
		"goal_params": {"type": 3, "count": 14, "web": 4},
		"stars": [900, 2000, 3600], "region": "point_pleasant",
		"flavor": "Chupacabra tracks cross the web-covered trails.",
		"obstacles": [
			[1, 3, ObstacleType.WEB, 1], [6, 3, ObstacleType.WEB, 1],
			[2, 5, ObstacleType.WEB, 1], [5, 5, ObstacleType.WEB, 1],
		],
	},
	# L28: Heavy ice fortress — 2-HP ice wall, demanding clears.
	28: {
		"moves": 22, "colors": 6, "goal": GoalType.CLEAR_OBSTACLES, "bonus": true,
		"goal_params": {"ice": 10},
		"stars": [1000, 2200, 3800], "region": "point_pleasant",
		"flavor": "A wall of ice blocks the passage. Shatter it all!",
		"obstacles": [
			[1, 2, ObstacleType.ICE, 2], [2, 2, ObstacleType.ICE, 2],
			[5, 2, ObstacleType.ICE, 2], [6, 2, ObstacleType.ICE, 2],
			[1, 5, ObstacleType.ICE, 2], [2, 5, ObstacleType.ICE, 2],
			[5, 5, ObstacleType.ICE, 2], [6, 5, ObstacleType.ICE, 2],
			[3, 3, ObstacleType.ICE, 1], [4, 3, ObstacleType.ICE, 1],
		],
	},
	# L29: Mana charge + collect + ice — all mechanics firing, tight moves.
	29: {
		"moves": 20, "colors": 6, "goal": GoalType.MIXED, "bonus": true,
		"goal_params": {"charges": 4, "type": 5, "count": 10, "ice": 4},
		"stars": [1100, 2400, 4000], "region": "point_pleasant",
		"flavor": "The Jersey Devil shrieks. Channel everything you have!",
		"obstacles": [
			[2, 3, ObstacleType.ICE, 2], [5, 3, ObstacleType.ICE, 2],
			[3, 5, ObstacleType.ICE, 1], [4, 5, ObstacleType.ICE, 1],
		],
	},
	# L30: Region 2 boss — massive obstacle field, mixed goals, pre-placed boosters.
	30: {
		"moves": 30, "colors": 6, "goal": GoalType.MIXED, "bonus": true,
		"goal_params": {"score": 2500, "ice": 8, "web": 4},
		"stars": [1400, 3000, 5000], "region": "point_pleasant",
		"flavor": "The Silver Bridge trembles. This is it — the final confrontation!",
		"obstacles": [
			[1, 1, ObstacleType.ICE, 2], [6, 1, ObstacleType.ICE, 2],
			[2, 3, ObstacleType.ICE, 2], [5, 3, ObstacleType.ICE, 2],
			[1, 5, ObstacleType.ICE, 2], [6, 5, ObstacleType.ICE, 2],
			[3, 2, ObstacleType.ICE, 1], [4, 2, ObstacleType.ICE, 1],
			[0, 3, ObstacleType.WEB, 1], [7, 3, ObstacleType.WEB, 1],
			[3, 4, ObstacleType.WEB, 1], [4, 4, ObstacleType.WEB, 1],
		],
		"pre_boosters": [[3, 0, 1], [4, 7, 2]],
	},
}


# === FEATURE TRICKLE SYSTEM v1.0 ===
# One-time discoveries triggered when the player first encounters a mechanic.
# Each discovery shows a themed popup, grants a small reward, and never repeats.
const DISCOVERIES: Dictionary = {
	"cascade_first": {
		"text": "The forest stirs\u2026",
		"reward_type": "fragments",
		"reward_amount": 10,
		"reward_label": "+10 Evidence Fragments!",
	},
	"mana_first": {
		"text": "Your cryptid awakens\u2026",
		"reward_type": "credibility_xp",
		"reward_amount": 15,
		"reward_label": "+15 Credibility XP!",
	},
	"booster_first": {
		"text": "A legendary power has been unleashed!",
		"reward_type": "fragments",
		"reward_amount": 15,
		"reward_label": "+15 Evidence Fragments!",
	},
	"ice_first": {
		"text": "Frozen secrets guard the truth\u2026",
		"reward_type": "fragments",
		"reward_amount": 20,
		"reward_label": "+20 Evidence Fragments!",
	},
	"combo_first": {
		"text": "The forest echoes your skill!",
		"reward_type": "extra_moves",
		"reward_amount": 1,
		"reward_label": "+1 Extra Move!",
	},
	"persistent_booster": {
		"text": "This power lingers\u2026 use it wisely",
		"reward_type": "fragments",
		"reward_amount": 25,
		"reward_label": "+25 Evidence Fragments!",
	},
}


func get_star_rating(score: int) -> int:
	if score >= star_3_score:
		return 3
	elif score >= star_2_score:
		return 2
	elif score >= star_1_score:
		return 1
	return 0


static func get_level(level: int) -> LevelData:
	if LEVEL_CATALOG.has(level):
		return _from_catalog(level, LEVEL_CATALOG[level])
	return create_default(level)


static func _from_catalog(level: int, entry: Dictionary) -> LevelData:
	var data := LevelData.new()
	data.level_number = level
	data.max_moves = entry.get("moves", 20)
	data.num_colors = entry.get("colors", 6)
	data.goal_type = entry.get("goal", GoalType.SCORE)
	data.goal_params = entry.get("goal_params", {})
	data.moves_bonus = entry.get("bonus", false)
	data.region_id = entry.get("region", "pacific_nw")
	data.flavor_text = entry.get("flavor", "")
	data.discovery_id = entry.get("discovery_id", "")

	var stars: Array = entry.get("stars", [500, 1500, 3000])
	data.star_1_score = stars[0]
	data.star_2_score = stars[1]
	data.star_3_score = stars[2]

	# Convert compact obstacle arrays [col, row, type, hp] to dictionaries
	var raw_obs: Array = entry.get("obstacles", [])
	for obs: Array in raw_obs:
		data.obstacles.append({"col": obs[0], "row": obs[1], "type": obs[2], "hp": obs[3]})

	# Convert compact pre-booster arrays [col, row, booster_type]
	var raw_boosters: Array = entry.get("pre_boosters", [])
	for b: Array in raw_boosters:
		data.pre_boosters.append({"col": b[0], "row": b[1], "booster_type": b[2]})

	return data


static func create_default(level: int) -> LevelData:
	var data := LevelData.new()
	data.level_number = level
	data.num_colors = 6

	var region: RegionData = RegionData.get_region_for_level(level)
	if region:
		data.region_id = region.region_id
	else:
		data.region_id = "pacific_nw"

	var pos_in_region: int = ((level - 1) % 15)
	var difficulty: float = _get_difficulty_factor(pos_in_region)

	data.max_moves = roundi(lerpf(25.0, 12.0, difficulty))

	var base_score: float = 400.0 + level * 30.0
	data.star_1_score = roundi(base_score * (0.8 + difficulty * 0.4))
	data.star_2_score = roundi(data.star_1_score * 2.5)
	data.star_3_score = roundi(data.star_1_score * 4.5)

	data.flavor_text = _get_flavor_text(level, pos_in_region)

	return data


static func _get_difficulty_factor(pos: int) -> float:
	match pos:
		0: return 0.0
		1: return 0.15
		2: return 0.3
		3: return 0.45
		4: return 0.55
		5: return 0.7
		6: return 0.85
		7: return 0.6
		8: return 0.75
		9: return 1.0
		10: return 0.2
		11: return 0.35
		12: return 0.5
		13: return 0.65
		14: return 0.9
		_: return 0.5


static func _get_flavor_text(level: int, pos: int) -> String:
	if pos == 0:
		return "A new area to investigate. Tread carefully."
	elif pos == 9:
		return "Something big lurks here. Prepare yourself!"
	elif pos == 10:
		return "A calm clearing. Catch your breath."
	elif pos == 14:
		return "The final challenge of this region awaits."
	elif level == 1:
		return "Your cryptid-hunting journey begins here!"
	return ""
