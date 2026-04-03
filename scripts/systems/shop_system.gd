extends Node
# MINIMAL MONETIZATION v1.0
## Manages energy packs, rewarded ad fulfillment, and shop navigation.
## All purchases are placeholders — swap prints for real IAP SDK later.

const ENERGY_PACKS: Array[Dictionary] = [
	{"name": "Energy Surge", "price": "$1.99", "energy": 25, "fragments": 50, "id": "energy_surge"},
	{"name": "Cryptid Awakening", "price": "$4.99", "energy": 80, "fragments": 150, "id": "cryptid_awakening"},
	{"name": "Expedition Pack", "price": "$9.99", "energy": 200, "fragments": 400, "id": "expedition_pack"},
]


func _ready() -> void:
	EventBus.energy_refill_requested.connect(_on_energy_refill_requested)
	EventBus.rewarded_ad_requested.connect(_on_rewarded_ad_requested)


func open_shop() -> void:
	EventBus.shop_opened.emit()
	EventBus.analytics_event.emit("shop_opened", {})
	SceneManager.change_scene("res://scenes/ui/shop_screen.tscn")


func purchase_pack(pack_index: int) -> void:
	if pack_index < 0 or pack_index >= ENERGY_PACKS.size():
		return
	var pack: Dictionary = ENERGY_PACKS[pack_index]
	# Placeholder: real IAP validation would happen here
	print("[ShopSystem] PURCHASED: %s (%s)" % [pack["name"], pack["price"]])
	PlayerData.add_purchased_energy(pack["energy"])
	PlayerData.add_fragments(pack["fragments"])
	EventBus.iap_purchased.emit(pack["id"])
	EventBus.analytics_event.emit("shop_purchase", {"pack": pack["name"], "price": pack["price"]})


func _on_energy_refill_requested() -> void:
	open_shop()


func _on_rewarded_ad_requested(reward_type: String) -> void:
	match reward_type:
		"extra_moves":
			AdPlacement.show_rewarded("extra_moves", func() -> void:
				GameManager.grant_extra_moves(3)
				EventBus.analytics_event.emit("rewarded_ad_completed", {"type": "extra_moves"})
			)
		"double_fragments":
			# Handled inline by result_screen.gd (uses AdPlacement directly)
			pass
		"free_energy":
			AdPlacement.show_rewarded("free_energy", func() -> void:
				PlayerData.add_energy(1)
				EventBus.analytics_event.emit("rewarded_ad_completed", {"type": "free_energy"})
			)
