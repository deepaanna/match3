extends Control
## World map with regions, level nodes, credibility rank, and nav buttons.

const PRE_LEVEL_SCENE: PackedScene = preload("res://scenes/ui/pre_level_popup.tscn")
const LEVEL_NODE_SCENE: PackedScene = preload("res://scenes/ui/level_node.tscn")

@onready var _rank_label: Label = %RankLabel
@onready var _star_label: Label = %StarLabel
@onready var _tab_row: HBoxContainer = %TabRow
@onready var _level_container: Control = %LevelContainer
@onready var _home_button: Button = %HomeButton
@onready var _field_guide_button: Button = %FieldGuideButton
@onready var _investigate_button: Button = %InvestigateButton
@onready var _cameras_button: Button = %CamerasButton

var _pre_level_popup: Control = null
var _current_region_idx: int = 0
var _regions: Array[RegionData] = []


func _ready() -> void:
	_regions = RegionData.get_all_regions()
	# Start at the region containing the player's next level
	for i in range(_regions.size()):
		if PlayerData.highest_level_completed < _regions[i].level_end:
			_current_region_idx = i
			break

	_rank_label.text = CredibilityData.get_rank_name(PlayerData.credibility_xp)
	_star_label.text = "★ %d" % PlayerData.total_stars

	_build_region_tabs()
	_refresh_levels()

	# Nav bar connections
	_home_button.pressed.connect(func() -> void: SceneManager.change_scene("res://scenes/home_screen.tscn"))
	_field_guide_button.pressed.connect(func() -> void: SceneManager.change_scene("res://scenes/field_guide_screen.tscn"))
	_investigate_button.pressed.connect(func() -> void: SceneManager.change_scene("res://scenes/investigation_screen.tscn"))
	_cameras_button.pressed.connect(func() -> void: SceneManager.change_scene("res://scenes/trail_camera_screen.tscn"))


func _build_region_tabs() -> void:
	for i in range(_regions.size()):
		var region: RegionData = _regions[i]
		var btn := Button.new()
		var is_unlocked: bool = PlayerData.is_region_unlocked(region)
		if is_unlocked:
			btn.text = region.display_name.substr(0, 6)
		else:
			btn.text = "🔒 %d★" % region.unlock_star_requirement
		btn.custom_minimum_size = Vector2(82, 35)
		btn.add_theme_font_size_override("font_size", 10)
		btn.disabled = not is_unlocked
		var idx: int = i
		btn.pressed.connect(func() -> void: _current_region_idx = idx; _refresh_levels())
		_tab_row.add_child(btn)


func _refresh_levels() -> void:
	for child in _level_container.get_children():
		child.queue_free()

	var region: RegionData = _regions[_current_region_idx]

	# Region title
	var title := Label.new()
	title.text = region.display_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 5)
	title.size = Vector2(540, 30)
	title.add_theme_font_size_override("font_size", 22)
	_level_container.add_child(title)

	# Grid of level nodes (5 columns x 3 rows = 15 levels)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(50, 45)
	grid.size = Vector2(440, 500)
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 20)
	_level_container.add_child(grid)

	for level in range(region.level_start, region.level_end + 1):
		var node: Control = LEVEL_NODE_SCENE.instantiate()
		grid.add_child(node)
		node.setup(level)
		node.level_pressed.connect(_on_level_pressed)


func _on_level_pressed(level_number: int) -> void:
	if _pre_level_popup:
		return
	_pre_level_popup = PRE_LEVEL_SCENE.instantiate()
	_pre_level_popup.setup(level_number)
	_pre_level_popup.start_expedition.connect(_on_start_expedition)
	_pre_level_popup.popup_closed.connect(_on_popup_closed)
	add_child(_pre_level_popup)


func _on_start_expedition(level_number: int) -> void:
	_remove_popup()
	EventBus.level_selected.emit(level_number)


func _on_popup_closed() -> void:
	_remove_popup()


func _remove_popup() -> void:
	if _pre_level_popup:
		_pre_level_popup.queue_free()
		_pre_level_popup = null
