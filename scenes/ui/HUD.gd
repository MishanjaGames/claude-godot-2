# HUD.gd  (patched — adds ClockLabel wired to DayNightCycle)
class_name HUD
extends CanvasLayer

@onready var health_bar:        ProgressBar   = $TopBar/HBoxContainer/HealthBar
@onready var stamina_bar:       ProgressBar   = $TopBar/HBoxContainer/StaminaBar
@onready var xp_bar:            ProgressBar   = $TopBar/HBoxContainer/XPBar
@onready var hotbar_row:        HBoxContainer = $HotbarRoot/HotbarRow
@onready var ammo_label:        Label         = $AmmoLabel
@onready var message_container: VBoxContainer = $MessageContainer
@onready var level_label:       Label         = $LevelLabel
@onready var clock_label:       Label         = $ClockLabel

const HOTBAR_SLOT_SCENE: PackedScene = preload("res://scenes/ui/HotbarSlot.tscn")

var _messages:     Array[Dictionary] = []
var _hotbar_slots: Array[Node]       = []

const MESSAGE_FADE_TIME: float = 0.4

func _ready() -> void:
	_build_hotbar()
	_connect_signals()
	ammo_label.visible  = false
	level_label.text    = "Lv. 1"
	xp_bar.max_value    = 100.0
	xp_bar.value        = 0.0
	clock_label.text    = "06:00"

func _process(delta: float) -> void:
	_tick_messages(delta)
	_update_xp_bar()
	_update_ammo_label()

func _connect_signals() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_stamina_changed.connect(_on_stamina_changed)
	EventBus.hotbar_slot_changed.connect(_on_hotbar_slot_changed)
	EventBus.active_hotbar_changed.connect(_on_active_hotbar_changed)
	EventBus.hud_show_message.connect(_on_show_message)
	EventBus.level_up.connect(_on_level_up)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_respawned.connect(_on_player_respawned)
	EventBus.time_of_day_changed.connect(_on_time_changed)

# ── Health / Stamina / XP ──────────────────────────────────────────────────────

func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	_tween_bar(health_bar, float(current))

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	_tween_bar(stamina_bar, current)

func _update_xp_bar() -> void:
	xp_bar.max_value = float(CombatManager.xp_for_next_level())
	xp_bar.value     = float(CombatManager.current_xp)

func _on_level_up(new_level: int) -> void:
	level_label.text = "Lv. %d" % new_level
	var tween := create_tween()
	tween.tween_property(xp_bar, "modulate", Color(1.0, 0.85, 0.1), 0.1)
	tween.tween_property(xp_bar, "modulate", Color.WHITE, 0.5)

func _tween_bar(bar: ProgressBar, target: float) -> void:
	var tween := bar.create_tween()
	tween.tween_property(bar, "value", target, 0.12).set_ease(Tween.EASE_OUT)

# ── Clock ──────────────────────────────────────────────────────────────────────

func _on_time_changed(_normalised_time: float) -> void:
	clock_label.text = DayNightCycle.clock_string()

# ── Hotbar ─────────────────────────────────────────────────────────────────────

func _build_hotbar() -> void:
	for i in InventoryManager.HOTBAR_SIZE:
		var slot: Node = HOTBAR_SLOT_SCENE.instantiate()
		hotbar_row.add_child(slot)
		_hotbar_slots.append(slot)
		if slot.has_method("setup"):
			slot.setup(i)

func _on_hotbar_slot_changed(slot_index: int, item: Resource) -> void:
	if slot_index >= _hotbar_slots.size(): return
	if _hotbar_slots[slot_index].has_method("set_item"):
		_hotbar_slots[slot_index].set_item(item)

func _on_active_hotbar_changed(slot_index: int) -> void:
	for i in _hotbar_slots.size():
		if _hotbar_slots[i].has_method("set_active"):
			_hotbar_slots[i].set_active(i == slot_index)

# ── Ammo ───────────────────────────────────────────────────────────────────────

func _update_ammo_label() -> void:
	var item := InventoryManager.get_active_item()
	if item is RangedData:
		var weapon := item as RangedData
		ammo_label.visible = true
		ammo_label.text    = "%d / %d" % [weapon._current_ammo, weapon.ammo_count]
		ammo_label.modulate = Color(1.0, 0.4, 0.4) if weapon._current_ammo == 0 else Color.WHITE
	else:
		ammo_label.visible = false

# ── Messages ───────────────────────────────────────────────────────────────────

func _on_show_message(text: String, duration: float) -> void:
	for entry in _messages:
		if entry["label"].text == text:
			entry["timer"] = duration
			entry["label"].modulate.a = 1.0
			return
	var lbl := Label.new()
	lbl.text                 = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	message_container.add_child(lbl)
	_messages.append({ "label": lbl, "timer": duration })

func _tick_messages(delta: float) -> void:
	var i := 0
	while i < _messages.size():
		var entry: Dictionary = _messages[i]
		entry["timer"] -= delta
		if entry["timer"] < MESSAGE_FADE_TIME:
			entry["label"].modulate.a = maxf(0.0, entry["timer"] / MESSAGE_FADE_TIME)
		if entry["timer"] <= 0.0:
			entry["label"].queue_free()
			_messages.remove_at(i)
		else:
			i += 1

# ── Death / Respawn ────────────────────────────────────────────────────────────

func _on_player_died() -> void:
	_on_show_message("You died…", 3.0)

func _on_player_respawned(_pos: Vector2) -> void:
	_on_show_message("Respawned", 2.0)
