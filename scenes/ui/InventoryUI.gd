# InventoryUI.gd
# 32-slot grid with drag-and-drop and right-click context menu.
extends CanvasLayer

@onready var grid: GridContainer      = $Panel/MarginContainer/GridContainer
@onready var context_menu: PopupMenu  = $ContextMenu
@onready var panel: PanelContainer    = $Panel

const SLOT_SCENE: PackedScene = preload("res://scenes/ui/InventorySlot.tscn")

var _selected_slot_index: int = -1
var _drag_slot_index: int     = -1
var _drag_preview: TextureRect = null

func _ready() -> void:
	panel.visible = false
	_build_grid()
	EventBus.inventory_item_added.connect(_on_inventory_changed)
	EventBus.inventory_item_removed.connect(_on_inventory_changed)

	context_menu.id_pressed.connect(_on_context_menu_id_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_inventory"):   # Map Tab in InputMap
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()

func _build_grid() -> void:
	for i in InventoryManager.INVENTORY_SIZE:
		var slot = SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.right_clicked.connect(_on_slot_right_clicked)
		slot.drag_started.connect(_on_slot_drag_started)
		slot.drag_dropped.connect(_on_slot_drag_dropped)
		grid.add_child(slot)
	_refresh_all_slots()

func _refresh_all_slots() -> void:
	var children = grid.get_children()
	for i in children.size():
		children[i].set_item(InventoryManager.slots[i])

func _on_inventory_changed(_item: Resource, _idx: int) -> void:
	_refresh_all_slots()

func _on_slot_right_clicked(slot_index: int) -> void:
	_selected_slot_index = slot_index
	if InventoryManager.slots[slot_index] == null:
		return
	context_menu.clear()
	context_menu.add_item("Use",     0)
	context_menu.add_item("Equip",   1)
	context_menu.add_item("Drop",    2)
	context_menu.add_item("Inspect", 3)
	context_menu.popup(Rect2i(get_viewport().get_mouse_position(), Vector2i(120, 0)))

func _on_context_menu_id_pressed(id: int) -> void:
	var item = InventoryManager.slots[_selected_slot_index]
	if item == null:
		return
	match id:
		0:  # Use
			item.use(GameManager.player_ref)
			EventBus.inventory_item_used.emit(item, GameManager.player_ref)
		1:  # Equip — assign to first free hotbar slot
			for h in InventoryManager.HOTBAR_SIZE:
				if InventoryManager.hotbar_slots[h] == null:
					InventoryManager.assign_to_hotbar(_selected_slot_index, h)
					break
		2:  # Drop — remove and spawn WorldItem at player feet
			var dropped = InventoryManager.remove_item(_selected_slot_index)
			# WorldItem spawning handled via EventBus listener in WorldScreen (stub)
			EventBus.world_item_spawned.emit(dropped)
		3:  # Inspect
			EventBus.hud_show_message.emit(item.display_name + ": " + item.description, 4.0)

func _on_slot_drag_started(slot_index: int) -> void:
	_drag_slot_index = slot_index

func _on_slot_drag_dropped(target_index: int) -> void:
	if _drag_slot_index >= 0 and _drag_slot_index != target_index:
		InventoryManager.move_item(_drag_slot_index, target_index)
		_refresh_all_slots()
	_drag_slot_index = -1
