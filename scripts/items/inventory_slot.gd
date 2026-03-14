extends Resource
class_name InventorySlot

var item:  Item = null
var count: int  = 0

func is_empty() -> bool:
	return item == null

static func make(p_item: Item, p_count: int) -> InventorySlot:
	var slot    := InventorySlot.new()
	slot.item   = p_item
	slot.count  = p_count
	return slot

func to_dict() -> Dictionary:
	if is_empty():
		return { "empty": true }
	return {
		"item":  item.to_dict(),
		"count": count,
	}

func print_info() -> void:
	print(JSON.stringify(to_dict(), "\t"))
