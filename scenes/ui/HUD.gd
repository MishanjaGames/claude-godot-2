# HUD.gd
# Reads from EventBus only — no direct references to Player.
extends CanvasLayer

@onready var health_bar: ProgressBar  = $MarginContainer/TopBar/HealthBar
@onready var stamina_bar: ProgressBar = $MarginContainer/TopBar/StaminaBar
@onready var hotbar_container: HBoxContainer = $HotbarContainer
@onready var minimap_placeholder: Control    = $MinimapPlaceholder
@onready var message_label: Label            = $MessageLabel

var _hotbar_slots: Array[TextureRect] = []
var _message_timer: float = 0.0

func _ready() -> void:
	# Cache hotbar slot TextureRects
	for child in hotbar_container.get_children():
		if child is TextureRect:
			_hotbar_slots.append(child)

	# Connect to EventBus
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_stamina_changed.connect(_on_stamina_changed)
	EventBus.hotbar_slot_changed.connect(_on_hotbar_changed)
	EventBus.hud_show_message.connect(_on_show_message)

	message_label.visible = false

func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.visible = false

# ── Signal Handlers ───────────────────────────────────────────────────────────

func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value     = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value     = current

func _on_hotbar_changed(slot_index: int, item: Resource) -> void:
	if slot_index >= _hotbar_slots.size():
		return
	_hotbar_slots[slot_index].texture = item.icon if item != null else null

func _on_show_message(text: String, duration: float) -> void:
	message_label.text    = text
	message_label.visible = true
	_message_timer        = duration
