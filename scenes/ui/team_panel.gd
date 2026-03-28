extends Control
## Shows 3 cryptid portraits with mana bars at the bottom of the game screen.

signal cryptid_tapped(cryptid_id: String)

@onready var _portrait_0: Button = $Portrait0
@onready var _portrait_1: Button = $Portrait1
@onready var _portrait_2: Button = $Portrait2

var _mana_system: Node = null
var _portraits: Array = []  # Array of team_portrait nodes


func setup(mana_system: Node) -> void:
	_mana_system = mana_system
	_portraits = [_portrait_0, _portrait_1, _portrait_2]

	var team: Array[CryptidData] = PlayerData.get_team_cryptids()
	for i in range(mini(team.size(), _portraits.size())):
		_portraits[i].setup(team[i])
		_portraits[i].portrait_pressed.connect(_on_portrait_pressed)
		_portraits[i].visible = true

	# Hide unused portraits
	for i in range(team.size(), _portraits.size()):
		_portraits[i].visible = false

	EventBus.mana_charged.connect(_on_mana_charged)


func _on_portrait_pressed(cid: String) -> void:
	if _mana_system and _mana_system.is_mana_full(cid):
		cryptid_tapped.emit(cid)
	else:
		for portrait in _portraits:
			if portrait.get_cryptid_id() == cid:
				portrait.shake_not_ready()
				break


func _on_mana_charged(piece_type: int, _amount: int) -> void:
	for portrait in _portraits:
		if portrait.get_element() == piece_type:
			portrait.pulse_circle()


func _process(_delta: float) -> void:
	if not _mana_system:
		return
	for portrait in _portraits:
		if not portrait.visible:
			continue
		var cid: String = portrait.get_cryptid_id()
		var fraction: float = _mana_system.get_mana_fraction(cid)
		var is_full: bool = _mana_system.is_mana_full(cid)
		portrait.update_mana(fraction, is_full)
