# InventoryManager.gd
# Global inventory. All item data lives here; UI reads from here.
extends Node

const INVENTORY_SIZE: int = 32
const HOTBAR_SIZE: int    = 8

var slots: Array        = []   # size = INVENTORY_SIZE, each entry: Item | null
var hotbar_slots: Array = []   # size = HOTBAR_SIZE
var active_hotbar_index: int = 0

func _ready() -> void:
	slots.resize(INVENTORY_SIZE)
	hotbar_slots.resize(HOTBAR_SIZE)
	slots.fill(null)
	hotbar_slots.fill(null)

# ── Public API ─────────────────────────────────────────────────────────────────

## Adds item to the first available slot. Returns true on success.
func add_item(item: Resource) -> bool:
	if item.stackable:
		for i in INVENTORY_SIZE:
			var s = slots[i]
			if s != null and s.id == item.id and s.quantity < s.max_stack:
				s.quantity += 1
				EventBus.inventory_item_added.emit(s, i)
				return true

	for i in INVENTORY_SIZE:
		if slots[i] == null:
			var new_item = item.duplicate()
			new_item.quantity = 1
			slots[i] = new_item
			EventBus.inventory_item_added.emit(new_item, i)
			return true

	push_warning("InventoryManager: Inventory full.")
	return false

## Removes and returns the item at slot_index, or null.
func remove_item(slot_index: int) -> Resource:
	if slot_index < 0 or slot_index >= INVENTORY_SIZE:
		return null
	var item = slots[slot_index]
	if item == null:
		return null
	slots[slot_index] = null
	EventBus.inventory_item_removed.emit(item, slot_index)
	return item

## Returns true if inventory contains at least one item with the given id.
func has_item(item_id: String) -> bool:
	for s in slots:
		if s != null and s.id == item_id:
			return true
	return false

## Swaps items between two slot indices.
func move_item(from_index: int, to_index: int) -> void:
	var temp = slots[to_index]
	slots[to_index]   = slots[from_index]
	slots[from_index] = temp

## Assigns the item at slot_index to a hotbar position.
func assign_to_hotbar(slot_index: int, hotbar_index: int) -> void:
	if hotbar_index < 0 or hotbar_index >= HOTBAR_SIZE:
		return
	hotbar_slots[hotbar_index] = slots[slot_index]
	EventBus.hotbar_slot_changed.emit(hotbar_index, hotbar_slots[hotbar_index])

## Returns the currently active hotbar item or null.
func get_active_item() -> Resource:
	return hotbar_slots[active_hotbar_index]

## Sets the active hotbar index and emits the changed signal.
func set_active_hotbar(index: int) -> void:
	active_hotbar_index = clamp(index, 0, HOTBAR_SIZE - 1)
	EventBus.hotbar_slot_changed.emit(active_hotbar_index, get_active_item())

## Clears all slots and hotbar slots.
func clear() -> void:
	slots.fill(null)
	hotbar_slots.fill(null)
	active_hotbar_index = 0

# ── Save / Load ────────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var data: Dictionary = {
		"slots":         [],
		"hotbar":        [],
		"active_hotbar": active_hotbar_index
	}
	for s in slots:
		data["slots"].append(null if s == null else {"id": s.id, "quantity": s.quantity})
	for h in hotbar_slots:
		data["hotbar"].append(null if h == null else {"id": h.id, "quantity": h.quantity})
	return data

func deserialize(data: Dictionary) -> void:
	clear()
	active_hotbar_index = data.get("active_hotbar", 0)

	var raw_slots: Array  = data.get("slots",  [])
	var raw_hotbar: Array = data.get("hotbar", [])

	for i in mini(raw_slots.size(), INVENTORY_SIZE):
		var entry = raw_slots[i]
		if entry == null:
			continue
		var item = ItemDatabase.get_item(entry.get("id", ""))
		if item != null:
			item.quantity = entry.get("quantity", 1)
			slots[i] = item

	for i in mini(raw_hotbar.size(), HOTBAR_SIZE):
		var entry = raw_hotbar[i]
		if entry == null:
			continue
		var item = ItemDatabase.get_item(entry.get("id", ""))
		if item != null:
			item.quantity = entry.get("quantity", 1)
			hotbar_slots[i] = item
			EventBus.hotbar_slot_changed.emit(i, hotbar_slots[i])
