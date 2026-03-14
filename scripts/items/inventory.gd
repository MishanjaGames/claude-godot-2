extends Resource
class_name Inventory

# ─── Signals ──────────────────────────────────────────────
signal item_added(item: Item, slot: int)
signal item_removed(item: Item, slot: int)
signal item_used(item: Item, slot: int)
signal stack_changed(slot: int, new_count: int)
signal inventory_full()

# ─── Config ───────────────────────────────────────────────
@export var capacity: int = 20

# ─── Internal state (now fully typed) ─────────────────────
var _slots: Array[InventorySlot] = []


# ══════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════

func initialize(slot_count: int = capacity) -> void:
	capacity = slot_count
	_slots.clear()
	for i in capacity:
		_slots.append(InventorySlot.new())  # empty slot


# ══════════════════════════════════════════════════════════
# ADD
# ══════════════════════════════════════════════════════════

func add_item(item: Item, count: int = 1) -> bool:
	var remaining: int = count

	# Try to top up existing stacks first
	if item.stackable:
		for i in _slots.size():
			if remaining <= 0:
				break
			var slot := _slots[i]
			if not slot.is_empty() and slot.item.id == item.id:
				var space: int = item.max_stack - slot.count
				var to_add: int = mini(space, remaining)
				slot.count += to_add
				remaining  -= to_add
				stack_changed.emit(i, slot.count)

	# Fill empty slots with the remainder
	for i in _slots.size():
		if remaining <= 0:
			break
		if _slots[i].is_empty():
			var to_add: int = mini(item.max_stack if item.stackable else 1, remaining)
			_slots[i] = InventorySlot.make(item, to_add)
			remaining -= to_add
			item_added.emit(item, i)

	if remaining > 0:
		inventory_full.emit()
		return false
	return true


# ══════════════════════════════════════════════════════════
# REMOVE
# ══════════════════════════════════════════════════════════

func remove_at(slot: int, count: int = 1) -> bool:
	if not _is_valid_slot(slot) or _slots[slot].is_empty():
		return false

	var entry := _slots[slot]
	entry.count -= count

	if entry.count <= 0:
		var removed_item := entry.item
		_slots[slot] = InventorySlot.new()  # reset to empty
		item_removed.emit(removed_item, slot)
	else:
		stack_changed.emit(slot, entry.count)

	return true

func remove_item(item_id: String, count: int = 1) -> bool:
	var slot: int = find_item(item_id)
	if slot == -1:
		return false
	return remove_at(slot, count)


# ══════════════════════════════════════════════════════════
# USE
# ══════════════════════════════════════════════════════════

func use_item(slot: int, user: Node) -> void:
	if not _is_valid_slot(slot) or _slots[slot].is_empty():
		return
	var entry := _slots[slot]
	entry.item.use(user)
	item_used.emit(entry.item, slot)


# ══════════════════════════════════════════════════════════
# QUERY
# ══════════════════════════════════════════════════════════

func find_item(item_id: String) -> int:
	for i in _slots.size():
		if not _slots[i].is_empty() and _slots[i].item.id == item_id:
			return i
	return -1

func has_item(item_id: String) -> bool:
	return find_item(item_id) != -1

func count_item(item_id: String) -> int:
	var total: int = 0
	for slot in _slots:
		if not slot.is_empty() and slot.item.id == item_id:
			total += slot.count
	return total

func get_slot(slot: int) -> InventorySlot:
	if not _is_valid_slot(slot):
		return InventorySlot.new()
	return _slots[slot]

func get_all_items() -> Array[InventorySlot]:
	var result: Array[InventorySlot] = []
	for slot in _slots:
		if not slot.is_empty():
			result.append(slot)
	return result

func is_full() -> bool:
	for slot in _slots:
		if slot.is_empty():
			return false
	return true

func is_empty() -> bool:
	for slot in _slots:
		if not slot.is_empty():
			return false
	return true


# ══════════════════════════════════════════════════════════
# MOVE / SWAP
# ══════════════════════════════════════════════════════════

func swap_slots(slot_a: int, slot_b: int) -> void:
	if not _is_valid_slot(slot_a) or not _is_valid_slot(slot_b):
		return
	var temp    := _slots[slot_a]
	_slots[slot_a] = _slots[slot_b]
	_slots[slot_b] = temp

# ══════════════════════════════════════════════════════════
# DEBUG / DISPLAY
# ══════════════════════════════════════════════════════════

# Full snapshot of every slot (including empty ones)
func to_dict() -> Dictionary:
	var slots_arr: Array = []
	for i in _slots.size():
		var entry: Dictionary = _slots[i].to_dict()
		entry["slot"] = i
		slots_arr.append(entry)
	return {
		"capacity": capacity,
		"used":     capacity - _count_empty(),
		"slots":    slots_arr,
	}

# Only occupied slots — less noise for quick inspection
func to_dict_compact() -> Dictionary:
	var slots_arr: Array = []
	for i in _slots.size():
		if not _slots[i].is_empty():
			var entry: Dictionary = _slots[i].to_dict()
			entry["slot"] = i
			slots_arr.append(entry)
	return {
		"capacity": capacity,
		"used":     capacity - _count_empty(),
		"slots":    slots_arr,
	}

func print_info(compact: bool = true) -> void:
	var data := to_dict_compact() if compact else to_dict()
	print(JSON.stringify(data, "\t"))

func _count_empty() -> int:
	var n: int = 0
	for slot in _slots:
		if slot.is_empty():
			n += 1
	return n

# ══════════════════════════════════════════════════════════
# PRIVATE
# ══════════════════════════════════════════════════════════

func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < _slots.size()
