# InventoryManager.gd
# Global inventory. Manages item slots, hotbar, and equipment.
# Uses Registry.get_item() for save-load restoration.
# LOAD ORDER: after Registry.
extends Node

const INVENTORY_SIZE: int = 32
const HOTBAR_SIZE:    int = 8

# Equipment slot indices (map to ArmourData.Slot enum)
const EQUIP_HEAD:        int = 0
const EQUIP_CHEST:       int = 1
const EQUIP_LEGS:        int = 2
const EQUIP_FEET:        int = 3
const EQUIP_ACCESSORY_1: int = 4
const EQUIP_ACCESSORY_2: int = 5
const EQUIP_SLOTS:       int = 6

# ── Slot arrays ────────────────────────────────────────────────────────────────
## Main 32-slot bag. Each entry: ItemData | null.
var slots:       Array = []
## 8-slot hotbar. Mirrors item references from slots (not separate copies).
var hotbar_slots: Array = []
## 6 equipment slots. ArmourData | null.
var equip_slots:  Array = []

var active_hotbar_index: int = 0

func _ready() -> void:
	_init_arrays()

func _init_arrays() -> void:
	slots.resize(INVENTORY_SIZE)
	hotbar_slots.resize(HOTBAR_SIZE)
	equip_slots.resize(EQUIP_SLOTS)
	slots.fill(null)
	hotbar_slots.fill(null)
	equip_slots.fill(null)

# ══════════════════════════════════════════════════════════════════════════════
# ITEM SLOTS
# ══════════════════════════════════════════════════════════════════════════════

## Adds item to the first available slot. Returns true on success.
func add_item(item: ItemData) -> bool:
	if item == null:
		return false

	# Try stacking first
	if item.stackable:
		for i in INVENTORY_SIZE:
			var s = slots[i]
			if s != null and s.id == item.id and s.quantity < s.max_stack:
				s.quantity += item.quantity
				if s.quantity > s.max_stack:
					item.quantity = s.quantity - s.max_stack
					s.quantity    = s.max_stack
					# continue loop to place overflow
				else:
					EventBus.inventory_item_added.emit(s, i)
					return true

	# Place in empty slot
	for i in INVENTORY_SIZE:
		if slots[i] == null:
			slots[i] = item.duplicate()
			slots[i].quantity = item.quantity
			EventBus.inventory_item_added.emit(slots[i], i)
			return true

	push_warning("InventoryManager: inventory full.")
	EventBus.inventory_full.emit()
	return false

## Removes and returns the item at slot_index. Returns null if empty.
func remove_item(slot_index: int) -> ItemData:
	if slot_index < 0 or slot_index >= INVENTORY_SIZE:
		return null
	var item = slots[slot_index]
	if item == null:
		return null
	slots[slot_index] = null
	_sync_hotbar_after_removal(slot_index)
	EventBus.inventory_item_removed.emit(item, slot_index)
	return item

