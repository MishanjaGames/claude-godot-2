# DayNightCycle.gd
# Autoload that advances world time and drives all time-of-day effects:
#   - Sky colour and ambient light tween per phase
#   - Music crossfade at dawn / dusk
#   - Hostile NPC spawn multiplier (more at night)
#   - EventBus signals so any system can react to phase changes
#
# A full in-game day = DAY_DURATION_SECONDS real seconds.
# Time is stored as a 0.0–1.0 normalised value (0 = midnight, 0.5 = noon).
#
# LOAD ORDER: after EventBus, AudioManager.
extends Node

# ── Duration ───────────────────────────────────────────────────────────────────
## Real seconds for one full in-game day. Default 20 minutes.
@export var day_duration: float = 1200.0

# ── Phase boundaries (0.0–1.0) ────────────────────────────────────────────────
const PHASE_DAWN:    Vector2 = Vector2(0.22, 0.27)   # 05:17 – 06:29
const PHASE_DAY:     Vector2 = Vector2(0.27, 0.71)   # 06:29 – 17:02
const PHASE_DUSK:    Vector2 = Vector2(0.71, 0.76)   # 17:02 – 18:14
const PHASE_NIGHT:   Vector2 = Vector2(0.76, 1.0)    # 18:14 – 24:00
# (Night also covers 0.0 – 0.22 wrapping from midnight to dawn)

enum Phase { DAWN, DAY, DUSK, NIGHT }

# ── Colour keyframes ───────────────────────────────────────────────────────────
const SKY_NIGHT:  Color = Color(0.04, 0.04, 0.12)
const SKY_DAWN:   Color = Color(0.85, 0.45, 0.25)
const SKY_DAY:    Color = Color(0.53, 0.81, 0.98)
const SKY_DUSK:   Color = Color(0.75, 0.35, 0.15)

const AMBIENT_NIGHT:  float = 0.15
const AMBIENT_DAWN:   float = 0.55
const AMBIENT_DAY:    float = 1.0
const AMBIENT_DUSK:   float = 0.6

# ── Hostile spawn multiplier by phase ─────────────────────────────────────────
const SPAWN_MULT: Dictionary = {
	Phase.DAWN:  0.6,
	Phase.DAY:   1.0,
	Phase.DUSK:  1.4,
	Phase.NIGHT: 2.5,
}

# ── Runtime state ──────────────────────────────────────────────────────────────
## Normalised time: 0.0 = midnight, 0.25 = 06:00, 0.5 = noon, 0.75 = 18:00.
var time_of_day:    float = 0.26   # start just before dawn
var current_phase:  Phase = Phase.DAY
var _prev_phase:    Phase = Phase.DAY
var day_count:      int   = 1

# Scene refs (set by World._ready() via setup()).
var _world_environment: WorldEnvironment = null
var _sun_light:         DirectionalLight2D = null

# ── EventBus signals added to EventBus.gd in Phase 9 ─────────────────────────
# (Add these manually to EventBus.gd)
# signal day_phase_changed(new_phase: int)
# signal day_elapsed(day_number: int)
# signal time_of_day_changed(normalised_time: float)

# ══════════════════════════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════════════════════════

## Called from World._ready() after the environment nodes are in the tree.
func setup(world_env: WorldEnvironment, sun: DirectionalLight2D = null) -> void:
	_world_environment = world_env
	_sun_light         = sun
	_apply_time(time_of_day, false)

# ══════════════════════════════════════════════════════════════════════════════
# UPDATE
# ══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	var prev_time := time_of_day
	time_of_day   = fmod(time_of_day + delta / day_duration, 1.0)

	# Day rollover.
	if prev_time > 0.9 and time_of_day < 0.1:
		day_count += 1
		if EventBus.has_signal("day_elapsed"):
			EventBus.emit_signal("day_elapsed", day_count)

	_update_phase()
	_apply_time(time_of_day, true)

	if EventBus.has_signal("time_of_day_changed"):
		EventBus.emit_signal("time_of_day_changed", time_of_day)

# ══════════════════════════════════════════════════════════════════════════════
# PHASE DETECTION
# ══════════════════════════════════════════════════════════════════════════════

func _update_phase() -> void:
	var new_phase := _phase_at(time_of_day)
	if new_phase == current_phase:
		return
	_prev_phase   = current_phase
	current_phase = new_phase

	if EventBus.has_signal("day_phase_changed"):
		EventBus.emit_signal("day_phase_changed", current_phase)

	match current_phase:
		Phase.DAWN:
			EventBus.hud_show_message.emit("Dawn", 2.5)
			EventBus.play_music_requested.emit("music_dawn", 3.0)
		Phase.DAY:
			EventBus.play_music_requested.emit("music_day", 3.0)
		Phase.DUSK:
			EventBus.hud_show_message.emit("Dusk", 2.5)
			EventBus.play_music_requested.emit("music_dusk", 3.0)
		Phase.NIGHT:
			EventBus.hud_show_message.emit("Night falls…", 2.5)
			EventBus.play_music_requested.emit("music_night", 3.0)

