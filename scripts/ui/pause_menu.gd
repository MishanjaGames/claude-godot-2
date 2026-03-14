extends CanvasLayer
class_name PauseMenu

# Built in code — no scene file needed.
# Add as a child of World, same level as PlayerHUD and InventoryUI.

signal resumed()
signal went_to_main_menu()


func _ready() -> void:
	_build()
	hide()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible


# ── Build ────────────────────────────────────────────────

func _build() -> void:
	# Dimmed backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(260, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel_style(panel, Color(0.07, 0.07, 0.13, 0.98), 10)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(24, 24)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.90, 0.90, 1.00))
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(1, 1, 1, 0.12))
	vbox.add_child(sep)

	_add_button("Continue",  Color(0.22, 0.48, 0.80), vbox).pressed.connect(_on_continue)
	_add_button("Settings",  Color(0.28, 0.28, 0.38), vbox).pressed.connect(_on_settings)
	_add_button("Main Menu", Color(0.38, 0.28, 0.18), vbox).pressed.connect(_on_main_menu)
	_add_button("Quit",      Color(0.50, 0.12, 0.12), vbox).pressed.connect(_on_quit)

	# Resize panel to fit content after one frame
	panel.set_deferred("size", Vector2(260, vbox.get_minimum_size().y + 48))


func _add_button(text: String, color: Color, parent: VBoxContainer) -> Button:
	var btn   := Button.new()
	btn.text   = text
	btn.custom_minimum_size = Vector2(212, 36)

	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left     = 5
	normal.corner_radius_top_right    = 5
	normal.corner_radius_bottom_left  = 5
	normal.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.18)
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 14)
	parent.add_child(btn)
	return btn


func _panel_style(node: Control, color: Color, radius: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	node.add_theme_stylebox_override("panel", s)


# ── Button handlers ──────────────────────────────────────

func _on_continue() -> void:
	hide()
	get_tree().paused = false
	resumed.emit()

func _on_settings() -> void:
	print("Settings — not yet implemented")

func _on_main_menu() -> void:
	get_tree().paused = false
	went_to_main_menu.emit()
	LoadingScreen.load_scene("res://scenes/ui/main_menu.tscn")

func _on_quit() -> void:
	get_tree().quit()
