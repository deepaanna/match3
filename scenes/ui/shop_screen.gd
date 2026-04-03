extends Control
# MINIMAL MONETIZATION v1.0
## Field Shop: energy packs, free energy ad, and starter pack reference.
## Built programmatically — all themed to the cryptid investigation aesthetic.

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.05, 0.1, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Top bar
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 10.0
	top.offset_bottom = 55.0
	top.offset_left = 10.0
	top.offset_right = -10.0
	top.add_theme_constant_override("separation", 10)
	add_child(top)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(80, 40)
	back_btn.pressed.connect(func() -> void:
		SceneManager.change_scene("res://scenes/home_screen.tscn")
	)
	top.add_child(back_btn)

	var title := Label.new()
	title.text = "FIELD SHOP"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.9))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(title)

	# Energy display
	var energy_label := Label.new()
	energy_label.text = "Energy: %d" % PlayerData.energy
	energy_label.name = "EnergyLabel"
	energy_label.add_theme_font_size_override("font_size", 14)
	energy_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	energy_label.offset_top = 58.0
	energy_label.offset_bottom = 78.0
	add_child(energy_label)

	# Scroll container for packs
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 85.0
	scroll.offset_bottom = -10.0
	scroll.offset_left = 20.0
	scroll.offset_right = -20.0
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	# Section: Free energy
	_add_section_header(vbox, "Free Resupply")
	_add_free_energy_card(vbox)

	# Section: Energy packs
	_add_section_header(vbox, "Expedition Supplies")
	for i in range(ShopSystem.ENERGY_PACKS.size()):
		_add_pack_card(vbox, i)

	# Section: Starter pack (if not purchased)
	if not PlayerData.starter_pack_purchased:
		_add_section_header(vbox, "Researcher's Kit")
		_add_starter_pack_card(vbox)

	# Listen for energy changes to update display
	EventBus.energy_changed.connect(func(new_energy: int) -> void:
		var lbl: Label = get_node_or_null("EnergyLabel")
		if lbl:
			lbl.text = "Energy: %d" % new_energy
	)


func _add_section_header(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3))
	parent.add_child(label)


func _add_free_energy_card(parent: Control) -> void:
	var card := _make_card(Color(0.1, 0.15, 0.12, 0.9))
	parent.add_child(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = "Watch Ad for Energy"
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.85))
	info.add_child(name_label)

	var desc := Label.new()
	desc.text = "Quick field resupply — +1 Energy"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.5, 0.6, 0.55))
	info.add_child(desc)

	var btn := Button.new()
	btn.text = "Watch"
	btn.custom_minimum_size = Vector2(80, 40)
	btn.pressed.connect(func() -> void:
		EventBus.rewarded_ad_requested.emit("free_energy")
	)
	hbox.add_child(btn)


func _add_pack_card(parent: Control, index: int) -> void:
	var pack: Dictionary = ShopSystem.ENERGY_PACKS[index]
	var card := _make_card(Color(0.08, 0.1, 0.14, 0.9))
	parent.add_child(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = pack["name"]
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	info.add_child(name_label)

	var desc := Label.new()
	desc.text = "+%d Energy, +%d Fragments" % [pack["energy"], pack["fragments"]]
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	info.add_child(desc)

	var btn := Button.new()
	btn.text = pack["price"]
	btn.custom_minimum_size = Vector2(80, 40)
	btn.add_theme_font_size_override("font_size", 14)
	var idx: int = index
	btn.pressed.connect(func() -> void:
		ShopSystem.purchase_pack(idx)
	)
	hbox.add_child(btn)


func _add_starter_pack_card(parent: Control) -> void:
	var card := _make_card(Color(0.14, 0.1, 0.06, 0.9))
	parent.add_child(card)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = "Researcher's Kit"
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	info.add_child(name_label)

	var desc := Label.new()
	desc.text = "500 Coins + 3 Rare Cryptids + Full Energy"
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.6, 0.55, 0.35))
	info.add_child(desc)

	var btn := Button.new()
	btn.text = "$4.99"
	btn.custom_minimum_size = Vector2(80, 40)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(func() -> void:
		# Reuse existing starter pack logic
		print("[ShopSystem] PURCHASED: Researcher's Kit ($4.99)")
		PlayerData.add_coins(500)
		for _i in range(3):
			var pool: Array[CryptidData] = CryptidDatabase.get_by_rarity(CryptidData.Rarity.RARE)
			if not pool.is_empty():
				var cryptid: CryptidData = pool[randi() % pool.size()]
				PlayerData.add_cryptid(cryptid.cryptid_id)
		PlayerData.refill_energy()
		PlayerData.starter_pack_purchased = true
		PlayerData.save_data()
		EventBus.iap_purchased.emit("starter_pack")
		EventBus.analytics_event.emit("shop_purchase", {"pack": "starter_pack", "price": "$4.99"})
		btn.text = "Owned"
		btn.disabled = true
	)
	hbox.add_child(btn)


func _make_card(bg_color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 65)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", style)
	return card
