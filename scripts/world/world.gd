extends Node2D

@onready var player:       CharacterBody2D = $Player
@onready var player_hud:   PlayerHUD       = $PlayerHUD
@onready var inventory_ui: InventoryUI     = $InventoryUI

const SWORD := preload("res://resources/weapons/wooden_sword.tres")

func _ready() -> void:
	player.bind_ui(player_hud, inventory_ui)
	player.inventory.add_item(SWORD.duplicate())
	player.inventory.print_info()