func _phase_at(t: float) -> Phase:
	if t >= PHASE_NIGHT.x or t < PHASE_DAWN.x:  return Phase.NIGHT
	if t < PHASE_DAWN.y:                         return Phase.DAWN
	if t < PHASE_DUSK.x:                         return Phase.DAY
	if t < PHASE_DUSK.y:                         return Phase.DUSK
	return Phase.NIGHT

# ══════════════════════════════════════════════════════════════════════════════
# VISUAL APPLICATION
# ══════════════════════════════════════════════════════════════════════════════

func _apply_time(t: float, smooth: bool) -> void:
	var sky_color    := _sample_sky_color(t)
	var ambient_eng  := _sample_ambient(t)
	var sun_angle    := _sun_angle_at(t)

	if _world_environment:
		var env := _world_environment.environment
		if env:
			if smooth:
				var tween := _world_environment.create_tween()
				tween.tween_property(env, "background_color", sky_color, 2.0)
				tween.parallel().tween_property(env, "ambient_light_energy", ambient_eng, 2.0)
			else:
				env.background_color      = sky_color
				env.ambient_light_energy  = ambient_eng

	if _sun_light:
		_sun_light.rotation_degrees = sun_angle
		_sun_light.energy           = clampf(ambient_eng, 0.0, 1.0)

func _sample_sky_color(t: float) -> Color:
	# Piecewise lerp through keyframes.
	if t < PHASE_DAWN.x:   return SKY_NIGHT   # deep night
	if t < PHASE_DAWN.y:
		var f := inverse_lerp(PHASE_DAWN.x, PHASE_DAWN.y, t)
		return SKY_NIGHT.lerp(SKY_DAWN, f)
	if t < PHASE_DAY.x + 0.04:
		var f := inverse_lerp(PHASE_DAWN.y, PHASE_DAY.x + 0.04, t)
		return SKY_DAWN.lerp(SKY_DAY, f)
	if t < PHASE_DUSK.x:
		return SKY_DAY
	if t < PHASE_DUSK.y:
		var f := inverse_lerp(PHASE_DUSK.x, PHASE_DUSK.y, t)
		return SKY_DAY.lerp(SKY_DUSK, f)
	var f := inverse_lerp(PHASE_DUSK.y, 1.0, t)
	return SKY_DUSK.lerp(SKY_NIGHT, f)

func _sample_ambient(t: float) -> float:
	if t < PHASE_DAWN.x:   return AMBIENT_NIGHT
	if t < PHASE_DAWN.y:
		return lerpf(AMBIENT_NIGHT, AMBIENT_DAWN, inverse_lerp(PHASE_DAWN.x, PHASE_DAWN.y, t))
	if t < PHASE_DAY.x + 0.04:
		return lerpf(AMBIENT_DAWN, AMBIENT_DAY, inverse_lerp(PHASE_DAWN.y, PHASE_DAY.x + 0.04, t))
	if t < PHASE_DUSK.x:   return AMBIENT_DAY
	if t < PHASE_DUSK.y:
		return lerpf(AMBIENT_DAY, AMBIENT_DUSK, inverse_lerp(PHASE_DUSK.x, PHASE_DUSK.y, t))
	return lerpf(AMBIENT_DUSK, AMBIENT_NIGHT, inverse_lerp(PHASE_DUSK.y, 1.0, t))

func _sun_angle_at(t: float) -> float:
	# Sun rises in the east (left), sets in the west (right).
	# Maps 0.0–1.0 normalised time → -180° to +180° rotation.
	return (t - 0.25) * 360.0   # noon (t=0.5) → 90°, midnight → -90°

# ══════════════════════════════════════════════════════════════════════════════
# PUBLIC HELPERS
# ══════════════════════════════════════════════════════════════════════════════

## Returns hostile NPC spawn rate multiplier for the current phase.
func hostile_spawn_multiplier() -> float:
	return SPAWN_MULT.get(current_phase, 1.0)

## Returns a human-readable clock string e.g. "06:30".
func clock_string() -> String:
	var total_minutes := int(time_of_day * 1440.0)   # 24h × 60
	return "%02d:%02d" % [total_minutes / 60, total_minutes % 60]

func is_night() -> bool:
	return current_phase == Phase.NIGHT

# ══════════════════════════════════════════════════════════════════════════════
# SAVE / LOAD
# ══════════════════════════════════════════════════════════════════════════════

func serialize() -> Dictionary:
	return { "time_of_day": time_of_day, "day_count": day_count }

func deserialize(data: Dictionary) -> void:
	time_of_day   = data.get("time_of_day", 0.26)
	day_count     = data.get("day_count",   1)
	current_phase = _phase_at(time_of_day)
	_prev_phase   = current_phase
