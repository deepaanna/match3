class_name RegionData
extends Resource

@export var region_id: String = ""
@export var display_name: String = ""
@export var level_start: int = 1
@export var level_end: int = 15
@export var unlock_star_requirement: int = 0


static func get_all_regions() -> Array[RegionData]:
	var regions: Array[RegionData] = []

	var r1 := RegionData.new()
	r1.region_id = "pacific_nw"
	r1.display_name = "Pacific Northwest"
	r1.level_start = 1
	r1.level_end = 15
	r1.unlock_star_requirement = 0
	regions.append(r1)

	var r2 := RegionData.new()
	r2.region_id = "point_pleasant"
	r2.display_name = "Point Pleasant"
	r2.level_start = 16
	r2.level_end = 30
	r2.unlock_star_requirement = 15
	regions.append(r2)

	var r3 := RegionData.new()
	r3.region_id = "scotland"
	r3.display_name = "Scotland"
	r3.level_start = 31
	r3.level_end = 45
	r3.unlock_star_requirement = 35
	regions.append(r3)

	var r4 := RegionData.new()
	r4.region_id = "puerto_rico"
	r4.display_name = "Puerto Rico"
	r4.level_start = 46
	r4.level_end = 60
	r4.unlock_star_requirement = 60
	regions.append(r4)

	var r5 := RegionData.new()
	r5.region_id = "himalayas"
	r5.display_name = "Himalayas"
	r5.level_start = 61
	r5.level_end = 75
	r5.unlock_star_requirement = 90
	regions.append(r5)

	var r6 := RegionData.new()
	r6.region_id = "pine_barrens"
	r6.display_name = "Pine Barrens"
	r6.level_start = 76
	r6.level_end = 90
	r6.unlock_star_requirement = 125
	regions.append(r6)

	return regions


static func get_region_for_level(level: int) -> RegionData:
	for region in get_all_regions():
		if level >= region.level_start and level <= region.level_end:
			return region
	return null


static func get_region_by_id(id: String) -> RegionData:
	for region in get_all_regions():
		if region.region_id == id:
			return region
	return null
