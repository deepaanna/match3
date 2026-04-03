extends Node

const SFX_PATH: String = "res://assets/audio/sfx/"
const MUSIC_PATH: String = "res://assets/audio/music/"
const MAX_SFX_PLAYERS: int = 8

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer = null
var _sfx_cache: Dictionary = {}
var _current_music_name: String = ""


func _ready() -> void:
	# Create SFX players
	for i in range(MAX_SFX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)

	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)

	# Connect EventBus signals
	EventBus.play_sfx.connect(_on_play_sfx)
	EventBus.play_music.connect(_on_play_music)
	EventBus.stop_music.connect(_on_stop_music)

	# Auto-trigger sounds from game events
	EventBus.swap_completed.connect(func() -> void: _on_play_sfx("swap"))
	EventBus.swap_failed.connect(func() -> void: _on_play_sfx("swap_fail"))
	EventBus.matches_cleared.connect(func(_c: int, _l: int) -> void: _on_play_sfx("match"))
	EventBus.piece_selected.connect(func(_c: int, _r: int) -> void: _on_play_sfx("select"))

	# New system audio triggers
	EventBus.ability_activated.connect(func(_id: String) -> void: _on_play_sfx("ability_activate"))
	EventBus.mana_full.connect(func(_id: String) -> void: _on_play_sfx("mana_full"))
	EventBus.investigation_result.connect(func(_id: String, _r: int) -> void: _on_play_sfx("gacha_reveal"))
	EventBus.camera_collected.connect(func(_b: String) -> void: _on_play_sfx("camera_collect"))


func _on_play_sfx(sfx_name: String) -> void:
	var stream: AudioStream = _load_sfx(sfx_name)
	if stream == null:
		return

	# Find an available player
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return

	# All players busy - override the first one
	_sfx_players[0].stream = stream
	_sfx_players[0].play()


func _on_play_music(music_name: String) -> void:
	if music_name == _current_music_name and _music_player.playing:
		return  # Already playing this track
	var path: String = MUSIC_PATH + music_name + ".ogg"
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		_music_player.stream = stream
		_music_player.play()
		_current_music_name = music_name


func _on_stop_music() -> void:
	_music_player.stop()
	_current_music_name = ""


func _load_sfx(sfx_name: String) -> AudioStream:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]

	# Try .ogg then .wav
	for ext in ["ogg", "wav"]:
		var path: String = SFX_PATH + sfx_name + "." + ext
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			_sfx_cache[sfx_name] = stream
			return stream

	return null
