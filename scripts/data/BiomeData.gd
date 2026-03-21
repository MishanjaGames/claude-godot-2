# BiomeData.gd
# Defines everything that makes a biome unique.
# WorldGenerator uses this during chunk generation to place tiles and objects.
# Create .tres files in res://data/biomes/
class_name BiomeData
extends Resource

# ── Identity ───────────────────────────────────────────────────────────────────
@export var id: String                      = ""
@export var display_name: String            = "Biome"

# ── Generation thresholds (all 0.0–1.0 normalised) ────────────────────────────
# WorldGenerator assigns a biome to each tile column based on where these ranges
# overlap with the noise-sampled temperature and moisture values.
@export_group("Generation Thresholds")
@export var temperature_min: float          = 0.0
@export var temperature_max: float          = 1.0
@export var moisture_min: float             = 0.0
@export var moisture_max: float             = 1.0
## Higher priority wins when multiple biomes match the same column.
@export var priority: int                   = 0

# ── Tile IDs (match your TileSet source IDs) ──────────────────────────────────
@export_group("Tiles")
## The main surface tile (grass, sand, snow, etc.)
@export var surface_tile_source: int        = 0
@export var surface_tile_coord: Vector2i    = Vector2i(0, 0)
## Subsurface layer (dirt under grass, sandstone under sand)
@export var subsurface_tile_source: int     = 0
@export var subsurface_tile_coord: Vector2i = Vector2i(1, 0)
## Deep underground (stone, bedrock)
@export var underground_tile_source: int    = 0
@export var underground_tile_coord: Vector2i = Vector2i(2, 0)
## Water/lava tile used for lakes/ponds in this biome
@export var fluid_tile_source: int          = 0
@export var fluid_tile_coord: Vector2i      = Vector2i(3, 0)

# ── Object placement ───────────────────────────────────────────────────────────
@export_group("Surface Objects")
## HarvestableData ids and their spawn density (0.0–1.0 per-tile probability)
@export var tree_ids: Array[String]         = []
@export var tree_density: float             = 0.1
@export var rock_ids: Array[String]         = []
@export var rock_density: float             = 0.05
@export var ore_ids: Array[String]          = []
@export var ore_density: float              = 0.02
## Generic decoration objects (flowers, grass tufts, etc.)
@export var decor_ids: Array[String]        = []
@export var decor_density: float            = 0.15

# ── NPC spawning ───────────────────────────────────────────────────────────────
@export_group("NPCs")
@export var ambient_npc_ids: Array[String]  = []   # peaceful wanderers
@export var hostile_npc_ids: Array[String]  = []   # enemies that spawn at night or deep
@export var max_ambient_npcs: int           = 5
@export var max_hostile_npcs: int           = 3

# ── Structure spawning ────────────────────────────────────────────────────────
@export_group("Structures")
@export var structure_ids: Array[String]    = []
@export var structure_chance: float         = 0.02  # per-chunk probability

# ── Atmosphere ────────────────────────────────────────────────────────────────
@export_group("Atmosphere")
@export var sky_color: Color                = Color(0.5, 0.7, 1.0)
@export var fog_color: Color                = Color(0.8, 0.9, 1.0, 0.0)
@export var fog_density: float              = 0.0
@export var ambient_light_energy: float     = 1.0
@export var music_id: String                = ""

# ── Helpers ───────────────────────────────────────────────────────────────────

func matches(temperature: float, moisture: float) -> bool:
	return temperature >= temperature_min and temperature <= temperature_max \
		and moisture >= moisture_min and moisture <= moisture_max

func random_tree_id() -> String:
	return _random_from(tree_ids)

func random_rock_id() -> String:
	return _random_from(rock_ids)

func random_ore_id() -> String:
	return _random_from(ore_ids)

func random_decor_id() -> String:
	return _random_from(decor_ids)

func _random_from(arr: Array) -> String:
	if arr.is_empty():
		return ""
	return arr[randi() % arr.size()]
