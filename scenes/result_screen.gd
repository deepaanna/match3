extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var thresholds_label: Label = %ThresholdsLabel
@onready var stars_container: HBoxContainer = $VBoxContainer/StarsContainer
@onready var rewards_label: Label = %RewardsLabel
@onready var replay_button: Button = $VBoxContainer/ButtonContainer/ReplayButton
@onready var home_button: Button = $VBoxContainer/ButtonContainer/HomeButton

var _doubled: bool = false
var _starter_pack_shown: bool = false


func _ready() -> void:
	replay_button.pressed.connect(func() -> void: EventBus.replay_pressed.emit())
	home_button.pressed.connect(func() -> void: EventBus.home_pressed.emit())

	# Unpause if we came from a paused state
	get_tree().paused = false

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

	var popup: Control = preload("res://scenes/ui/starter_pack_popup.tscn").instantiate()
	popup.purchased.connect(func() -> void: popup.queue_free())
	popup.dismissed.connect(func() -> void: popup.queue_free())
	add_child(popup)
