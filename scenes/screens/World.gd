# World.gd
# Root script for the main gameplay scene (scenes/screens/World.tscn).
# Orchestrates player spawn, chunk loading, save/load, and UI wiring.
#
# EXPECTED SCENE TREE (World.tscn):
#   World                [Node2D]         ← this script
#   ├── TileMap          [TileMap]        ← 2 layers: 0=terrain, 1=background
#   ├── ObjectLayer      [Node2D]         ← parent for all world objects
#   ├── ChunkManager     [ChunkManager]   ← scenes/world/ChunkManager.tscn or inline
#   ├── Camera2D         [Camera2D]       ← will be reparented to Player
#   ├── SpawnPoints      [Node2D]
#   │   └── PlayerSpawn  [Marker2D]
#   └── UI               [CanvasLayer]    ← layer=1, contains all UI sub-scenes:
#       ├── HUD          (instance of HUD.tscn)
#       ├── InventoryUI  (instance of InventoryUI.tscn)
#       ├── DialogueBox  (instance of DialogueBox.tscn)
#       ├── PauseMenu    (instance of PauseMenu.tscn)
#       ├── SettingsScreen (instance of SettingsScreen.tscn)
#       └── FadeOverlay  (instance of FadeOverlay.tscn)
extends Node2D

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var tilemap:       TileMap        = $TileMap
@onready var object_layer:  Node2D         = $ObjectLayer
@onready var chunk_manager: ChunkManager   = $ChunkManager
@onready var camera:        Camera2D       = $Camera2D
@onready var player_spawn:  Marker2D       = $SpawnPoints/PlayerSpawn
@onready var fade_overlay:  CanvasLayer    = $UI/FadeOverlay
@onready var pause_menu:    CanvasLayer    = $UI/PauseMenu

const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/Player.tscn")

var _player: Node = null

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Boot ChunkManager with scene references.
	chunk_manager.setup(tilemap, object_layer)

	# Determine spawn position (save data overrides the default spawn marker).
	var spawn_pos := _resolve_spawn_position()

	# Load the initial ring of chunks before spawning the player so the ground exists.
	chunk_manager.load_initial(spawn_pos)

	# Spawn player.
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	_player.global_position = spawn_pos
	GameManager.player_ref  = _player

	# Camera follows player.
	camera.reparent(_player)
	camera.position = Vector2.ZERO

	# Apply save data if continuing.
	if SaveManager.has_save():
		SaveManager.apply_save(_player)

	# Fade in.
	if fade_overlay and fade_overlay.has_method("fade_in"):
		fade_overlay.fade_in()

	# Wire signals.
	EventBus.player_died.connect(_on_player_died)

	GameManager.on_scene_loaded(scene_file_path)

func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	chunk_manager.update_for_player(_player.global_position)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_menu and pause_menu.has_method("toggle"):
			pause_menu.toggle()
		get_viewport().set_input_as_handled()

# ── Spawn position ─────────────────────────────────────────────────────────────

func _resolve_spawn_position() -> Vector2:
	if not SaveManager.has_save():
		return player_spawn.global_position

	# Peek at saved player position without applying the full save yet.
	var raw := SaveManager.load_raw()
	var pd  := raw.get("player", {})
	if pd.is_empty():
		return player_spawn.global_position

	return Vector2(
		pd.get("position_x", player_spawn.global_position.x),
		pd.get("position_y", player_spawn.global_position.y)
	)

# ── Player death / respawn ────────────────────────────────────────────────────

func _on_player_died() -> void:
	# Simple respawn: wait for death anim, reload at spawn point.
	await get_tree().create_timer(2.5).timeout
	_player.global_position = player_spawn.global_position
	_player.current_health  = _player.stat_block.get_max_health()
	_player.current_stamina = _player.stat_block.get_max_stamina()
	_player._is_dead        = false
	_player.collision.set_deferred("disabled", false)
	_player._on_entity_ready()   # re-emits health/stamina to HUD
	EventBus.player_respawned.emit(player_spawn.global_position)
