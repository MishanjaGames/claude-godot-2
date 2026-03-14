extends Node2D

@onready var player:       CharacterBody2D = $Player
@onready var player_hud:   PlayerHUD       = $PlayerHUD
@onready var inventory_ui: InventoryUI     = $InventoryUI

const SWORD := preload("res://resources/weapons/wooden_sword.tres")
const CHESTPLATE := preload("res://resources/items/chestplate.tres")
const HELMET := preload("res://resources/items/helmet.tres")
const LEGGINGS := preload("res://resources/items/leggings.tres")
const BOOTS := preload("res://resources/items/boots.tres")

func _ready() -> void:
	player.bind_ui(player_hud, inventory_ui)
	player.inventory.add_item(SWORD.duplicate())
	player.inventory.add_item(HELMET.duplicate())
	player.inventory.add_item(CHESTPLATE.duplicate())
	player.inventory.add_item(LEGGINGS.duplicate())
	player.inventory.add_item(BOOTS.duplicate())
	player.inventory.print_info()
	player.item_equip.print_info()
