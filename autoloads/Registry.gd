# Registry.gd
# Global data registry. Scans res://data/ subfolders on startup and indexes
# every Resource by its `id` field. Replaces ItemDatabase.
#
# ADDING NEW CONTENT:
#   Just drop a .tres file in the correct res://data/ subfolder.
#   No code changes needed — Registry picks it up automatically on next run.
#
# LOAD ORDER: after EventBus, before GameManager and InventoryManager.
extends Node

# ── Typed dictionaries (id → Resource) ────────────────────────────────────────
var _items:        Dictionary = {}   # ItemData and all subclasses
var _npcs:         Dictionary = {}   # NPCData
var _biomes:       Dictionary = {}   # BiomeData
var _harvestables: Dictionary = {}   # HarvestableData
var _structures:   Dictionary = {}   # StructureData
var _drop_tables:  Dictionary = {}   # DropTable

# Subfolder → target dictionary mapping
const _FOLDERS: Array[Dictionary] = [
	{ "path": "res://data/items/",        "dict": "_items"        },
	{ "path": "res://data/weapons/",      "dict": "_items"        },
	{ "path": "res://data/consumables/",  "dict": "_items"        },
	{ "path": "res://data/armour/",       "dict": "_items"        },
	{ "path": "res://data/key_items/",    "dict": "_items"        },
	{ "path": "res://data/npcs/",         "dict": "_npcs"         },
	{ "path": "res://data/biomes/",       "dict": "_biomes"       },
	{ "path": "res://data/harvestables/", "dict": "_harvestables" },
	{ "path": "res://data/structures/",   "dict": "_structures"   },
	{ "path": "res://data/drops/",        "dict": "_drop_tables"  },
]

func _ready() -> void:
	for entry in _FOLDERS:
		_load_folder(entry["path"], get(entry["dict"]))
	print("Registry: loaded %d items, %d NPCs, %d biomes, %d harvestables, %d structures, %d drop tables." % [
		_items.size(), _npcs.size(), _biomes.size(),
		_harvestables.size(), _structures.size(), _drop_tables.size()
	])

# ── Public getters ─────────────────────────────────────────────────────────────

## Returns a duplicate of the ItemData for `id`, or null.
## Always duplicated so runtime quantity/state doesn't bleed between instances.
func get_item(id: String) -> ItemData:
	if _items.has(id):
		return _items[id].duplicate()
	push_warning("Registry.get_item: unknown id '%s'" % id)
	return null

func get_npc(id: String) -> NPCData:
	if _npcs.has(id):
		return _npcs[id]
	push_warning("Registry.get_npc: unknown id '%s'" % id)
	return null

func get_biome(id: String) -> BiomeData:
	if _biomes.has(id):
		return _biomes[id]
	push_warning("Registry.get_biome: unknown id '%s'" % id)
	return null

func get_harvestable(id: String) -> HarvestableData:
	if _harvestables.has(id):
		return _harvestables[id]
	push_warning("Registry.get_harvestable: unknown id '%s'" % id)
	return null

func get_structure(id: String) -> StructureData:
	if _structures.has(id):
		return _structures[id]
	push_warning("Registry.get_structure: unknown id '%s'" % id)
	return null

func get_drop_table(id: String) -> DropTable:
	if _drop_tables.has(id):
		return _drop_tables[id]
	push_warning("Registry.get_drop_table: unknown id '%s'" % id)
	return null

# ── Existence checks ──────────────────────────────────────────────────────────
func has_item(id: String)        -> bool: return _items.has(id)
func has_npc(id: String)         -> bool: return _npcs.has(id)
func has_biome(id: String)       -> bool: return _biomes.has(id)
func has_harvestable(id: String) -> bool: return _harvestables.has(id)
func has_structure(id: String)   -> bool: return _structures.has(id)
func has_drop_table(id: String)  -> bool: return _drop_tables.has(id)

# ── Bulk accessors ────────────────────────────────────────────────────────────
func all_items()        -> Array: return _items.values()
func all_npcs()         -> Array: return _npcs.values()
func all_biomes()       -> Array: return _biomes.values()
func all_harvestables() -> Array: return _harvestables.values()
func all_structures()   -> Array: return _structures.values()

# ── Runtime registration (mods / dynamic content) ─────────────────────────────

func register_item(item: ItemData) -> void:
	_register(item, _items)

func register_npc(npc: NPCData) -> void:
	_register(npc, _npcs)

# ── Internal ───────────────────────────────────────────────────────────────────

func _load_folder(path: String, dict: Dictionary) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return   # folder doesn't exist yet — fine during early development
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var full_path = path + file_name
			var res = load(full_path)
			if res == null:
				push_warning("Registry: failed to load '%s'" % full_path)
			else:
				_register(res, dict)
		file_name = dir.get_next()
	dir.list_dir_end()

func _register(res: Resource, dict: Dictionary) -> void:
	if not "id" in res:
		push_warning("Registry: resource has no 'id' field — skipping (%s)" % res.resource_path)
		return
	if res.id.is_empty():
		push_warning("Registry: resource has empty id — skipping (%s)" % res.resource_path)
		return
	if dict.has(res.id):
		push_warning("Registry: duplicate id '%s' — overwriting with %s" % [res.id, res.resource_path])
	dict[res.id] = res
