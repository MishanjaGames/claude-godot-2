extends CanvasLayer
class_name InventoryUI

const SLOT_SIZE  := 64
const COLS       := 5
const GAP        := 4
const C_SLOT     := Color(0.18, 0.18, 0.24)
const C_HOVER    := Color(0.28, 0.28, 0.36)
const C_SELECTED := Color(0.35, 0.55, 0.90)

@onready var grid:          GridContainer = $Root/VBox/Grid
@onready var tooltip:       Panel         = $Tooltip
@onready var tooltip_label: RichTextLabel = $Tooltip/Label
@onready var action_menu:   PopupMenu     = $ActionMenu

signal slot_selected(slot: int)
signal item_used_from_ui(slot: int)
signal item_dropped_from_ui(slot: int)

var _inventory:   Inventory = null
var _user:        Node      = null
var _panels:      Array     = []
var _selected:    int       = -1
var _hovered:     int       = -1
var _action_slot: int       = -1

const DROPPED_ITEM_SCENE := preload("res://scenes/world/dropped_item.tscn")


# ── Setup ────────────────────────────────────────────────

func setup(inv: Inventory, user: Node) -> void:
	_inventory = inv
	_user      = user
	inv.item_added.connect(_on_slot_changed)
	inv.item_removed.connect(_on_slot_changed)
	inv.stack_changed.connect(_on_stack_changed)
	_build_slots()
	tooltip.hide()
	hide()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_all()


# ── Build ────────────────────────────────────────────────

func _build_slots() -> void:
	for child in grid.get_children():
		child.queue_free()
	_panels.clear()
	for i in _inventory.capacity:
		_panels.append(_build_slot(i))


func _build_slot(i: int) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_style(panel, C_SLOT, 4)

	var icon := TextureRect.new()
	icon.name         = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(icon)

	var count := Label.new()
	count.name         = "Count"
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.position     = Vector2(-22, -18)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_color_override("font_color", Color.WHITE)
	count.add_theme_font_size_override("font_size", 11)
	panel.add_child(count)

	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(_on_hover.bind(i))
	panel.mouse_exited.connect(_on_hover_end.bind(i))
	panel.gui_input.connect(_on_slot_input.bind(i))
	grid.add_child(panel)
	return panel


# ── Refresh ──────────────────────────────────────────────

func _refresh_all() -> void:
	for i in _panels.size():
		_refresh_slot(i)


func _refresh_slot(i: int) -> void:
	if i >= _panels.size():
		return
	var panel := _panels[i]       as Panel
	var icon  := panel.get_node("Icon")  as TextureRect
	var count := panel.get_node("Count") as Label
	var entry := _inventory.get_slot(i)

	if entry.is_empty():
		icon.texture = null
		count.text   = ""
	else:
		icon.texture = entry.item.icon
		count.text   = str(entry.count) if entry.count > 1 else ""

	var c := C_SELECTED if i == _selected else \
			 C_HOVER    if i == _hovered  else C_SLOT
	_style(panel, c, 4)


func _on_slot_changed(_item: Item, slot: int) -> void:
	_refresh_slot(slot)

func _on_stack_changed(slot: int, _count: int) -> void:
	_refresh_slot(slot)


# ── Input ────────────────────────────────────────────────

func _on_hover(i: int) -> void:
	_hovered = i
	_refresh_slot(i)
	_show_tooltip(i)

func _on_hover_end(i: int) -> void:
	_hovered = -1
	_refresh_slot(i)
	tooltip.hide()

