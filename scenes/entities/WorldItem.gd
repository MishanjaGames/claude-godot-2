# WorldItem.gd
# A dropped item lying in the world.
# Auto-picked up when the player walks over it, or manually via interact().
#
# SCENE TREE (WorldItem.tscn):
#   WorldItem       [Area2D]     ← this script
#   ├── Sprite2D                 (texture set at runtime)
#   ├── CollisionShape2D         (CircleShape2D r=12)
#   └── Label                    (text=item name, offset_y=-18, h_align=center)
class_name WorldItem
extends Area2D

@export var item: ItemData = null   # assign in editor or call setup()

@onready var sprite: Sprite2D          = $Sprite2D
@onready var label:  Label             = $Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if item != null:
		_apply_visuals()

## Called when spawned at runtime (e.g. from ChunkManager or drop).
func setup(data: ItemData) -> void:
	item = data
	_apply_visuals()

func _apply_visuals() -> void:
	if item == null:
		return
	sprite.texture = item.icon
	label.text     = item.display_name

func _on_body_entered(body: Node) -> void:
	if body == GameManager.player_ref:
		_pickup(body)

## Called by Player's InteractRay when E is pressed over this item.
func interact(interactor: Node) -> void:
	_pickup(interactor)

func _pickup(picker: Node) -> void:
	if item == null:
		return
	if InventoryManager.add_item(item):
		EventBus.world_item_picked_up.emit(item, picker)
		EventBus.hud_show_message.emit("Picked up %s." % item.display_name, 1.5)
		queue_free()
	else:
		EventBus.hud_show_message.emit("Inventory full!", 1.5)
