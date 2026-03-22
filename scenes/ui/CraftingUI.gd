# CraftingUI.gd
# Crafting panel. Shows available recipes for the active station.
# Opened by CraftingStation.interact(). Closed by ui_cancel / close button.
#
# SCENE TREE (CraftingUI.tscn):
#   CraftingUI          [CanvasLayer]  layer=6        ← this script
#                                      add_to_group("crafting_ui")
#   └── Root            [PanelContainer]               anchors=center, min=(520,440)
#       └── MarginContainer
#           └── VBoxContainer
#               ├── TitleLabel     [Label]             text="CRAFTING"
#               ├── StationLabel   [Label]             text="Workbench", font_size=12
#               ├── ContentRow     [HBoxContainer]
#               │   ├── RecipeList [VBoxContainer]     min_width=200, scroll
#               │   │   └── (RecipeButton nodes added at runtime)
#               │   └── DetailPanel [VBoxContainer]   min_width=280
#               │       ├── ResultLabel  [Label]
#               │       ├── ResultIcon   [TextureRect] custom_min=(48,48)
#               │       ├── IngredientsLabel [Label]   text="Requires:"
#               │       ├── IngredientsList  [VBoxContainer]
#               │       └── CraftButton  [Button]      text="Craft"
#               └── CloseButton    [Button]            text="Close"
class_name CraftingUI
extends CanvasLayer

@onready var root:              PanelContainer = $Root
@onready var title_label:       Label          = $Root/MarginContainer/VBoxContainer/TitleLabel
@onready var station_label:     Label          = $Root/MarginContainer/VBoxContainer/StationLabel
@onready var recipe_list:       VBoxContainer  = $Root/MarginContainer/VBoxContainer/ContentRow/RecipeList
@onready var result_label:      Label          = $Root/MarginContainer/VBoxContainer/ContentRow/DetailPanel/ResultLabel
@onready var result_icon:       TextureRect    = $Root/MarginContainer/VBoxContainer/ContentRow/DetailPanel/ResultIcon
@onready var ingredients_list:  VBoxContainer  = $Root/MarginContainer/VBoxContainer/ContentRow/DetailPanel/IngredientsList
@onready var craft_button:      Button         = $Root/MarginContainer/VBoxContainer/ContentRow/DetailPanel/CraftButton
@onready var close_button:      Button         = $Root/MarginContainer/VBoxContainer/CloseButton

var _selected_recipe: RecipeData = null
var _recipes:         Array      = []

# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("crafting_ui")
	root.visible = false
	craft_button.pressed.connect(_on_craft)
	close_button.pressed.connect(close)
	_clear_detail()

func _input(event: InputEvent) -> void:
	if root.visible and event.is_action_just_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# ══════════════════════════════════════════════════════════════════════════════
# OPEN / CLOSE
# ══════════════════════════════════════════════════════════════════════════════

func open(station: RecipeData.CraftStation, display_name: String) -> void:
	station_label.text = display_name
	_recipes           = CraftingManager.available_recipes(station)
	_build_recipe_list()
	root.visible = true
	get_tree().paused = true
	EventBus.menu_opened.emit("crafting")

func close() -> void:
	root.visible = false
	get_tree().paused = false
	_selected_recipe  = null
	EventBus.menu_closed.emit("crafting")

# ══════════════════════════════════════════════════════════════════════════════
# RECIPE LIST
# ══════════════════════════════════════════════════════════════════════════════

func _build_recipe_list() -> void:
	for child in recipe_list.get_children():
		child.queue_free()

	if _recipes.is_empty():
		var lbl := Label.new()
		lbl.text = "No recipes available."
		lbl.add_theme_font_size_override("font_size", 13)
		recipe_list.add_child(lbl)
		return

	for recipe in _recipes:
		var btn  := Button.new()
		var res  := Registry.get_item(recipe.result_id)
		btn.text = res.display_name if res else recipe.result_id
		btn.add_theme_font_size_override("font_size", 13)
		# Grey out if uncraftable.
		if not recipe.can_craft():
			btn.modulate = Color(0.55, 0.55, 0.55)
		btn.pressed.connect(_select_recipe.bind(recipe))
		recipe_list.add_child(btn)

# ══════════════════════════════════════════════════════════════════════════════
# DETAIL PANEL
# ══════════════════════════════════════════════════════════════════════════════

func _select_recipe(recipe: RecipeData) -> void:
	_selected_recipe = recipe
	var res := Registry.get_item(recipe.result_id)

	result_label.text = (res.display_name if res else recipe.result_id) \
		+ " ×%d" % recipe.result_qty
	result_icon.texture = res.icon if res and res.icon else null

	# Rebuild ingredient list.
	for child in ingredients_list.get_children():
		child.queue_free()
	for ing in recipe.ingredients:
		var item_id:  String = ing.get("item_id",  "")
		var required: int    = ing.get("quantity", 1)
		var have:     int    = InventoryManager.count_item(item_id)
		var item_res          = Registry.get_item(item_id)
		var item_name: String = item_res.display_name if item_res else item_id

		var row := Label.new()
		row.text = "  %s  %d / %d" % [item_name, have, required]
		row.add_theme_font_size_override("font_size", 12)
		row.modulate = Color.WHITE if have >= required else Color(1.0, 0.4, 0.4)
		ingredients_list.add_child(row)

	craft_button.disabled = not recipe.can_craft()

func _clear_detail() -> void:
	result_label.text    = "Select a recipe"
	result_icon.texture  = null
	craft_button.disabled = true
	for child in ingredients_list.get_children():
		child.queue_free()

# ══════════════════════════════════════════════════════════════════════════════
# CRAFT
# ══════════════════════════════════════════════════════════════════════════════

func _on_craft() -> void:
	if _selected_recipe == null:
		return
	if CraftingManager.craft(_selected_recipe):
		# Refresh list after successful craft (ingredient counts changed).
		_build_recipe_list()
		_select_recipe(_selected_recipe)   # refresh detail panel