func _on_slot_input(event: InputEvent, i: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			var prev  := _selected
			_selected  = i if _selected != i else -1
			if prev != -1: _refresh_slot(prev)
			_refresh_slot(i)
			slot_selected.emit(_selected)
		MOUSE_BUTTON_RIGHT:
			if not _inventory.get_slot(i).is_empty():
				_action_slot = i
				action_menu.popup(Rect2i(
					Vector2i(get_viewport().get_mouse_position()),
					Vector2i.ZERO
				))

func _on_action_menu_id_pressed(id: int) -> void:
	match id:
		0: # Use
			_inventory.use_item(_action_slot, _user)
			item_used_from_ui.emit(_action_slot)
		1: # Drop
			_drop_item(_action_slot)


# ── Drop ─────────────────────────────────────────────────

func _drop_item(slot: int) -> void:
	var entry := _inventory.get_slot(slot)
	if entry.is_empty():
		return
	var dropped := DROPPED_ITEM_SCENE.instantiate() as DroppedItem
	get_tree().current_scene.add_child(dropped)
	dropped.global_position = _user.global_position + Vector2(
		randf_range(-24.0, 24.0),
		randf_range(-24.0, 24.0)
	)
	dropped.setup(entry.item, entry.count)
	_inventory.remove_at(slot, entry.count)
	item_dropped_from_ui.emit(slot)


# ── Tooltip ──────────────────────────────────────────────

func _show_tooltip(i: int) -> void:
	var entry := _inventory.get_slot(i)
	if entry.is_empty():
		tooltip.hide()
		return

	tooltip_label.text = _build_tooltip_text(entry)
	tooltip.show()

	var mp := get_viewport().get_mouse_position()
	var vs := get_viewport().get_visible_rect().size
	var tx := mp.x + 16.0
	if tx + tooltip.size.x > vs.x:
		tx = mp.x - tooltip.size.x - 8.0
	tooltip.position = Vector2(tx, clampf(mp.y, 0.0, vs.y - tooltip.size.y))


func _build_tooltip_text(entry: InventorySlot) -> String:
	var item := entry.item
	var t    := "[b]%s[/b]\n" % item.name

	if item.description != "":
		t += "[color=#aaaaaa]%s[/color]\n" % item.description

	if item is WeaponItem:
		t += _weapon_tooltip(item as WeaponItem)

	if item is EquippableItem:
		var eq := item as EquippableItem
		t += "\n[color=#aaddff]─ Equipment ─[/color]\n"
		t += "Slot: %s\n" % EquippableItem.EquipSlot.keys()[eq.slot]

	if not item.stat_modifiers.is_empty():
		t += "\n[color=#88ddff]─ Modifiers ─[/color]\n"
		for stat in item.stat_modifiers:
			var val: float = item.stat_modifiers[stat]
			var c   := "#88ff88" if val >= 0.0 else "#ff8888"
			var sgn := "+" if val >= 0.0 else ""
			t += "%s: [color=%s]%s%.1f[/color]\n" % [stat, c, sgn, val]

	if entry.count > 1:
		t += "\n[color=#888888]Stack: %d / %d[/color]" % [entry.count, item.max_stack]

	return t


func _weapon_tooltip(w: WeaponItem) -> String:
	var t := "\n[color=#ffdd88]─ Weapon ─[/color]\n"
	t += "Type:   %s\n"                                      % WeaponItem.WeaponType.keys()[w.weapon_type]
	t += "Damage: [color=#ff9966]%.1f[/color]\n"             % w.damage
	t += "Speed:  [color=#99ff99]%.2f/s[/color]\n"           % w.attack_speed
	if w.knockback > 0.0:
		t += "Knockback: %.0f\n"                             % w.knockback

	if w is MeleeWeapon:
		var m := w as MeleeWeapon
		t += "Range:  %.0f px\n"                             % m.range
		t += "Arc:    %.0f°\n"                               % m.hit_angle
		if m.pierce_count > 1:
			t += "Pierce: %d targets\n"                      % m.pierce_count

	if w is ShieldWeapon:
		var sh := w as ShieldWeapon
		t += "Block: [color=#88ccff]%.0f%%[/color] absorbed\n" % (sh.block_reduction * 100.0)

	if w is RangedWeapon and not (w is StaffWeapon):
		var r := w as RangedWeapon
		t += "Proj. speed: %.0f\n"                           % r.projectile_speed
		t += "Proj. range: %.0f\n"                           % r.projectile_range
		if r.ammo_type != "":
			t += "Ammo: [color=#ffcc66]%s[/color]\n"        % r.ammo_type

	if w is ThrowableWeapon:
		var th := w as ThrowableWeapon
		t += "Type: %s\n"                                    % ThrowableWeapon.ThrowableType.keys()[th.throwable_type]

	if w is StaffWeapon:
		var s := w as StaffWeapon
		t += "Mana cost: [color=#8899ff]%.1f[/color]\n"     % s.mana_cost
		if s.spell_effect != "":
			t += "Effect: [color=#cc88ff]%s (%.1fs)[/color]\n" % [s.spell_effect, s.effect_duration]

	return t


# ── Style ────────────────────────────────────────────────

func _style(node: Control, color: Color, radius: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color                   = color
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	node.add_theme_stylebox_override("panel", s)
