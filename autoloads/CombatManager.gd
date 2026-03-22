# CombatManager.gd
# Autoload that handles all the combat plumbing that doesn't belong in Entity:
#   - Floating damage / heal number popups
#   - Block input forwarding to MeleeData
#   - Death queue (deferred cleanup so signals fire before nodes free)
#   - XP accumulation and level-up
#   - Kill streak / combo tracking (foundation for future scoring)
#
# LOAD ORDER: after EventBus, Registry, InventoryManager.
extends Node

# ── XP / Level ─────────────────────────────────────────────────────────────────
## XP required to reach each level. Index = level (0-based, so index 1 = level 1).
## Extend this array to add more levels.
const LEVEL_XP_TABLE: Array[int] = [
	0,      # level 0 (unused)
	0,      # level 1  — starting level
	100,    # level 2
	250,    # level 3
	500,    # level 4
	900,    # level 5
	1400,   # level 6
	2100,   # level 7
	3000,   # level 8
	4200,   # level 9
	6000,   # level 10
]
const MAX_LEVEL: int = 10

var current_xp:    int = 0
var current_level: int = 1

# ── Combo / kill streak ────────────────────────────────────────────────────────
var _kill_streak:       int   = 0
var _combo_reset_timer: float = 0.0
const COMBO_RESET_TIME: float = 4.0   # seconds of no kills resets streak

# ── Death queue ────────────────────────────────────────────────────────────────
## Entities that have died and are waiting for deferred cleanup.
var _death_queue: Array[Node] = []

# ── Popup scene ────────────────────────────────────────────────────────────────
## Optional: assign a PackedScene for floating number labels.
## If null, popups are skipped gracefully.
@export var damage_popup_scene: PackedScene = null

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	EventBus.entity_damaged.connect(_on_entity_damaged)
	EventBus.entity_healed.connect(_on_entity_healed)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.experience_gained.connect(_on_experience_gained)
	EventBus.hud_show_popup.connect(_on_hud_show_popup)

func _process(delta: float) -> void:
	# Combo reset countdown.
	if _combo_reset_timer > 0.0:
		_combo_reset_timer -= delta
		if _combo_reset_timer <= 0.0:
			_kill_streak = 0

	# Flush death queue — deferred so all signals from _die() finish first.
	if not _death_queue.is_empty():
		var to_clean := _death_queue.duplicate()
		_death_queue.clear()
		for entity in to_clean:
			if is_instance_valid(entity):
				entity.queue_free()

# ══════════════════════════════════════════════════════════════════════════════
# BLOCK
# Called from Player._physics_process() when block input is held.
# ══════════════════════════════════════════════════════════════════════════════

## Returns true if the player is currently blocking with a capable weapon.
func is_player_blocking() -> bool:
	var item := InventoryManager.get_active_item()
	if not item is MeleeData:
		return false
	return (item as MeleeData).can_block and Input.is_action_pressed("block")

## Calculates final incoming damage after block reduction.
## Call this instead of take_damage() directly on the player when blocking.
func apply_block(player: Node, raw_damage: int, damage_type: String, source: Node) -> void:
	var item := InventoryManager.get_active_item()
	if item is MeleeData and (item as MeleeData).can_block:
		var weapon := item as MeleeData
		var stamina_cost := weapon.block_stamina_cost
		if player.current_stamina >= stamina_cost:
			# Successful block.
			player.current_stamina -= stamina_cost
			EventBus.player_stamina_changed.emit(
				player.current_stamina, player.stat_block.get_max_stamina())
			var reduced := int(float(raw_damage) * (1.0 - weapon.block_reduction))
			if reduced > 0:
				player.take_damage(reduced, damage_type, source)
			EventBus.hud_show_popup.emit(
				"BLOCK", player.global_position + Vector2(0, -32), Color(0.5, 0.8, 1.0))
			return
	# No block or out of stamina — take full damage.
	player.take_damage(raw_damage, damage_type, source)

# ══════════════════════════════════════════════════════════════════════════════
# XP & LEVELLING
# ══════════════════════════════════════════════════════════════════════════════

