# ChunkManager.gd
# Node that lives in World.tscn.
# Maintains a LOAD_RADIUS-chunk grid of active tiles around the player.
# Calls WorldGenerator for first-time generation, WorldManager for delta replays.
#
# SCENE SETUP:
#   Add ChunkManager as a child of World (Node2D root).
#   Call setup() from World._ready() after TileMap and ObjectLayer are in the tree.
class_name ChunkManager
extends Node

# ── Tunables ───────────────────────────────────────────────────────────────────
## Chunks loaded in each cardinal direction from player. 2 = 5×5 = 25 active chunks.
const LOAD_RADIUS: int = 2
## Must match WorldManager.WORLD_WIDTH_TILES / WorldManager.CHUNK_SIZE.
const TOTAL_CHUNKS_X: int = 2048   # 65536 / 32
const TOTAL_CHUNKS_Y: int = 128    # 4096  / 32

# ── Injected references (set by World via setup()) ─────────────────────────────
var _tilemap:      TileMap
var _object_layer: Node2D
var _generator:    WorldGenerator
var _placer:       StructurePlacer

# ── Runtime state ──────────────────────────────────────────────────────────────
var _player_chunk:  Vector2i = Vector2i(-9999, -9999)
## chunk_coords → true  (which chunks currently have tiles in the TileMap)
var _loaded_chunks: Dictionary = {}
## chunk_coords → Array[Node2D]  (which object scenes belong to each chunk)
var _chunk_objects: Dictionary = {}

# ── Preload ────────────────────────────────────────────────────────────────────
const HARVESTABLE_SCENE: PackedScene = preload("res://scenes/objects/Harvestable.tscn")
const WORLD_ITEM_SCENE:  PackedScene = preload("res://scenes/entities/WorldItem.tscn")

# ── Setup ──────────────────────────────────────────────────────────────────────

func setup(tilemap: TileMap, object_layer: Node2D) -> void:
	_tilemap      = tilemap
	_object_layer = object_layer
	_generator    = WorldGenerator.new()
	_placer       = StructurePlacer.new()
	_generator.setup(WorldManager.get_world_seed())
	_placer.setup(_generator)
	EventBus.world_item_spawned.connect(_on_world_item_spawned)
	EventBus.tile_changed.connect(_on_tile_changed)

# ── Per-frame update (called from World._physics_process) ─────────────────────

## Call every physics frame with the player's current world pixel position.
func update_for_player(player_world_pos: Vector2) -> void:
	var new_chunk := WorldManager.world_pos_to_chunk(player_world_pos)

	if new_chunk == _player_chunk:
		return

	var old_chunk := _player_chunk
	_player_chunk  = new_chunk

	# Build old and new desired sets.
	var old_set := _desired_set(old_chunk)
	var new_set := _desired_set(new_chunk)

	# Unload chunks that left the desired set.
	for coords in old_set:
		if not new_set.has(coords):
			_unload_chunk(coords)

	# Load chunks that entered the desired set.
	for coords in new_set:
		if not _loaded_chunks.has(coords):
			_load_chunk(coords)

	if old_chunk != Vector2i(-9999, -9999):
		EventBus.player_chunk_changed.emit(old_chunk, new_chunk)

## Force-load the initial set of chunks at a given position (call from World._ready()).
func load_initial(player_world_pos: Vector2) -> void:
	_player_chunk = WorldManager.world_pos_to_chunk(player_world_pos)
	for coords in _desired_set(_player_chunk):
		_load_chunk(coords)

# ── Load / unload ──────────────────────────────────────────────────────────────

func _load_chunk(chunk_coords: Vector2i) -> void:
	if _loaded_chunks.has(chunk_coords):
		return

	_loaded_chunks[chunk_coords] = true
	_chunk_objects[chunk_coords] = []

	if WorldManager.is_chunk_generated(chunk_coords):
		# Replay only the recorded modifications — base tiles are implicit.
		_apply_chunk_base(chunk_coords)
		_apply_chunk_delta(chunk_coords)
	else:
		# First-time generation.
		var result := _generator.generate_chunk(chunk_coords, WorldManager.get_world_seed())
		_apply_tiles(result["tiles"])
		_spawn_objects(result["objects"], chunk_coords)
		_placer.try_place_in_chunk(chunk_coords, _tilemap, _object_layer, _chunk_objects[chunk_coords])
		WorldManager.mark_chunk_generated(chunk_coords)

	EventBus.chunk_loaded.emit(chunk_coords)

func _unload_chunk(chunk_coords: Vector2i) -> void:
	if not _loaded_chunks.has(chunk_coords):
		return

	# Remove all objects belonging to this chunk.
	var objects: Array = _chunk_objects.get(chunk_coords, [])
	for obj in objects:
		if is_instance_valid(obj):
			obj.queue_free()
	_chunk_objects.erase(chunk_coords)

	# Erase TileMap cells.
	var origin := chunk_coords * WorldManager.CHUNK_SIZE
	for lx in WorldManager.CHUNK_SIZE:
		for ly in WorldManager.CHUNK_SIZE:
			var tp := origin + Vector2i(lx, ly)
			_tilemap.erase_cell(WorldGenerator.TERRAIN_LAYER, tp)
			_tilemap.erase_cell(WorldGenerator.BACKGROUND_LAYER, tp)

	_loaded_chunks.erase(chunk_coords)
	EventBus.chunk_unloaded.emit(chunk_coords)

