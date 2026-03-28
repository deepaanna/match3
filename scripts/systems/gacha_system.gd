class_name GachaSystem
extends RefCounted

const SINGLE_COST: int = 100  # fragments
const MULTI_COST: int = 900   # fragments for 10 pulls
const PITY_RARE: int = 30     # guaranteed Rare at this pull count
const PITY_EPIC: int = 90     # guaranteed Epic at this pull count

# Rarity weights (must sum to 100)
const RARITY_WEIGHTS: Dictionary = {
	CryptidData.Rarity.COMMON: 60,
	CryptidData.Rarity.UNCOMMON: 25,
	CryptidData.Rarity.RARE: 10,
	CryptidData.Rarity.EPIC: 4,
	CryptidData.Rarity.LEGENDARY: 1,
}


static func pull_single() -> CryptidData:
	if not PlayerData.spend_fragments(SINGLE_COST):
		return null
	return _do_pull()


static func pull_multi() -> Array[CryptidData]:
	if not PlayerData.spend_fragments(MULTI_COST):
		return []
	var results: Array[CryptidData] = []
	for _i in range(10):
		results.append(_do_pull())
	return results


static func _do_pull() -> CryptidData:
	PlayerData.pity_rare += 1
	PlayerData.pity_epic += 1

	var rarity: CryptidData.Rarity = _roll_rarity()

	# Pity system
	if PlayerData.pity_epic >= PITY_EPIC and rarity < CryptidData.Rarity.EPIC:
		rarity = CryptidData.Rarity.EPIC
	elif PlayerData.pity_rare >= PITY_RARE and rarity < CryptidData.Rarity.RARE:
		rarity = CryptidData.Rarity.RARE

	# Reset pity counters based on what we got
	if rarity >= CryptidData.Rarity.EPIC:
		PlayerData.pity_epic = 0
		PlayerData.pity_rare = 0
	elif rarity >= CryptidData.Rarity.RARE:
		PlayerData.pity_rare = 0

	# Pick random cryptid of that rarity
	var pool: Array[CryptidData] = CryptidDatabase.get_by_rarity(rarity)
	if pool.is_empty():
		# Fallback to common
		pool = CryptidDatabase.get_by_rarity(CryptidData.Rarity.COMMON)

	var cryptid: CryptidData = pool[randi() % pool.size()]

	# Add to collection
	PlayerData.add_cryptid(cryptid.cryptid_id)
	EventBus.investigation_result.emit(cryptid.cryptid_id, cryptid.rarity)

	PlayerData.save_data()
	return cryptid


static func _roll_rarity() -> CryptidData.Rarity:
	var roll: int = randi() % 100
	var cumulative: int = 0
	for rarity: CryptidData.Rarity in RARITY_WEIGHTS:
		cumulative += RARITY_WEIGHTS[rarity]
		if roll < cumulative:
			return rarity
	return CryptidData.Rarity.COMMON


static func can_pull_single() -> bool:
	return PlayerData.evidence_fragments >= SINGLE_COST


static func can_pull_multi() -> bool:
	return PlayerData.evidence_fragments >= MULTI_COST