func add_xp(amount: int) -> void:
	if current_level >= MAX_LEVEL:
		return
	current_xp += amount
	while current_level < MAX_LEVEL and current_xp >= xp_for_next_level():
		current_xp -= xp_for_next_level()
		current_level += 1
		_on_level_up(current_level)

func xp_for_next_level() -> int:
	if current_level >= LEVEL_XP_TABLE.size() - 1:
		return 999999
	return LEVEL_XP_TABLE[current_level + 1]

func xp_ratio() -> float:
	var needed := xp_for_next_level()
	return float(current_xp) / float(needed) if needed > 0 else 1.0

func _on_level_up(new_level: int) -> void:
	EventBus.level_up.emit(new_level)
	EventBus.hud_show_message.emit("Level Up! You are now level %d." % new_level, 3.0)
	# Reward: raise max health by 10 per level on the player's StatBlock.
	var player := GameManager.player_ref
	if player and player.stat_block:
		player.stat_block.base_max_health += 10
		player.heal(10)   # heal the bonus HP immediately

func serialize() -> Dictionary:
	return { "xp": current_xp, "level": current_level }

func deserialize(data: Dictionary) -> void:
	current_xp    = data.get("xp",    0)
	current_level = data.get("level", 1)

# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS
# ══════════════════════════════════════════════════════════════════════════════

func _on_entity_damaged(entity: Node, amount: int, damage_type: String, _source: Node) -> void:
	if not is_instance_valid(entity):
		return
	var color := _damage_color(damage_type, amount)
	var pos   := entity.global_position + Vector2(randf_range(-8.0, 8.0), -28.0)
	_spawn_popup(str(amount), pos, color)

func _on_entity_healed(entity: Node, amount: int) -> void:
	if not is_instance_valid(entity):
		return
	var pos := entity.global_position + Vector2(randf_range(-6.0, 6.0), -28.0)
	_spawn_popup("+%d" % amount, pos, Color(0.2, 0.9, 0.3))

func _on_entity_died(entity: Node, _position: Vector2, killer: Node) -> void:
	if not is_instance_valid(entity):
		return
	# Queue deferred free so death animation and signals complete first.
	if entity not in _death_queue:
		_death_queue.append(entity)
	# Kill streak tracking.
	if killer == GameManager.player_ref:
		_kill_streak     += 1
		_combo_reset_timer = COMBO_RESET_TIME
		if _kill_streak > 1:
			EventBus.hud_show_message.emit(
				"%d kill streak!" % _kill_streak, 1.5)

func _on_experience_gained(amount: int, _source: String) -> void:
	add_xp(amount)
	var player := GameManager.player_ref
	if player:
		var pos := player.global_position + Vector2(0, -44)
		_spawn_popup("+%d XP" % amount, pos, Color(1.0, 0.85, 0.1))

func _on_hud_show_popup(text: String, position: Vector2, color: Color) -> void:
	_spawn_popup(text, position, color)

# ══════════════════════════════════════════════════════════════════════════════
# POPUP SPAWNING
# ══════════════════════════════════════════════════════════════════════════════

func _spawn_popup(text: String, world_pos: Vector2, color: Color) -> void:
	if damage_popup_scene == null:
		return   # gracefully skip if no popup scene assigned
	var scene := get_tree().current_scene
	if scene == null:
		return
	var popup: Node = damage_popup_scene.instantiate()
	scene.add_child(popup)
	popup.global_position = world_pos
	if popup.has_method("setup"):
		popup.setup(text, color)

# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _damage_color(damage_type: String, amount: int) -> Color:
	match damage_type:
		"fire":      return Color(1.0, 0.45, 0.1)
		"ice":       return Color(0.5, 0.85, 1.0)
		"poison":    return Color(0.4, 0.9, 0.2)
		"lightning": return Color(1.0, 0.95, 0.2)
		"magic":     return Color(0.8, 0.4, 1.0)
		"true":      return Color(1.0, 1.0, 1.0)
		_:           # physical
			return Color(1.0, 0.9, 0.9) if amount < 15 else Color(1.0, 0.3, 0.3)
