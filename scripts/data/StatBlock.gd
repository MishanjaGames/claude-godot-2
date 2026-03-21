# StatBlock.gd
# Resource that defines all base stats for an entity.
# Every Entity duplicates one of these so modifiers don't bleed between instances.
#
# USAGE:
#   In the Inspector, drag a StatBlock .tres onto the entity's stat_block field.
#   Entity calls stat_block.get_max_health() etc. after applying equipment mods.
#   Call add_modifier / remove_modifier to push/pop equipment or buff changes.
class_name StatBlock
extends Resource

# ── Base stats (set in Inspector or .tres file) ────────────────────────────────
@export_group("Vitals")
@export var base_max_health: int        = 100
@export var base_max_stamina: float     = 100.0
@export var stamina_regen: float        = 15.0   # per second at rest
@export var stamina_drain: float        = 30.0   # per second while sprinting

@export_group("Movement")
@export var base_move_speed: float      = 160.0
@export var sprint_multiplier: float    = 1.8
@export var sprint_stamina_min: float   = 10.0   # stamina floor to begin sprint

@export_group("Offence")
@export var base_attack: int            = 10     # added to weapon damage
@export var crit_chance: float          = 0.05   # 0.0–1.0
@export var crit_multiplier: float      = 1.5
@export var knockback_force: float      = 120.0  # applied to targets on hit

@export_group("Defence")
@export var base_defence: int           = 0      # flat damage reduction
@export var magic_resist: float         = 0.0    # 0.0–1.0 fraction
@export var knockback_resist: float     = 0.0    # 0.0–1.0 fraction

@export_group("Misc")
@export var base_weight_limit: float    = 50.0   # total carry weight before slowdown
@export var luck: float                 = 1.0    # multiplier on DropTable rolls

# ── Runtime modifiers (added/removed by equipment and buffs) ──────────────────
# Each modifier is a Dictionary:
#   { "id": String, "stat": String, "value": Variant, "mode": "add"|"mul" }
var _modifiers: Array[Dictionary] = []

# ── Stat accessors (base + modifiers) ─────────────────────────────────────────

func get_max_health() -> int:
	return max(1, base_max_health + _sum_flat("max_health"))

func get_max_stamina() -> float:
	return maxf(1.0, base_max_stamina + _sum_flat("max_stamina"))

func get_move_speed() -> float:
	return maxf(20.0, (base_move_speed + _sum_flat("move_speed")) * _product_mul("move_speed"))

func get_attack() -> int:
	return max(0, base_attack + _sum_flat("attack"))

func get_defence() -> int:
	return max(0, base_defence + _sum_flat("defence"))

func get_magic_resist() -> float:
	return clampf(magic_resist + _sum_flat("magic_resist"), 0.0, 0.95)

func get_luck() -> float:
	return maxf(0.0, luck + _sum_flat("luck"))

# ── Damage calculation ─────────────────────────────────────────────────────────

## Returns actual damage taken after applying defence and resistance.
## damage_type: "physical" | "magic" | "true"  (true ignores all reductions)
func calculate_incoming_damage(raw: int, damage_type: String = "physical") -> int:
	if damage_type == "true":
		return max(1, raw)
	if damage_type == "magic":
		var reduced = raw * (1.0 - get_magic_resist())
		return max(1, int(reduced))
	# Physical: flat defence subtraction
	var reduced = raw - get_defence()
	return max(1, reduced)

## Rolls crit. Returns true if this hit crits.
func roll_crit() -> bool:
	return randf() < crit_chance

## Applies crit multiplier to a damage value.
func apply_crit(damage: int) -> int:
	return int(float(damage) * crit_multiplier)

# ── Modifier management ────────────────────────────────────────────────────────

## Add a modifier. mode = "add" (flat) or "mul" (multiplicative, stacks as product).
func add_modifier(mod_id: String, stat: String, value: float, mode: String = "add") -> void:
	remove_modifier(mod_id, stat)   # ensure no duplicate
	_modifiers.append({"id": mod_id, "stat": stat, "value": value, "mode": mode})

## Remove a modifier by its id + stat combination.
func remove_modifier(mod_id: String, stat: String) -> void:
	_modifiers = _modifiers.filter(func(m): return not (m.id == mod_id and m.stat == stat))

## Remove ALL modifiers from a given source (e.g. when an item is unequipped).
func remove_all_modifiers_from(mod_id: String) -> void:
	_modifiers = _modifiers.filter(func(m): return m.id != mod_id)

## Clear every modifier (used on death / full reset).
func clear_modifiers() -> void:
	_modifiers.clear()

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		"base_max_health":    base_max_health,
		"base_max_stamina":   base_max_stamina,
		"base_move_speed":    base_move_speed,
		"base_attack":        base_attack,
		"base_defence":       base_defence,
		"crit_chance":        crit_chance,
		"luck":               luck,
	}

func deserialize(data: Dictionary) -> void:
	base_max_health  = data.get("base_max_health",  base_max_health)
	base_max_stamina = data.get("base_max_stamina",  base_max_stamina)
	base_move_speed  = data.get("base_move_speed",   base_move_speed)
	base_attack      = data.get("base_attack",        base_attack)
	base_defence     = data.get("base_defence",       base_defence)
	crit_chance      = data.get("crit_chance",        crit_chance)
	luck             = data.get("luck",               luck)

# ── Internal helpers ───────────────────────────────────────────────────────────

func _sum_flat(stat: String) -> float:
	var total: float = 0.0
	for m in _modifiers:
		if m.stat == stat and m.mode == "add":
			total += float(m.value)
	return total

func _product_mul(stat: String) -> float:
	var product: float = 1.0
	for m in _modifiers:
		if m.stat == stat and m.mode == "mul":
			product *= float(m.value)
	return product
