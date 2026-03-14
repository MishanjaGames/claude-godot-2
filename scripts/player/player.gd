extends CharacterBody2D

var stats     := Stats.new()
var inventory := Inventory.new()

@onready var item_hold:  ItemHold  = $ItemHold
@onready var item_equip: ItemEquip = $ItemEquip

var _hud:          PlayerHUD   = null
var _inventory_ui: InventoryUI = null
var _pause_menu:   PauseMenu   = null


func _ready() -> void:
	stats.initialize({ "health": 100.0, "mana": 100.0, "stamina": 100.0, "speed": 220.0 })
	stats.died.connect(_on_died)
	inventory.initialize(20)
	item_equip.setup(stats)
	item_hold.main_hand_changed.connect(_on_hand_changed)
	item_hold.off_hand_changed.connect(_on_hand_changed)


# Called by world.gd after instantiation.
func bind_ui(hud: PlayerHUD, inv_ui: InventoryUI, pause: PauseMenu) -> void:
	_hud          = hud
	_inventory_ui = inv_ui
	_pause_menu   = pause
	hud.setup(stats)
	inv_ui.setup(inventory, item_equip, self)
	inv_ui.slot_selected.connect(_on_slot_selected)


# ── Physics ──────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_right"): dir.x += 1
	if Input.is_action_pressed("move_left"):  dir.x -= 1
	if Input.is_action_pressed("move_down"):  dir.y += 1
	if Input.is_action_pressed("move_up"):    dir.y -= 1
	if dir.length() > 0:
		dir = dir.normalized()
	velocity = dir * stats.get_stat("speed")
	move_and_slide()

	item_hold.tick(delta)
	if Input.is_action_just_pressed("attack"):
		item_hold.attack_main(self, [])
	if Input.is_action_just_pressed("attack_off"):
		item_hold.attack_off(self, [])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_open_inventory()
	elif event.is_action_pressed("ui_cancel"):  # Esc
		_toggle_pause()
	elif event.is_action_pressed("toggle_raw"):
		Global.toggle_raw()


# ── UI helpers ───────────────────────────────────────────

func _open_inventory() -> void:
	if _pause_menu != null and _pause_menu.visible:
		return  # don't open inventory while paused
	if _inventory_ui != null:
		_inventory_ui.toggle()

func _toggle_pause() -> void:
	if _pause_menu == null:
		return
	if _inventory_ui != null and _inventory_ui.visible:
		_inventory_ui.hide()
		return  # Esc closes inventory first
	_pause_menu.toggle()


# ── Inventory slot selected ──────────────────────────────

func _on_slot_selected(slot: int) -> void:
	if slot == -1:
		return
	var entry := inventory.get_slot(slot)
	if entry.is_empty():
		return
	if entry.item is WeaponItem:
		var weapon := entry.item as WeaponItem
		_toggle_hand(weapon, weapon.weapon_type == WeaponItem.WeaponType.SHIELD)
	elif entry.item is EquippableItem:
		var eq := entry.item as EquippableItem
		if item_equip.get_item(eq.slot) == eq:
			item_equip.unequip(eq.slot)
		else:
			item_equip.equip(eq)


# ── Hand management ──────────────────────────────────────

func _toggle_hand(weapon: WeaponItem, to_off: bool) -> void:
	var current := item_hold.get_off() if to_off else item_hold.get_main()
	var hand    := "off" if to_off else "main"
	if current == weapon:
		_remove_weapon_modifiers(weapon, hand)
		if to_off: item_hold.unequip_off()
		else:      item_hold.unequip_main()
	else:
		if current != null:
			_remove_weapon_modifiers(current, hand)
		_add_weapon_modifiers(weapon, hand)
		if to_off: item_hold.equip_off(weapon)
		else:      item_hold.equip_main(weapon)

func _add_weapon_modifiers(weapon: WeaponItem, hand: String) -> void:
	for stat in weapon.stat_modifiers:
		stats.add_modifier("weapon_%s_%s" % [hand, stat], stat, weapon.stat_modifiers[stat])

func _remove_weapon_modifiers(weapon: WeaponItem, hand: String) -> void:
	for stat in weapon.stat_modifiers:
		stats.remove_modifier("weapon_%s_%s" % [hand, stat])


# ── Signal handlers ──────────────────────────────────────

func _on_hand_changed(_weapon: WeaponItem) -> void:
	if _hud == null:
		return
	var main := item_hold.get_main()
	_hud.set_weapon(main.name if main != null else "")

func _on_died() -> void:
	print("[Player] Died!")
	queue_free()
