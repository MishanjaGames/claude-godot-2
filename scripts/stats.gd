extends Resource
class_name Stats

# ─── Signals ──────────────────────────────────────────────────────────────────
signal stat_changed(stat_name: String, old_value: float, new_value: float)
signal health_changed(current: float, maximum: float)
signal died

# ─── Hardcoded defaults (fallback for every entity) ───────────────────────────
const DEFAULTS: Dictionary = {
	"max_health": 100.0,
	"attack":     10.0,
	"defense":    5.0,
	"speed":      200.0,
}

# ─── Protected internal state (never access these directly outside this file) ─
var _base:      Dictionary = {}   # base stat values
var _modifiers: Dictionary = {}   # { "id": { "stat": String, "value": float } }
var _health:    float       = 0.0 # current health tracked separately


# ══════════════════════════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════════════════════════

# Call this when the entity enters the scene.
# Pass overrides to customize this entity's stats from defaults.
# Example: stats.initialize({ "max_health": 200.0, "speed": 150.0 })
func initialize(overrides: Dictionary = {}) -> void:
	_base = DEFAULTS.duplicate()
	for key in overrides:
		_base[key] = float(overrides[key])
	_health = _base["max_health"]


# ══════════════════════════════════════════════════════════════════════════════
# BASE STATS — add / get / change / delete
# ══════════════════════════════════════════════════════════════════════════════

# Get effective value of a stat (base + all active modifiers)
func get_stat(stat: String) -> float:
	if not _base.has(stat):
		push_warning("Stats.get_stat(): unknown stat '%s'" % stat)
		return 0.0
	var total: float = _base[stat]
	for mod in _modifiers.values():
		if mod["stat"] == stat:
			total += mod["value"]
	return total

# Get only the raw base value (ignores modifiers)
func get_base(stat: String) -> float:
	return _base.get(stat, 0.0)

# Add a new stat OR change an existing one
# Fires stat_changed signal automatically
func set_stat(stat: String, value: float) -> void:
	var old := get_stat(stat)
	_base[stat] = value
	stat_changed.emit(stat, old, get_stat(stat))

# Permanently remove a stat from this entity
func delete_stat(stat: String) -> void:
	if not _base.has(stat):
		return
	var old := get_stat(stat)
	_base.erase(stat)
	stat_changed.emit(stat, old, 0.0)

# Check whether a stat exists
func has_stat(stat: String) -> bool:
	return _base.has(stat)

# List all stat names on this entity
func list_stats() -> Array:
	return _base.keys()


# ══════════════════════════════════════════════════════════════════════════════
# MODIFIERS — temporary/conditional stat changes
# ══════════════════════════════════════════════════════════════════════════════

# Add or overwrite a modifier by id
# id:    unique name so you can find and remove it later  ("sword_equip", "poison")
# stat:  which stat this affects                          ("attack", "speed", ...)
# value: how much to add — use negative to reduce         (-20.0 for a slow debuff)
func add_modifier(id: String, stat: String, value: float) -> void:
	if not has_stat(stat):
		push_warning("Stats.add_modifier(): stat '%s' doesn't exist" % stat)
		return
	var old := get_stat(stat)
	_modifiers[id] = { "stat": stat, "value": value }
	stat_changed.emit(stat, old, get_stat(stat))

# Remove a modifier by id
func remove_modifier(id: String) -> void:
	if not _modifiers.has(id):
		return
	var affected_stat: String = _modifiers[id]["stat"]
	var old := get_stat(affected_stat)
	_modifiers.erase(id)
	stat_changed.emit(affected_stat, old, get_stat(affected_stat))

# Check if a modifier is active
func has_modifier(id: String) -> bool:
	return _modifiers.has(id)

# Remove all modifiers (optional: only for one specific stat)
func clear_modifiers(stat: String = "") -> void:
	if stat.is_empty():
		_modifiers.clear()
		return
	for id in _modifiers.keys():
		if _modifiers[id]["stat"] == stat:
			_modifiers.erase(id)


# ══════════════════════════════════════════════════════════════════════════════
# HEALTH — special tracked stat
# ══════════════════════════════════════════════════════════════════════════════

func get_health() -> float:
	return _health

func take_damage(amount: float) -> void:
	var mitigated : float = max(1.0, amount - get_stat("defense"))
	_health = max(0.0, _health - mitigated)
	health_changed.emit(_health, get_stat("max_health"))
	if _health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	_health = min(get_stat("max_health"), _health + amount)
	health_changed.emit(_health, get_stat("max_health"))
