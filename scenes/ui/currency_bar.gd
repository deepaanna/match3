extends HBoxContainer
## Horizontal bar showing all 3 currencies.

@onready var _fragments_label: Label = %FragmentsLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _research_label: Label = %ResearchLabel


func _ready() -> void:
	_fragments_label.text = "Fragments: %d" % PlayerData.evidence_fragments
	_coins_label.text = "Coins: %d" % PlayerData.cryptid_coins
	_research_label.text = "Research: %d" % PlayerData.research_data

	EventBus.fragments_changed.connect(func(v: int) -> void: _fragments_label.text = "Fragments: %d" % v)
	EventBus.coins_changed.connect(func(v: int) -> void: _coins_label.text = "Coins: %d" % v)
	EventBus.research_data_changed.connect(func(v: int) -> void: _research_label.text = "Research: %d" % v)
