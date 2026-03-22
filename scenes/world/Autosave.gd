# AutoSave.gd
# Node attached to World.tscn that handles automatic saving.
# Features:
#   - Periodic save every AUTOSAVE_INTERVAL seconds
#   - Save on OS window close (NOTIFICATION_WM_CLOSE_REQUEST)
#   - Save on player death (so progress leading to death is kept)
#   - "Saving…" indicator via HUD message
#   - Respects pause state (timer pauses with the game)
#
# SCENE TREE placement: direct child of World root, process_mode = ALWAYS.
class_name AutoSave
extends Node

## Seconds between automatic saves. Set to 0 to disable periodic saves.
@export var autosave_interval: float = 120.0
## Show a HUD message when auto-saving.
@export var show_indicator:    bool  = true

var _timer: float = 0.0
var _save_pending: bool = false   # deferred flag to avoid saving mid-physics

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.player_died.connect(_on_player_died)
	# Intercept OS close so we save before quitting.
	get_tree().root.close_requested.connect(_on_close_requested)

func _process(delta: float) -> void:
	# Don't auto-save while paused (in menus) or if interval is disabled.
	if get_tree().paused or autosave_interval <= 0.0:
		return

	_timer += delta
	if _timer >= autosave_interval:
		_timer = 0.0
		_do_save("Auto-saved.")

	if _save_pending:
		_save_pending = false
		_do_save("Game saved.")

# ── Public ─────────────────────────────────────────────────────────────────────

## Request a deferred save (safe to call from physics callbacks).
func request_save() -> void:
	_save_pending = true

## Immediate save (call only from non-physics context).
func save_now(message: String = "Game saved.") -> void:
	_do_save(message)

# ── Internal ───────────────────────────────────────────────────────────────────

func _do_save(indicator_text: String) -> void:
	SaveManager.save_game()
	if show_indicator:
		EventBus.hud_show_message.emit(indicator_text, 2.0)

func _on_player_died() -> void:
	# Save after a short delay so death state (position, health) is recorded
	# but the player isn't locked out of respawning.
	await get_tree().create_timer(0.5).timeout
	_do_save("Progress saved.")

func _on_close_requested() -> void:
	SaveManager.save_game()
	get_tree().quit()

func _notification(what: int) -> void:
	# Belt-and-suspenders: also catch the notification path.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.save_game()
		get_tree().quit()
