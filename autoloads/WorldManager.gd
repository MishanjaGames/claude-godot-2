# WorldManager.gd
# Owns all world-level constants and runtime state:
#   - World dimensions and coordinate math
#   - Planet-wrap logic (horizontal cylinder — left edge = right edge)
#   - Which chunks have been generated / modified
#   - The active world seed
#
# LOAD ORDER: after Registry.
extends Node

# ── Constants ─────────────────────────────────────────────────────────────────
## Width of the world in tiles. ~65k gives a convincing planet circumference.
const WORLD_WIDTH_TILES:  int = 65536
## Height of the world in tiles. More = deeper underground.
const WORLD_HEIGHT_TILES: int = 4096
## Pixel size of one tile. Must match your TileSet tile_size.
const TILE_SIZE:          int = 16
## Tiles per chunk edge (square). 32×32 = 1024 tiles per chunk.
const CHUNK_SIZE:         int = 32

## Derived pixel dimensions (computed at startup, stored for convenience)
var world_width_px:  int = WORLD_WIDTH_TILES  * TILE_SIZE
var world_height_px: int = WORLD_HEIGHT_TILES * TILE_SIZE
var chunk_px:        int = CHUNK_SIZE * TILE_SIZE

# ── Runtime state ──────────────────────────────────────────────────────────────
var world_seed: int = 0

## Chunks that have been procedurally generated at least once.
## Key: Vector2i chunk coords.  Value: true.
var _generated_chunks: Dictionary = {}

## Chunks modified after generation (mined tiles, placed objects, etc.)
## Key: Vector2i.  Value: Dictionary of tile deltas (populated in Phase 2).
var _modified_chunks: Dictionary = {}

# ── Seed ──────────────────────────────────────────────────────────────────────

func set_world_seed(new_seed: int) -> void:
	world_seed = new_seed
	seed(new_seed)

func get_world_seed() -> int:
	return world_seed

# ── Planet-wrap ────────────────────────────────────────────────────────────────

## Wraps a pixel-space position so it stays inside the world cylinder.
## X wraps (left ↔ right).  Y is clamped (no top/bottom wrap — those are poles).
## Call this on every entity every physics frame.
func wrap_position(pos: Vector2) -> Vector2:
	pos.x = fposmod(pos.x, float(world_width_px))
	pos.y = clampf(pos.y, 0.0, float(world_height_px))
	return pos

## Returns true if old_pos and new_pos are on opposite sides of the wrap boundary.
## Use this to detect a wrap event and fire EventBus.player_world_wrapped.
func crossed_wrap_boundary(old_pos: Vector2, new_pos: Vector2) -> bool:
	var half := world_width_px * 0.5
	return abs(new_pos.x - old_pos.x) > half

# ── Coordinate math ────────────────────────────────────────────────────────────

## Converts a pixel-space position to chunk coordinates.
func world_pos_to_chunk(world_pos: Vector2) -> Vector2i:
	var wx = int(fposmod(world_pos.x, float(world_width_px)))
	var wy = int(clampf(world_pos.y, 0.0, float(world_height_px - 1)))
	return Vector2i(wx / chunk_px, wy / chunk_px)

## Returns the pixel-space top-left corner of a chunk.
func chunk_to_world_pos(chunk_coords: Vector2i) -> Vector2:
	return Vector2(chunk_coords) * float(chunk_px)

## Converts pixel-space to tile coordinates (no wrap applied).
func world_pos_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(fposmod(world_pos.x, float(world_width_px))) / TILE_SIZE,
		int(clampf(world_pos.y, 0.0, float(world_height_px - 1))) / TILE_SIZE
	)

## Returns the pixel-space centre of a tile.
func tile_to_world_pos(tile_coords: Vector2i) -> Vector2:
	return Vector2(tile_coords) * float(TILE_SIZE) + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)

# ── Chunk registry ─────────────────────────────────────────────────────────────

func is_chunk_generated(chunk_coords: Vector2i) -> bool:
	return _generated_chunks.has(chunk_coords)

func mark_chunk_generated(chunk_coords: Vector2i) -> void:
	_generated_chunks[chunk_coords] = true

func is_chunk_modified(chunk_coords: Vector2i) -> bool:
	return _modified_chunks.has(chunk_coords)

## Returns the modification dictionary for a chunk (empty dict if unmodified).
func get_chunk_delta(chunk_coords: Vector2i) -> Dictionary:
	return _modified_chunks.get(chunk_coords, {})

## Records a tile modification. Called by the world TileMap when a tile changes.
func record_tile_change(tile_pos: Vector2i, source_id: int, atlas_coord: Vector2i) -> void:
	var chunk = world_pos_to_chunk(tile_to_world_pos(tile_pos))
	if not _modified_chunks.has(chunk):
		_modified_chunks[chunk] = {}
	_modified_chunks[chunk]["%d,%d" % [tile_pos.x, tile_pos.y]] = {
		"source_id":   source_id,
		"atlas_coord": atlas_coord
	}

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	# Convert Vector2i keys to strings for JSON
	var gen: Dictionary = {}
	for k in _generated_chunks:
		gen["%d,%d" % [k.x, k.y]] = true

	var mod: Dictionary = {}
	for k in _modified_chunks:
		mod["%d,%d" % [k.x, k.y]] = _modified_chunks[k]

	return {
		"world_seed":        world_seed,
		"generated_chunks":  gen,
		"modified_chunks":   mod,
	}

func deserialize(data: Dictionary) -> void:
	world_seed = data.get("world_seed", 0)
	seed(world_seed)

	_generated_chunks.clear()
	for key in data.get("generated_chunks", {}).keys():
		var parts = key.split(",")
		_generated_chunks[Vector2i(int(parts[0]), int(parts[1]))] = true

	_modified_chunks.clear()
	for key in data.get("modified_chunks", {}).keys():
		var parts = key.split(",")
		_modified_chunks[Vector2i(int(parts[0]), int(parts[1]))] = data["modified_chunks"][key]

func clear() -> void:
	_generated_chunks.clear()
	_modified_chunks.clear()
	world_seed = 0
