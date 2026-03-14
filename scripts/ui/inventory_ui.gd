extends CanvasLayer
class_name InventoryUI

# ── Layout constants ─────────────────────────────────────
const SLOT_SIZE   := 56
const COLS        := 5
const GAP         := 4
const PANEL_PAD   := 12

const C_BG        := Color(0.07, 0.07, 0.13, 0.97)
const C_SLOT      := Color(0.16, 0.16, 0.22)
const C_SLOT_HVR  := Color(0.26, 0.26, 0.34)
const C_SLOT_SEL  := Color(0.30, 0.50, 0.85)
const C_SLOT_EQ   := Color(0.20, 0.40, 0.22)   # green tint for equipped slots
const C_DETAIL_BG := Color(0.05, 0.05, 0.10, 0.97)

# Equipment slot layout: { EquipSlot → display label }
const EQUIP_LAYOUT: Array = [
	{ "slot": EquippableItem.EquipSlot.HEAD,     "label": "Head"    },
	{ "slot": EquippableItem.EquipSlot.CHEST,    "label": "Chest"   },
	{ "slot": EquippableItem.EquipSlot.LEGS,     "label": "Legs"    },
	{ "slot": EquippableItem.EquipSlot.FEET,     "label": "Feet"    },
	{ "slot": EquippableItem.EquipSlot.HANDS,    "label": "Hands"   },
	{ "slot": EquippableItem.EquipSlot.RING_L,   "label": "Ring L"  },
	{ "slot": EquippableItem.EquipSlot.RING_R,   "label": "Ring R"  },
	{ "slot": EquippableItem.EquipSlot.AMULET,   "label": "Amulet"  },
	{ "slot": EquippableItem.EquipSlot.ARTIFACT, "label": "Artifact"},
]

signal slot_selected(slot: int)
signal item_used_from_ui(slot: int)
signal item_dropped_from_ui(slot: int)

var _inventory:    Inventory = null
var _item_equip:   ItemEquip = null
var _user:         Node      = null

# Inventory grid
var _inv_panels:   Array = []
var _selected:     int   = -1
var _hovered:      int   = -1

# Equipment panel slots: { EquipSlot → Panel }
var _equip_panels: Dictionary = {}

# Currently shown detail item — either from inv slot index or equip slot
var _detail_inv_slot:   int                          = -1
var _detail_equip_slot: EquippableItem.EquipSlot     = EquippableItem.EquipSlot.HEAD
var _detail_from_equip: bool                         = false

# UI nodes
var _root:           Control     = null
var _detail_panel:   Panel       = null
var _detail_name:    Label       = null
var _detail_desc:    Label       = null
var _detail_stats:   RichTextLabel = null
var _btn_equip:      Button      = null
var _btn_use:        Button      = null
var _btn_drop:       Button      = null

const DROPPED_ITEM_SCENE := preload("res://scenes/world/dropped_item.tscn")


# ── Setup ────────────────────────────────────────────────

func setup(inv: Inventory, equip: ItemEquip, user: Node) -> void:
	_inventory  = inv
	_item_equip = equip
	_user       = user

	inv.item_added.connect(_on_inv_changed)
	inv.item_removed.connect(_on_inv_changed)
	inv.stack_changed.connect(_on_stack_changed)
	equip.equipped.connect(_on_equip_changed)
	equip.unequipped.connect(_on_equip_changed)

	_build()
	hide()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_all()
		_hide_detail()


# ── Build ─────────────────────────────────────────────────

func _build() -> void:
	# Dark fullscreen backdrop (click to close)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.45)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			hide()
	)
	add_child(backdrop)

	# Main container — centered
	_root = HBoxContainer.new()
	_root.add_theme_constant_override("separation", 8)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_root)

	_build_player_panel()
	_build_inventory_panel()
	_build_detail_panel()

	# Reposition after one frame so sizes are known
	_root.set_deferred("position", Vector2.ZERO)


