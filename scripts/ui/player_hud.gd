extends CanvasLayer
class_name PlayerHUD

var _stats:        Stats        = null
var _hp_bar:       ProgressBar  = null
var _mana_bar:     ProgressBar  = null
var _stats_lbl:    RichTextLabel = null
var _weapon_lbl:   Label        = null
var _root:         Panel        = null


func setup(stats: Stats) -> void:
	_stats = stats
	stats.health_changed.connect(_on_health_changed)
	stats.stat_changed.connect(_on_stat_changed)
	_build()
	_refresh()


func set_weapon(weapon_name: String) -> void:
	_weapon_lbl.text = ("⚔  " + weapon_name) if weapon_name != "" else ""


# ══════════════════════════════════════════════════════════
# BUILD
# ══════════════════════════════════════════════════════════

func _build() -> void:
	_root = Panel.new()
	_root.custom_minimum_size = Vector2(220, 0)
	_root.position            = Vector2(12, 12)
	_apply_style(_root, Color(0.07, 0.07, 0.12, 0.92), 8)
	add_child(_root)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.add_theme_constant_override("separation", 6)
	_root.add_child(vbox)

	# HP bar
	_hp_bar = _make_bar("HP", Color(0.85, 0.2, 0.2), Color(0.3, 0.08, 0.08), vbox)

	# Mana bar (only if the entity has mana)
	if _stats.has_stat("mana"):
		_mana_bar = _make_bar("MP", Color(0.25, 0.45, 0.9), Color(0.08, 0.1, 0.3), vbox)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(1, 1, 1, 0.1))
	vbox.add_child(sep)

	# Stats list
	_stats_lbl = RichTextLabel.new()
	_stats_lbl.bbcode_enabled         = true
	_stats_lbl.fit_content            = true
	_stats_lbl.custom_minimum_size    = Vector2(200, 0)
	_stats_lbl.scroll_active          = false
	vbox.add_child(_stats_lbl)

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(1, 1, 1, 0.1))
	vbox.add_child(sep2)

	# Equipped weapon
	_weapon_lbl = Label.new()
	_weapon_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_weapon_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_weapon_lbl)

	# Resize root after one frame
	_root.size = Vector2(220, 160)

func _process(_delta: float) -> void:
	if _root != null and _stats_lbl != null:
		_root.size = Vector2(220, _stats_lbl.get_parent().size.y + 20)

func _make_bar(label: String, fill: Color, bg: Color, parent: VBoxContainer) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(26, 0)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(160, 14)
	bar.show_percentage     = false
	bar.min_value           = 0.0
	bar.max_value           = 100.0
	bar.value               = 100.0

	var fs := StyleBoxFlat.new()
	fs.bg_color = fill
	fs.corner_radius_bottom_left = 3
	fs.corner_radius_top_right = 3
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


# ══════════════════════════════════════════════════════════
# REFRESH
# ══════════════════════════════════════════════════════════

func _refresh() -> void:
	_hp_bar.max_value = _stats.get_stat("max_health")
	_hp_bar.value     = _stats.get_health()

	if _mana_bar != null and _stats.has_stat("mana"):
		var max_mana: float = _stats.get_stat("max_mana") if _stats.has_stat("max_mana") else 100.0
		_mana_bar.max_value = max_mana
		_mana_bar.value     = _stats.get_stat("mana")

	# Stats list (skip bars and internal stats)
	var skip := ["max_health", "mana", "max_mana"]
	var text := ""
	for stat in _stats.list_stats():
		if stat in skip:
			continue
		var val := _stats.get_stat(stat)
		var base := _stats.get_base(stat)
		var diff := val - base
		var diff_str := ""
		if abs(diff) > 0.01:
			var c    := "#88ff88" if diff > 0 else "#ff8888"
			var sign := "+" if diff > 0 else ""
			diff_str = " [color=%s](%s%.0f)[/color]" % [c, sign, diff]
		text += "[color=#aaaaaa]%s:[/color] [color=#ffffff]%.1f[/color]%s\n" % [stat, val, diff_str]

	_stats_lbl.text = text

func _on_health_changed(current: float, maximum: float) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value     = current

func _on_stat_changed(_name: String, _old: float, _new: float) -> void:
	_refresh()


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
	s.content_margin_left = 0 
	s.content_margin_right = 0
	s.content_margin_top  = 0 
	s.content_margin_bottom = 0
	node.add_theme_stylebox_override("panel", s)
