extends CanvasLayer
class_name PlayerHUD

@onready var hp_bar:      ProgressBar   = $Panel/VBox/HPRow/HPBar
@onready var mana_row:    HBoxContainer = $Panel/VBox/ManaRow
@onready var mana_bar:    ProgressBar   = $Panel/VBox/ManaRow/ManaBar
@onready var stats_label: RichTextLabel = $Panel/VBox/StatsLabel
@onready var weapon_label: Label        = $Panel/VBox/WeaponLabel

var _stats: Stats = null


func setup(s: Stats) -> void:
	_stats = s
	s.health_changed.connect(_on_health_changed)
	s.stat_changed.connect(_on_stat_changed)
	mana_row.visible = s.has_stat("mana")
	_refresh()


func set_weapon(weapon_name: String) -> void:
	weapon_label.text = ("⚔  " + weapon_name) if weapon_name != "" else ""


func _refresh() -> void:
	if _stats == null:
		return

	hp_bar.max_value = _stats.get_stat("max_health")
	hp_bar.value     = _stats.get_health()

	if _stats.has_stat("mana"):
		var max_mana: float = _stats.get_stat("max_mana") if _stats.has_stat("max_mana") else 100.0
		mana_bar.max_value = max_mana
		mana_bar.value     = _stats.get_stat("mana")

	var skip := ["max_health", "mana", "max_mana"]
	var text := ""
	for stat in _stats.list_stats():
		if stat in skip:
			continue
		var val:  float = _stats.get_stat(stat)
		var base: float = _stats.get_base(stat)
		var diff: float = val - base
		var diff_str := ""
		if abs(diff) > 0.01:
			var c    := "#88ff88" if diff > 0.0 else "#ff8888"
			var sign := "+" if diff > 0.0 else ""
			diff_str = " [color=%s](%s%.0f)[/color]" % [c, sign, diff]
		text += "[color=#aaaaaa]%s:[/color] [color=#ffffff]%.1f[/color]%s\n" % [stat, val, diff_str]
	stats_label.text = text


func _on_health_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value     = current


func _on_stat_changed(_name: String, _old: float, _new: float) -> void:
	_refresh()
