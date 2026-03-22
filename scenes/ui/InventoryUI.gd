# InventoryUI.gd
# Full inventory panel: 32 item slots, 6 equipment slots, drag-and-drop, context menu.
# Toggled by "ui_inventory" input action (Tab by default).
#
# SCENE TREE (InventoryUI.tscn):
#   InventoryUI         [CanvasLayer]  layer=5        ← this script
#   └── Root            [PanelContainer]               anchors=center, min=(560,520)
#       └── MarginContainer
#           └── VBoxContainer
#               ├── TitleLabel      [Label]            text="INVENTORY"
#               ├── ContentRow      [HBoxContainer]
#               │   ├── BagSection  [VBoxContainer]
#               │   │   ├── BagLabel  [Label]          text="Bag"
#               │   │   └── BagGrid   [GridContainer]  columns=8
#               │   └── EquipSection [VBoxContainer]
#               │       ├── EquipLabel [Label]         text="Equipment"
#               │       └── EquipGrid  [GridContainer] columns=2
#               └── WeightLabel     [Label]            text="0.0 / 50.0 kg"
#   ContextMenu         [PopupMenu]                    (sibling of Root)
class_name InventoryUI
extends CanvasLayer

@onready var root:           PanelContainer = $Root
@onready var bag_grid:       GridContainer  = $Root/MarginContainer/VBoxContainer/ContentRow/BagSection/BagGrid
@onready var equip_grid:     GridContainer  = $Root/MarginContainer/VBoxContainer/ContentRow/EquipSection/EquipGrid
@onready var weight_label:   Label          = $Root/MarginContainer/VBoxContainer/WeightLabel
@onready var context_menu:   PopupMenu      = $ContextMenu

const SLOT_SCENE: PackedScene = preload("res://scenes/ui/InventorySlot.tscn")

# ── Slot node arrays ───────────────────────────────────────────────────────────
var _bag_slots:   Array[Node] = []
var _equip_slots: Array[Node] = []

# ── Drag state ─────────────────────────────────────────────────────────────────
var _drag_from:    int  = -1
var _drag_is_equip: bool = false
var _ctx_slot:     int  = -1
var _ctx_is_equip: bool = false

# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	root.visible = false
	_build_bag_grid()
	_build_equip_grid()

	EventBus.inventory_item_added.connect(func(_i, _s): _refresh())
	EventBus.inventory_item_removed.connect(func(_i, _s): _refresh())
	EventBus.inventory_item_moved.connect(func(_f, _t): _refresh())
	EventBus.equipment_changed.connect(func(_s, _i): _refresh())

	context_menu.id_pressed.connect(_on_context_menu_id_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_just_pressed("ui_inventory"):
		_toggle()
		get_viewport().set_input_as_handled()

# ══════════════════════════════════════════════════════════════════════════════
# BUILD GRIDS
# ══════════════════════════════════════════════════════════════════════════════

func _build_bag_grid() -> void:
	for i in InventoryManager.INVENTORY_SIZE:
		var slot: Node = SLOT_SCENE.instantiate()
		bag_grid.add_child(slot)
		_bag_slots.append(slot)
		if slot.has_method("setup"):
			slot.setup(i, false)
		_connect_slot(slot, i, false)

func _build_equip_grid() -> void:
	const LABELS := ["Head", "Chest", "Legs", "Feet", "Ring 1", "Ring 2"]
	for i in InventoryManager.EQUIP_SLOTS:
		var slot: Node = SLOT_SCENE.instantiate()
		equip_grid.add_child(slot)
		_equip_slots.append(slot)
		if slot.has_method("setup"):
			slot.setup(i, true)
		if slot.has_method("set_placeholder_text"):
			slot.set_placeholder_text(LABELS[i])
		_connect_slot(slot, i, true)

func _connect_slot(slot: Node, index: int, is_equip: bool) -> void:
	if slot.has_signal("right_clicked"):
		slot.right_clicked.connect(func(): _on_right_clicked(index, is_equip))
	if slot.has_signal("drag_started"):
		slot.drag_started.connect(func(): _on_drag_started(index, is_equip))
	if slot.has_signal("drag_dropped"):
		slot.drag_dropped.connect(func(): _on_drag_dropped(index, is_equip))

# ══════════════════════════════════════════════════════════════════════════════
# REFRESH
# ══════════════════════════════════════════════════════════════════════════════

func _refresh() -> void:
	for i in _bag_slots.size():
		if _bag_slots[i].has_method("set_item"):
			_bag_slots[i].set_item(InventoryManager.slots[i])

	for i in _equip_slots.size():
		if _equip_slots[i].has_method("set_item"):
			_equip_slots[i].set_item(InventoryManager.equip_slots[i])

	_update_weight()

func _update_weight() -> void:
	var total := 0.0
	for s in InventoryManager.slots:
		if s != null:
			total += s.weight * s.quantity
	var limit := 50.0
	if GameManager.player_ref and GameManager.player_ref.stat_block:
		limit = GameManager.player_ref.stat_block.base_weight_limit
	weight_label.text = "%.1f / %.0f kg" % [total, limit]
	weight_label.modulate = Color(1.0, 0.4, 0.3) if total > limit else Color.WHITE

# ══════════════════════════════════════════════════════════════════════════════
# TOGGLE
# ══════════════════════════════════════════════════════════════════════════════

func _toggle() -> void:
	root.visible = not root.visible
	if root.visible:
		_refresh()
		EventBus.menu_opened.emit("inventory")
	else:
		EventBus.menu_closed.emit("inventory")

# ══════════════════════════════════════════════════════════════════════════════
# DRAG & DROP
# ══════════════════════════════════════════════════════════════════════════════

func _on_drag_started(index: int, is_equip: bool) -> void:
	_drag_from      = index
	_drag_is_equip  = is_equip

func _on_drag_dropped(target_index: int, target_is_equip: bool) -> void:
	if _drag_from < 0:
		return

	if not _drag_is_equip and not target_is_equip:
		# Bag → Bag swap.
		InventoryManager.move_item(_drag_from, target_index)
	elif not _drag_is_equip and target_is_equip:
		# Bag → Equipment: try to equip.
		InventoryManager.equip_from_slot(_drag_from)
	elif _drag_is_equip and not target_is_equip:
		# Equipment → Bag: unequip into specific slot.
		InventoryManager.unequip(_drag_from)

	_drag_from = -1
	_refresh()

# ══════════════════════════════════════════════════════════════════════════════
# CONTEXT MENU
# ══════════════════════════════════════════════════════════════════════════════

func _on_right_clicked(index: int, is_equip: bool) -> void:
	_ctx_slot     = index
	_ctx_is_equip = is_equip

	var item := InventoryManager.equip_slots[index] if is_equip \
		else InventoryManager.slots[index]
	if item == null:
		return

	context_menu.clear()
	if not is_equip:
		context_menu.add_item("Use",    0)
		context_menu.add_item("Equip",  1)
		context_menu.add_item("Drop",   2)
		context_menu.add_item("Info",   3)
	else:
		context_menu.add_item("Unequip", 4)
		context_menu.add_item("Info",    3)

	context_menu.popup(Rect2i(
		get_viewport().get_mouse_position(),
		Vector2i(130, 0)
	))

func _on_context_menu_id_pressed(id: int) -> void:
	var item := InventoryManager.equip_slots[_ctx_slot] if _ctx_is_equip \
		else InventoryManager.slots[_ctx_slot]
	if item == null:
		return

	match id:
		0:  # Use
			if item.has_method("use") and item.has_method("can_use"):
				if item.can_use(GameManager.player_ref):
					item.use(GameManager.player_ref)
					InventoryManager.consume_one(_ctx_slot)
					EventBus.inventory_item_used.emit(item, GameManager.player_ref)
					_refresh()
		1:  # Equip
			InventoryManager.equip_from_slot(_ctx_slot)
			_refresh()
		2:  # Drop
			var dropped := InventoryManager.remove_item(_ctx_slot)
			if dropped and GameManager.player_ref:
				EventBus.world_item_spawned.emit(dropped, GameManager.player_ref.global_position)
			_refresh()
		3:  # Info
			var desc := "%s\n%s\nValue: %d  Weight: %.1f" % [
				item.display_name, item.description, item.value, item.weight]
			EventBus.hud_show_message.emit(desc, 4.0)
		4:  # Unequip
			InventoryManager.unequip(_ctx_slot)
			_refresh()
