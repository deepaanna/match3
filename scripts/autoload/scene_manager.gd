extends Node

var _overlay: ColorRect = null
var _canvas_layer: CanvasLayer = null
var _is_transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100
	add_child(_canvas_layer)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_overlay)


func change_scene(scene_path: String, duration: float = 0.4) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Start background loading
	ResourceLoader.load_threaded_request(scene_path)

	# Fade to black
	var fade_out: Tween = create_tween()
	fade_out.tween_property(_overlay, "color:a", 1.0, duration / 2.0)
	await fade_out.finished

	# Wait for resource to be loaded
	while ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if packed_scene:
		get_tree().change_scene_to_packed(packed_scene)
	else:
		push_error("Failed to load scene: " + scene_path)

	# Wait a frame for scene to initialize
	await get_tree().process_frame

	# Fade from black
	var fade_in: Tween = create_tween()
	fade_in.tween_property(_overlay, "color:a", 0.0, duration / 2.0)
	await fade_in.finished

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false


func change_scene_instant(scene_path: String) -> void:
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene:
		get_tree().change_scene_to_packed(packed_scene)
