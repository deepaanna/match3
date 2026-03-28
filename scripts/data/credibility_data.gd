class_name CredibilityData
extends RefCounted

const RANKS: Array[Dictionary] = [
	{"name": "Curious Tourist", "xp_required": 0},
	{"name": "Amateur Investigator", "xp_required": 100},
	{"name": "Field Researcher", "xp_required": 350},
	{"name": "Seasoned Tracker", "xp_required": 750},
	{"name": "Expert Cryptozoologist", "xp_required": 1500},
	{"name": "Master Investigator", "xp_required": 3000},
	{"name": "Renowned Authority", "xp_required": 5500},
	{"name": "Legendary Tracker", "xp_required": 10000},
]


static func get_rank_index(xp: int) -> int:
	var rank_idx: int = 0
	for i in range(RANKS.size()):
		if xp >= RANKS[i]["xp_required"]:
			rank_idx = i
	return rank_idx


static func get_rank_name(xp: int) -> String:
	return RANKS[get_rank_index(xp)]["name"]


static func get_next_rank_xp(xp: int) -> int:
	var idx: int = get_rank_index(xp)
	if idx < RANKS.size() - 1:
		return RANKS[idx + 1]["xp_required"]
	return RANKS[idx]["xp_required"]


static func get_current_rank_xp(xp: int) -> int:
	return RANKS[get_rank_index(xp)]["xp_required"]


static func get_rank_progress(xp: int) -> float:
	var current: int = get_current_rank_xp(xp)
	var next: int = get_next_rank_xp(xp)
	if next == current:
		return 1.0
	return float(xp - current) / float(next - current)
