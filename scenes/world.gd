extends Node2D

func _ready() -> void:
	var player = $Player

	# Create a sword
	var sword := MeleeWeapon.new()
	sword.id          = "iron_sword"
	sword.name        = "Iron Sword"
	sword.weapon_type = WeaponItem.WeaponType.SWORD
	sword.apply_type_defaults()
	sword.print_info()

	# Create an axe
	var axe := MeleeWeapon.new()
	axe.id          = "iron_axe"
	axe.name        = "Iron Axe"
	axe.weapon_type = WeaponItem.WeaponType.AXE
	axe.apply_type_defaults()
	axe.print_info()

	# Create a bow
	var bow := RangedWeapon.new()
	bow.id   = "short_bow"
	bow.name = "Short Bow"
	bow.apply_type_defaults()
	bow.print_info()

	# Add to inventory
	player.inventory.add_item(sword)
	player.inventory.add_item(axe)
	player.inventory.add_item(bow)
	player.inventory.print_info()
