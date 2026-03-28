extends Control
## Trail camera placement and collection screen.

const BIOME_SLOT_SCENE: PackedScene = preload("res://scenes/ui/biome_slot.tscn")

@onready var _biome_grid: GridContainer = %BiomeGrid
@onready var _back_button: Button = %BackButton

var _slots: Array[Control] = []


func _ready() -> void:
	for biome: String in TrailCameraSystem.BIOMES:
		var slot: Control = BIOME_SLOT_SCENE.instantiate()
		_biome_grid.add_child(slot)
		slot.setup(biome)
		_slots.append(slot)

	_back_button.pressed.connect(_on_back)


func _process(_delta: float) -> void:
	for slot in _slots:
		slot.update_timer()


func _on_back() -> void:
	SceneManager.change_scene("res://scenes/home_screen.tscn")
