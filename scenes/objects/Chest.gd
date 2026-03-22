# Chest.gd  (patched — adds add_to_group)
class_name Chest
extends StaticBody2D

@export var drop_table_id:  String    = ""
@export var closed_texture: Texture2D = null
@export var open_texture:   Texture2D = null

var _is_looted: bool = false

@onready var sprite:         Sprite2D            = $Sprite2D
@onready var interact_label: Label               = $InteractLabel
@onready var open_sound:     AudioStreamPlayer2D = $OpenSound
@onready var interact_area:  Area2D              = $InteractArea

func setup(table_id: String) -> void:
	drop_table_id = table_id

func _ready() -> void:
	add_to_group("chest")   # SaveManager scans this group
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	interact_label.visible = false
	if closed_texture:
		sprite.texture = closed_texture

func interact(_interactor: Node) -> void:
	if _is_looted:
		EventBus.hud_show_message.emit("This chest is empty.", 1.5)
		return
	_open()

func _open() -> void:
	_is_looted             = true
	interact_label.visible = false
	if open_texture:
		sprite.texture = open_texture
	if open_sound.stream:
		open_sound.play()
	_drop_loot()
	EventBus.chest_opened.emit(self, GameManager.player_ref)

func _drop_loot() -> void:
	if drop_table_id.is_empty():
		return
	var table := Registry.get_drop_table(drop_table_id)
	if table == null:
		return
	var luck := 1.0
	if GameManager.player_ref and GameManager.player_ref.stat_block:
		luck = GameManager.player_ref.stat_block.get_luck()
	for item in table.roll_items(luck):
		var scatter := Vector2(randf_range(-20.0, 20.0), randf_range(-12.0, 4.0))
		EventBus.world_item_spawned.emit(item, global_position + scatter)

func _on_body_entered(body: Node) -> void:
	if body == GameManager.player_ref and not _is_looted:
		interact_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body == GameManager.player_ref:
		interact_label.visible = false

func get_state() -> Dictionary:
	return { "looted": _is_looted }

func apply_state(state: Dictionary) -> void:
	if state.get("looted", false):
		_is_looted = true
		if open_texture:
			sprite.texture = open_texture
