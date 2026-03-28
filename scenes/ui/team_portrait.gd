extends Button
## Single cryptid portrait with mana bar for the team panel.

signal portrait_pressed(cryptid_id: String)

@onready var _element_circle: ColorRect = $ElementCircle
@onready var _name_label: Label = $NameLabel
@onready var _match_hint: Label = $MatchHint
@onready var _ability_label: Label = $AbilityLabel
@onready var _mana_bar: ProgressBar = $ManaBar
@onready var _mana_text: Label = $ManaText
@onready var _ready_label: Label = $ReadyLabel
@onready var _not_ready_label: Label = $NotReadyLabel

var _cryptid_id: String = ""
var _element: int = -1
var _mana_cost: int = 0


func setup(cryptid: CryptidData) -> void:
	_cryptid_id = cryptid.cryptid_id
	_element = cryptid.base_cryptid
	_mana_cost = cryptid.mana_cost

	_element_circle.color = PieceData.get_color(cryptid.base_cryptid)
	_name_label.text = cryptid.variant_name
	_match_hint.text = "Match %s" % PieceData.get_piece_name(cryptid.base_cryptid)
	_match_hint.modulate = PieceData.get_color(cryptid.base_cryptid)
	_ability_label.text = CryptidData.get_ability_description(cryptid.ability_type, cryptid.ability_power)
	_mana_text.text = "0/%d" % cryptid.mana_cost

	pressed.connect(func() -> void: portrait_pressed.emit(_cryptid_id))


func get_cryptid_id() -> String:
	return _cryptid_id


func get_element() -> int:
	return _element


func update_mana(fraction: float, is_full: bool) -> void:
	_mana_bar.value = fraction
	var current: int = roundi(fraction * _mana_cost)
	_mana_text.text = "%d/%d" % [current, _mana_cost]
	_ready_label.visible = is_full


func pulse_circle() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_element_circle, "scale", Vector2(1.1, 1.1), 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_element_circle, "scale", Vector2.ONE, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func shake_not_ready() -> void:
	var shake_tween: Tween = create_tween()
	var orig_x: float = position.x
	shake_tween.tween_property(self, "position:x", orig_x - 5.0, 0.04)
	shake_tween.tween_property(self, "position:x", orig_x + 5.0, 0.04)
	shake_tween.tween_property(self, "position:x", orig_x - 3.0, 0.04)
	shake_tween.tween_property(self, "position:x", orig_x, 0.04)
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(_not_ready_label, "modulate:a", 1.0, 0.1)
	flash_tween.tween_interval(0.8)
	flash_tween.tween_property(_not_ready_label, "modulate:a", 0.0, 0.3)
