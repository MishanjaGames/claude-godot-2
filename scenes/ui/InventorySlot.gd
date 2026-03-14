# InventorySlot.gd
# Individual slot in the inventory grid.
extends PanelContainer

signal right_clicked(slot_index: int)
signal drag_started(slot_index: int)
signal drag_dropped(target_index: int)

@export var slot_index: int = 0

@onready var icon: TextureRect = $TextureRect
@onready var qty_label: Label  = $QtyLabel

var _item: Resource = null

func set_item(item: Resource) -> void:
	_item = item
	if item == null:
		icon.texture  = null
		qty_label.text = ""
		qty_label.visible = false
	else:
		icon.texture  = item.icon
		if item.stackable and item.quantity > 1:
			qty_label.text    = str(item.quantity)
			qty_label.visible = true
		else:
			qty_label.visible = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			right_clicked.emit(slot_index)
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _item != null:
			drag_started.emit(slot_index)

# Called by InventoryUI drag-and-drop logic when another slot drops onto this one.
func accept_drop(from_index: int) -> void:
	drag_dropped.emit(from_index)
