extends Control
## Gacha pull UI — "Investigate Sighting"

const CRYPTID_CARD_SCENE: PackedScene = preload("res://scenes/ui/cryptid_card.tscn")

@onready var _fragment_label: Label = %FragmentLabel
@onready var _pity_label: Label = %PityLabel
@onready var _reveal_container: Control = %RevealContainer
@onready var _single_pull_button: Button = %SinglePullButton
@onready var _multi_pull_button: Button = %MultiPullButton
@onready var _back_button: Button = %BackButton

var _results: Array[CryptidData] = []
var _result_index: int = 0


func _ready() -> void:
	_fragment_label.text = "Fragments: %d" % PlayerData.evidence_fragments
	_update_pity_label()

	_single_pull_button.pressed.connect(_on_single_pull)
	_multi_pull_button.pressed.connect(_on_multi_pull)
	_back_button.pressed.connect(_on_back)

	EventBus.fragments_changed.connect(_on_fragments_changed)


func _on_single_pull() -> void:
	var result: CryptidData = GachaSystem.pull_single()
	if result:
		_results = [result]
		_result_index = 0
		_show_reveal(result)
		_update_pity_label()


func _on_multi_pull() -> void:
	var results: Array[CryptidData] = GachaSystem.pull_multi()
	if not results.is_empty():
		_results = results
		_result_index = 0
		_show_reveal(results[0])
		_update_pity_label()


func _show_reveal(cryptid: CryptidData) -> void:
	# Clear previous reveal
	for child in _reveal_container.get_children():
		child.queue_free()

	# Rarity glow background
	var glow := ColorRect.new()
	glow.size = Vector2(200, 250)
	glow.color = CryptidData.get_rarity_color(cryptid.rarity) * Color(1, 1, 1, 0.2)
	_reveal_container.add_child(glow)

	# Card
	var card: Control = CRYPTID_CARD_SCENE.instantiate()
	card.position = Vector2(40, 20)
	_reveal_container.add_child(card)
	card.setup(cryptid, true)

	# New/Dupe indicator
	var is_new: bool = PlayerData.collected_cryptids.get(cryptid.cryptid_id, {}).get("duplicates", 0) == 0
	var status_label := Label.new()
	status_label.text = "NEW!" if is_new else "DUPLICATE (+Research Data)"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(0, 200)
	status_label.size = Vector2(200, 30)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.modulate = Color(1.0, 0.9, 0.2) if is_new else Color(0.7, 0.7, 0.7)
	_reveal_container.add_child(status_label)

	# If multi pull, show progress
	if _results.size() > 1:
		var progress_label := Label.new()
		progress_label.text = "%d / %d" % [_result_index + 1, _results.size()]
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress_label.position = Vector2(0, 230)
		progress_label.size = Vector2(200, 20)
		progress_label.add_theme_font_size_override("font_size", 12)
		_reveal_container.add_child(progress_label)

		# Next button
		if _result_index < _results.size() - 1:
			var next_btn := Button.new()
			next_btn.text = "Next"
			next_btn.position = Vector2(50, 255)
			next_btn.custom_minimum_size = Vector2(100, 35)
			next_btn.pressed.connect(_on_next_result)
			_reveal_container.add_child(next_btn)

	# Animate reveal
	glow.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(glow, "modulate:a", 1.0, 0.5)


func _on_next_result() -> void:
	_result_index += 1
	if _result_index < _results.size():
		_show_reveal(_results[_result_index])


func _update_pity_label() -> void:
	_pity_label.text = "Rare pity: %d/%d | Epic pity: %d/%d" % [
		PlayerData.pity_rare, GachaSystem.PITY_RARE,
		PlayerData.pity_epic, GachaSystem.PITY_EPIC
	]


func _on_fragments_changed(_amount: int) -> void:
	_fragment_label.text = "Fragments: %d" % PlayerData.evidence_fragments


func _on_back() -> void:
	SceneManager.change_scene("res://scenes/home_screen.tscn")
