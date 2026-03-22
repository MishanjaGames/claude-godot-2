# InventorySlot.gd
# Reusable slot node used in both the bag grid and equipment grid.
# Emits signals upward; InventoryUI owns all logic.
#
# SCENE TREE (InventorySlot.tscn):
#   InventorySlot      [PanelContainer]  custom_min=(52,52)  ← this script
#   ├── Icon           [TextureRect]     expand=FIT_WIDTH_PROPORTIONAL, anchors=full
#   ├── QtyLabel       [Label]           anchors=bottom-right, font_size=11
#   └── PlaceholderLabel [Label]         anchors=center, font_size=10, modulate.a=0.4
class_name InventorySlot
extends PanelContainer

signal right_clicked()
signal drag_started()
signal drag_dropped()

@onready var icon:               TextureRect = $Icon
@onready var qty_label:          Label       = $QtyLabel
@onready var placeholder_label:  Label       = $PlaceholderLabel

var _slot_index: int  = 0
var _is_equip:   bool = false
var _item: Resource   = null

# ── Setup ──────────────────────────────────────────────────────────────────────

func setup(slot_index: int, is_equip: bool) -> void:
	_slot_index = slot_index
	_is_equip   = is_equip
	qty_label.visible         = false
	placeholder_label.visible = false

func set_placeholder_text(text: String) -> void:
	placeholder_label.text    = text
	placeholder_label.visible = (_item == null)

# ── State ──────────────────────────────────────────────────────────────────────

func set_item(item: Resource) -> void:
	_item = item
	if item == null:
		icon.texture              = null
		qty_label.visible         = false
		placeholder_label.visible = (placeholder_label.text != "")
		return

	icon.texture              = item.icon if "icon" in item else null
	placeholder_label.visible = false

	var show_qty := "stackable" in item and item.stackable \
		and "quantity" in item and item.quantity > 1
	if show_qty:
		qty_label.text    = str(item.quantity)
		qty_label.visible = true
	else:
		qty_label.visible = false

# ── Input ──────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			right_clicked.emit()
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_LEFT:
			if _item != null:
				drag_started.emit()
				get_viewport().set_input_as_handled()

## Called by InventoryUI when another slot is dragged and released over this one.
func accept_drop() -> void:
	drag_dropped.emit()
