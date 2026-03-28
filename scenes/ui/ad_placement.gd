class_name AdPlacement
extends RefCounted
## Placeholder ad integration. Ready for real SDK.


static func show_rewarded(placement: String, callback: Callable) -> void:
	# Placeholder: immediately call the callback as if ad was watched
	print("[AdPlacement] Rewarded ad shown for: ", placement)
	EventBus.ad_watched.emit(placement)
	callback.call()


static func show_interstitial(placement: String) -> void:
	# Placeholder: log and continue
	print("[AdPlacement] Interstitial shown for: ", placement)
