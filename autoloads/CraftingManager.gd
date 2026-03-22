# CraftingManager.gd
# Autoload for all crafting logic.
# Recipes are loaded from res://data/recipes/ by Registry (same pattern as items).
# Station validation is done against the player's proximity — stations register
# themselves to groups ("station_workbench", "station_forge", etc.)
#
# LOAD ORDER: after Registry, InventoryManager.
extends Node

# ── Active station ─────────────────────────────────────────────────────────────
## Set when the player opens a crafting station. CraftingUI reads this.
var active_station: RecipeData.CraftStation = RecipeData.CraftStation.HAND
var _near_station_nodes: Dictionary = {}   # CraftStation → Node

# ══════════════════════════════════════════════════════════════════════════════
# RECIPE QUERIES
# ══════════════════════════════════════════════════════════════════════════════

## All recipes available at the given station that the player meets the level for.
func available_recipes(station: RecipeData.CraftStation) -> Array:
	var level := CombatManager.current_level
	var result: Array = []
	for recipe in Registry.all_items():   # recipes stored via Registry too
		if not recipe is RecipeData:
			continue
		if recipe.station != station:
			continue
		if recipe.unlock_level > level:
			continue
		result.append(recipe)
	return result

## Recipes the player can craft right now (ingredients present).
func craftable_recipes(station: RecipeData.CraftStation) -> Array:
	return available_recipes(station).filter(func(r): return r.can_craft())

# ══════════════════════════════════════════════════════════════════════════════
# CRAFT EXECUTION
# ══════════════════════════════════════════════════════════════════════════════

## Attempt to craft a recipe. Returns true on success.
func craft(recipe: RecipeData) -> bool:
	if not recipe.can_craft():
		EventBus.hud_show_message.emit("Missing ingredients.", 2.0)
		return false

	if not _station_available(recipe.station):
		EventBus.hud_show_message.emit(
			"Need a %s." % _station_name(recipe.station), 2.0)
		return false

	recipe.consume_ingredients()

	var result := Registry.get_item(recipe.result_id)
	if result == null:
		push_warning("CraftingManager: result_id '%s' not in Registry." % recipe.result_id)
		return false

	result.quantity = recipe.result_qty
	if not InventoryManager.add_item(result):
		EventBus.hud_show_message.emit("Inventory full!", 2.0)
		return false

	EventBus.hud_show_message.emit("Crafted: %s" % result.display_name, 2.0)
	EventBus.inventory_item_used.emit(result, GameManager.player_ref)

	if recipe.xp_reward > 0:
		EventBus.experience_gained.emit(recipe.xp_reward, "crafting")

	return true

# ══════════════════════════════════════════════════════════════════════════════
# STATION PROXIMITY
# ══════════════════════════════════════════════════════════════════════════════

## Called by CraftingStation nodes in their _ready() / body_entered callbacks.
func register_nearby_station(station: RecipeData.CraftStation, node: Node) -> void:
	_near_station_nodes[station] = node

func unregister_nearby_station(station: RecipeData.CraftStation) -> void:
	_near_station_nodes.erase(station)

func _station_available(station: RecipeData.CraftStation) -> bool:
	if station == RecipeData.CraftStation.HAND:
		return true
	return _near_station_nodes.has(station)

func _station_name(station: RecipeData.CraftStation) -> String:
	match station:
		RecipeData.CraftStation.WORKBENCH: return "Workbench"
		RecipeData.CraftStation.FORGE:     return "Forge"
		RecipeData.CraftStation.ALCHEMY:   return "Alchemy Table"
		RecipeData.CraftStation.LOOM:      return "Loom"
		_:                                 return "Crafting Station"

# ══════════════════════════════════════════════════════════════════════════════
# SAVE / LOAD  (no state to save — recipes are always derived from Registry)
# ══════════════════════════════════════════════════════════════════════════════

func serialize() -> Dictionary:   return {}
func deserialize(_data: Dictionary) -> void: pass
