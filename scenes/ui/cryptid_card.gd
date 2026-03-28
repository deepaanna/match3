extends Control
## Reusable cryptid card component.

@onready var _rarity_border: ColorRect = %RarityBorder
@onready var _collected_group: Control = %CollectedGroup
@onready var _element_circle: ColorRect = %ElementCircle
@onready var _name_label: Label = %NameLabel
@onready var _rarity_label: Label = %RarityLabel
@onready var _ability_label: Label = %AbilityLabel
@onready var _leader_label: Label = %LeaderLabel
@onready var _uncollected_group: Control = %UncollectedGroup
@onready var _mystery_label: Label = %MysteryLabel
@onready var _uncollected_name: Label = %UncollectedName

var _cryptid: CryptidData = null
var _is_collected: bool = false


func setup(cryptid: CryptidData, collected: bool = true) -> void:
	_cryptid = cryptid
	_is_collected = collected

	if not is_node_ready():
		await ready

	_update_card()


func _update_card() -> void:
	if not _cryptid:
		_rarity_border.color = Color(0.3, 0.3, 0.3)
		_collected_group.visible = false
		_uncollected_group.visible = false
		return

	_rarity_border.color = CryptidData.get_rarity_color(_cryptid.rarity)

	if _is_collected:
		_collected_group.visible = true
		_uncollected_group.visible = false

		_element_circle.color = PieceData.get_color(_cryptid.base_cryptid)
		_name_label.text = _cryptid.display_name
		_rarity_label.text = CryptidData.get_rarity_name(_cryptid.rarity)
		_rarity_label.modulate = CryptidData.get_rarity_color(_cryptid.rarity)
		_ability_label.text = CryptidData.get_ability_description(_cryptid.ability_type, _cryptid.ability_power)

		var leader_desc: String = CryptidData.get_leader_description(_cryptid.leader_skill_type, _cryptid.leader_skill_value)
		if leader_desc != "":
			_leader_label.text = "Leader: %s" % leader_desc
			_leader_label.modulate = Color(1.0, 0.85, 0.0)
			_leader_label.add_theme_font_size_override("font_size", 8)
		else:
			_leader_label.text = PieceData.get_piece_name(_cryptid.base_cryptid)
			_leader_label.modulate = Color(0.7, 0.7, 0.7)
			_leader_label.add_theme_font_size_override("font_size", 9)
	else:
		_collected_group.visible = false
		_uncollected_group.visible = true

		_uncollected_name.text = _cryptid.display_name
