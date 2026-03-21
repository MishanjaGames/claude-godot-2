# StructurePlacer.gd
# Called by ChunkManager after base terrain is placed.
# Uses a per-chunk seeded RNG so placement is always deterministic given the same seed.
# Reads StructureData .tres files from Registry.
class_name StructurePlacer
extends RefCounted

# ── Scene preloads ─────────────────────────────────────────────────────────────
const NPC_BASE_SCENE:  PackedScene = preload("res://scenes/entities/NPCBase.tscn")
const CHEST_SCENE:     PackedScene = preload("res://scenes/objects/Chest.tscn")
const DOOR_SCENE:      PackedScene = preload("res://scenes/objects/Door.tscn")
const WORLD_ITEM_SCENE:PackedScene = preload("res://scenes/entities/WorldItem.tscn")

# ── Injected ───────────────────────────────────────────────────────────────────
var _generator: WorldGenerator

## Tracks where each structure id was last placed: structure_id → Array[Vector2i] tile positions.
## Used for min_distance_tiles checks across chunks.
var _placement_log: Dictionary = {}

func setup(generator: WorldGenerator) -> void:
	_generator = generator

# ── Main entry point ───────────────────────────────────────────────────────────

## Called by ChunkManager once per new (never-before-generated) chunk.
## Writes tiles directly to tilemap and appends spawned nodes to chunk_objects.
func try_place_in_chunk(
		chunk_coords:  Vector2i,
		tilemap:       TileMap,
		object_layer:  Node2D,
		chunk_objects: Array
) -> void:
	var rng := _seeded_rng(chunk_coords)
	var chunk_origin_tile := chunk_coords * WorldManager.CHUNK_SIZE
	var biome := _generator.get_biome_at(chunk_origin_tile.x + WorldManager.CHUNK_SIZE / 2)

	for structure_id in biome.structure_ids:
		var structure := Registry.get_structure(structure_id)
		if structure == null:
			continue
		if rng.randf() > structure.spawn_chance:
			continue
		if not _check_min_distance(structure, chunk_origin_tile):
			continue

		var origin := _find_placement(structure, chunk_coords, rng)
		if origin == Vector2i(-1, -1):
			continue   # no valid position found

		_stamp_tiles(structure, origin, tilemap)
		_spawn_points(structure, origin, object_layer, chunk_objects)
		_record_placement(structure, origin)

# ── Tile stamping ──────────────────────────────────────────────────────────────

func _stamp_tiles(structure: StructureData, world_origin: Vector2i, tilemap: TileMap) -> void:
	for entry in structure.get_world_tile_entries(world_origin):
		var source_id: int      = entry.get("source_id", -1)
		var atlas: Vector2i     = entry.get("atlas_coord", Vector2i.ZERO)
		var world_pos: Vector2i = entry.get("world_pos", Vector2i.ZERO)
		var layer: int          = structure.tile_layer

		if source_id < 0:
			tilemap.erase_cell(layer, world_pos)
		else:
			tilemap.set_cell(layer, world_pos, source_id, atlas)
		# Record every stamped tile as a modification so SaveManager persists it.
		WorldManager.record_tile_change(world_pos, source_id, atlas)

# ── Spawn point instantiation ──────────────────────────────────────────────────

func _spawn_points(
		structure:     StructureData,
		world_origin:  Vector2i,
		object_layer:  Node2D,
		chunk_objects: Array
) -> void:
	for pt in structure.get_world_spawn_points(world_origin):
		var type: String    = pt.get("type", "")
		var world_tile: Vector2i = pt.get("world_pos", Vector2i.ZERO)
		var pixel_pos: Vector2   = WorldManager.tile_to_world_pos(world_tile)
		var node: Node2D

		match type:
			"npc":
				var npc_data := Registry.get_npc(pt.get("npc_id", ""))
				if npc_data == null: continue
				node = NPC_BASE_SCENE.instantiate()
				if node.has_method("setup"):
					node.setup(npc_data)

			"chest":
				node = CHEST_SCENE.instantiate()
				if node.has_method("setup"):
					node.setup(pt.get("drop_table_id", ""))

			"door":
				node = DOOR_SCENE.instantiate()
				if node.has_method("setup"):
					node.setup(pt.get("key_item_id", ""))

			"item":
				var item := Registry.get_item(pt.get("item_id", ""))
				if item == null: continue
				item.quantity = pt.get("qty", 1)
				node = WORLD_ITEM_SCENE.instantiate()
				if node.has_method("setup"):
					node.setup(item)

			_:
				continue

		object_layer.add_child(node)
		node.global_position = pixel_pos
		chunk_objects.append(node)

# ── Placement finding ──────────────────────────────────────────────────────────

## Tries up to 8 random x positions within the chunk to find a valid surface spot.
func _find_placement(structure: StructureData, chunk_coords: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var chunk_origin := chunk_coords * WorldManager.CHUNK_SIZE
	var half_w       := structure.size.x / 2

	for _attempt in 8:
		var local_x := rng.randi_range(half_w, WorldManager.CHUNK_SIZE - half_w - 1)
		var tx      := chunk_origin.x + local_x
		var surf_y  := _generator.get_surface_y_at(tx)

		if structure.is_underground:
			var depth := rng.randi_range(structure.min_depth, WorldManager.CHUNK_SIZE - structure.size.y)
			return Vector2i(tx - half_w, surf_y + depth)
		else:
			return Vector2i(tx - half_w, surf_y - structure.size.y + 1)

	return Vector2i(-1, -1)   # failed

# ── Distance / placement log ───────────────────────────────────────────────────

func _check_min_distance(structure: StructureData, chunk_tile_origin: Vector2i) -> bool:
	var past: Array = _placement_log.get(structure.id, [])
	for prev_origin in past:
		# Wrap-aware horizontal distance.
		var dx := absi(prev_origin.x - chunk_tile_origin.x)
		dx = mini(dx, WorldManager.WORLD_WIDTH_TILES - dx)   # planet wrap
		var dy := absi(prev_origin.y - chunk_tile_origin.y)
		if dx < structure.min_distance_tiles and dy < structure.min_distance_tiles:
			return false
	return true

func _record_placement(structure: StructureData, world_tile_origin: Vector2i) -> void:
	if not _placement_log.has(structure.id):
		_placement_log[structure.id] = []
	_placement_log[structure.id].append(world_tile_origin)

# ── RNG ───────────────────────────────────────────────────────────────────────

func _seeded_rng(chunk_coords: Vector2i) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(chunk_coords) ^ WorldManager.get_world_seed()
	return rng
