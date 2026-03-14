extends Node2D
class_name ItemHold

const CURSOR_AIM_TYPES: Array = [
	WeaponItem.WeaponType.SPEAR,
	WeaponItem.WeaponType.BOW,
	WeaponItem.WeaponType.STAFF,
	WeaponItem.WeaponType.THROWABLE,
]

signal main_hand_changed(weapon: WeaponItem)
signal off_hand_changed(weapon: WeaponItem)
signal attack_started(hand: String, weapon: WeaponItem)
signal attack_finished(hand: String, weapon: WeaponItem)

var _main_hand:   WeaponItem = null
var _off_hand:    WeaponItem = null
var _main_visual: Node2D     = null
var _off_visual:  Node2D     = null
var _main_busy:   bool       = false  # true while animation plays
var _off_busy:    bool       = false

@onready var _main_node: Node2D = $MainHand
@onready var _off_node:  Node2D = $OffHand


# ══════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════

func equip_main(weapon: WeaponItem) -> void:
	_main_hand = weapon
	_rebuild_visual(_main_node, weapon, false)
	main_hand_changed.emit(weapon)

func equip_off(weapon: WeaponItem) -> void:
	_off_hand = weapon
	_rebuild_visual(_off_node, weapon, true)
	off_hand_changed.emit(weapon)

func unequip_main() -> void: equip_main(null)
func unequip_off()  -> void: equip_off(null)

func get_main() -> WeaponItem: return _main_hand
func get_off()  -> WeaponItem: return _off_hand

func tick(delta: float) -> void:
	if _main_hand != null: _main_hand.tick(delta)
	if _off_hand  != null: _off_hand.tick(delta)

func attack_main(user: Node, targets: Array[Node]) -> void:
	if _main_hand == null or _main_busy:
		return
	if not _main_hand.can_attack():
		return
	_main_hand.attack(user, targets)
	_play_animation(_main_node, _main_hand, "main")

func attack_off(user: Node, targets: Array[Node]) -> void:
	if _off_hand == null or _off_busy:
		return
	if not _off_hand.can_attack():
		return
	_off_hand.attack(user, targets)
	_play_animation(_off_node, _off_hand, "off")


# ══════════════════════════════════════════════════════════
# CURSOR AIMING
# ══════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	if _main_hand != null and _main_hand.weapon_type in CURSOR_AIM_TYPES:
		if not _main_busy:
			_main_node.look_at(get_global_mouse_position())
	if _off_hand != null and _off_hand.weapon_type in CURSOR_AIM_TYPES:
		if not _off_busy:
			_off_node.look_at(get_global_mouse_position())


# ══════════════════════════════════════════════════════════
# ANIMATIONS
# ══════════════════════════════════════════════════════════

func _play_animation(parent: Node2D, weapon: WeaponItem, hand: String) -> void:
	var vis := _get_visual(parent)
	if vis == null:
		return

	var busy_ref := "_%s_busy" % hand
	set(busy_ref, true)
	attack_started.emit(hand, weapon)

	var tween := create_tween()

	match weapon.weapon_type:
		WeaponItem.WeaponType.SWORD:
			_anim_sword_swing(tween, vis, parent)
		WeaponItem.WeaponType.AXE:
			_anim_axe_swing(tween, vis, parent)
		WeaponItem.WeaponType.SPEAR:
			_anim_spear_thrust(tween, vis, parent)
		WeaponItem.WeaponType.BOW:
			_anim_bow_shoot(tween, vis, parent)
		WeaponItem.WeaponType.STAFF:
			_anim_staff_cast(tween, vis, parent)
		WeaponItem.WeaponType.THROWABLE:
			_anim_throwable(tween, vis, parent)
		WeaponItem.WeaponType.SHIELD:
			_anim_shield_bash(tween, vis, parent)

	tween.finished.connect(func() -> void:
		set(busy_ref, false)
		attack_finished.emit(hand, weapon)
	)


# ─── Sword: fast horizontal swing arc ────────────────────
func _anim_sword_swing(tween: Tween, _vis: Node2D, parent: Node2D) -> void:
	var origin := parent.rotation
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(parent, "rotation", origin - deg_to_rad(50.0), 0.06)
	tween.tween_property(parent, "rotation", origin + deg_to_rad(90.0), 0.12)
	tween.tween_property(parent, "rotation", origin,                    0.10)


