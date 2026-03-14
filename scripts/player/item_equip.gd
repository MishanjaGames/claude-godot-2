extends Node2D
class_name ItemEquip

signal equipped(item: EquippableItem, slot: EquippableItem.EquipSlot)
signal unequipped(item: EquippableItem, slot: EquippableItem.EquipSlot)

# Current item in each slot — null = empty
var _slots: Dictionary = {}

# Reference to the owner's stats so we can apply modifiers
var _stats: Stats = null


func setup(stats: Stats) -> void:
	_stats = stats
	# Pre-fill all slots with null
	for slot in EquippableItem.EquipSlot.values():
		_slots[slot] = null


# ── Public API ───────────────────────────────────────────

func equip(item: EquippableItem) -> void:
	var slot := item.slot

	# Unequip whatever is already there
	if _slots[slot] != null:
		unequip(slot)

	_slots[slot] = item
	_apply_modifiers(item, true)
	equipped.emit(item, slot)


func unequip(slot: EquippableItem.EquipSlot) -> void:
	var item: EquippableItem = _slots[slot]
	if item == null:
		return
	_apply_modifiers(item, false)
	_slots[slot] = null
	unequipped.emit(item, slot)


func get_item(slot: EquippableItem.EquipSlot) -> EquippableItem:
	return _slots.get(slot, null)


func is_slot_empty(slot: EquippableItem.EquipSlot) -> bool:
	return _slots.get(slot, null) == null


func get_all_equipped() -> Array[EquippableItem]:
	var result: Array[EquippableItem] = []
	for item in _slots.values():
		if item != null:
			result.append(item)
	return result


func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for slot in _slots:
		var item: EquippableItem = _slots[slot]
		result[EquippableItem.EquipSlot.keys()[slot]] = \
			item.to_dict() if item != null else null
	return result


func print_info() -> void:
	print(JSON.stringify(to_dict(), "\t"))


# ── Internals ────────────────────────────────────────────

func _apply_modifiers(item: EquippableItem, add: bool) -> void:
	if _stats == null:
		return
	for stat in item.stat_modifiers:
		var mod_id := "equip_%s_%s" % [EquippableItem.EquipSlot.keys()[item.slot], stat]
		if add:
			_stats.add_modifier(mod_id, stat, item.stat_modifiers[stat])
		else:
			_stats.remove_modifier(mod_id)
