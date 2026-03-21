# ItemDatabase.gd
# Global registry: item_id (String) → Item resource.
# All items must be registered here before save/load can restore them.
#
# HOW TO REGISTER ITEMS:
#   Option A — preload .tres files (recommended for production):
#       _register(preload("res://assets/items/health_potion.tres"))
#
#   Option B — build items in code (great for prototyping):
#       var potion := ConsumableItem.new()
#       potion.id = "health_potion"
#       ...
#       _register(potion)
#
# Both options work identically at runtime.
extends Node

# ── Registry ───────────────────────────────────────────────────────────────────
var _items: Dictionary = {}   # id → Item resource

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_register_all()

func _register_all() -> void:
	# ── Consumables ────────────────────────────────────────────────────────────
	_register(_make_health_potion())
	_register(_make_stamina_potion())
	_register(_make_mega_potion())

	# ── Melee weapons ──────────────────────────────────────────────────────────
	_register(_make_iron_sword())
	_register(_make_wooden_club())
	_register(_make_dagger())

	# ── Ranged weapons ─────────────────────────────────────────────────────────
	_register(_make_bow())
	_register(_make_crossbow())

	# ── Tools ──────────────────────────────────────────────────────────────────
	_register(_make_axe())
	_register(_make_pickaxe())
	_register(_make_shovel())

	# ── Key items ──────────────────────────────────────────────────────────────
	_register(_make_iron_key())
	_register(_make_ancient_relic())

# ── Public API ─────────────────────────────────────────────────────────────────

## Returns the Item resource for the given id, or null if not found.
func get_item(id: String) -> Resource:
	if _items.has(id):
		return _items[id].duplicate()   # always return a fresh copy
	push_warning("ItemDatabase.get_item: unknown id '%s'" % id)
	return null

## Returns true if the id is registered.
func has_item(id: String) -> bool:
	return _items.has(id)

## Manually register an item at runtime (e.g. from a mod or DLC).
func register_item(item: Resource) -> void:
	_register(item)

# ── Internal ───────────────────────────────────────────────────────────────────

func _register(item: Resource) -> void:
	if item == null:
		return
	if not "id" in item or item.id == "":
		push_warning("ItemDatabase._register: item has no id, skipping.")
		return
	_items[item.id] = item

# ══════════════════════════════════════════════════════════════════════════════
# ITEM TEMPLATES
# Each function returns a fully configured Item resource ready for use.
# Replace icon = null with your actual Texture2D resources.
# ══════════════════════════════════════════════════════════════════════════════

# ── Consumables ────────────────────────────────────────────────────────────────

func _make_health_potion() -> ConsumableItem:
	var i := ConsumableItem.new()
	i.id             = "health_potion"
	i.display_name   = "Health Potion"
	i.description    = "Restores 30 HP."
	i.icon           = null   # replace: preload("res://assets/sprites/items/health_potion.png")
	i.stackable      = true
	i.max_stack      = 10
	i.weight         = 0.3
	i.heal_amount    = 30
	return i

func _make_stamina_potion() -> ConsumableItem:
	var i := ConsumableItem.new()
	i.id               = "stamina_potion"
	i.display_name     = "Stamina Potion"
	i.description      = "Restores 50 stamina."
	i.icon             = null
	i.stackable        = true
	i.max_stack        = 10
	i.weight           = 0.3
	i.stamina_restore  = 50.0
	return i

func _make_mega_potion() -> ConsumableItem:
	var i := ConsumableItem.new()
	i.id               = "mega_potion"
	i.display_name     = "Mega Potion"
	i.description      = "Restores 60 HP and 60 stamina."
	i.icon             = null
	i.stackable        = true
	i.max_stack        = 5
	i.weight           = 0.5
	i.heal_amount      = 60
	i.stamina_restore  = 60.0
	return i

# ── Melee weapons ──────────────────────────────────────────────────────────────

func _make_iron_sword() -> MeleeWeapon:
	var i := MeleeWeapon.new()
	i.id              = "iron_sword"
	i.display_name    = "Iron Sword"
	i.description     = "A sturdy iron blade."
	i.icon            = null
	i.stackable       = false
	i.weight          = 2.5
	i.damage          = 18
	i.attack_speed    = 1.2
	i.attack_range    = 52.0
	i.knockback_force = 180.0
	return i

