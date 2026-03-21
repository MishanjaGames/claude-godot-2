# StructureData.gd
# Defines a pre-authored structure that WorldGenerator stamps into the world.
# "Stamp" means: copy tile data into the TileMap, spawn defined NPCs/items/chests.
# Create .tres files in res://data/structures/
class_name StructureData
extends Resource

# ── Identity ───────────────────────────────────────────────────────────────────
@export var id: String                          = ""
@export var display_name: String                = "Structure"

# ── Footprint ──────────────────────────────────────────────────────────────────
## Size of this structure in tiles (width × height).
@export var size: Vector2i                      = Vector2i(16, 12)
## Tile layer index this structure occupies on the TileMap.
@export var tile_layer: int                     = 0

# ── Tile data ──────────────────────────────────────────────────────────────────
## Serialised as an Array of Dictionaries:
## Each entry: { "local_pos": Vector2i, "source_id": int, "atlas_coord": Vector2i }
## Populated by the StructureEditor tool (Phase 2) or hand-authored.
@export var tile_entries: Array[Dictionary]     = []

# ── Spawn points ──────────────────────────────────────────────────────────────
## Array of Dictionaries — each defines something to spawn relative to structure origin.
## Formats:
##   NPC:   { "type": "npc",   "npc_id": String, "local_pos": Vector2i }
##   Item:  { "type": "item",  "item_id": String, "local_pos": Vector2i, "qty": int }
##   Chest: { "type": "chest", "drop_table_id": String, "local_pos": Vector2i }
##   Door:  { "type": "door",  "local_pos": Vector2i, "key_item_id": String }
@export var spawn_points: Array[Dictionary]     = []

# ── Placement rules ────────────────────────────────────────────────────────────
@export_group("Placement")
## Which biome ids this structure can appear in. Empty = any biome.
@export var allowed_biome_ids: Array[String]    = []
## Minimum tile distance from another structure of the same id.
@export var min_distance_tiles: int             = 128
## Per-chunk probability of attempting to place this structure.
@export var spawn_chance: float                 = 0.02
## If true, structure is carved into terrain (caves, dungeons). If false, built on surface.
@export var is_underground: bool                = false
## Minimum depth below surface (in tiles) for underground structures.
@export var min_depth: int                      = 20

# ── Helpers ───────────────────────────────────────────────────────────────────

func can_spawn_in_biome(biome_id: String) -> bool:
	return allowed_biome_ids.is_empty() or biome_id in allowed_biome_ids

## Returns tile entries converted to world tile positions given a world origin.
func get_world_tile_entries(origin: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in tile_entries:
		var world_entry = entry.duplicate()
		world_entry["world_pos"] = origin + entry.get("local_pos", Vector2i.ZERO)
		result.append(world_entry)
	return result

## Returns spawn points in world tile space given a world origin.
func get_world_spawn_points(origin: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pt in spawn_points:
		var world_pt = pt.duplicate()
		world_pt["world_pos"] = origin + pt.get("local_pos", Vector2i.ZERO)
		result.append(world_pt)
	return result
