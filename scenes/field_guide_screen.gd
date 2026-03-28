extends Control
## Collection viewer — field guide / cork board of cryptids.

const CRYPTID_CARD_SCENE: PackedScene = preload("res://scenes/ui/cryptid_card.tscn")

@onready var _progress_label: Label = %ProgressLabel
@onready var _filter_row: HBoxContainer = %FilterRow
@onready var _all_button: Button = %AllButton
@onready var _card_grid: GridContainer = %CardGrid
@onready var _back_button: Button = %BackButton

var _filter_element: int = -1  # -1 = all
var _filter_rarity: int = -1  # -1 = all


func _ready() -> void:
	_all_button.pressed.connect(func() -> void: _filter_element = -1; _refresh_grid())

	for pt: int in range(PieceData.PIECE_COUNT):
		var btn := Button.new()
		btn.text = PieceData.get_piece_name(pt)
		btn.custom_minimum_size = Vector2(60, 28)
		btn.add_theme_font_size_override("font_size", 10)
		var captured_pt: int = pt
		btn.pressed.connect(func() -> void: _filter_element = captured_pt; _refresh_grid())
		_filter_row.add_child(btn)

	_back_button.pressed.connect(_on_back)
	_refresh_grid()


func _refresh_grid() -> void:
	for child in _card_grid.get_children():
		child.queue_free()

	var all_cryptids: Array[CryptidData] = CryptidDatabase.get_all()
	var collected_count: int = 0
	var shown_count: int = 0

	for cryptid in all_cryptids:
		var is_collected: bool = PlayerData.has_cryptid(cryptid.cryptid_id)
		if is_collected:
			collected_count += 1

		# Apply filter
		if _filter_element >= 0 and cryptid.base_cryptid != _filter_element:
			continue
		if _filter_rarity >= 0 and cryptid.rarity != _filter_rarity:
			continue

		shown_count += 1
		var card: Control = CRYPTID_CARD_SCENE.instantiate()
		_card_grid.add_child(card)
		card.setup(cryptid, is_collected)

	var total: int = all_cryptids.size()
	_progress_label.text = "%d / %d Documented" % [collected_count, total]


func _on_back() -> void:
	SceneManager.change_scene("res://scenes/home_screen.tscn")
