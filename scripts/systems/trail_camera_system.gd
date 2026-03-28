class_name TrailCameraSystem
extends RefCounted

const BIOMES: Array[String] = [
	"pacific_nw", "point_pleasant", "scotland",
	"puerto_rico", "himalayas", "pine_barrens"
]

const BIOME_NAMES: Dictionary = {
	"pacific_nw": "Pacific Northwest",
	"point_pleasant": "Point Pleasant",
	"scotland": "Scotland",
	"puerto_rico": "Puerto Rico",
	"himalayas": "Himalayas",
	"pine_barrens": "Pine Barrens",
}


static func place_camera(biome: String, hours: int) -> void:
	PlayerData.trail_cameras[biome] = {
		"placed_time": Time.get_unix_time_from_system(),
		"duration_hours": hours,
	}
	EventBus.camera_placed.emit(biome)
	PlayerData.save_data()


static func is_camera_active(biome: String) -> bool:
	return PlayerData.trail_cameras.has(biome)


static func is_camera_ready(biome: String) -> bool:
	if not PlayerData.trail_cameras.has(biome):
		return false
	var cam: Dictionary = PlayerData.trail_cameras[biome]
	var elapsed: float = Time.get_unix_time_from_system() - cam["placed_time"]
	return elapsed >= cam["duration_hours"] * 3600.0


static func get_time_remaining(biome: String) -> float:
	if not PlayerData.trail_cameras.has(biome):
		return 0.0
	var cam: Dictionary = PlayerData.trail_cameras[biome]
	var elapsed: float = Time.get_unix_time_from_system() - cam["placed_time"]
	var total: float = cam["duration_hours"] * 3600.0
	return maxf(total - elapsed, 0.0)


static func collect_camera(biome: String) -> Dictionary:
	## Returns {fragments, coins, free_pull}
	if not is_camera_ready(biome):
		return {}

	var cam: Dictionary = PlayerData.trail_cameras[biome]
	var hours: int = cam["duration_hours"]

	# Base fragments: hours * random 5-12
	var fragments: int = hours * randi_range(5, 12)

	# 20% chance bonus coins
	var coins: int = 0
	if randf() < 0.2:
		coins = randi_range(10, 30)

	# 5% chance free pull
	var free_pull: bool = randf() < 0.05

	# Award rewards
	PlayerData.add_fragments(fragments)
	if coins > 0:
		PlayerData.add_coins(coins)
	if free_pull:
		PlayerData.add_fragments(GachaSystem.SINGLE_COST)  # Give fragments equivalent to 1 pull

	# Remove camera
	PlayerData.trail_cameras.erase(biome)
	EventBus.camera_collected.emit(biome)
	PlayerData.save_data()

	return {"fragments": fragments, "coins": coins, "free_pull": free_pull}