# ─── Axe: slow heavy overhead arc ────────────────────────
func _anim_axe_swing(tween: Tween, _vis: Node2D, parent: Node2D) -> void:
	var origin := parent.rotation
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(parent, "rotation", origin - deg_to_rad(80.0), 0.10)
	tween.tween_property(parent, "rotation", origin + deg_to_rad(100.0), 0.20)
	tween.tween_property(parent, "rotation", origin,                     0.12)


# ─── Spear: stab forward then pull back ──────────────────
func _anim_spear_thrust(tween: Tween, vis: Node2D, _parent: Node2D) -> void:
	var origin := vis.position
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(vis, "position", origin + Vector2(28.0, 0.0), 0.07)
	tween.tween_property(vis, "position", origin,                      0.12)


# ─── Bow: pull string back then snap ─────────────────────
func _anim_bow_shoot(tween: Tween, vis: Node2D, _parent: Node2D) -> void:
	var origin := vis.scale
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	# Compress slightly to simulate draw
	tween.tween_property(vis, "scale", Vector2(0.85, 1.0), 0.14)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(vis, "scale", origin,              0.20)


# ─── Staff: orb pulse + recoil ───────────────────────────
func _anim_staff_cast(tween: Tween, vis: Node2D, _parent: Node2D) -> void:
	var origin := vis.scale
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(vis, "scale", origin * 1.35, 0.10)
	tween.tween_property(vis, "scale", origin * 0.80, 0.08)
	tween.tween_property(vis, "scale", origin,        0.12)


# ─── Throwable: quick forward toss + fade ────────────────
func _anim_throwable(tween: Tween, vis: Node2D, _parent: Node2D) -> void:
	var origin_pos := vis.position
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(vis, "position", origin_pos + Vector2(20.0, 0.0), 0.05)
	tween.tween_property(vis, "modulate:a", 0.0,                           0.08)
	tween.tween_property(vis, "modulate:a", 1.0,                           0.05)
	tween.tween_property(vis, "position",   origin_pos,                    0.05)


# ─── Shield: short forward bash + shake ──────────────────
func _anim_shield_bash(tween: Tween, vis: Node2D, parent: Node2D) -> void:
	var origin_rot := parent.rotation
	var origin_pos := vis.position
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(vis,    "position", origin_pos + Vector2(14.0, 0.0), 0.06)
	tween.tween_property(parent, "rotation", origin_rot + deg_to_rad(10.0),  0.04)
	tween.tween_property(vis,    "position", origin_pos,                      0.10)
	tween.tween_property(parent, "rotation", origin_rot,                      0.08)


# ══════════════════════════════════════════════════════════
# VISUAL BUILDING
# ══════════════════════════════════════════════════════════

func _rebuild_visual(parent: Node2D, weapon: WeaponItem, mirror: bool) -> void:
	for child in parent.get_children():
		child.queue_free()

	if weapon == null:
		return

	var vis: Node2D
	if Global.use_raw:
		vis = _make_raw_visual(weapon)
	else:
		vis = _make_sprite_visual(weapon)

	if vis != null:
		if mirror:
			vis.scale.y = -1.0
		parent.add_child(vis)

	# Reconnect when raw mode is toggled at runtime
	if not Global.raw_mode_changed.is_connected(_on_raw_mode_changed):
		Global.raw_mode_changed.connect(_on_raw_mode_changed)


func _on_raw_mode_changed(_enabled: bool) -> void:
	if _main_hand != null:
		_rebuild_visual(_main_node, _main_hand, false)
	if _off_hand != null:
		_rebuild_visual(_off_node, _off_hand, true)


func _get_visual(parent: Node2D) -> Node2D:
	for child in parent.get_children():
		if child is Node2D:
			return child as Node2D
	return null


# ── Sprite visual (textures) ─────────────────────────────

func _make_sprite_visual(weapon: WeaponItem) -> Node2D:
	var h    := Node2D.new()
	var spr  := Sprite2D.new()
	spr.texture = weapon.icon   # uses the item's icon field
	spr.position = Vector2(24, 0)
	h.add_child(spr)
	return h


# ── Raw visuals (hardcoded shapes) ───────────────────────

