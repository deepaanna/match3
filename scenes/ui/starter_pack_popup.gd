extends Control
## One-time offer after level 5: Researcher's Kit.

signal purchased()
signal dismissed()

@onready var _countdown_label: Label = %CountdownLabel
@onready var _buy_button: Button = %BuyButton
@onready var _dismiss_button: Button = %DismissButton

var _show_time: float = 0.0
const OFFER_DURATION_HOURS: float = 48.0


func _ready() -> void:
	_show_time = Time.get_unix_time_from_system()
	_buy_button.pressed.connect(_on_purchase)
	_dismiss_button.pressed.connect(func() -> void: dismissed.emit())


func _process(_delta: float) -> void:
	var elapsed: float = Time.get_unix_time_from_system() - _show_time
	var remaining: float = OFFER_DURATION_HOURS * 3600.0 - elapsed
	if remaining <= 0:
		_countdown_label.text = "Offer expired!"
	else:
		var hours: int = floori(remaining / 3600.0)
		var minutes: int = floori(fmod(remaining, 3600.0) / 60.0)
		_countdown_label.text = "Expires in: %dh %dm" % [hours, minutes]


func _on_purchase() -> void:
	# Placeholder: IAP would happen here
	PlayerData.add_coins(500)
	# 3 guaranteed Rare pulls
	for _i in range(3):
		var pool: Array[CryptidData] = CryptidDatabase.get_by_rarity(CryptidData.Rarity.RARE)
		if not pool.is_empty():
			var cryptid: CryptidData = pool[randi() % pool.size()]
			PlayerData.add_cryptid(cryptid.cryptid_id)
	PlayerData.refill_energy()
	PlayerData.starter_pack_purchased = true
	PlayerData.save_data()
	EventBus.iap_purchased.emit("starter_pack")
	purchased.emit()
