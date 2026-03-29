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