func _make_raw_visual(weapon: WeaponItem) -> Node2D:
	match weapon.weapon_type:
		WeaponItem.WeaponType.SWORD:     return _make_sword()
		WeaponItem.WeaponType.AXE:       return _make_axe()
		WeaponItem.WeaponType.SPEAR:     return _make_spear()
		WeaponItem.WeaponType.BOW:       return _make_bow()
		WeaponItem.WeaponType.SHIELD:    return _make_shield()
		WeaponItem.WeaponType.THROWABLE: return _make_throwable()
		WeaponItem.WeaponType.STAFF:     return _make_staff()
	return null


# ── Shape helpers ────────────────────────────────────────

func _line(from: Vector2, to: Vector2, width: float, color: Color) -> Line2D:
	var l           := Line2D.new()
	l.add_point(from)
	l.add_point(to)
	l.width         = width
	l.default_color = color
	return l

func _poly(points: PackedVector2Array, color: Color) -> Polygon2D:
	var p     := Polygon2D.new()
	p.polygon  = points
	p.color    = color
	return p

func _circle(radius: float, segments: int, color: Color) -> Polygon2D:
	var pts := PackedVector2Array()
	for i in segments:
		var a: float = (float(i) / segments) * TAU
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return _poly(pts, color)

func _make_sword() -> Node2D:
	var h := Node2D.new()
	h.position = Vector2(18, 8)
	h.add_child(_line(Vector2.ZERO, Vector2(42, 0),    4.0, Color.SILVER))
	h.add_child(_line(Vector2(10, -8), Vector2(10, 8), 4.0, Color.GRAY))
	h.add_child(_line(Vector2(-8, 0),  Vector2(10, 0), 5.0, Color(0.4, 0.2, 0.0)))
	return h

func _make_axe() -> Node2D:
	var h := Node2D.new()
	h.position = Vector2(18, 8)
	h.add_child(_line(Vector2.ZERO, Vector2(36, 0), 5.0, Color(0.5, 0.3, 0.1)))
	h.add_child(_poly(PackedVector2Array([
		Vector2(28, -14), Vector2(46, -4), Vector2(46, 8), Vector2(30, 6)
	]), Color.SILVER))
	return h

func _make_spear() -> Node2D:
	var h := Node2D.new()
	h.position = Vector2(10, 0)
	h.add_child(_line(Vector2.ZERO, Vector2(75, 0), 3.0, Color(0.6, 0.4, 0.2)))
	h.add_child(_poly(PackedVector2Array([
		Vector2(75, -5), Vector2(92, 0), Vector2(75, 5)
	]), Color.SILVER))
	return h

func _make_bow() -> Node2D:
	var h   := Node2D.new()
	h.position = Vector2(18, 0)
	var arc := Line2D.new()
	arc.width         = 3.0
	arc.default_color = Color(0.6, 0.4, 0.2)
	for i in 10:
		var t: float = (float(i) / 9.0) - 0.5
		arc.add_point(Vector2(-t * t * 18.0, t * 48.0))
	h.add_child(arc)
	h.add_child(_line(Vector2(0, -24), Vector2(0, 24), 1.0, Color.WHITE_SMOKE))
	return h

func _make_shield() -> Node2D:
	var h := Node2D.new()
	h.position = Vector2(-20, 0)
	h.add_child(_poly(PackedVector2Array([
		Vector2(-8, -18), Vector2(8, -18),
		Vector2(14,  -4), Vector2(8,  18),
		Vector2(-8,  18), Vector2(-14, -4),
	]), Color(0.35, 0.45, 0.75)))
	h.add_child(_circle(4.0, 8, Color.SILVER))
	return h

func _make_throwable() -> Node2D:
	var h := Node2D.new()
	h.position = Vector2(18, 0)
	h.add_child(_line(Vector2(-10, 0), Vector2(0, 0),  4.0, Color(0.3, 0.2, 0.1)))
	h.add_child(_poly(PackedVector2Array([
		Vector2(0, -2), Vector2(22, 0), Vector2(0, 2), Vector2(5, 0)
	]), Color.SILVER))
	return h

func _make_staff() -> Node2D:
	var h := Node2D.new()
	h.position = Vector2(10, 0)
	h.add_child(_line(Vector2.ZERO, Vector2(58, 0), 4.0, Color(0.5, 0.25, 0.7)))
	var orb      := _circle(9.0,  12, Color(0.85, 0.35, 1.0))
	orb.position  = Vector2(67, 0)
	var ring     := _circle(11.0, 12, Color(0.85, 0.35, 1.0, 0.3))
	ring.position = Vector2(67, 0)
	h.add_child(orb)
	h.add_child(ring)
	return h
