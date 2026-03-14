extends CanvasLayer
class_name PlayerHUD

# Always-visible minimal HUD: health, mana, stamina bars + equipped weapon.
# Built entirely in code — no scene file needed.

var _stats: Stats = null

var _hp_bar:      ProgressBar = null
var _mp_bar:      ProgressBar = null
var _sp_bar:      ProgressBar = null
var _weapon_label: Label      = null


# ── Setup ────────────────────────────────────────────────

func setup(s: Stats) -> void:
	_stats = s
	s.health_changed.connect(_on_health_changed)
	s.mana_changed.connect(_on_mana_changed)
	s.stamina_changed.connect(_on_stamina_changed)
	_build()
	_refresh()


func set_weapon(weapon_name: String) -> void:
	if _weapon_label != null:
		_weapon_label.text = ("⚔  " + weapon_name) if weapon_name != "" else ""


# ── Build ────────────────────────────────────────────────

func _build() -> void:
	var root := Panel.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	root.position          = Vector2(12, -120)
	root.custom_minimum_size = Vector2(200, 108)
	_panel_style(root, Color(0.05, 0.05, 0.10, 0.85), 8)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.add_theme_constant_override("separation", 6)
	root.add_child(vbox)

	_hp_bar = _make_bar("HP", Color(0.85, 0.18, 0.18), Color(0.25, 0.06, 0.06), vbox)
	if _stats.has_stat("max_mana"):
		_mp_bar = _make_bar("MP", Color(0.22, 0.40, 0.90), Color(0.07, 0.10, 0.28), vbox)
	if _stats.has_stat("max_stamina"):
		_sp_bar = _make_bar("SP", Color(0.20, 0.75, 0.30), Color(0.06, 0.22, 0.08), vbox)

	_weapon_label = Label.new()
	_weapon_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_weapon_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_weapon_label)


func _make_bar(tag: String, fill: Color, bg: Color, parent: VBoxContainer) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = tag
	lbl.custom_minimum_size = Vector2(24, 0)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(155, 13)
	bar.show_percentage     = false
	bar.min_value           = 0.0
	bar.max_value           = 100.0
	bar.value               = 100.0

	var fs := StyleBoxFlat.new()
	fs.bg_color = fill
	fs.corner_radius_top_left = 3 
	fs.corner_radius_top_right     = 3
	fs.corner_radius_bottom_left = 3 
	fs.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fs)

	var bs := StyleBoxFlat.new()
	bs.bg_color = bg
	bs.corner_radius_top_left = 3
	bs.corner_radius_top_right = 3
	bs.corner_radius_bottom_left = 3 
	bs.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bs)

	row.add_child(bar)
	return bar


func _panel_style(node: Control, color: Color, radius: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	node.add_theme_stylebox_override("panel", s)


# ── Refresh ──────────────────────────────────────────────

func _refresh() -> void:
	if _stats == null:
		return
	_hp_bar.max_value = _stats.get_stat("max_health")
	_hp_bar.value     = _stats.get_health()
	if _mp_bar != null:
		_mp_bar.max_value = _stats.get_stat("max_mana")
		_mp_bar.value     = _stats.get_mana()
	if _sp_bar != null:
		_sp_bar.max_value = _stats.get_stat("max_stamina")
		_sp_bar.value     = _stats.get_stamina()


# ── Signal handlers ──────────────────────────────────────

func _on_health_changed(current: float, maximum: float) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value     = current

func _on_mana_changed(current: float, maximum: float) -> void:
	if _mp_bar != null:
		_mp_bar.max_value = maximum
		_mp_bar.value     = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	if _sp_bar != null:
		_sp_bar.max_value = maximum
		_sp_bar.value     = current