## Decrements stack quantity by 1. Removes the slot if quantity reaches 0.
func consume_one(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= INVENTORY_SIZE:
		return false
	var item = slots[slot_index]
	if item == null:
		return false
	item.quantity -= 1
	if item.quantity <= 0:
		remove_item(slot_index)
	else:
		EventBus.inventory_item_added.emit(item, slot_index)
	return true

## Swaps two slot indices (works across hotbar mirror too).
func move_item(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= INVENTORY_SIZE: return
	if to_index   < 0 or to_index   >= INVENTORY_SIZE: return
	var temp         = slots[to_index]
	slots[to_index]  = slots[from_index]
	slots[from_index] = temp
	EventBus.inventory_item_moved.emit(from_index, to_index)

## Returns true if any slot holds an item with the given id.
func has_item(item_id: String) -> bool:
	for s in slots:
		if s != null and s.id == item_id:
			return true
	return false

## Counts total quantity of an item id across all slots.
func count_item(item_id: String) -> int:
	var total := 0
	for s in slots:
		if s != null and s.id == item_id:
			total += s.quantity
	return total

# ══════════════════════════════════════════════════════════════════════════════
# HOTBAR
# ══════════════════════════════════════════════════════════════════════════════

## Mirrors a slot into a hotbar position.
func assign_to_hotbar(slot_index: int, hotbar_index: int) -> void:
	if hotbar_index < 0 or hotbar_index >= HOTBAR_SIZE: return
	hotbar_slots[hotbar_index] = slots[slot_index]
	EventBus.hotbar_slot_changed.emit(hotbar_index, hotbar_slots[hotbar_index])

func get_active_item() -> ItemData:
	return hotbar_slots[active_hotbar_index]

func set_active_hotbar(index: int) -> void:
	active_hotbar_index = clamp(index, 0, HOTBAR_SIZE - 1)
	EventBus.active_hotbar_changed.emit(active_hotbar_index)
	EventBus.hotbar_slot_changed.emit(active_hotbar_index, get_active_item())

func scroll_hotbar(direction: int) -> void:
	set_active_hotbar((active_hotbar_index + direction + HOTBAR_SIZE) % HOTBAR_SIZE)

# ══════════════════════════════════════════════════════════════════════════════
# EQUIPMENT
# ══════════════════════════════════════════════════════════════════════════════

## Equips an ArmourData from a slot. Swaps with existing item if occupied.
func equip_from_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= INVENTORY_SIZE: return false
	var item = slots[slot_index]
	if item == null or not item is ArmourData: return false

	var armour := item as ArmourData
	var equip_index: int = armour.slot

	var previously_equipped = equip_slots[equip_index]
	equip_slots[equip_index] = armour
	slots[slot_index] = previously_equipped   # swap old armour back to bag

	_apply_equipment_modifiers(armour, true)
	if previously_equipped:
		_apply_equipment_modifiers(previously_equipped as ArmourData, false)

	EventBus.equipment_changed.emit(equip_index, armour)
	return true

## Unequips the armour in an equipment slot back to the first free bag slot.
func unequip(equip_index: int) -> bool:
	if equip_index < 0 or equip_index >= EQUIP_SLOTS: return false
	var armour = equip_slots[equip_index]
	if armour == null: return false

	if not add_item(armour):
		push_warning("InventoryManager.unequip: no space in bag.")
		return false

	_apply_equipment_modifiers(armour as ArmourData, false)
	equip_slots[equip_index] = null
	EventBus.equipment_changed.emit(equip_index, null)
	return true

func get_equipped(equip_index: int) -> ArmourData:
	if equip_index < 0 or equip_index >= EQUIP_SLOTS: return null
	return equip_slots[equip_index]

## Pushes/removes StatBlock modifiers when armour is equipped or unequipped.
func _apply_equipment_modifiers(armour: ArmourData, equipping: bool) -> void:
	var player = GameManager.player_ref
	if player == null or player.stat_block == null: return

	var mod_id := "equip_%d" % armour.slot

	if equipping:
		if armour.defence_bonus      != 0: player.stat_block.add_modifier(mod_id, "defence",      armour.defence_bonus,      "add")
		if armour.max_health_bonus   != 0: player.stat_block.add_modifier(mod_id, "max_health",   armour.max_health_bonus,   "add")
		if armour.max_stamina_bonus  != 0: player.stat_block.add_modifier(mod_id, "max_stamina",  armour.max_stamina_bonus,  "add")
		if armour.magic_resist_bonus != 0: player.stat_block.add_modifier(mod_id, "magic_resist", armour.magic_resist_bonus, "add")
		if armour.attack_bonus       != 0: player.stat_block.add_modifier(mod_id, "attack",       armour.attack_bonus,       "add")
		if armour.move_speed_penalty != 0: player.stat_block.add_modifier(mod_id, "move_speed",  -armour.move_speed_penalty, "add")
	else:
		player.stat_block.remove_all_modifiers_from(mod_id)

# ══════════════════════════════════════════════════════════════════════════════
# CLEAR
# ══════════════════════════════════════════════════════════════════════════════

func clear() -> void:
	slots.fill(null)
	hotbar_slots.fill(null)
	equip_slots.fill(null)
	active_hotbar_index = 0

# ══════════════════════════════════════════════════════════════════════════════
# SAVE / LOAD
# ══════════════════════════════════════════════════════════════════════════════

func serialize() -> Dictionary:
	var slot_data: Array = []
	for s in slots:
		slot_data.append(null if s == null else s.to_save_dict())

	var hotbar_data: Array = []
	for h in hotbar_slots:
		hotbar_data.append(null if h == null else h.to_save_dict())

	var equip_data: Array = []
	for e in equip_slots:
		equip_data.append(null if e == null else e.to_save_dict())

	return {
		"slots":         slot_data,
		"hotbar":        hotbar_data,
		"equip":         equip_data,
		"active_hotbar": active_hotbar_index,
	}

func deserialize(data: Dictionary) -> void:
	clear()
	active_hotbar_index = data.get("active_hotbar", 0)

	var raw_slots: Array  = data.get("slots",  [])
	var raw_hotbar: Array = data.get("hotbar", [])
	var raw_equip: Array  = data.get("equip",  [])

	for i in mini(raw_slots.size(), INVENTORY_SIZE):
		var entry = raw_slots[i]
		if entry == null: continue
		var item = Registry.get_item(entry.get("id", ""))
		if item:
			item.quantity = entry.get("quantity", 1)
			slots[i] = item

	for i in mini(raw_hotbar.size(), HOTBAR_SIZE):
		var entry = raw_hotbar[i]
		if entry == null: continue
		var item = Registry.get_item(entry.get("id", ""))
		if item:
			item.quantity = entry.get("quantity", 1)
			hotbar_slots[i] = item
			EventBus.hotbar_slot_changed.emit(i, hotbar_slots[i])

	for i in mini(raw_equip.size(), EQUIP_SLOTS):
		var entry = raw_equip[i]
		if entry == null: continue
		var item = Registry.get_item(entry.get("id", ""))
		if item and item is ArmourData:
			equip_slots[i] = item
			_apply_equipment_modifiers(item as ArmourData, true)
			EventBus.equipment_changed.emit(i, item)

# ── Hotbar sync helper ─────────────────────────────────────────────────────────

func _sync_hotbar_after_removal(slot_index: int) -> void:
	# If a hotbar slot was mirroring the removed slot, clear that hotbar entry
	for i in HOTBAR_SIZE:
		if hotbar_slots[i] != null and hotbar_slots[i] == slots[slot_index]:
			hotbar_slots[i] = null
			EventBus.hotbar_slot_changed.emit(i, null)
			break
