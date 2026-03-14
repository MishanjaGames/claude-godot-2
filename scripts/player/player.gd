extends CharacterBody2D

var stats     := Stats.new()
var inventory := Inventory.new()

@onready var weapon_holder: WeaponHolder = $WeaponHolder

var _equipped_weapon: WeaponItem = null
var _hud:             PlayerHUD   = null
var _inventory_ui:    InventoryUI = null


func _ready() -> void:
	stats.initialize({ "max_health": 120.0, "speed": 220.0 })
	stats.died.connect(_on_died)
	inventory.initialize(20)


# Called by world.gd after instantiation
func bind_ui(hud: PlayerHUD, inv_ui: InventoryUI) -> void:
	_hud          = hud
	_inventory_ui = inv_ui
	hud.setup(stats)
	inv_ui.setup(inventory, self)
	inv_ui.slot_selected.connect(_on_slot_selected)


func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_right"): direction.x += 1
	if Input.is_action_pressed("move_left"):  direction.x -= 1
	if Input.is_action_pressed("move_down"):  direction.y += 1
	if Input.is_action_pressed("move_up"):    direction.y -= 1
	if direction.length() > 0:
		direction = direction.normalized()
	velocity = direction * stats.get_stat("speed")
	move_and_slide()

	if _equipped_weapon != null:
		_equipped_weapon.tick(delta)
		if Input.is_action_just_pressed("attack"):
			_equipped_weapon.attack(self, [])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory") and _inventory_ui != null:
		_inventory_ui.toggle()


func equip_weapon(weapon: WeaponItem) -> void:
	if _equipped_weapon != null:
		for stat in _equipped_weapon.stat_modifiers:
			stats.remove_modifier("weapon_" + stat)

	_equipped_weapon = weapon

	if weapon != null:
		for stat in weapon.stat_modifiers:
			stats.add_modifier("weapon_" + stat, stat, weapon.stat_modifiers[stat])
		if weapon_holder != null:
			weapon_holder.equip(weapon)
		if _hud != null:
			_hud.set_weapon(weapon.name)
	else:
		if weapon_holder != null:
			weapon_holder.unequip()
		if _hud != null:
			_hud.set_weapon("")


func _on_slot_selected(slot: int) -> void:
	if slot == -1:
		equip_weapon(null)
		return
	var entry := inventory.get_slot(slot)
	if not entry.is_empty() and entry.item is WeaponItem:
		equip_weapon(entry.item as WeaponItem)


func _on_died() -> void:
	print("[Player] Died!")
	queue_free()
