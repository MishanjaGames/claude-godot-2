# WorldScreen.gd
# Sets up the play world after loading. Spawns player, registers with GameManager.
extends Node2D

@onready var tile_map: TileMap           = $TileMap
@onready var player_spawn: Marker2D      = $SpawnPoints/PlayerSpawn
@onready var camera: Camera2D            = $Camera2D
@onready var hud: CanvasLayer            = $HUD

const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/Player.tscn")

var _player_instance: CharacterBody2D = null

func _ready() -> void:
	_spawn_player()
	_apply_save_if_exists()

func _spawn_player() -> void:
	_player_instance = PLAYER_SCENE.instantiate()
	add_child(_player_instance)
	_player_instance.global_position = player_spawn.global_position
	GameManager.player_ref = _player_instance

	# Camera follows player
	camera.reparent(_player_instance)
	camera.position = Vector2.ZERO

func _apply_save_if_exists() -> void:
	if GameManager.has_save():
		var data = GameManager.load_game()
		if data.is_empty():
			return
		var pd = data.get("player", {})
		_player_instance.global_position = Vector2(
			pd.get("position_x", player_spawn.global_position.x),
			pd.get("position_y", player_spawn.global_position.y)
		)
		_player_instance.current_health  = pd.get("health",  _player_instance.max_health)
		_player_instance.current_stamina = pd.get("stamina", _player_instance.max_stamina)
		InventoryManager.deserialize(data.get("inventory", {}))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Quick-save on Escape (replace with pause menu later)
		GameManager.save_game()
		EventBus.hud_show_message.emit("Game Saved.", 2.0)
