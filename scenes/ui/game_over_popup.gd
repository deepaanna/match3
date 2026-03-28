extends Control
## Failure popup shown when out of moves.

signal continue_coins()
signal continue_ad()
signal give_up()

@onready var _continue_button: Button = %ContinueButton
@onready var _ad_button: Button = %AdButton
@onready var _give_up_button: Button = %GiveUpButton


func _ready() -> void:
	_continue_button.pressed.connect(func() -> void: continue_coins.emit())
	_ad_button.pressed.connect(func() -> void: continue_ad.emit())
	_give_up_button.pressed.connect(func() -> void: give_up.emit())