# ── Tile application ───────────────────────────────────────────────────────────

func _apply_tiles(tiles: Array) -> void:
	for t in tiles:
		_tilemap.set_cell(
			WorldGenerator.TERRAIN_LAYER,
			t["tile_pos"],
			t["source_id"],
			t["atlas_coord"]
		)

## Regenerate the base terrain for an already-generated chunk so deltas overlay correctly.
func _apply_chunk_base(chunk_coords: Vector2i) -> void:
	var result := _generator.generate_chunk(chunk_coords, WorldManager.get_world_seed())
	_apply_tiles(result["tiles"])
	# Don't re-spawn objects for already-generated chunks — delta handles them.

## Apply WorldManager's recorded tile modifications on top of base terrain.
func _apply_chunk_delta(chunk_coords: Vector2i) -> void:
	var delta := WorldManager.get_chunk_delta(chunk_coords)
	for key in delta:
		var entry: Dictionary = delta[key]
		var parts := key.split(",")
		var tp := Vector2i(int(parts[0]), int(parts[1]))
		var source_id: int = entry.get("source_id", -1)
		if source_id < 0:
			_tilemap.erase_cell(WorldGenerator.TERRAIN_LAYER, tp)
		else:
			_tilemap.set_cell(WorldGenerator.TERRAIN_LAYER, tp,
				source_id, entry.get("atlas_coord", Vector2i.ZERO))

# ── Object spawning ────────────────────────────────────────────────────────────

func _spawn_objects(objects: Array, chunk_coords: Vector2i) -> void:
	for entry in objects:
		var harvestable_id: String = entry.get("harvestable_id", "")
		var tile_pos: Vector2i     = entry.get("tile_pos", Vector2i.ZERO)

		var data := Registry.get_harvestable(harvestable_id)
		if data == null:
			continue

		var node: Node2D = HARVESTABLE_SCENE.instantiate()
		_object_layer.add_child(node)
		# Position on top of the surface tile (anchor at tile centre bottom).
		node.global_position = WorldManager.tile_to_world_pos(tile_pos)
		if node.has_method("setup"):
			node.setup(data)

		_chunk_objects[chunk_coords].append(node)

# ── Runtime tile modification ──────────────────────────────────────────────────

## Called when a tile is destroyed or placed at runtime (mining, building).
## Propagates the change to WorldManager for persistence.
func modify_tile(world_tile_pos: Vector2i, source_id: int, atlas_coord: Vector2i) -> void:
	_tilemap.set_cell(WorldGenerator.TERRAIN_LAYER, world_tile_pos, source_id, atlas_coord)
	WorldManager.record_tile_change(world_tile_pos, source_id, atlas_coord)
	EventBus.tile_changed.emit(world_tile_pos,
		_tilemap.get_cell_source_id(WorldGenerator.TERRAIN_LAYER, world_tile_pos),
		source_id)

func erase_tile(world_tile_pos: Vector2i) -> void:
	_tilemap.erase_cell(WorldGenerator.TERRAIN_LAYER, world_tile_pos)
	WorldManager.record_tile_change(world_tile_pos, -1, Vector2i.ZERO)

## Returns the source_id of the terrain tile at a world tile position (-1 if empty).
func get_tile_at(world_tile_pos: Vector2i) -> int:
	return _tilemap.get_cell_source_id(WorldGenerator.TERRAIN_LAYER, world_tile_pos)

# ── Signal handlers ────────────────────────────────────────────────────────────

func _on_world_item_spawned(item: Resource, spawn_position: Vector2) -> void:
	if item == null:
		return
	var node: Node2D = WORLD_ITEM_SCENE.instantiate()
	_object_layer.add_child(node)
	node.global_position = spawn_position
	if node.has_method("setup"):
		node.setup(item)

func _on_tile_changed(world_tile_pos: Vector2i, _old_source: int, new_source: int) -> void:
	# If a tile is destroyed (new_source == -1), check if an object sat on it.
	if new_source >= 0:
		return
	# Nothing to clean up here — Harvestable nodes handle their own lifecycle.

# ── Helpers ────────────────────────────────────────────────────────────────────

## Returns the Set (Dictionary used as set) of chunk coords that should be loaded
## given the player's current chunk.
func _desired_set(center: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var cx := wrapi(center.x + dx, 0, TOTAL_CHUNKS_X)
			var cy := clampi(center.y + dy, 0, TOTAL_CHUNKS_Y - 1)
			result[Vector2i(cx, cy)] = true
	return result
