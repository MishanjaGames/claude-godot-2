# DebugOverlay.gd
# Developer overlay toggled by F3. Shows runtime diagnostics with zero GC pressure.
# Safe to ship — toggle is disabled in exported builds automatically.
#
# SCENE TREE (DebugOverlay.tscn — instance inside World.tscn):
#   DebugOverlay       [CanvasLayer]  layer=127       ← this script
#   └── Panel          [PanelContainer]               anchors=top-left, min=(260,0)
#       └── MarginContainer
#           └── Lines  [VBoxContainer]
#               └── (Label nodes added once in _ready, updated each frame)
class_name DebugOverlay
extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var lines: VBoxContainer  = $Panel/MarginContainer/Lines

# ── Line keys (in display order) ──────────────────────────────────────────────
const LINE_KEYS: Array[String] = [
	"fps",
	"pos",
	"chunk",
	"tile",
	"biome",
	"time",
	"day",
	"phase",
	"entities",
	"loaded_chunks",
	"level_xp",
	"inventory",
	"active_sfx",
]

var _labels:  Dictionary = {}   # key → Label
var _visible: bool       = false
var _tick:    float      = 0.0
const UPDATE_RATE: float = 0.1   # seconds between updates

# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	process_mode  = Node.PROCESS_MODE_ALWAYS
	panel.visible = false

	# Build one Label per line key.
	for key in LINE_KEYS:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.text = key + ": …"
		lines.add_child(lbl)
		_labels[key] = lbl

	# Only active in debug builds.
	if not OS.is_debug_build():
		queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed \
			and event.keycode == KEY_F3 and not event.echo:
		_visible      = not _visible
		panel.visible = _visible
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _visible:
		return
	_tick += delta
	if _tick < UPDATE_RATE:
		return
	_tick = 0.0
	_refresh()

# ══════════════════════════════════════════════════════════════════════════════
# DATA GATHERING
# ══════════════════════════════════════════════════════════════════════════════

func _refresh() -> void:
	var player := GameManager.player_ref

	_set("fps", "FPS: %d (%.2f ms)" % [
		Engine.get_frames_per_second(),
		1000.0 / maxf(Engine.get_frames_per_second(), 0.001)
	])

	if player:
		var pos := player.global_position
		_set("pos",   "Pos:   %.0f, %.0f" % [pos.x, pos.y])
		_set("chunk", "Chunk: %s" % str(WorldManager.world_pos_to_chunk(pos)))
		_set("tile",  "Tile:  %s" % str(WorldManager.world_pos_to_tile(pos)))

		# Biome from ChunkManager._generator if available.
		var chunk_mgr := get_tree().get_first_node_in_group("chunk_manager")
		if chunk_mgr and "_generator" in chunk_mgr:
			var biome = chunk_mgr._generator.get_biome_at(
				WorldManager.world_pos_to_tile(pos).x)
			_set("biome", "Biome: %s" % (biome.id if biome else "?"))
		else:
			_set("biome", "Biome: (no generator)")
	else:
		for k in ["pos", "chunk", "tile", "biome"]:
			_set(k, k + ": no player")

	# Day/Night.
	if Engine.has_singleton("DayNightCycle") or \
			ClassDB.class_exists("DayNightCycle"):
		_set("time",  "Time:  %s" % DayNightCycle.clock_string())
		_set("day",   "Day:   %d" % DayNightCycle.day_count)
		_set("phase", "Phase: %s" % Phase_name(DayNightCycle.current_phase))
	else:
		for k in ["time", "day", "phase"]:
			_set(k, k + ": N/A")

	# Entity count.
	var entities := get_tree().get_nodes_in_group("entity")
	_set("entities", "Entities: %d" % entities.size())

	# Loaded chunks.
	var chunk_mgr2 := get_tree().get_first_node_in_group("chunk_manager")
	if chunk_mgr2 and "_loaded_chunks" in chunk_mgr2:
		_set("loaded_chunks", "Chunks: %d loaded" % chunk_mgr2._loaded_chunks.size())
	else:
		_set("loaded_chunks", "Chunks: N/A")

	# Level / XP.
	_set("level_xp", "Lv %d  XP %d/%d" % [
		CombatManager.current_level,
		CombatManager.current_xp,
		CombatManager.xp_for_next_level()
	])

	# Inventory slots used.
	var used := InventoryManager.slots.filter(func(s): return s != null).size()
	_set("inventory", "Inventory: %d/32" % used)

	# Active SFX pool nodes.
	var playing := AudioManager._pool.filter(func(p): return p.playing).size()
	_set("active_sfx", "SFX pool: %d/%d" % [playing, AudioManager.SFX_POOL_SIZE])

func _set(key: String, text: String) -> void:
	if _labels.has(key):
		_labels[key].text = text

func Phase_name(phase: int) -> String:
	match phase:
		0: return "Dawn"
		1: return "Day"
		2: return "Dusk"
		3: return "Night"
		_: return "?"