func _make_wooden_club() -> MeleeWeapon:
	var i := MeleeWeapon.new()
	i.id              = "wooden_club"
	i.display_name    = "Wooden Club"
	i.description     = "Slow but heavy. Sends foes flying."
	i.icon            = null
	i.stackable       = false
	i.weight          = 3.0
	i.damage          = 24
	i.attack_speed    = 0.7
	i.attack_range    = 48.0
	i.knockback_force = 320.0
	return i

func _make_dagger() -> MeleeWeapon:
	var i := MeleeWeapon.new()
	i.id              = "dagger"
	i.display_name    = "Dagger"
	i.description     = "Light and quick. Low damage, high speed."
	i.icon            = null
	i.stackable       = false
	i.weight          = 0.8
	i.damage          = 9
	i.attack_speed    = 2.5
	i.attack_range    = 36.0
	i.knockback_force = 60.0
	return i

# ── Ranged weapons ─────────────────────────────────────────────────────────────

func _make_bow() -> RangedWeapon:
	var i := RangedWeapon.new()
	i.id            = "bow"
	i.display_name  = "Wooden Bow"
	i.description   = "A simple shortbow. Fires toward the cursor."
	i.icon          = null
	i.stackable     = false
	i.weight        = 1.2
	i.damage        = 14
	i.attack_speed  = 1.0
	i.attack_range  = 400.0
	i.ammo_count    = 20
	i.reload_time   = 2.0
	return i

func _make_crossbow() -> RangedWeapon:
	var i := RangedWeapon.new()
	i.id            = "crossbow"
	i.display_name  = "Crossbow"
	i.description   = "Hard to reload, hits hard."
	i.icon          = null
	i.stackable     = false
	i.weight        = 2.0
	i.damage        = 28
	i.attack_speed  = 0.5
	i.attack_range  = 500.0
	i.ammo_count    = 10
	i.reload_time   = 3.5
	return i

# ── Tools ──────────────────────────────────────────────────────────────────────

func _make_axe() -> Tool:
	var i := Tool.new()
	i.id           = "axe"
	i.display_name = "Woodcutter's Axe"
	i.description  = "Chops trees. Tool power 2."
	i.icon         = null
	i.stackable    = false
	i.weight       = 2.2
	i.tool_type    = Tool.ToolType.AXE
	i.tool_power   = 2
	return i

func _make_pickaxe() -> Tool:
	var i := Tool.new()
	i.id           = "pickaxe"
	i.display_name = "Iron Pickaxe"
	i.description  = "Mines stone and ore. Tool power 2."
	i.icon         = null
	i.stackable    = false
	i.weight       = 2.5
	i.tool_type    = Tool.ToolType.PICKAXE
	i.tool_power   = 2
	return i

func _make_shovel() -> Tool:
	var i := Tool.new()
	i.id           = "shovel"
	i.display_name = "Shovel"
	i.description  = "Digs soil and sand. Tool power 1."
	i.icon         = null
	i.stackable    = false
	i.weight       = 1.5
	i.tool_type    = Tool.ToolType.SHOVEL
	i.tool_power   = 1
	return i

# ── Key items ──────────────────────────────────────────────────────────────────

func _make_iron_key() -> KeyItem:
	var i := KeyItem.new()
	i.id           = "iron_key"
	i.display_name = "Iron Key"
	i.description  = "Opens an iron-locked door."
	i.icon         = null
	i.stackable    = false
	i.weight       = 0.1
	i.quest_id     = ""
	i.unlocks      = "IronDoor"   # match this to a door node's name
	return i

func _make_ancient_relic() -> KeyItem:
	var i := KeyItem.new()
	i.id           = "ancient_relic"
	i.display_name = "Ancient Relic"
	i.description  = "A mysterious artefact tied to an old quest."
	i.icon         = null
	i.stackable    = false
	i.weight       = 0.5
	i.quest_id     = "quest_ancient_temple"
	i.unlocks      = ""
	return i