func _build_player_panel() -> void:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(180, 0)
	_bg_style(panel, C_BG, 8)
	_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(PANEL_PAD, PANEL_PAD)
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "EQUIPMENT"
	title.add_theme_color_override("font_color", Color(0.75, 0.75, 1.0))
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	# One slot row per equipment slot
	for entry in EQUIP_LAYOUT:
		var slot_enum: EquippableItem.EquipSlot = entry["slot"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = entry["label"]
		lbl.custom_minimum_size = Vector2(52, 0)
		lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.70))
		lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(lbl)

		var slot_panel := Panel.new()
		slot_panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		_slot_style(slot_panel, C_SLOT, 4)
		row.add_child(slot_panel)

		var icon := TextureRect.new()
		icon.name         = "Icon"
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_panel.add_child(icon)

		var elbl := Label.new()
		elbl.name = "Label"
		elbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		elbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		elbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		elbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
		elbl.add_theme_font_size_override("font_size", 10)
		elbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(elbl)

		slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_panel.mouse_entered.connect(_on_equip_hover.bind(slot_enum, slot_panel))
		slot_panel.mouse_exited.connect(_on_equip_hover_end.bind(slot_enum, slot_panel))
		slot_panel.gui_input.connect(_on_equip_slot_input.bind(slot_enum))

		_equip_panels[slot_enum] = slot_panel


func _build_inventory_panel() -> void:
	var panel := Panel.new()
	_bg_style(panel, C_BG, 8)
	_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(PANEL_PAD, PANEL_PAD)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "INVENTORY"
	title.add_theme_color_override("font_color", Color(0.75, 0.75, 1.0))
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.name    = "Grid"
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	vbox.add_child(grid)

	for i in _inventory.capacity:
		_inv_panels.append(_build_inv_slot(i, grid))


func _build_inv_slot(i: int, parent: GridContainer) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_slot_style(slot, C_SLOT, 4)
	parent.add_child(slot)

	var icon := TextureRect.new()
	icon.name         = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(icon)

	var count := Label.new()
	count.name         = "Count"
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.position     = Vector2(-20, -16)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_color_override("font_color", Color.WHITE)
	count.add_theme_font_size_override("font_size", 10)
	slot.add_child(count)

	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_entered.connect(_on_inv_hover.bind(i))
	slot.mouse_exited.connect(_on_inv_hover_end.bind(i))
	slot.gui_input.connect(_on_inv_slot_input.bind(i))
	return slot


func _build_detail_panel() -> void:
	_detail_panel = Panel.new()
	_detail_panel.custom_minimum_size = Vector2(210, 0)
	_bg_style(_detail_panel, C_DETAIL_BG, 8)
	_root.add_child(_detail_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(PANEL_PAD, PANEL_PAD)
	vbox.add_theme_constant_override("separation", 8)
	_detail_panel.add_child(vbox)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 15)
	_detail_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_detail_name)

	_detail_desc = Label.new()
	_detail_desc.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	_detail_desc.add_theme_font_size_override("font_size", 11)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_detail_desc)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(1, 1, 1, 0.12))
	vbox.add_child(sep)

	_detail_stats = RichTextLabel.new()
	_detail_stats.bbcode_enabled      = true
	_detail_stats.fit_content         = true
	_detail_stats.scroll_active       = false
	_detail_stats.custom_minimum_size = Vector2(186, 0)
	vbox.add_child(_detail_stats)

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(1, 1, 1, 0.12))
	vbox.add_child(sep2)

	# Action buttons
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_vbox)

	_btn_equip = _make_button("Equip",      Color(0.25, 0.50, 0.85), btn_vbox)
	_btn_use   = _make_button("Use",        Color(0.22, 0.60, 0.28), btn_vbox)
	_btn_drop  = _make_button("Drop",       Color(0.55, 0.18, 0.18), btn_vbox)

	_btn_equip.pressed.connect(_on_btn_equip)
	_btn_use.pressed.connect(_on_btn_use)
	_btn_drop.pressed.connect(_on_btn_drop)

	_detail_panel.visible = false


func _make_button(text: String, color: Color, parent: VBoxContainer) -> Button:
	var btn := Button.new()
	btn.text = text
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_top    = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	parent.add_child(btn)
	return btn


# ── Refresh ──────────────────────────────────────────────

func _refresh_all() -> void:
	for i in _inv_panels.size():
		_refresh_inv_slot(i)
	for entry in EQUIP_LAYOUT:
		_refresh_equip_slot(entry["slot"])


func _refresh_inv_slot(i: int) -> void:
	if i >= _inv_panels.size():
		return
	var panel := _inv_panels[i]              as Panel
	var icon  := panel.get_node("Icon")      as TextureRect
	var count := panel.get_node("Count")     as Label
	var entry := _inventory.get_slot(i)

	icon.texture = entry.item.icon if not entry.is_empty() else null
	count.text   = str(entry.count) if (not entry.is_empty() and entry.count > 1) else ""

	var c := C_SLOT_SEL if i == _selected else \
			 C_SLOT_HVR if i == _hovered  else C_SLOT
	_slot_style(panel, c, 4)


