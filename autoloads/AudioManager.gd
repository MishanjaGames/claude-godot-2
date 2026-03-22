# AudioManager.gd
# Autoload that handles all audio in the game.
#
# FEATURES:
#   - SFX pool: a fixed pool of AudioStreamPlayer2D nodes so we never
#     instantiate/free audio nodes at runtime (avoids GC hitches).
#   - Positional SFX: sounds attenuate with distance from the player.
#   - Music crossfade: smooth transition between tracks.
#   - SFX registry: maps sfx_id strings → AudioStream resources loaded from
#     res://assets/sounds/  (auto-scanned on _ready).
#   - Respects audio bus volumes set by SettingsScreen.
#
# LOAD ORDER: after EventBus. Before GameManager so music can start on MainMenu.
extends Node

# ── Pool settings ──────────────────────────────────────────────────────────────
const SFX_POOL_SIZE:     int   = 16    # max simultaneous SFX
const SFX_MAX_DISTANCE:  float = 600.0 # pixels — beyond this, SFX is silent
const MUSIC_FADE_DEFAULT: float = 1.0  # seconds

# ── Bus names (must match your AudioServer bus layout) ────────────────────────
const BUS_SFX:   String = "SFX"
const BUS_MUSIC: String = "Music"

# ── SFX pool ───────────────────────────────────────────────────────────────────
var _pool:     Array[AudioStreamPlayer2D] = []
var _pool_idx: int = 0

# ── Music players (A/B for crossfade) ─────────────────────────────────────────
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: String = ""   # id of currently playing track

# ── Registry ───────────────────────────────────────────────────────────────────
var _sfx_library:   Dictionary = {}   # sfx_id → AudioStream
var _music_library: Dictionary = {}   # music_id → AudioStream

# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_build_pool()
	_build_music_players()
	_scan_audio_folder("res://assets/sounds/sfx/",   _sfx_library)
	_scan_audio_folder("res://assets/sounds/music/", _music_library)

	EventBus.play_sfx_requested.connect(_on_play_sfx)
	EventBus.play_music_requested.connect(_on_play_music)
	EventBus.stop_music_requested.connect(_on_stop_music)

# ══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════════════════

## Play a positional sound effect. position = world pixel position.
## If sfx_id is not in the registry it is silently skipped.
func play_sfx(sfx_id: String, position: Vector2 = Vector2.ZERO) -> void:
	if sfx_id.is_empty():
		return
	var stream := _sfx_library.get(sfx_id) as AudioStream
	if stream == null:
		return

	# Cull by distance to player.
	var player := GameManager.player_ref
	if player != null:
		var dist := position.distance_to(player.global_position)
		if dist > SFX_MAX_DISTANCE:
			return

	var player_node := _next_pool_node()
	player_node.stream          = stream
	player_node.global_position = position
	# Attenuate manually via volume_db since we're using a flat pool.
	if player != null:
		var dist := position.distance_to(player.global_position)
		var t    := clampf(1.0 - dist / SFX_MAX_DISTANCE, 0.0, 1.0)
		player_node.volume_db = linear_to_db(t * t)   # quadratic rolloff
	else:
		player_node.volume_db = 0.0
	player_node.play()

## Start a music track with a crossfade. Silently skips unknown ids.
func play_music(music_id: String, fade_time: float = MUSIC_FADE_DEFAULT) -> void:
	if music_id == _music_active:
		return
	var stream := _music_library.get(music_id) as AudioStream
	if stream == null:
		push_warning("AudioManager: music_id '%s' not found." % music_id)
		return

	_music_active = music_id
	# Swap A/B players.
	var outgoing := _music_a if _music_a.playing else _music_b
	var incoming := _music_b if _music_a.playing else _music_a

	incoming.stream    = stream
	incoming.volume_db = linear_to_db(0.001)
	incoming.play()

	var tween := create_tween().set_parallel(true)
	tween.tween_property(incoming, "volume_db", 0.0,                  fade_time)
	tween.tween_property(outgoing, "volume_db", linear_to_db(0.001),  fade_time)
	tween.chain().tween_callback(outgoing.stop)

## Stop music with a fade.
func stop_music(fade_time: float = MUSIC_FADE_DEFAULT) -> void:
	_music_active = ""
	for p in [_music_a, _music_b]:
		if p.playing:
			var tween := create_tween()
			tween.tween_property(p, "volume_db", linear_to_db(0.001), fade_time)
			tween.tween_callback(p.stop)

## Register a stream at runtime (e.g. loaded from a mod or DLC pack).
func register_sfx(sfx_id: String, stream: AudioStream) -> void:
	_sfx_library[sfx_id] = stream

func register_music(music_id: String, stream: AudioStream) -> void:
	_music_library[music_id] = stream

# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS
# ══════════════════════════════════════════════════════════════════════════════

func _on_play_sfx(sfx_id: String, position: Vector2) -> void:
	play_sfx(sfx_id, position)

func _on_play_music(music_id: String, fade_time: float) -> void:
	play_music(music_id, fade_time)

func _on_stop_music(fade_time: float) -> void:
	stop_music(fade_time)

# ══════════════════════════════════════════════════════════════════════════════
# INTERNAL SETUP
# ══════════════════════════════════════════════════════════════════════════════

func _build_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer2D.new()
		p.bus      = BUS_SFX
		p.max_distance  = SFX_MAX_DISTANCE
		p.attenuation   = 1.0
		add_child(p)
		_pool.append(p)

func _build_music_players() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for p in [_music_a, _music_b]:
		p.bus = BUS_MUSIC
		add_child(p)

func _next_pool_node() -> AudioStreamPlayer2D:
	# Round-robin. Skip nodes that are still playing to avoid cutting them off
	# unless the whole pool is busy.
	var start := _pool_idx
	while _pool[_pool_idx].playing:
		_pool_idx = (_pool_idx + 1) % SFX_POOL_SIZE
		if _pool_idx == start:
			break   # pool full — steal the oldest
	var node := _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % SFX_POOL_SIZE
	return node

func _scan_audio_folder(path: String, dict: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return   # folder doesn't exist yet — fine during early dev
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".wav") or file_name.ends_with(".ogg") \
				or file_name.ends_with(".mp3"):
			var full := path + file_name
			var stream := load(full) as AudioStream
			if stream:
				# id = filename without extension
				var id := file_name.get_basename()
				dict[id] = stream
		file_name = dir.get_next()
	dir.list_dir_end()
