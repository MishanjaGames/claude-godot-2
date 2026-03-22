# World.gd  (patched — adds DayNightCycle, apply_object_states)
extends Node2D

@onready var tilemap:       TileMap      = $TileMap
@onready var object_layer:  Node2D       = $ObjectLayer
@onready var chunk_manager: ChunkManager = $ChunkManager
@onready var camera:        Camera2D     = $Camera2D
@onready var player_spawn:  Marker2D     = $SpawnPoints/PlayerSpawn
@onready var fade_overlay:  CanvasLayer  = $UI/FadeOverlay
@onready var pause_menu:    CanvasLayer  = $UI/PauseMenu
@onready var world_env:     WorldEnvironment    = $WorldEnvironment
@onready var sun:           DirectionalLight2D  = $Sun

const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/Player.tscn")

var _player: Node = null

func _ready() -> void:
	chunk_manager.setup(tilemap, object_layer)

	var spawn_pos := _resolve_spawn_position()
	chunk_manager.load_initial(spawn_pos)

	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	_player.global_position = spawn_pos
	GameManager.player_ref  = _player

	camera.reparent(_player)
	camera.position = Vector2.ZERO

	# Wire day/night to this scene's environment nodes.
	DayNightCycle.setup(world_env, sun)

	if SaveManager.has_save():
		SaveManager.apply_save(_player)
		SaveManager.apply_object_states()   # restore chests/doors/structures

	if fade_overlay and fade_overlay.has_method("fade_in"):
		fade_overlay.fade_in()

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

func _resolve_spawn_position() -> Vector2:
	if not SaveManager.has_save():
		return player_spawn.global_position
	var raw := SaveManager.load_raw()
	var pd  := raw.get("player", {})
	if pd.is_empty():
		return player_spawn.global_position
	return Vector2(
		pd.get("position_x", player_spawn.global_position.x),
		pd.get("position_y", player_spawn.global_position.y)
	)

func _on_player_died() -> void:
	await get_tree().create_timer(2.5).timeout
	_player.global_position = player_spawn.global_position
	_player.current_health  = _player.stat_block.get_max_health()
	_player.current_stamina = _player.stat_block.get_max_stamina()
	_player._is_dead        = false
	_player.collision.set_deferred("disabled", false)
	_player._on_entity_ready()
	EventBus.player_respawned.emit(player_spawn.global_position)
