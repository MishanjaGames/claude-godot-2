extends Resource
class_name Stats

# ─── Signals ──────────────────────────────────────────────
signal stat_changed(stat_name: String, old_value: float, new_value: float)
signal health_changed(current: float, maximum: float)
signal mana_changed(current: float, maximum: float)
signal died

# ─── Defaults ─────────────────────────────────────────────
const DEFAULTS: Dictionary = {
	"max_health": 100.0,
	"attack":     10.0,
	"defense":    5.0,
	"speed":      200.0,
}

# ─── Aliases — shorthand → real stat name ─────────────────
# These are NEVER stored as stats themselves.
# Writing "health" sets "max_health", "mana" sets "max_mana", etc.
const ALIASES: Dictionary = {
	"health":     "max_health",
	"mana":       "max_mana",
	"hp":         "max_health",
	"mp":         "max_mana",
}

# ─── Internal state ───────────────────────────────────────
var _base:       Dictionary = {}
var _modifiers:  Dictionary = {}
var _health:     float      = 0.0
var _mana:       float      = 0.0


# ══════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════

# Pass any mix of real names or aliases.
# Example: stats.initialize({ "health": 120.0, "mana": 50.0, "speed": 250.0 })
func initialize(overrides: Dictionary = {}) -> void:
	_base = DEFAULTS.duplicate()

	for key in overrides:
		var real := _resolve(key)
		_base[real] = float(overrides[key])

	_health = _base["max_health"]

	if _base.has("max_mana"):
		_mana = _base["max_mana"]


# ══════════════════════════════════════════════════════════
# ALIAS RESOLVER
# ══════════════════════════════════════════════════════════

# Converts alias → real name, or returns the name unchanged.
func _resolve(name: String) -> String:
	return ALIASES.get(name, name)


# ══════════════════════════════════════════════════════════
# BASE STATS
# ══════════════════════════════════════════════════════════

# Get effective value (base + modifiers). Accepts aliases.
func get_stat(stat: String) -> float:
	var real := _resolve(stat)
	if not _base.has(real):
		push_warning("Stats.get_stat(): unknown stat '%s'" % real)
		return 0.0
	var total: float = _base[real]
	for mod in _modifiers.values():
		if mod["stat"] == real:
			total += mod["value"]
	return total

# Get raw base value only. Accepts aliases.
func get_base(stat: String) -> float:
	return _base.get(_resolve(stat), 0.0)

# Add or change a stat. Accepts aliases.
func set_stat(stat: String, value: float) -> void:
	var real := _resolve(stat)
	var old  := get_stat(real)
	_base[real] = value
	stat_changed.emit(real, old, get_stat(real))

# Remove a stat entirely. Accepts aliases.
func delete_stat(stat: String) -> void:
	var real := _resolve(stat)
	if not _base.has(real):
		return
	var old := get_stat(real)
	_base.erase(real)
	stat_changed.emit(real, old, 0.0)

# Check existence. Accepts aliases.
func has_stat(stat: String) -> bool:
	return _base.has(_resolve(stat))

# Returns all real stat names (no aliases).
func list_stats() -> Array:
	return _base.keys()


# ══════════════════════════════════════════════════════════
# MODIFIERS
# ══════════════════════════════════════════════════════════

func add_modifier(id: String, stat: String, value: float) -> void:
	var real := _resolve(stat)
	if not has_stat(real):
		push_warning("Stats.add_modifier(): stat '%s' doesn't exist" % real)
		return
	var old := get_stat(real)
	_modifiers[id] = { "stat": real, "value": value }
	stat_changed.emit(real, old, get_stat(real))

func remove_modifier(id: String) -> void:
	if not _modifiers.has(id):
		return
	var affected: String = _modifiers[id]["stat"]
	var old := get_stat(affected)
	_modifiers.erase(id)
	stat_changed.emit(affected, old, get_stat(affected))

func has_modifier(id: String) -> bool:
	return _modifiers.has(id)

func clear_modifiers(stat: String = "") -> void:
	if stat.is_empty():
		_modifiers.clear()
		return
	var real := _resolve(stat)
	for id in _modifiers.keys():
		if _modifiers[id]["stat"] == real:
			_modifiers.erase(id)


# ══════════════════════════════════════════════════════════
# HEALTH
# ══════════════════════════════════════════════════════════

func get_health() -> float:
	return _health

func take_damage(amount: float) -> void:
	var mitigated: float = max(1.0, amount - get_stat("defense"))
	_health = max(0.0, _health - mitigated)
	health_changed.emit(_health, get_stat("max_health"))
	if _health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	_health = min(get_stat("max_health"), _health + amount)
	health_changed.emit(_health, get_stat("max_health"))


# ══════════════════════════════════════════════════════════
# MANA
# ══════════════════════════════════════════════════════════

func get_mana() -> float:
	return _mana

func spend_mana(amount: float) -> bool:
	if _mana < amount:
		return false
	_mana = max(0.0, _mana - amount)
	mana_changed.emit(_mana, get_stat("max_mana"))
	return true

func restore_mana(amount: float) -> void:
	if not has_stat("max_mana"):
		return
	_mana = min(get_stat("max_mana"), _mana + amount)
	mana_changed.emit(_mana, get_stat("max_mana"))


# ══════════════════════════════════════════════════════════
# DEBUG
# ══════════════════════════════════════════════════════════

func to_dict() -> Dictionary:
	var result: Dictionary = {
		"health":    "%s / %s" % [_health, get_stat("max_health")],
		"modifiers": _modifiers.duplicate(),
		"stats":     {}
	}
	if has_stat("max_mana"):
		result["mana"] = "%s / %s" % [_mana, get_stat("max_mana")]
	for stat in _base:
		result["stats"][stat] = get_stat(stat)
	return result

func print_info() -> void:
	print(JSON.stringify(to_dict(), "\t"))
