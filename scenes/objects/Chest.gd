# Chest.gd
# Interactable chest that rolls a DropTable and spawns WorldItems on open.
# StructurePlacer calls setup(drop_table_id) after instantiation.
# Looted state is persisted via WorldManager tile delta (chest replaced with empty tile).
#
# SCENE TREE (Chest.tscn):
#   Chest               [StaticBody2D]   ← this script
#   ├── Sprite2D                         (texture: closed chest — swaps to open on loot)
#   ├── CollisionShape2D                 (RectangleShape2D)
#   ├── InteractLabel   [Label]          (text="[E] Open", offset_y=-24, visible=false)
#   ├── OpenSound       [AudioStreamPlayer2D]
#   └── InteractArea    [Area2D]
#       └── CollisionShape2D             (slightly larger than chest body)
class_name Chest
extends StaticBody2D

@export var drop_table_id: String  = ""
@export var closed_texture: Texture2D = null
@export var open_texture:   Texture2D = null

var _is_looted: bool = false

@onready var sprite:         Sprite2D              = $Sprite2D
@onready var interact_label: Label                 = $InteractLabel
@onready var open_sound:     AudioStreamPlayer2D   = $OpenSound
@onready var interact_area:  Area2D                = $InteractArea

# ══════════════════════════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════════════════════════

## Called by StructurePlacer with the drop_table_id string from StructureData.
func setup(table_id: String) -> void:
	drop_table_id = table_id

func _ready() -> void:
	add_to_group("chest")
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	interact_label.visible = false
	if closed_texture:
		sprite.texture = closed_texture

# ══════════════════════════════════════════════════════════════════════════════
# INTERACT
# ══════════════════════════════════════════════════════════════════════════════

func interact(_interactor: Node) -> void:
	if _is_looted:
		EventBus.hud_show_message.emit("This chest is empty.", 1.5)
		return
	_open()

func _open() -> void:
	_is_looted = true
	interact_label.visible = false

	# Swap to open sprite.
	if open_texture:
		sprite.texture = open_texture

	# Play sound.
	if open_sound.stream:
		open_sound.play()

	# Roll and scatter drops.
	_drop_loot()

	EventBus.chest_opened.emit(self, GameManager.player_ref)

func _drop_loot() -> void:
	if drop_table_id.is_empty():
		return
	var table := Registry.get_drop_table(drop_table_id)
	if table == null:
		push_warning("Chest: drop_table_id '%s' not found in Registry." % drop_table_id)
		return
	var luck := 1.0
	if GameManager.player_ref and GameManager.player_ref.stat_block:
		luck = GameManager.player_ref.stat_block.get_luck()
	var items := table.roll_items(luck)
	for item in items:
		var scatter := Vector2(randf_range(-20.0, 20.0), randf_range(-12.0, 4.0))
		EventBus.world_item_spawned.emit(item, global_position + scatter)

# ══════════════════════════════════════════════════════════════════════════════
# PROXIMITY LABEL
# ══════════════════════════════════════════════════════════════════════════════

func _on_body_entered(body: Node) -> void:
	if body == GameManager.player_ref and not _is_looted:
		interact_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body == GameManager.player_ref:
		interact_label.visible = false

# ══════════════════════════════════════════════════════════════════════════════
# SERIALIZATION (called by Structure/SaveManager if needed)
# ══════════════════════════════════════════════════════════════════════════════

func get_state() -> Dictionary:
	return { "looted": _is_looted }

func apply_state(state: Dictionary) -> void:
	if state.get("looted", false):
		_is_looted     = true
		if open_texture:
			sprite.texture = open_texture
