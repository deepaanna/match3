extends Control
## Grid of collected cryptids for team assignment.

signal cryptid_selected(cryptid_id: String)

@onready var _filter_row: HBoxContainer = %FilterRow
@onready var _all_button: Button = %AllButton
@onready var _grid_container: GridContainer = %GridContainer
@onready var _cancel_button: Button = %CancelButton

var _filter_element: int = -1


func _ready() -> void:
	_all_button.pressed.connect(func() -> void: _filter_element = -1; _refresh())

	for pt: int in range(PieceData.PIECE_COUNT):
		var btn := Button.new()
		btn.text = PieceData.get_piece_name(pt)
		btn.custom_minimum_size = Vector2(55, 26)
		btn.add_theme_font_size_override("font_size", 10)
		var captured_pt: int = pt
		btn.pressed.connect(func() -> void: _filter_element = captured_pt; _refresh())
		_filter_row.add_child(btn)

	_cancel_button.pressed.connect(func() -> void: queue_free())

	_refresh()


func _refresh() -> void:
	for child in _grid_container.get_children():
		child.queue_free()

	var count: int = 0
	for cid: String in PlayerData.collected_cryptids:
		var cryptid: CryptidData = CryptidDatabase.get_cryptid(cid)
		if not cryptid:
			continue
		if _filter_element >= 0 and cryptid.base_cryptid != _filter_element:
			continue

		count += 1
		var btn := Button.new()
		btn.text = cryptid.display_name + "\n" + CryptidData.get_rarity_name(cryptid.rarity) + "\n" + CryptidData.get_ability_name(cryptid.ability_type)
		btn.custom_minimum_size = Vector2(155, 100)
		btn.add_theme_font_size_override("font_size", 11)
		var captured_cid: String = cid
		btn.pressed.connect(func() -> void:
			cryptid_selected.emit(captured_cid)
			queue_free()
		)
		_grid_container.add_child(btn)

	if count == 0:
		var empty_label := Label.new()
		empty_label.text = "No cryptids found.\nInvestigate sightings to discover more!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.modulate = Color(0.6, 0.6, 0.6)
		_grid_container.add_child(empty_label)
