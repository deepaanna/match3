class_name LevelData
extends Resource

@export var level_number: int = 1
@export var max_moves: int = 20
@export var star_1_score: int = 500
@export var star_2_score: int = 1500
@export var star_3_score: int = 3000
@export var region_id: String = ""
@export var flavor_text: String = ""


func get_star_rating(score: int) -> int:
	if score >= star_3_score:
		return 3
	elif score >= star_2_score:
		return 2
	elif score >= star_1_score:
		return 1
	return 0


static func create_default(level: int) -> LevelData:
	var data := LevelData.new()
	data.level_number = level

	# Determine region
	var region: RegionData = RegionData.get_region_for_level(level)
	if region:
		data.region_id = region.region_id
	else:
		data.region_id = "pacific_nw"

	# Sawtooth difficulty within each 15-level region
	var pos_in_region: int = ((level - 1) % 15)  # 0-14
	var difficulty: float = _get_difficulty_factor(pos_in_region)

	# Moves: 25 (easiest) to 12 (hardest)
	data.max_moves = roundi(lerpf(25.0, 12.0, difficulty))

	# Star thresholds scale with difficulty and level
	var base_score: float = 400.0 + level * 30.0
	data.star_1_score = roundi(base_score * (0.8 + difficulty * 0.4))
	data.star_2_score = roundi(data.star_1_score * 2.5)
	data.star_3_score = roundi(data.star_1_score * 4.5)

	# Flavor text
	data.flavor_text = _get_flavor_text(level, pos_in_region)

	return data


static func _get_difficulty_factor(pos: int) -> float:
	## Sawtooth: easy→medium→hard→boss→relief→ramp within 15 levels
	## Returns 0.0 (easiest) to 1.0 (hardest)
	match pos:
		0: return 0.0    # easy intro
		1: return 0.15
		2: return 0.3
		3: return 0.45   # medium
		4: return 0.55
		5: return 0.7    # hard
		6: return 0.85
		7: return 0.6    # slight relief
		8: return 0.75
		9: return 1.0    # boss
		10: return 0.2   # relief
		11: return 0.35
		12: return 0.5   # ramp back up
		13: return 0.65
		14: return 0.9   # near-boss finale
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
