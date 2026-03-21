# WorldGenerator.gd
# Pure data generator — no Node, no scene tree dependency.
# Given a chunk coordinate and world seed, returns tile and object placement data.
# ChunkManager owns one instance and calls generate_chunk() per new chunk.
#
# NOISE LAYERS:
#   _height   — 1D smooth noise → surface Y per tile column
#   _cave     — 2D cellular    → carves underground caves
#   _temp     — 1D very smooth → temperature map (drives biome selection)
#   _moisture — 1D very smooth → moisture map (drives biome selection)
#   _ore      — 2D perlin      → ore vein placement
#   _object   — per-chunk RNG  → deterministic object scatter
class_name WorldGenerator
extends RefCounted

# ── Terrain shape ──────────────────────────────────────────────────────────────
## Y tile at which sea-level / flat land sits (from top of world).
const SEA_LEVEL:         int   = 800
## Max tiles the surface rises or dips from sea level.
const TERRAIN_AMPLITUDE: int   = 180
## Tiles below surface before stone/underground starts.
const SUBSURFACE_DEPTH:  int   = 6
## Tiles below surface before caves can begin carving.
const CAVE_MIN_DEPTH:    int   = 12
## FastNoiseLite threshold below which a tile becomes a cave.
const CAVE_THRESHOLD:    float = -0.38
## Tiles below surface before ore veins can appear.
const ORE_MIN_DEPTH:     int   = 35
## FastNoiseLite threshold above which a tile becomes an ore vein.
const ORE_THRESHOLD:     float = 0.58

## TileMap layer indices (must match your TileMap layer setup in Godot).
const TERRAIN_LAYER:    int = 0
const BACKGROUND_LAYER: int = 1

# ── Noise objects ──────────────────────────────────────────────────────────────
var _height:   FastNoiseLite
var _cave:     FastNoiseLite
var _temp:     FastNoiseLite
var _moisture: FastNoiseLite
var _ore:      FastNoiseLite

# ── Sorted biome list (cached in setup()) ─────────────────────────────────────
var _biomes: Array   # BiomeData, sorted by priority descending
var _fallback_biome: BiomeData

# ── Setup ──────────────────────────────────────────────────────────────────────

## Call once after Registry is ready and world seed is set.
func setup(world_seed: int) -> void:
	_biomes = Registry.all_biomes()
	_biomes.sort_custom(func(a, b): return a.priority > b.priority)
	if _biomes.is_empty():
		push_warning("WorldGenerator: no BiomeData found in Registry.")
	else:
		_fallback_biome = _biomes[-1]   # lowest priority = most generic

	_height   = _make_noise(world_seed ^ 0x1A2B3C, 0.0025, 5, FastNoiseLite.FRACTAL_FBM)
	_cave     = _make_noise(world_seed ^ 0x4D5E6F, 0.018,  3, FastNoiseLite.FRACTAL_NONE, FastNoiseLite.TYPE_CELLULAR)
	_temp     = _make_noise(world_seed ^ 0x7A8B9C, 0.0008, 2, FastNoiseLite.FRACTAL_FBM)
	_moisture = _make_noise(world_seed ^ 0xABCDEF, 0.0006, 2, FastNoiseLite.FRACTAL_FBM)
	_ore      = _make_noise(world_seed ^ 0xF1E2D3, 0.035,  2, FastNoiseLite.FRACTAL_NONE)

# ── Main entry point ───────────────────────────────────────────────────────────

