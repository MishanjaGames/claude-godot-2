# WorldItem.gd
# An item lying in the world. Player walks over / interacts to pick up.
extends Area2D

@export var item: Resource = null   # Assign an Item resource in the editor

@onready var sprite: Sprite2D            = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var label: Label                = $Label

func _ready() -> void:
	if item != null:
		sprite.texture = item.icon
		label.text     = item.display_name
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Auto-pickup when player walks over
	if body == GameManager.player_ref:
		_pickup(body)

func interact(interactor: Node) -> void:
	_pickup(interactor)

func _pickup(picker: Node) -> void:
	if item == null:
		return
	if InventoryManager.add_item(item):
		EventBus.world_item_picked_up.emit(item, picker)
		EventBus.hud_show_message.emit("Picked up " + item.display_name, 2.0)
		queue_free()
	else:
		EventBus.hud_show_message.emit("Inventory full!", 2.0)
