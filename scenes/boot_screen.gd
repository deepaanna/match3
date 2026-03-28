extends Control

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var status_label: Label = $VBoxContainer/StatusLabel

const MESSAGES: Array[String] = [
	"Tracking Bigfoot prints...",
	"Scanning for Mothman sightings...",
	"Diving into Loch Ness...",
	"Setting Chupacabra traps...",
	"Mapping Yeti territory...",
	"Investigating Jersey Devil...",
	"Preparing field equipment...",
	"Almost ready...",
]

const SCENES_TO_PRELOAD: Array[String] = [
	"res://scenes/home_screen.tscn",
	"res://scenes/game_screen.tscn",
	"res://scenes/result_screen.tscn",
	"res://scenes/map_screen.tscn",
	"res://scenes/field_guide_screen.tscn",
	"res://scenes/investigation_screen.tscn",
	"res://scenes/trail_camera_screen.tscn",
]

var _progress: float = 0.0
var _message_index: int = 0
var _message_timer: float = 0.0
const MESSAGE_INTERVAL: float = 0.4
const LOAD_SPEED: float = 0.6


func _ready() -> void:
	progress_bar.value = 0.0
	status_label.text = MESSAGES[0]

	# Start preloading scenes
	for scene_path in SCENES_TO_PRELOAD:
		ResourceLoader.load_threaded_request(scene_path)


func _process(delta: float) -> void:
	_progress = minf(_progress + delta * LOAD_SPEED, 1.0)
	progress_bar.value = _progress * 100.0

	_message_timer += delta
	if _message_timer >= MESSAGE_INTERVAL:
		_message_timer = 0.0
		_message_index = mini(_message_index + 1, MESSAGES.size() - 1)
		status_label.text = MESSAGES[_message_index]

	if _progress >= 1.0:
		set_process(false)
		SceneManager.change_scene("res://scenes/home_screen.tscn")
