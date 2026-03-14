# LootTable.gd
# Weighted random loot roller.
class_name LootTable
extends Resource

## Each entry: { "item": Item, "weight": float, "min_qty": int, "max_qty": int }
@export var drops: Array[Dictionary] = []

## Rolls the table and returns an Array of Item resources.
func roll() -> Array:
	var result: Array = []
	for entry in drops:
		var item: Resource = entry.get("item", null)
		if item == null:
			continue
		var weight: float  = entry.get("weight", 1.0)
		var min_q: int     = entry.get("min_qty", 1)
		var max_q: int     = entry.get("max_qty", 1)
		# Weighted chance: weight is treated as a 0-100 percent probability
		if randf() * 100.0 <= weight:
			var qty = randi_range(min_q, max_q)
			for _i in qty:
				var drop = item.duplicate()
				result.append(drop)
	return result