func _refresh_equip_slot(slot_enum: EquippableItem.EquipSlot) -> void:
	var panel := _equip_panels.get(slot_enum) as Panel
	if panel == null:
		return
	var item: EquippableItem = _item_equip.get_item(slot_enum)
	var icon  := panel.get_node("Icon")  as TextureRect
	var label := panel.get_node("Label") as Label

	if item != null:
		icon.texture = item.icon
		label.text   = ""
		_slot_style(panel, C_SLOT_EQ, 4)
	else:
		icon.texture = null
		label.text   = "—"
		_slot_style(panel, C_SLOT, 4)


func _on_inv_changed(_item: Item, slot: int) -> void:
	_refresh_inv_slot(slot)

func _on_stack_changed(slot: int, _count: int) -> void:
	_refresh_inv_slot(slot)

func _on_equip_changed(_item: EquippableItem, slot: EquippableItem.EquipSlot) -> void:
	_refresh_equip_slot(slot)


# ── Inventory slot input ─────────────────────────────────

func _on_inv_hover(i: int) -> void:
	_hovered = i
	_refresh_inv_slot(i)

func _on_inv_hover_end(i: int) -> void:
	_hovered = -1
	_refresh_inv_slot(i)

func _on_inv_slot_input(event: InputEvent, i: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		var prev  := _selected
		_selected  = i if _selected != i else -1
		if prev != -1: _refresh_inv_slot(prev)
		_refresh_inv_slot(i)
		slot_selected.emit(_selected)
		if _selected != -1:
			_show_detail_for_inv(_selected)
		else:
			_hide_detail()


# ── Equipment slot input ─────────────────────────────────

func _on_equip_hover(slot_enum: EquippableItem.EquipSlot, panel: Panel) -> void:
	if _item_equip.get_item(slot_enum) != null:
		_slot_style(panel, C_SLOT_HVR, 4)

func _on_equip_hover_end(slot_enum: EquippableItem.EquipSlot, panel: Panel) -> void:
	_refresh_equip_slot(slot_enum)

func _on_equip_slot_input(event: InputEvent, slot_enum: EquippableItem.EquipSlot) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if _item_equip.get_item(slot_enum) != null:
			_show_detail_for_equip(slot_enum)
		else:
			_hide_detail()


# ── Detail panel ─────────────────────────────────────────

func _show_detail_for_inv(i: int) -> void:
	var entry := _inventory.get_slot(i)
	if entry.is_empty():
		_hide_detail()
		return
	_detail_inv_slot   = i
	_detail_from_equip = false
	_populate_detail(entry.item, entry.count)

func _show_detail_for_equip(slot_enum: EquippableItem.EquipSlot) -> void:
	var item: EquippableItem = _item_equip.get_item(slot_enum)
	if item == null:
		_hide_detail()
		return
	_detail_equip_slot = slot_enum
	_detail_from_equip = true
	_populate_detail(item, 1)

func _hide_detail() -> void:
	_detail_panel.visible = false
	_detail_inv_slot      = -1
	_detail_from_equip    = false


func _populate_detail(item: Item, count: int) -> void:
	_detail_name.text = item.name
	_detail_desc.text = item.description

	# Stats block
	var t := ""
	if item is WeaponItem:
		var w := item as WeaponItem
		t += "[color=#ffdd88]Weapon — %s[/color]\n" % WeaponItem.WeaponType.keys()[w.weapon_type]
		t += "Damage:  [color=#ff9966]%.1f[/color]\n" % w.damage
		t += "Speed:   [color=#99ff99]%.2f/s[/color]\n" % w.attack_speed
		if w.knockback > 0.0:
			t += "Knockback: %.0f\n" % w.knockback
		if w is MeleeWeapon:
			var m := w as MeleeWeapon
			t += "Range:   %.0f px\n" % m.range
			t += "Arc:     %.0f°\n"   % m.hit_angle
			if m.pierce_count > 1:
				t += "Pierce: %d\n"   % m.pierce_count
		if w is ShieldWeapon:
			t += "Block:  [color=#88ccff]%.0f%%[/color]\n" % ((w as ShieldWeapon).block_reduction * 100.0)
		if w is RangedWeapon and not (w is StaffWeapon):
			var r := w as RangedWeapon
			t += "Proj. spd: %.0f\n" % r.projectile_speed
			if r.ammo_type != "":
				t += "Ammo: [color=#ffcc66]%s[/color]\n" % r.ammo_type
		if w is StaffWeapon:
			var s := w as StaffWeapon
			t += "Mana:    [color=#8899ff]%.1f[/color]\n"   % s.mana_cost
			if s.spell_effect != "":
				t += "Effect: [color=#cc88ff]%s %.1fs[/color]\n" % [s.spell_effect, s.effect_duration]

	if item is EquippableItem:
		var eq := item as EquippableItem
		t += "[color=#aaddff]Equipment — %s[/color]\n" % EquippableItem.EquipSlot.keys()[eq.slot]

	if not item.stat_modifiers.is_empty():
		t += "\n[color=#88ddff]Modifiers[/color]\n"
		for stat in item.stat_modifiers:
			var val: float = item.stat_modifiers[stat]
			var c   := "#88ff88" if val >= 0.0 else "#ff8888"
			var sgn := "+" if val >= 0.0 else ""
			t += "%s: [color=%s]%s%.1f[/color]\n" % [stat, c, sgn, val]

	if count > 1:
		t += "\n[color=#777777]x%d[/color]" % count

	_detail_stats.text = t

	# Show/hide action buttons based on item type
	var is_equippable := item is WeaponItem or item is EquippableItem
	var is_usable     := not (item is WeaponItem) and not (item is EquippableItem)

	_btn_equip.visible = is_equippable
	_btn_use.visible   = is_usable
	_btn_drop.visible  = true

	# Change label: Equip ↔ Unequip
	if _detail_from_equip:
		_btn_equip.text = "Unequip"
	else:
		_btn_equip.text = "Equip"

	_detail_panel.visible = true


# ── Action buttons ────────────────────────────────────────

func _on_btn_equip() -> void:
	if _detail_from_equip:
		_item_equip.unequip(_detail_equip_slot)
		_hide_detail()
		return

	var entry := _inventory.get_slot(_detail_inv_slot)
	if entry.is_empty():
		return

	if entry.item is EquippableItem:
		var eq := entry.item as EquippableItem
		if _item_equip.get_item(eq.slot) == eq:
			_item_equip.unequip(eq.slot)
		else:
			_item_equip.equip(eq)

	elif entry.item is WeaponItem:
		slot_selected.emit(_detail_inv_slot)

	_hide_detail()
	_selected = -1
	_refresh_all()


func _on_btn_use() -> void:
	if _detail_inv_slot == -1:
		return
	_inventory.use_item(_detail_inv_slot, _user)
	item_used_from_ui.emit(_detail_inv_slot)
	_hide_detail()
	_selected = -1


func _on_btn_drop() -> void:
	if _detail_from_equip:
		# Unequip first then drop into world
		var item := _item_equip.get_item(_detail_equip_slot)
		if item != null:
			_item_equip.unequip(_detail_equip_slot)
			_spawn_dropped(item, 1)
		_hide_detail()
		return

	if _detail_inv_slot == -1:
		return
	var entry := _inventory.get_slot(_detail_inv_slot)
	if entry.is_empty():
		return
	_spawn_dropped(entry.item, entry.count)
	_inventory.remove_at(_detail_inv_slot, entry.count)
	item_dropped_from_ui.emit(_detail_inv_slot)
	_hide_detail()
	_selected = -1
	_refresh_all()


func _spawn_dropped(item: Item, count: int) -> void:
	var dropped := DROPPED_ITEM_SCENE.instantiate() as DroppedItem
	get_tree().current_scene.add_child(dropped)
	dropped.global_position = _user.global_position + Vector2(
		randf_range(-28.0, 28.0), randf_range(-28.0, 28.0)
	)
	dropped.setup(item, count)


# ── Style helpers ────────────────────────────────────────

func _bg_style(node: Control, color: Color, radius: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left   = PANEL_PAD
	s.content_margin_right  = PANEL_PAD
	s.content_margin_top    = PANEL_PAD
	s.content_margin_bottom = PANEL_PAD
	node.add_theme_stylebox_override("panel", s)

func _slot_style(node: Control, color: Color, radius: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	node.add_theme_stylebox_override("panel", s)
