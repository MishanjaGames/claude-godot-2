# RecipeData.gd
# Data resource defining one crafting recipe.
# Create .tres files in res://data/recipes/ — Registry auto-loads them.
#
# INGREDIENT FORMAT:
#   { "item_id": String, "quantity": int }
#
# EXAMPLE:
#   id            = "recipe_iron_sword"
#   ingredients   = [{"item_id": "iron_ore", "quantity": 3},
#                    {"item_id": "wood",     "quantity": 1}]
#   result_id     = "iron_sword"
#   result_qty    = 1
#   station       = FORGE
class_name RecipeData
extends Resource

enum CraftStation {
	HAND,       # no station needed — craft anywhere
	WORKBENCH,  # basic crafting table
	FORGE,      # metalworking
	ALCHEMY,    # potions and consumables
	LOOM,       # cloth and armour
}

@export var id:           String      = ""
@export var result_id:    String      = ""     # ItemData id to produce
@export var result_qty:   int         = 1
@export var ingredients:  Array[Dictionary] = []
@export var station:      CraftStation = CraftStation.HAND
@export var unlock_level: int         = 1      # minimum player level to see recipe
@export var xp_reward:    int         = 5      # XP granted on craft

## Returns true if the player's inventory contains all required ingredients.
func can_craft() -> bool:
	for ing in ingredients:
		var item_id:  String = ing.get("item_id",  "")
		var required: int    = ing.get("quantity", 1)
		if InventoryManager.count_item(item_id) < required:
			return false
	return true

## Consumes ingredients from inventory. Call only after can_craft() returns true.
func consume_ingredients() -> void:
	for ing in ingredients:
		var item_id:  String = ing.get("item_id",  "")
		var required: int    = ing.get("quantity", 1)
		var remaining := required
		for i in InventoryManager.INVENTORY_SIZE:
			var slot := InventoryManager.slots[i]
			if slot == null or slot.id != item_id:
				continue
			var take := mini(slot.quantity, remaining)
			slot.quantity -= take
			remaining     -= take
			if slot.quantity <= 0:
				InventoryManager.remove_item(i)
			if remaining <= 0:
				break
