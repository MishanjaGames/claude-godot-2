# ConsumableData.gd
# Extends ItemData for any item that is consumed on use.
# Covers health potions, food, stamina drinks, stat-boosting items, etc.
class_name ConsumableData
extends ItemData

# ── Recovery ───────────────────────────────────────────────────────────────────
@export var heal_amount: int              = 0
@export var stamina_restore: float        = 0.0

# ── Status effects applied on consumption ─────────────────────────────────────
@export var apply_effects: Array[StatusEffect] = []
## Negative effects applied on use (e.g. a cursed item)
@export var apply_debuffs: Array[StatusEffect] = []

# ── Cooldown ───────────────────────────────────────────────────────────────────
## Seconds before the same item can be used again (shared per-item-id).
@export var use_cooldown: float           = 0.0

# ── Override ───────────────────────────────────────────────────────────────────

func use(user: Node) -> void:
	if not can_use(user):
		return

	if heal_amount > 0 and user.has_method("heal"):
		user.heal(heal_amount)

	if stamina_restore > 0.0 and "current_stamina" in user:
		user.current_stamina = minf(
			user.stat_block.get_max_stamina(),
			user.current_stamina + stamina_restore
		)
		EventBus.player_stamina_changed.emit(user.current_stamina, user.stat_block.get_max_stamina())

	for effect in apply_effects:
		if user.has_method("apply_status_effect"):
			user.apply_status_effect(effect.duplicate())

	for debuff in apply_debuffs:
		if user.has_method("apply_status_effect"):
			user.apply_status_effect(debuff.duplicate())

	EventBus.hud_show_message.emit("Used %s." % display_name, 2.0)
