extends Control
## Battle Pass stub — Free + Premium reward tracks over 30 tiers.
## Tiers grant fragments, coins, energy, and gacha tickets.
## XP is earned by completing levels (stars = XP).
## Premium track is a placeholder — no real IAP wired yet.
# FINAL LAUNCH SPRINT COMPLETE

const TIERS: int = 30
const XP_PER_TIER: int = 50  # XP needed to reach the next tier

# Free track rewards: tier_index -> {type, amount, label}
# Premium track rewards: tier_index -> {type, amount, label}
# Only milestone tiers are defined; others are empty
const FREE_REWARDS: Dictionary = {
	0:  {"type": "fragments", "amount": 30, "label": "+30 Fragments"},
	2:  {"type": "energy", "amount": 1, "label": "+1 Energy"},
	4:  {"type": "fragments", "amount": 50, "label": "+50 Fragments"},
	6:  {"type": "coins", "amount": 10, "label": "+10 Coins"},
	9:  {"type": "fragments", "amount": 75, "label": "+75 Fragments"},
	11: {"type": "energy", "amount": 2, "label": "+2 Energy"},
	14: {"type": "fragments", "amount": 100, "label": "+100 Fragments"},
	17: {"type": "coins", "amount": 25, "label": "+25 Coins"},
	19: {"type": "energy", "amount": 3, "label": "+3 Energy"},
	22: {"type": "fragments", "amount": 150, "label": "+150 Fragments"},
	24: {"type": "coins", "amount": 30, "label": "+30 Coins"},
	27: {"type": "fragments", "amount": 200, "label": "+200 Fragments"},
	29: {"type": "coins", "amount": 50, "label": "+50 Coins"},
}

const PREMIUM_REWARDS: Dictionary = {
	0:  {"type": "coins", "amount": 20, "label": "+20 Coins"},
	3:  {"type": "fragments", "amount": 100, "label": "+100 Fragments"},
	6:  {"type": "energy", "amount": 3, "label": "+3 Energy"},
	9:  {"type": "coins", "amount": 40, "label": "+40 Coins"},
	12: {"type": "fragments", "amount": 200, "label": "+200 Fragments"},
	15: {"type": "coins", "amount": 50, "label": "+50 Coins"},
	18: {"type": "energy", "amount": 5, "label": "Full Energy"},
	21: {"type": "fragments", "amount": 300, "label": "+300 Fragments"},
	24: {"type": "coins", "amount": 75, "label": "+75 Coins"},
	27: {"type": "energy", "amount": 5, "label": "Full Energy"},
	29: {"type": "coins", "amount": 100, "label": "+100 Coins"},
}

var _scroll_container: ScrollContainer = null
var _grid: GridContainer = null


func _ready() -> void:
	_build_ui()
	EventBus.battle_pass_xp_gained.connect(_on_xp_gained)


func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Top bar: title + back button
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
	title.text = "FIELD PASS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.9))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(title)

	# XP progress label
	var xp_label := Label.new()
	xp_label.name = "XPLabel"
	xp_label.add_theme_font_size_override("font_size", 13)
	xp_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	xp_label.offset_top = 55.0
	xp_label.offset_bottom = 75.0
	add_child(xp_label)
	_update_xp_label(xp_label)

	# XP progress bar
	var xp_bar := ProgressBar.new()
	xp_bar.name = "XPBar"
	xp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	xp_bar.offset_top = 75.0
	xp_bar.offset_bottom = 85.0
	xp_bar.offset_left = 20.0
	xp_bar.offset_right = -20.0
	xp_bar.max_value = XP_PER_TIER
	xp_bar.value = PlayerData.credibility_xp % XP_PER_TIER
	xp_bar.show_percentage = false
	add_child(xp_bar)

	# Premium status / purchase button
	var premium_btn := Button.new()
	premium_btn.name = "PremiumButton"
	premium_btn.set_anchors_preset(Control.PRESET_TOP_WIDE)
	premium_btn.offset_top = 90.0
	premium_btn.offset_bottom = 120.0
	premium_btn.offset_left = 140.0
	premium_btn.offset_right = -140.0
	if PlayerData.starter_pack_purchased:
		premium_btn.text = "PREMIUM ACTIVE"
		premium_btn.disabled = true
	else:
		premium_btn.text = "Upgrade to Premium"
		premium_btn.pressed.connect(func() -> void:
			# Stub: toggle premium flag for testing
			PlayerData.starter_pack_purchased = true
			PlayerData.save_data()
			premium_btn.text = "PREMIUM ACTIVE"
			premium_btn.disabled = true
			_rebuild_grid()
			EventBus.analytics_event.emit("bp_premium_purchased", {})
		)
	add_child(premium_btn)

	# Track headers
	var header := HBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 128.0
	header.offset_bottom = 150.0
	header.offset_left = 10.0
	header.offset_right = -10.0
	add_child(header)

	var tier_header := Label.new()
	tier_header.text = "Tier"
	tier_header.add_theme_font_size_override("font_size", 12)
	tier_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	tier_header.custom_minimum_size = Vector2(50, 0)
	tier_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(tier_header)

	var free_header := Label.new()
	free_header.text = "Free Track"
	free_header.add_theme_font_size_override("font_size", 12)
	free_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	free_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	free_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(free_header)

	var prem_header := Label.new()
	prem_header.text = "Premium Track"
	prem_header.add_theme_font_size_override("font_size", 12)
	prem_header.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3))
	prem_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prem_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(prem_header)

	# Scrollable tier grid
	_scroll_container = ScrollContainer.new()
	_scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll_container.offset_top = 152.0
	_scroll_container.offset_bottom = -10.0
	_scroll_container.offset_left = 10.0
	_scroll_container.offset_right = -10.0
	add_child(_scroll_container)

	_rebuild_grid()


