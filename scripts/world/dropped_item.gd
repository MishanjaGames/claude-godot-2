extends Area2D
class_name DroppedItem

@onready var sprite: Sprite2D = $Sprite2D
@onready var label:  Label    = $Label

var item:  Item = null
var count: int  = 1


func setup(p_item: Item, p_count: int) -> void:
	item        = p_item
	count       = p_count
	label.text  = p_item.name
	if p_item.icon != null:
		sprite.texture = p_item.icon


func _on_body_entered(body: Node) -> void:
	if body.get("inventory") is Inventory:
		if body.inventory.add_item(item, count):
			queue_free()
