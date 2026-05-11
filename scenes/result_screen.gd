extends Control
# CRYPTID CELEBRATION v1.0

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var thresholds_label: Label = %ThresholdsLabel
@onready var stars_container: HBoxContainer = $VBoxContainer/StarsContainer
@onready var rewards_label: Label = %RewardsLabel
@onready var replay_button: Button = $VBoxContainer/ButtonContainer/ReplayButton
@onready var home_button: Button = $VBoxContainer/ButtonContainer/HomeButton

var _doubled: bool = false
var _starter_pack_shown: bool = false
var _celebration_layer: CanvasLayer = null
var _celebration_tweens: Array[Tween] = []


func _ready() -> void:
	replay_button.pressed.connect(func() -> void: EventBus.replay_pressed.emit())
	home_button.pressed.connect(func() -> void: EventBus.home_pressed.emit())

	# Unpause if we came from a paused state
	get_tree().paused = false

	# On victory, play celebration FIRST then reveal result UI
	var is_victory: bool = GameManager.state == GameManager.GameState.LEVEL_COMPLETE
	var star_rating: int = 0
	if GameManager.current_level_data:
		star_rating = GameManager.current_level_data.get_star_rating(GameManager.score)

	if is_victory and star_rating > 0:
		# Hide main UI during celebration
		$VBoxContainer.modulate.a = 0.0
		_play_celebration(star_rating)
		await get_tree().create_timer(2.5).timeout
		_fade_in_results()
	else:
		$VBoxContainer.modulate.a = 1.0

	_display_results()
	_add_rewards_section()
	_check_starter_pack()


func _display_results() -> void:
	var final_score: int = GameManager.score
	var star_rating: int = 0
	if GameManager.current_level_data:
		star_rating = GameManager.current_level_data.get_star_rating(final_score)

	# Set title based on outcome
	if GameManager.state == GameManager.GameState.LEVEL_COMPLETE:
		title_label.text = "LEVEL COMPLETE!"
		EventBus.play_music.emit("victory_theme")
	else:
		title_label.text = "GAME OVER"
		EventBus.play_music.emit("defeat_theme")

	score_label.text = "Score: %d" % final_score

	# Show star thresholds
	if GameManager.current_level_data:
		var ld: LevelData = GameManager.current_level_data
		thresholds_label.text = "★ %d  |  ★★ %d  |  ★★★ %d" % [ld.star_1_score, ld.star_2_score, ld.star_3_score]
		thresholds_label.visible = true
	else:
		thresholds_label.visible = false

	# Animate stars
	_show_stars(star_rating)


func _show_stars(count: int) -> void:
	# Clear existing stars
	for child in stars_container.get_children():
		child.queue_free()

	# Create 3 star labels
	for i in range(3):
		var star: Label = Label.new()
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.add_theme_font_size_override("font_size", 48)
		star.custom_minimum_size = Vector2(60, 60)

		if i < count:
			star.text = "*"
			star.modulate = Color(1.0, 0.85, 0.0)  # Gold
			star.modulate.a = 0.0
		else:
			star.text = "*"
			star.modulate = Color(0.3, 0.3, 0.3)  # Gray
			star.modulate.a = 0.0

		stars_container.add_child(star)

	# Animate stars appearing sequentially
	var tween: Tween = create_tween()
	for i in range(3):
		var star: Label = stars_container.get_child(i)
		tween.tween_interval(0.3)
		tween.tween_property(star, "modulate:a", 1.0, 0.3)
		if i < count:
			tween.tween_property(star, "scale", Vector2(1.3, 1.3), 0.1)
			tween.tween_property(star, "scale", Vector2.ONE, 0.2)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _add_rewards_section() -> void:
	# Read the actual awarded amounts from GameManager (set in _record_completion)
	var fragments: int = GameManager.last_reward_fragments
	var coins: int = GameManager.last_reward_coins

	if fragments > 0:
		var reward_text: String = "Rewards: +%d Fragments" % fragments
		if coins > 0:
			reward_text += ", +%d Coins" % coins
		rewards_label.text = reward_text
	else:
		rewards_label.text = "No rewards this time.\nScore higher to earn fragments!"

	# Double rewards button (only on completion with rewards)
	if not _doubled and fragments > 0:
		var double_btn := Button.new()
		double_btn.text = "Double Rewards (Watch Ad)"
		double_btn.custom_minimum_size = Vector2(250, 45)
		double_btn.add_theme_font_size_override("font_size", 14)
		double_btn.pressed.connect(func() -> void:
			_doubled = true
			EventBus.rewarded_ad_requested.emit("double_fragments")
			AdPlacement.show_rewarded("double_rewards", func() -> void:
				PlayerData.add_fragments(fragments)
				var coin_text: String = ""
				if coins > 0:
					PlayerData.add_coins(coins)
					coin_text = ", +%d Coins" % (coins * 2)
				rewards_label.text = "Rewards: +%d Fragments%s (Doubled!)" % [fragments * 2, coin_text]
				EventBus.reward_doubled.emit()
			)
			double_btn.queue_free()
		)
		$VBoxContainer.add_child(double_btn)
		$VBoxContainer.move_child(double_btn, $VBoxContainer.get_child_count() - 2)


