extends CanvasLayer
class_name InventoryUI

const SLOT_SIZE  : int   = 64
const COLS       : int   = 5
const GAP        : int   = 4
const C_BG               := Color(0.08, 0.08, 0.14, 0.96)
const C_SLOT             := Color(0.18, 0.18, 0.24)
const C_SLOT_HOVER       := Color(0.28, 0.28, 0.36)
const C_SLOT_SEL         := Color(0.35, 0.55, 0.9)

var _inventory:    Inventory = null
var _user:         Node      = null
var _slot_panels:  Array     = []
var _selected:     int       = -1
var _hovered:      int       = -1

var _root:         Panel
var _tooltip:      Panel
var _tooltip_lbl:  RichTextLabel
var _action_menu:  PopupMenu
var _action_slot:  int = -1

signal slot_selected(slot: int)
signal item_used_from_ui(slot: int)
signal item_dropped_from_ui(slot: int)


func setup(inv: Inventory, user: Node) -> void:
	_inventory = inv
	_user      = user
	inv.item_added.connect(_on_changed)
	inv.item_removed.connect(_on_changed)
	inv.stack_changed.connect(_on_stack_changed)
	_build()
	hide()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_all()


# ══════════════════════════════════════════════════════════
# BUILD
# ══════════════════════════════════════════════════════════

func _build() -> void:
	_root = Panel.new()
	_apply_style(_root, C_BG, 8)
	add_child(_root)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(12, 12)
	vbox.add_theme_constant_override("separation", 8)
	_root.add_child(vbox)

	var title := Label.new()
	title.text = "INVENTORY"
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	vbox.add_child(grid)

	for i in _inventory.capacity:
		_slot_panels.append(_build_slot(i, grid))

	# Resize root to fit
	var rows: int = ceil(float(_inventory.capacity) / COLS)
	_root.size = Vector2(
		COLS * (SLOT_SIZE + GAP) + GAP + 24,
		rows * (SLOT_SIZE + GAP) + GAP + 52
	)
	# Center on screen — wait one frame for viewport size
	await get_tree().process_frame
	var vs := get_viewport().get_visible_rect().size
	_root.position = (vs - _root.size) / 2.0

	_build_tooltip()
	_build_action_menu()


func _build_slot(index: int, parent: GridContainer) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_apply_style(slot, C_SLOT, 4)
	parent.add_child(slot)

	var icon := TextureRect.new()
	icon.name              = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.stretch_mode      = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(icon)

	var count := Label.new()
	count.name = "Count"
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.position = Vector2(-22, -18)
	count.add_theme_color_override("font_color", Color.WHITE)
	count.add_theme_font_size_override("font_size", 11)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count)

	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_entered.connect(_on_hover.bind(index))
	slot.mouse_exited.connect(_on_hover_end.bind(index))
	slot.gui_input.connect(_on_slot_input.bind(index))

	return slot


func _build_tooltip() -> void:
	_tooltip = Panel.new()
	_apply_style(_tooltip, Color(0.05, 0.05, 0.12, 0.97), 6)
	_tooltip.custom_minimum_size = Vector2(190, 0)
	add_child(_tooltip)

	_tooltip_lbl = RichTextLabel.new()
	_tooltip_lbl.bbcode_enabled = true
	_tooltip_lbl.fit_content    = true
	_tooltip_lbl.custom_minimum_size = Vector2(180, 0)
	_tooltip_lbl.position       = Vector2(8, 8)
	_tooltip.add_child(_tooltip_lbl)
	_tooltip.hide()


func _build_action_menu() -> void:
	_action_menu = PopupMenu.new()
	_action_menu.add_item("Use",  0)
	_action_menu.add_item("Drop", 1)
	add_child(_action_menu)
	_action_menu.id_pressed.connect(_on_action)


# ══════════════════════════════════════════════════════════
# REFRESH
# ══════════════════════════════════════════════════════════

func _refresh_all() -> void:
	for i in _slot_panels.size():
		_refresh_slot(i)

func _refresh_slot(i: int) -> void:
	var panel := _slot_panels[i]  as Panel
	var icon  := panel.get_node("Icon")  as TextureRect
	var count := panel.get_node("Count") as Label
	var entry := _inventory.get_slot(i)

	if entry.is_empty():
		icon.texture = null
		count.text   = ""
	else:
		icon.texture = entry.item.icon
		count.text   = str(entry.count) if entry.count > 1 else ""

	var c := C_SLOT_SEL if i == _selected else \
			 C_SLOT_HOVER if i == _hovered else C_SLOT
	_apply_style(panel, c, 4)

func _on_changed(_item: Item, slot: int) -> void:
	_refresh_slot(slot)

