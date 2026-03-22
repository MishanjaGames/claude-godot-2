# Minimap.gd
# Renders a pixel-art minimap into a SubViewport, displayed on the HUD.
# Each pixel = one chunk. Colours are drawn per-biome.
# Player position is a bright dot. Explored chunks are revealed; unexplored = dark.
#
# SCENE TREE (Minimap.tscn — instance inside HUD.tscn):
#   Minimap              [Control]    custom_min=(150,150)   ← this script
#   ├── SubViewport      [SubViewport]  size=(150,150)
#   │   └── ColorRect    [ColorRect]   anchors=full  (cleared each frame)
#   ├── MapTexture       [TextureRect]  texture=SubViewport, anchors=full
#   ├── PlayerDot        [ColorRect]   size=(3,3), color=WHITE
#   └── Border           [Panel]       anchors=full (just a styled border)
class_name Minimap
extends Control

# ── Tunables ───────────────────────────────────────────────────────────────────
## Pixel size of the minimap display in screen pixels.
const MAP_SIZE:        int = 150
## How many world chunks each minimap pixel represents.
const CHUNKS_PER_PIXEL: int = 1

# ── Biome colour palette (biome_id → Color) ───────────────────────────────────
## Populated from BiomeData at startup. Falls back to UNKNOWN_COLOR.
const UNKNOWN_COLOR:  Color = Color(0.05, 0.05, 0.05)   # unexplored
const OCEAN_COLOR:    Color = Color(0.15, 0.25, 0.55)
const DEFAULT_COLOR:  Color = Color(0.25, 0.35, 0.18)   # generic land

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var sub_viewport: SubViewport = $SubViewport
@onready var map_texture:  TextureRect = $MapTexture
@onready var player_dot:   ColorRect   = $PlayerDot

# ── Internal state ─────────────────────────────────────────────────────────────
var _image:     Image          = null   # CPU-side pixel buffer
var _texture:   ImageTexture   = null   # GPU texture updated from _image
var _dirty:     bool           = false  # redraw flag

# Biome colours cached from Registry.
var _biome_colors: Dictionary  = {}     # biome_id → Color

# Chunks we have drawn already (don't re-draw unless modified).
var _drawn_chunks: Dictionary  = {}     # Vector2i → Color

# ── Update rate ────────────────────────────────────────────────────────────────
var _tick: float = 0.0
const UPDATE_INTERVAL: float = 0.25   # seconds between full redraws

# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_image   = Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGB8)
	_image.fill(UNKNOWN_COLOR)
	_texture = ImageTexture.create_from_image(_image)
	map_texture.texture = _texture

	_cache_biome_colors()

	EventBus.chunk_loaded.connect(_on_chunk_loaded)
	EventBus.chunk_unloaded.connect(_on_chunk_unloaded)
	EventBus.tile_changed.connect(func(_p, _o, _n): _dirty = true)

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= UPDATE_INTERVAL:
		_tick = 0.0
		_update_player_dot()
		if _dirty:
			_dirty = false
			_redraw()

# ══════════════════════════════════════════════════════════════════════════════
# DRAWING
# ══════════════════════════════════════════════════════════════════════════════

func _on_chunk_loaded(chunk_coords: Vector2i) -> void:
	var biome := _get_biome_color_for_chunk(chunk_coords)
	_drawn_chunks[chunk_coords] = biome
	_draw_chunk_pixel(chunk_coords, biome)
	_dirty = true

func _on_chunk_unloaded(_chunk_coords: Vector2i) -> void:
	pass   # keep explored chunks visible on the minimap

func _redraw() -> void:
	_image.fill(UNKNOWN_COLOR)
	for chunk_coords in _drawn_chunks:
		_draw_chunk_pixel(chunk_coords, _drawn_chunks[chunk_coords])
	_texture.update(_image)

func _draw_chunk_pixel(chunk_coords: Vector2i, color: Color) -> void:
	var player := GameManager.player_ref
	if player == null:
		return
	var player_chunk := WorldManager.world_pos_to_chunk(player.global_position)
	# Offset so player chunk is always at MAP_SIZE/2.
	var half       := MAP_SIZE / 2
	var rel        := chunk_coords - player_chunk
	var px         := half + rel.x * CHUNKS_PER_PIXEL
	var py         := half + rel.y * CHUNKS_PER_PIXEL
	if px < 0 or py < 0 or px >= MAP_SIZE or py >= MAP_SIZE:
		return
	for dx in CHUNKS_PER_PIXEL:
		for dy in CHUNKS_PER_PIXEL:
			_image.set_pixel(px + dx, py + dy, color)

func _update_player_dot() -> void:
	# Player dot stays at MAP_SIZE/2, dead centre.
	var half := MAP_SIZE * 0.5
	player_dot.position = Vector2(half - 1.5, half - 1.5)
	_texture.update(_image)

# ══════════════════════════════════════════════════════════════════════════════
# BIOME COLOURS
# ══════════════════════════════════════════════════════════════════════════════

func _cache_biome_colors() -> void:
	for biome in Registry.all_biomes():
		# Use the sky_color darkened as a map colour, or fallback.
		var col: Color = biome.sky_color.darkened(0.4)
		_biome_colors[biome.id] = col

func _get_biome_color_for_chunk(chunk_coords: Vector2i) -> Color:
	var tile_x := chunk_coords.x * WorldManager.CHUNK_SIZE + WorldManager.CHUNK_SIZE / 2
	# WorldGenerator is only available inside World.tscn scope.
	# We use a shortcut: ask the WorldManager for the noise-derived biome.
	# Since WorldGenerator is a RefCounted we can't autoload it, but ChunkManager
	# exposes _generator. This is the safest approach without tight coupling.
	var chunk_mgr := get_tree().get_first_node_in_group("chunk_manager")
	if chunk_mgr and "_generator" in chunk_mgr:
		var biome = chunk_mgr._generator.get_biome_at(tile_x)
		if biome and _biome_colors.has(biome.id):
			return _biome_colors[biome.id]
	return DEFAULT_COLOR
