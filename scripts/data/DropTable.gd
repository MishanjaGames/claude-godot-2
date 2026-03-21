# DropTable.gd
# Weighted random loot roller used by NPCs, Harvestables, and Chests.
# Create .tres files in res://data/drops/ — they are auto-loaded by Registry.
#
# DROP ENTRY FORMAT:
#   {
#     "item_id":   String,   # must exist in Registry
#     "weight":    float,    # 0–100 probability percentage
#     "min_qty":   int,
#     "max_qty":   int,
#     "condition": String,   # optional — "" = always eligible
#   }
#
# GUARANTEED ENTRY FORMAT (always included, no roll):
#   { "item_id": String, "min_qty": int, "max_qty": int }
class_name DropTable
extends Resource

@export var id: String                      = ""
@export var drops: Array[Dictionary]        = []
@export var guaranteed_drops: Array[Dictionary] = []

## Rolls the table and returns an Array of { item_id, quantity } dicts.
## luck_modifier: multiplied against each weight (e.g. 1.2 = +20% all chances).
func roll(luck_modifier: float = 1.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	# Guaranteed drops first
	for entry in guaranteed_drops:
		var qty = randi_range(
			entry.get("min_qty", 1),
			entry.get("max_qty", 1)
		)
		result.append({ "item_id": entry.get("item_id", ""), "quantity": qty })

	# Weighted probabilistic drops
	for entry in drops:
		var weight: float = entry.get("weight", 0.0) * luck_modifier
		if weight <= 0.0:
			continue
		if randf() * 100.0 <= weight:
			var qty = randi_range(
				entry.get("min_qty", 1),
				entry.get("max_qty", 1)
			)
			result.append({ "item_id": entry.get("item_id", ""), "quantity": qty })

	return result

## Rolls and returns actual ItemData resources (duplicated, ready to add to inventory).
func roll_items(luck_modifier: float = 1.0) -> Array:
	var raw = roll(luck_modifier)
	var items: Array = []
	for entry in raw:
		var item = Registry.get_item(entry.item_id)
		if item == null:
			continue
		item.quantity = entry.quantity
		items.append(item)
	return items