func _on_stack_changed(slot: int, _count: int) -> void:
	_refresh_slot(slot)


# ══════════════════════════════════════════════════════════
# INPUT
# ══════════════════════════════════════════════════════════

func _on_hover(i: int) -> void:
	_hovered = i
	_refresh_slot(i)
	_show_tooltip(i)

func _on_hover_end(i: int) -> void:
	_hovered = -1
	_refresh_slot(i)
	_tooltip.hide()

func _on_slot_input(event: InputEvent, i: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			var prev := _selected
			_selected = i if _selected != i else -1
			if prev != -1: _refresh_slot(prev)
			_refresh_slot(i)
			slot_selected.emit(_selected)
		MOUSE_BUTTON_RIGHT:
			if not _inventory.get_slot(i).is_empty():
				_action_slot = i
				_action_menu.popup(Rect2i(
					Vector2i(get_viewport().get_mouse_position()),
					Vector2i.ZERO
				))

func _on_action(id: int) -> void:
	match id:
		0:
			_inventory.use_item(_action_slot, _user)
			item_used_from_ui.emit(_action_slot)
		1:
			_inventory.remove_at(_action_slot)
			item_dropped_from_ui.emit(_action_slot)


# ══════════════════════════════════════════════════════════
# TOOLTIP
# ══════════════════════════════════════════════════════════

func _show_tooltip(i: int) -> void:
	var entry := _inventory.get_slot(i)
	if entry.is_empty():
		_tooltip.hide()
		return

	var item := entry.item
	var t    := "[b]%s[/b]\n" % item.name

	if item.description != "":
		t += "[color=#aaaaaa]%s[/color]\n" % item.description

	# Weapon stats block
	if item is WeaponItem:
		var w: WeaponItem = item
		t += "\n[color=#ffdd88]─ Weapon ─[/color]\n"
		t += "Type:   %s\n"   % WeaponItem.WeaponType.keys()[w.weapon_type]
		t += "Damage: [color=#ff9966]%.1f[/color]\n" % w.damage
		t += "Speed:  [color=#99ff99]%.2f/s[/color]\n" % w.attack_speed
		if w.knockback > 0:
			t += "Knockback: %.0f\n" % w.knockback

		if item is MeleeWeapon:
			var m: MeleeWeapon = item
			t += "Range:  %.0f px\n"  % m.range
			t += "Arc:    %.0f°\n"    % m.hit_angle
			if m.pierce_count > 1:
				t += "Pierce: %d targets\n" % m.pierce_count

		if item is RangedWeapon:
			var r: RangedWeapon = item
			t += "Proj. speed: %.0f\n" % r.projectile_speed
			t += "Proj. range: %.0f\n" % r.projectile_range
			if r.ammo_type != "":
				t += "Ammo: [color=#ffcc66]%s[/color]\n" % r.ammo_type

		if item is StaffWeapon:
			var s: StaffWeapon = item
			t += "Mana cost: [color=#8899ff]%.1f[/color]\n" % s.mana_cost
			if s.spell_effect != "":
				t += "Effect: [color=#cc88ff]%s (%.1fs)[/color]\n" % [s.spell_effect, s.effect_duration]

		if item is ShieldWeapon:
			var sh: ShieldWeapon = item
			t += "Block: [color=#88ccff]%.0f%%[/color] absorbed\n" % (sh.block_reduction * 100)

	# Stat modifiers
	if not item.stat_modifiers.is_empty():
		t += "\n[color=#88ddff]─ Modifiers ─[/color]\n"
		for stat in item.stat_modifiers:
			var val: float = item.stat_modifiers[stat]
			var c   := "#88ff88" if val >= 0.0 else "#ff8888"
			var sgn := "+" if val >= 0.0 else ""
			t += "%s: [color=%s]%s%.1f[/color]\n" % [stat, c, sgn, val]

	if entry.count > 1:
		t += "\n[color=#888888]Stack: %d / %d[/color]" % [entry.count, item.max_stack]

	_tooltip_lbl.text = t
	_tooltip.show()

	# Auto-size then position near cursor, keep on screen
	var mp := get_viewport().get_mouse_position()
	var vs := get_viewport().get_visible_rect().size
	var tx := mp.x + 16
	if (tx + _tooltip.size.x) > vs.x:
		tx = mp.x - _tooltip.size.x - 8
	_tooltip.position = Vector2(tx, clamp(mp.y, 0, vs.y - _tooltip.size.y))


# ══════════════════════════════════════════════════════════
# STYLE HELPER
# ══════════════════════════════════════════════════════════

func _apply_style(node: Control, color: Color, radius: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color                   = color
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	node.add_theme_stylebox_override("panel", s)
