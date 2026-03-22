# Door.gd  (patched — adds add_to_group)
class_name Door
extends StaticBody2D

@export var key_item_id:    String    = ""
@export var closed_texture: Texture2D = null
@export var open_texture:   Texture2D = null
@export var starts_open:    bool      = false

var _is_open:   bool = false
var _is_locked: bool = false

@onready var sprite:         Sprite2D            = $Sprite2D
@onready var body_collision: CollisionShape2D    = $CollisionShape2D
@onready var interact_label: Label               = $InteractLabel
@onready var open_sound:     AudioStreamPlayer2D = $OpenSound
@onready var locked_sound:   AudioStreamPlayer2D = $LockedSound
@onready var interact_area:  Area2D              = $InteractArea

func setup(key_id: String) -> void:
	key_item_id = key_id

func _ready() -> void:
	add_to_group("door")   # SaveManager scans this group
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	interact_label.visible = false
	_is_locked = not key_item_id.is_empty()
	_set_open(starts_open, false)
	EventBus.key_item_used.connect(_on_key_item_used)

func interact(_interactor: Node) -> void:
	if _is_locked:
		if InventoryManager.has_item(key_item_id):
			_unlock(_interactor)
		else:
			_play_locked_feedback()
		return
	_toggle(true)

func _toggle(play_sound: bool) -> void:
	_set_open(not _is_open, play_sound)

func _set_open(open: bool, play_sound: bool) -> void:
	_is_open = open
	sprite.texture = open_texture if open else closed_texture
	body_collision.set_deferred("disabled", open)
	if play_sound and open and open_sound.stream:
		open_sound.play()
	EventBus.door_toggled.emit(self, open)

func _unlock(interactor: Node) -> void:
	_is_locked = false
	EventBus.hud_show_message.emit("Unlocked!", 1.5)
	EventBus.key_item_used.emit(key_item_id, InventoryManager.get_active_item(), interactor)
	_toggle(true)

func _play_locked_feedback() -> void:
	EventBus.hud_show_message.emit("Locked. Requires: %s" % _key_display_name(), 2.0)
	if locked_sound.stream:
		locked_sound.play()

func _key_display_name() -> String:
	if key_item_id.is_empty(): return ""
	var item := Registry.get_item(key_item_id)
	return item.display_name if item else key_item_id

func _on_key_item_used(quest_id: String, _item: Resource, _user: Node) -> void:
	if quest_id == key_item_id and _is_locked:
		_is_locked = false

func _on_body_entered(body: Node) -> void:
	if body != GameManager.player_ref: return
	interact_label.text    = "[E] Locked" if _is_locked else ("[E] Close" if _is_open else "[E] Open")
	interact_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body == GameManager.player_ref:
		interact_label.visible = false

func get_state() -> Dictionary:
	return { "is_open": _is_open, "is_locked": _is_locked }

func apply_state(state: Dictionary) -> void:
	_is_locked = state.get("is_locked", not key_item_id.is_empty())
	_set_open(state.get("is_open", false), false)