# === CRYPTID CELEBRATION v1.0 ===

func _play_celebration(stars: int) -> void:
	## Show the player's team as glowing silhouette cards with particle bursts.
	## Intensity scales with star rating.
	EventBus.play_sfx.emit("cryptid_celebration")
	EventBus.vfx_request.emit("ability_flash", Vector2.ZERO)

	_celebration_layer = CanvasLayer.new()
	_celebration_layer.layer = 50
	add_child(_celebration_layer)

	# Dim overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_celebration_layer.add_child(overlay)

	# Golden burst particles (stronger with more stars)
	_spawn_burst_particles(stars)

	# Misty teal background particles
	_spawn_mist_particles()

	# Team cryptid cards
	var team: Array[CryptidData] = PlayerData.get_team_cryptids()
	if team.is_empty():
		return

	var viewport_w: float = 540.0
	var viewport_h: float = 960.0
	var card_count: int = team.size()
	var card_spacing: float = viewport_w / (card_count + 1)
	var card_y: float = viewport_h * 0.42

	for i in range(card_count):
		var cryptid: CryptidData = team[i]
		var is_leader: bool = i == 0
		var card_x: float = card_spacing * (i + 1)
		_create_cryptid_card(cryptid, Vector2(card_x, card_y), is_leader, stars, i)

	# Star burst text
	var star_text := Label.new()
	star_text.text = _get_star_text(stars)
	star_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_text.add_theme_font_size_override("font_size", 28 + stars * 4)
	star_text.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	star_text.set_anchors_preset(Control.PRESET_CENTER_TOP)
	star_text.offset_top = viewport_h * 0.15
	star_text.offset_bottom = viewport_h * 0.22
	star_text.offset_left = -200.0
	star_text.offset_right = 200.0
	star_text.modulate.a = 0.0
	_celebration_layer.add_child(star_text)

	var text_tween := create_tween()
	text_tween.tween_property(star_text, "modulate:a", 1.0, 0.3)
	text_tween.tween_property(star_text, "scale", Vector2(1.1, 1.1), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	text_tween.tween_property(star_text, "scale", Vector2.ONE, 0.2)


func _create_cryptid_card(cryptid: CryptidData, pos: Vector2, is_leader: bool, stars: int, index: int) -> void:
	## A glowing silhouette card for one team cryptid.
	var card_w: float = 100.0 if is_leader else 80.0
	var card_h: float = 130.0 if is_leader else 105.0
	var base_color: Color = PieceData.get_color(cryptid.base_cryptid)
	var rarity_color: Color = CryptidData.get_rarity_color(cryptid.rarity)

	# Card container
	var card := Control.new()
	card.position = Vector2(pos.x - card_w / 2.0, pos.y - card_h / 2.0)
	card.size = Vector2(card_w, card_h)
	card.modulate.a = 0.0
	card.scale = Vector2(0.3, 0.3)
	card.pivot_offset = Vector2(card_w / 2.0, card_h / 2.0)
	_celebration_layer.add_child(card)

	# Outer glow (rarity-colored)
	var glow := ColorRect.new()
	glow.position = Vector2(-4, -4)
	glow.size = Vector2(card_w + 8, card_h + 8)
	glow.color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.5)
	card.add_child(glow)

	# Card background
	var bg := ColorRect.new()
	bg.size = Vector2(card_w, card_h)
	bg.color = Color(0.08, 0.06, 0.12, 0.9)
	card.add_child(bg)

	# Cryptid silhouette circle (uses base type color)
	var circle := ColorRect.new()
	var circle_size: float = card_w * 0.55
	circle.position = Vector2((card_w - circle_size) / 2.0, 10.0)
	circle.size = Vector2(circle_size, circle_size)
	circle.color = base_color
	card.add_child(circle)

	# Inner glow on the circle
	var inner_glow := ColorRect.new()
	var ig_size: float = circle_size * 0.7
	inner_glow.position = Vector2(
		circle.position.x + (circle_size - ig_size) / 2.0,
		circle.position.y + (circle_size - ig_size) / 2.0
	)
	inner_glow.size = Vector2(ig_size, ig_size)
	inner_glow.color = Color(base_color.r + 0.3, base_color.g + 0.3, base_color.b + 0.3, 0.6)
	card.add_child(inner_glow)

	# Name label
	var name_label := Label.new()
	name_label.text = cryptid.variant_name if cryptid.variant_name != "" else cryptid.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 9 if not is_leader else 11)
	name_label.add_theme_color_override("font_color", rarity_color)
	name_label.position = Vector2(0, card_h - 32.0)
	name_label.size = Vector2(card_w, 16)
	card.add_child(name_label)

	# Role label (Leader or Support)
	var role_label := Label.new()
	role_label.text = "LEADER" if is_leader else "Support"
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_font_size_override("font_size", 8)
	role_label.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.2) if is_leader else Color(0.5, 0.6, 0.55))
	role_label.position = Vector2(0, card_h - 18.0)
	role_label.size = Vector2(card_w, 14)
	card.add_child(role_label)

	# Animate entrance: stagger by index, leader arrives first with bigger pop
	var delay: float = index * 0.2
	var target_scale: float = 1.0
	var card_tween := create_tween()
	card_tween.tween_interval(delay)
	card_tween.tween_property(card, "modulate:a", 1.0, 0.25)
	card_tween.parallel().tween_property(card, "scale", Vector2(target_scale * 1.15, target_scale * 1.15), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card_tween.tween_property(card, "scale", Vector2(target_scale, target_scale), 0.15)

	# Leader victory pose: continuous gentle float + glow pulse
	if is_leader:
		var float_tween := create_tween().set_loops()
		float_tween.tween_property(card, "position:y", card.position.y - 8.0, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(delay + 0.4)
		float_tween.tween_property(card, "position:y", card.position.y, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_celebration_tweens.append(float_tween)

		var glow_tween := create_tween().set_loops()
		glow_tween.tween_property(glow, "color:a", 0.8, 0.4).set_delay(delay + 0.4)
		glow_tween.tween_property(glow, "color:a", 0.35, 0.4)
		_celebration_tweens.append(glow_tween)

	# Stronger glow animation for 3 stars
	if stars >= 3:
		var star_glow := create_tween().set_loops()
		star_glow.tween_property(inner_glow, "color:a", 0.9, 0.3).set_delay(delay + 0.3)
		star_glow.tween_property(inner_glow, "color:a", 0.4, 0.3)
		_celebration_tweens.append(star_glow)


func _spawn_burst_particles(stars: int) -> void:
	## Golden burst particles — more particles for more stars.
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 60.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 80.0 + stars * 40.0
	mat.initial_velocity_max = 180.0 + stars * 60.0
	mat.gravity = Vector3(0, 100, 0)
	mat.scale_min = 2.0
	mat.scale_max = 5.0 + stars
	mat.color = Color(1.0, 0.85, 0.2, 0.9)
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(1.0, 0.9, 0.3, 1.0))
	color_ramp.set_color(1, Color(1.0, 0.6, 0.1, 0.0))
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = color_ramp
	mat.color_ramp = color_tex

	particles.process_material = mat
	particles.amount = 20 + stars * 15
	particles.lifetime = 1.2
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.position = Vector2(270, 400)
	_celebration_layer.add_child(particles)
	particles.emitting = true


func _spawn_mist_particles() -> void:
	## Subtle teal mist rising behind the cards.
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(250, 10, 0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 35.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 8.0
	mat.scale_max = 16.0
	mat.color = Color(0.3, 0.8, 0.7, 0.12)

	particles.process_material = mat
	particles.amount = 12
	particles.lifetime = 2.5
	particles.position = Vector2(270, 600)
	_celebration_layer.add_child(particles)
	particles.emitting = true


func _fade_in_results() -> void:
	## Fade out celebration, fade in result UI.
	if _celebration_layer:
		var fade := create_tween()
		fade.tween_property(_celebration_layer, "modulate:a", 0.0, 0.5)
	var ui_tween := create_tween()
	ui_tween.tween_property($VBoxContainer, "modulate:a", 1.0, 0.5)
	# Clean up celebration layer after fade
	if _celebration_layer:
		await get_tree().create_timer(0.6).timeout
		for t: Tween in _celebration_tweens:
			t.kill()
		_celebration_tweens.clear()
		_celebration_layer.queue_free()
		_celebration_layer = null


func _get_star_text(stars: int) -> String:
	match stars:
		1: return "Investigation Complete!"
		2: return "Excellent Discovery!"
		3: return "Legendary Find!"
	return "Complete!"


func _check_starter_pack() -> void:
	if _starter_pack_shown:
		return
	if PlayerData.starter_pack_purchased:
		return
	if PlayerData.starter_pack_shown:
		return
	if GameManager.current_level < 5:
		return

	# Show starter pack after a delay
	PlayerData.starter_pack_shown = true
	PlayerData.save_data()
	_starter_pack_shown = true

	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self):
		return

	var popup: Control = preload("res://scenes/ui/starter_pack_popup.tscn").instantiate()
	popup.purchased.connect(func() -> void: popup.queue_free())
	popup.dismissed.connect(func() -> void: popup.queue_free())
	add_child(popup)
