extends HBoxContainer
## Shows 5 hearts + regen timer.

@onready var _heart_0: Label = $Heart0
@onready var _heart_1: Label = $Heart1
@onready var _heart_2: Label = $Heart2
@onready var _heart_3: Label = $Heart3
@onready var _heart_4: Label = $Heart4
@onready var _timer_label: Label = $TimerLabel

var _hearts: Array[Label] = []


func _ready() -> void:
	_hearts = [_heart_0, _heart_1, _heart_2, _heart_3, _heart_4]

	EventBus.energy_changed.connect(func(_e: int) -> void: _update_display())
	_update_display()


func _process(_delta: float) -> void:
	_update_timer()


func _update_display() -> void:
	for i in range(_hearts.size()):
		if i < PlayerData.energy:
			_hearts[i].modulate = Color(1.0, 0.2, 0.2)  # Red = full
		else:
			_hearts[i].modulate = Color(0.3, 0.3, 0.3)  # Gray = empty


func _update_timer() -> void:
	if PlayerData.energy >= PlayerData.MAX_ENERGY:
		_timer_label.text = "Full"
		return
	var remaining: float = PlayerData.get_energy_regen_remaining()
	var minutes: int = floori(remaining / 60.0)
	var seconds: int = floori(fmod(remaining, 60.0))
	_timer_label.text = "%d:%02d" % [minutes, seconds]