## Generates one 32×32 chunk.
## Returns:
##   "tiles"   — Array[Dictionary] { tile_pos: Vector2i, source_id: int, atlas_coord: Vector2i }
##   "objects" — Array[Dictionary] { harvestable_id: String, tile_pos: Vector2i }
## All positions are in world tile space.
func generate_chunk(chunk_coords: Vector2i, world_seed: int) -> Dictionary:
	var chunk_origin_tile := chunk_coords * WorldManager.CHUNK_SIZE

	var tiles:   Array[Dictionary] = []
	var objects: Array[Dictionary] = []

	# Per-chunk seeded RNG for deterministic object placement.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(chunk_coords.x * 73856093, chunk_coords.y * 19349663) ^ world_seed)

	# Cache per-column data so we only sample 1D noise once per column.
	var col_surface_y: Array[int]     = []
	var col_biome:     Array[BiomeData] = []

	for lx in WorldManager.CHUNK_SIZE:
		var tx := chunk_origin_tile.x + lx
		col_surface_y.append(_get_surface_y(tx))
		col_biome.append(_get_biome(tx))

	# ── Tile pass ────────────────────────────────────────────────────────────
	for lx in WorldManager.CHUNK_SIZE:
		var tx      := chunk_origin_tile.x + lx
		var surf_y  := col_surface_y[lx]
		var biome   := col_biome[lx]

		for ly in WorldManager.CHUNK_SIZE:
			var ty := chunk_origin_tile.y + ly

			if ty < surf_y:
				# Above surface — sky, leave empty.
				continue

			var depth := ty - surf_y
			var in_cave := depth >= CAVE_MIN_DEPTH \
				and _cave.get_noise_2d(float(tx), float(ty)) < CAVE_THRESHOLD

			if in_cave:
				# Carve out air inside caves.
				continue

			# ── Choose tile ────────────────────────────────────────────────
			var source_id:   int      = 0
			var atlas_coord: Vector2i = Vector2i.ZERO

			if depth == 0:
				source_id   = biome.surface_tile_source
				atlas_coord = biome.surface_tile_coord
			elif depth <= SUBSURFACE_DEPTH:
				source_id   = biome.subsurface_tile_source
				atlas_coord = biome.subsurface_tile_coord
			else:
				# Underground — check for ore vein first.
				if depth >= ORE_MIN_DEPTH \
						and _ore.get_noise_2d(float(tx), float(ty)) > ORE_THRESHOLD:
					# Ore tile: use the biome's ore_ids to pick a source.
					# In your TileSet, ore atlas coords must be defined separately.
					# For now we fall through to underground tile; Phase 3 adds ore lookup.
					source_id   = biome.underground_tile_source
					atlas_coord = biome.underground_tile_coord
				else:
					source_id   = biome.underground_tile_source
					atlas_coord = biome.underground_tile_coord

			tiles.append({
				"tile_pos":    Vector2i(tx, ty),
				"source_id":   source_id,
				"atlas_coord": atlas_coord,
			})

	# ── Object pass (surface only) ────────────────────────────────────────────
	for lx in WorldManager.CHUNK_SIZE:
		var tx     := chunk_origin_tile.x + lx
		var surf_y := col_surface_y[lx]
		var biome  := col_biome[lx]

		# Only spawn objects on solid surface tiles (surf_y must be in this chunk).
		if surf_y < chunk_origin_tile.y or surf_y >= chunk_origin_tile.y + WorldManager.CHUNK_SIZE:
			continue

		var surf_tile := Vector2i(tx, surf_y)

		# Try each object category in priority order.
		var placed := false
		if not placed and not biome.tree_ids.is_empty() \
				and rng.randf() < biome.tree_density:
			objects.append({ "harvestable_id": biome.random_tree_id(), "tile_pos": surf_tile })
			placed = true

		if not placed and not biome.rock_ids.is_empty() \
				and rng.randf() < biome.rock_density:
			objects.append({ "harvestable_id": biome.random_rock_id(), "tile_pos": surf_tile })
			placed = true

		if not placed and not biome.decor_ids.is_empty() \
				and rng.randf() < biome.decor_density:
			objects.append({ "harvestable_id": biome.random_decor_id(), "tile_pos": surf_tile })

	return { "tiles": tiles, "objects": objects }

# ── Surface height ────────────────────────────────────────────────────────────

func _get_surface_y(tile_x: int) -> int:
	var n := _height.get_noise_2d(float(tile_x), 0.0)   # -1 to 1
	return clamp(SEA_LEVEL + int(n * TERRAIN_AMPLITUDE),
		SEA_LEVEL - TERRAIN_AMPLITUDE,
		SEA_LEVEL + TERRAIN_AMPLITUDE)

## Returns the surface Y for a world tile X. Used by ChunkManager for spawn positioning.
func get_surface_y_at(tile_x: int) -> int:
	return _get_surface_y(tile_x)

# ── Biome selection ────────────────────────────────────────────────────────────

func _get_biome(tile_x: int) -> BiomeData:
	var t := (_temp.get_noise_2d(float(tile_x), 0.0) + 1.0) * 0.5      # 0–1
	var m := (_moisture.get_noise_2d(float(tile_x), 0.0) + 1.0) * 0.5  # 0–1
	for biome in _biomes:
		if biome.matches(t, m):
			return biome
	return _fallback_biome

## Returns the BiomeData for a world tile X. Used by StructurePlacer and ChunkManager.
func get_biome_at(tile_x: int) -> BiomeData:
	return _get_biome(tile_x)

# ── Noise factory ──────────────────────────────────────────────────────────────

func _make_noise(
		s:            int,
		freq:         float,
		octaves:      int,
		fractal_type: FastNoiseLite.FractalType,
		noise_type:   FastNoiseLite.NoiseType = FastNoiseLite.TYPE_PERLIN
) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type   = noise_type
	n.seed         = s
	n.frequency    = freq
	n.fractal_type = fractal_type
	if fractal_type != FastNoiseLite.FRACTAL_NONE:
		n.fractal_octaves = octaves
	return n
