extends CharacterBody2D

var stats     := Stats.new()
var inventory := Inventory.new()

@onready var item_hold:  ItemHold  = $ItemHold
@onready var item_equip: ItemEquip = $ItemEquip

var _hud:          PlayerHUD   = null
var _inventory_ui: InventoryUI = null


func _ready() -> void:
	stats.initialize({ "health": 100.0, "mana": 100.0, "speed": 220.0 })
	stats.died.connect(_on_died)
	inventory.initialize(20)

	item_equip.setup(stats)

	item_hold.main_hand_changed.connect(_on_main_hand_changed)
	item_hold.off_hand_changed.connect(_on_off_hand_changed)


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

	item_hold.tick(delta)

	if Input.is_action_just_pressed("attack"):
		item_hold.attack_main(self, [])

	if Input.is_action_just_pressed("attack_off"):
		item_hold.attack_off(self, [])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory") and _inventory_ui != null:
		_inventory_ui.toggle()
	if event.is_action_pressed("toggle_raw"):
		Global.toggle_raw()


# ── Slot selected in inventory UI ────────────────────────

func _on_slot_selected(slot: int) -> void:
	if slot == -1:
		return
	var entry := inventory.get_slot(slot)
	if entry.is_empty():
		return

	# Weapon → goes to ItemHold
	if entry.item is WeaponItem:
		var weapon := entry.item as WeaponItem
		# Shield always goes to off-hand
		if weapon.weapon_type == WeaponItem.WeaponType.SHIELD:
			_toggle_off_hand(weapon)
		else:
			_toggle_main_hand(weapon)

	# Equippable → goes to ItemEquip
	elif entry.item is EquippableItem:
		var equippable := entry.item as EquippableItem
		if item_equip.get_item(equippable.slot) == equippable:
			item_equip.unequip(equippable.slot)
		else:
			item_equip.equip(equippable)


func _toggle_main_hand(weapon: WeaponItem) -> void:
	if item_hold.get_main() == weapon:
		_remove_weapon_modifiers(weapon, "main")
		item_hold.unequip_main()
	else:
		if item_hold.get_main() != null:
			_remove_weapon_modifiers(item_hold.get_main(), "main")
		_add_weapon_modifiers(weapon, "main")
		item_hold.equip_main(weapon)


func _toggle_off_hand(weapon: WeaponItem) -> void:
	if item_hold.get_off() == weapon:
		_remove_weapon_modifiers(weapon, "off")
		item_hold.unequip_off()
	else:
		if item_hold.get_off() != null:
			_remove_weapon_modifiers(item_hold.get_off(), "off")
		_add_weapon_modifiers(weapon, "off")
		item_hold.equip_off(weapon)


func _add_weapon_modifiers(weapon: WeaponItem, hand: String) -> void:
	for stat in weapon.stat_modifiers:
		stats.add_modifier("weapon_%s_%s" % [hand, stat], stat, weapon.stat_modifiers[stat])


func _remove_weapon_modifiers(weapon: WeaponItem, hand: String) -> void:
	for stat in weapon.stat_modifiers:
		stats.remove_modifier("weapon_%s_%s" % [hand, stat])



# ── Signals ──────────────────────────────────────────────

func _on_main_hand_changed(weapon: WeaponItem) -> void:
	if _hud != null:
		_hud.set_weapon(weapon.name if weapon != null else "")


func _on_off_hand_changed(weapon: WeaponItem) -> void:
	pass  # HUD off-hand display comes later


func _on_died() -> void:
	print("[Player] Died!")
	queue_free()
