extends Control
## Circle button representing a level on the map.

signal level_pressed(level_number: int)

@onready var _level_button: Button = %LevelButton
@onready var _star_label: Label = %StarLabel

var _level: int = 0
var _stars: int = 0
var _unlocked: bool = false


func setup(level: int) -> void:
	_level = level
	_stars = PlayerData.get_level_stars(level)
	_unlocked = PlayerData.is_level_unlocked(level)

	# Configure button for locked / unlocked state
	if _unlocked:
		_level_button.text = str(_level)
		_level_button.add_theme_font_size_override("font_size", 16)
		_level_button.disabled = false
		_level_button.pressed.connect(func() -> void: level_pressed.emit(_level))
	else:
		_level_button.text = "🔒"
		_level_button.add_theme_font_size_override("font_size", 14)
		_level_button.disabled = true

	# Build star text
	var star_text: String = ""
	for i in range(3):
		if i < _stars:
			star_text += "★"
		else:
			star_text += "☆"
	_star_label.text = star_text
	_star_label.modulate = Color(1.0, 0.85, 0.0) if _stars > 0 else Color(0.4, 0.4, 0.4)
