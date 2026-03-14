extends Node2D
class_name WeaponHolder

# These types always point at the mouse cursor
const CURSOR_AIM_TYPES: Array = [
	WeaponItem.WeaponType.SPEAR,
	WeaponItem.WeaponType.BOW,
	WeaponItem.WeaponType.STAFF,
	WeaponItem.WeaponType.THROWABLE,
]

var _current_weapon: WeaponItem = null
var _visual:         Node2D     = null


func equip(weapon: WeaponItem) -> void:
	_current_weapon = weapon
	_rebuild_visual()

func unequip() -> void:
	_current_weapon = null
	_rebuild_visual()


func _process(_delta: float) -> void:
	if _current_weapon == null:
		return
	if _current_weapon.weapon_type in CURSOR_AIM_TYPES:
		look_at(get_global_mouse_position())


# ── Rebuild placeholder visual ───────────────────────────

func _rebuild_visual() -> void:
	if _visual != null:
		_visual.queue_free()
		_visual = null

	if _current_weapon == null:
		return

	match _current_weapon.weapon_type:
		WeaponItem.WeaponType.SWORD:     _visual = _make_sword()
		WeaponItem.WeaponType.AXE:       _visual = _make_axe()
		WeaponItem.WeaponType.SPEAR:     _visual = _make_spear()
		WeaponItem.WeaponType.BOW:       _visual = _make_bow()
		WeaponItem.WeaponType.SHIELD:    _visual = _make_shield()
		WeaponItem.WeaponType.THROWABLE: _visual = _make_throwable()
		WeaponItem.WeaponType.STAFF:     _visual = _make_staff()

	if _visual != null:
		add_child(_visual)


# ── Shape helpers ────────────────────────────────────────

func _line(from: Vector2, to: Vector2, width: float, color: Color) -> Line2D:
	var l := Line2D.new()
	l.add_point(from)
	l.add_point(to)
	l.width         = width
	l.default_color = color
	return l

func _poly(points: PackedVector2Array, color: Color) -> Polygon2D:
	var p   := Polygon2D.new()
	p.polygon = points
	p.color   = color
	return p

func _circle(radius: float, segments: int, color: Color) -> Polygon2D:
	var pts := PackedVector2Array()
	for i in segments:
		var a: float = (float(i) / segments) * TAU
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return _poly(pts, color)


# ── Weapon shapes ────────────────────────────────────────

func _make_sword() -> Node2D:
	var h := Node2D.new()
	h.position = Vector2(18, 8)
	h.add_child(_line(Vector2.ZERO, Vector2(42, 0),   4.0, Color.SILVER))        # blade
	h.add_child(_line(Vector2(10, -8), Vector2(10, 8), 4.0, Color.GRAY))         # guard
	h.add_child(_line(Vector2(-8, 0), Vector2(10, 0),  5.0, Color(0.4, 0.2, 0))) # handle
	return h

func _make_axe() -> Node2D:
	var h := Node2D.new()
	h.position = Vector2(18, 8)
	h.add_child(_line(Vector2.ZERO, Vector2(36, 0), 5.0, Color(0.5, 0.3, 0.1)))  # handle
	h.add_child(_poly(PackedVector2Array([
		Vector2(28, -14), Vector2(46, -4), Vector2(46, 8), Vector2(30, 6)
	]), Color.SILVER))                                                             # head
	return h

func _make_spear() -> Node2D:
	var h := Node2D.new()
	h.position = Vector2(10, 0)
	h.add_child(_line(Vector2.ZERO, Vector2(75, 0), 3.0, Color(0.6, 0.4, 0.2)))  # shaft
	h.add_child(_poly(PackedVector2Array([
		Vector2(75, -5), Vector2(92, 0), Vector2(75, 5)
	]), Color.SILVER))                                                             # tip
	return h

func _make_bow() -> Node2D:
	var h := Node2D.new()
	h.position = Vector2(18, 0)
	# Curved bow body
	var arc := Line2D.new()
	arc.width         = 3.0
	arc.default_color = Color(0.6, 0.4, 0.2)
	for i in 10:
		var t: float = (float(i) / 9.0) - 0.5
		arc.add_point(Vector2(-t * t * 18.0, t * 48.0))
	h.add_child(arc)
	# String
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
	# Boss (center knob)
	h.add_child(_circle(4.0, 8, Color.SILVER))
	return h

func _make_throwable() -> Node2D:
	var h := Node2D.new()
	h.position = Vector2(18, 0)
	h.add_child(_line(Vector2(-10, 0), Vector2(0, 0),  4.0, Color(0.3, 0.2, 0.1))) # handle
	h.add_child(_poly(PackedVector2Array([
		Vector2(0, -2), Vector2(22, 0), Vector2(0, 2), Vector2(5, 0)
	]), Color.SILVER))                                                               # blade
	return h

func _make_staff() -> Node2D:
	var h := Node2D.new()
	h.position = Vector2(10, 0)
	h.add_child(_line(Vector2.ZERO, Vector2(58, 0), 4.0, Color(0.5, 0.25, 0.7)))   # shaft
	# Orb
	var orb := _circle(9.0, 12, Color(0.85, 0.35, 1.0))
	orb.position = Vector2(67, 0)
	h.add_child(orb)
	# Orb glow ring
	var ring := _circle(11.0, 12, Color(0.85, 0.35, 1.0, 0.3))
	ring.position = Vector2(67, 0)
	h.add_child(ring)
	return h
