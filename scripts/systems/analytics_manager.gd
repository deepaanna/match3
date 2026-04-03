extends Node
## Lightweight analytics logger. Captures key game events for balancing.
## Replace _log_event() internals with a real SDK (GameAnalytics, Firebase, etc.)
## when ready for production telemetry.
# FINAL LAUNCH SPRINT COMPLETE

var _session_start: float = 0.0
var _session_events: int = 0


func _ready() -> void:
	_session_start = Time.get_unix_time_from_system()
	EventBus.analytics_event.connect(_on_analytics_event)

	# Wire up core game signals directly so callers don't need to know about analytics
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.ability_activated.connect(_on_ability_activated)
	EventBus.shuffle_used.connect(_on_shuffle_used)
	EventBus.daily_login_reward.connect(_on_daily_login)
	EventBus.cryptid_obtained.connect(_on_cryptid_obtained)
	EventBus.energy_empty.connect(_on_energy_empty)
	EventBus.battle_pass_reward_claimed.connect(_on_bp_reward_claimed)


func _on_analytics_event(event_name: String, parameters: Dictionary) -> void:
	_log_event(event_name, parameters)


# --- Auto-tracked events ---

func _on_level_completed(final_score: int, star_rating: int) -> void:
	_log_event("level_completed", {
		"level": GameManager.current_level,
		"stars": star_rating,
		"score": final_score,
		"moves_used": GameManager.current_level_data.max_moves - GameManager.moves_remaining if GameManager.current_level_data else 0,
	})


func _on_game_over(final_score: int, _star_rating: int) -> void:
	_log_event("level_failed", {
		"level": GameManager.current_level,
		"score": final_score,
	})


func _on_ability_activated(cryptid_id: String) -> void:
	_log_event("ability_used", {"cryptid": cryptid_id, "level": GameManager.current_level})


func _on_shuffle_used() -> void:
	_log_event("shuffle_used", {"level": GameManager.current_level})


func _on_daily_login(streak: int, reward: Dictionary) -> void:
	_log_event("daily_login", {"streak": streak, "reward": reward.get("label", "")})


func _on_cryptid_obtained(cryptid_id: String, is_new: bool) -> void:
	_log_event("gacha_pull", {"cryptid": cryptid_id, "is_new": is_new})


func _on_energy_empty() -> void:
	_log_event("energy_empty", {"level": GameManager.current_level})


func _on_bp_reward_claimed(tier: int, is_premium: bool) -> void:
	_log_event("bp_reward_claimed", {"tier": tier, "premium": is_premium})


# --- Core logger ---

func _log_event(event_name: String, parameters: Dictionary) -> void:
	_session_events += 1
	var elapsed: float = Time.get_unix_time_from_system() - _session_start
	# Console log for dev builds — replace with SDK call for production
	print("[ANALYTICS] %s (%.0fs) %s" % [event_name, elapsed, str(parameters)])
	# TODO: GameAnalytics.addDesignEvent(event_name, parameters)
	# TODO: Firebase.Analytics.log_event(event_name, parameters)
