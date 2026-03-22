# CraftingStation.gd
# Interactable world object (Workbench, Forge, etc.).
# Registers itself as a nearby station when the player enters range,
# then opens the CraftingUI on interact.
#
# SCENE TREE (CraftingStation.tscn):
#   CraftingStation    [StaticBody2D]    ← this script
#   ├── Sprite2D                         (swap per station type)
#   ├── CollisionShape2D
#   ├── InteractLabel  [Label]           text="[E] Craft", offset_y=-28
#   └── InteractArea   [Area2D]
#       └── CollisionShape2D             (slightly larger radius)
class_name CraftingStation
extends StaticBody2D

@export var station_type: RecipeData.CraftStation = RecipeData.CraftStation.WORKBENCH
@export var station_display_name: String           = "Workbench"

@onready var interact_label: Label  = $InteractLabel
@onready var interact_area:  Area2D = $InteractArea

func _ready() -> void:
	interact_label.visible = false
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func interact(_interactor: Node) -> void:
	CraftingManager.active_station = station_type
	# Open CraftingUI — find it by group.
	var ui := get_tree().get_first_node_in_group("crafting_ui")
	if ui and ui.has_method("open"):
		ui.open(station_type, station_display_name)

func _on_body_entered(body: Node) -> void:
	if body != GameManager.player_ref:
		return
	interact_label.text    = "[E] %s" % station_display_name
	interact_label.visible = true
	CraftingManager.register_nearby_station(station_type, self)

func _on_body_exited(body: Node) -> void:
	if body != GameManager.player_ref:
		return
	interact_label.visible = false
	CraftingManager.unregister_nearby_station(station_type)