func _rebuild_grid() -> void:
	if _grid:
		_grid.queue_free()

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 4)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_grid)

	var current_tier: int = _get_current_tier()
	var claimed_free: Dictionary = _get_claimed("bp_free_claimed")
	var claimed_premium: Dictionary = _get_claimed("bp_premium_claimed")
	var has_premium: bool = PlayerData.starter_pack_purchased

	for i in range(TIERS):
		var unlocked: bool = i < current_tier

		# Tier number
		var tier_label := Label.new()
		tier_label.text = str(i + 1)
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_label.custom_minimum_size = Vector2(50, 44)
		tier_label.add_theme_font_size_override("font_size", 14)
		if unlocked:
			tier_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.9))
		else:
			tier_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
		_grid.add_child(tier_label)

		# Free reward cell
		_grid.add_child(_create_reward_cell(i, false, unlocked, claimed_free.has(str(i))))

		# Premium reward cell
		_grid.add_child(_create_reward_cell(i, true, unlocked and has_premium, claimed_premium.has(str(i))))


func _create_reward_cell(tier: int, is_premium: bool, unlocked: bool, claimed: bool) -> Control:
	var rewards: Dictionary = PREMIUM_REWARDS if is_premium else FREE_REWARDS
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(210, 44)

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0

	if claimed:
		style.bg_color = Color(0.15, 0.25, 0.2, 0.6)
	elif unlocked and rewards.has(tier):
		style.bg_color = Color(0.12, 0.18, 0.15, 0.8)
	else:
		style.bg_color = Color(0.1, 0.1, 0.12, 0.5)
	cell.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	if rewards.has(tier):
		var reward: Dictionary = rewards[tier]
		var label := Label.new()
		label.text = reward["label"]
		label.add_theme_font_size_override("font_size", 12)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if claimed:
			label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.5))
		elif is_premium:
			label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3))
		else:
			label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		hbox.add_child(label)

		if claimed:
			var check := Label.new()
			check.text = "Claimed"
			check.add_theme_font_size_override("font_size", 10)
			check.add_theme_color_override("font_color", Color(0.4, 0.6, 0.5))
			hbox.add_child(check)
		elif unlocked:
			var btn := Button.new()
			btn.text = "Claim"
			btn.custom_minimum_size = Vector2(55, 30)
			btn.pressed.connect(_claim_reward.bind(tier, is_premium))
			hbox.add_child(btn)
	else:
		var empty := Label.new()
		empty.text = "—"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(empty)

	cell.add_child(hbox)
	return cell


func _claim_reward(tier: int, is_premium: bool) -> void:
	var rewards: Dictionary = PREMIUM_REWARDS if is_premium else FREE_REWARDS
	if not rewards.has(tier):
		return

	var reward: Dictionary = rewards[tier]
	match reward["type"]:
		"fragments":
			PlayerData.add_fragments(reward["amount"])
		"coins":
			PlayerData.add_coins(reward["amount"])
		"energy":
			PlayerData.add_energy(reward["amount"])

	# Mark as claimed
	var key: String = "bp_premium_claimed" if is_premium else "bp_free_claimed"
	var claimed: Dictionary = _get_claimed(key)
	claimed[str(tier)] = true
	PlayerData.tutorial_hints_shown[key] = claimed
	PlayerData.save_data()

	EventBus.battle_pass_reward_claimed.emit(tier, is_premium)
	EventBus.play_sfx.emit("discovery")

	_rebuild_grid()


func _get_current_tier() -> int:
	# XP is driven by credibility_xp (earned from level completions)
	return mini(floori(float(PlayerData.credibility_xp) / XP_PER_TIER), TIERS)


func _get_claimed(key: String) -> Dictionary:
	var val = PlayerData.tutorial_hints_shown.get(key, {})
	if val is Dictionary:
		return val
	return {}


func _update_xp_label(label: Label) -> void:
	var tier: int = _get_current_tier()
	var xp_in_tier: int = PlayerData.credibility_xp % XP_PER_TIER
	label.text = "Tier %d / %d — %d / %d XP" % [mini(tier + 1, TIERS), TIERS, xp_in_tier, XP_PER_TIER]


func _on_xp_gained(_amount: int) -> void:
	# Refresh display if screen is visible
	var xp_label: Label = get_node_or_null("XPLabel")
	var xp_bar: ProgressBar = get_node_or_null("XPBar")
	if xp_label:
		_update_xp_label(xp_label)
	if xp_bar:
		xp_bar.value = PlayerData.credibility_xp % XP_PER_TIER
	_rebuild_grid()
