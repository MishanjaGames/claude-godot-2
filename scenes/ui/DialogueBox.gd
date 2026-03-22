# DialogueBox.gd
# Dialogue sequencer with typewriter effect.
# Pauses the tree while open. Advances on ui_accept, skips typewriter on first press.
# Choices stub ready for Phase 7 quest system.
#
# SCENE TREE (DialogueBox.tscn):
#   DialogueBox        [CanvasLayer]  layer=8        ← this script
#   └── Panel          [PanelContainer]               anchors=bottom-wide, min_y=160
#       └── MarginContainer  (margin=12)
#           └── VBoxContainer  (separation=6)
#               ├── SpeakerLabel   [Label]            bold, font_size=14
#               ├── RichTextLabel                     bbcode=true, fit_content=true
#               ├── ContinueHint   [Label]            italic, align=right, font_size=12
#               └── ChoiceContainer [VBoxContainer]   visible=false
class_name DialogueBox
extends CanvasLayer

@onready var panel:             PanelContainer = $Panel
@onready var speaker_label:     Label          = $Panel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var rich_label:        RichTextLabel  = $Panel/MarginContainer/VBoxContainer/RichTextLabel
@onready var continue_hint:     Label          = $Panel/MarginContainer/VBoxContainer/ContinueHint
@onready var choice_container:  VBoxContainer  = $Panel/MarginContainer/VBoxContainer/ChoiceContainer

# ── Typewriter ─────────────────────────────────────────────────────────────────
const CHARS_PER_SEC: float = 40.0
var _typewriter_timer: float = 0.0
var _full_text:        String = ""
var _visible_chars:    int    = 0
var _typing_done:      bool   = true

# ── Dialogue state ─────────────────────────────────────────────────────────────
var _lines:       Array  = []
var _current_line: int   = 0
var _source_npc:   Node  = null
var _is_open:      bool  = false

# ── Choices (populated by quest system in Phase 7) ────────────────────────────
var _choices: Array[Dictionary] = []   # { "text": String, "callback": Callable }

# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	panel.visible = false
	choice_container.visible = false
	EventBus.dialogue_open_requested.connect(_open)

func _process(delta: float) -> void:
	if not _is_open or _typing_done:
		return
	_typewriter_timer += delta
	var chars_to_show := int(_typewriter_timer * CHARS_PER_SEC)
	if chars_to_show >= _full_text.length():
		_finish_typing()
	else:
		rich_label.visible_characters = chars_to_show

func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_just_pressed("ui_accept"):
		if not _typing_done:
			_finish_typing()           # skip to end of current line
		else:
			_advance()
		get_viewport().set_input_as_handled()

# ══════════════════════════════════════════════════════════════════════════════
# OPEN / CLOSE
# ══════════════════════════════════════════════════════════════════════════════

func _open(lines: Array, npc: Node) -> void:
	_lines        = lines
	_source_npc   = npc
	_current_line = 0
	_is_open      = true
	panel.visible = true
	speaker_label.text = npc.npc_name if npc != null and "npc_name" in npc else ""
	get_tree().paused  = true
	_show_line()
	EventBus.npc_dialogue_started.emit(npc, lines)

func _close() -> void:
	_is_open      = false
	panel.visible = false
	get_tree().paused = false
	_choices.clear()
	_clear_choices_ui()
	EventBus.dialogue_closed.emit()
	EventBus.npc_dialogue_ended.emit(_source_npc)

## Public API for quest system — add a choice button before opening.
func add_choice(text: String, callback: Callable) -> void:
	_choices.append({ "text": text, "callback": callback })

# ══════════════════════════════════════════════════════════════════════════════
# LINE MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════

func _show_line() -> void:
	if _current_line >= _lines.size():
		_close()
		return

	_full_text             = str(_lines[_current_line])
	_visible_chars         = 0
	_typing_done           = false
	_typewriter_timer      = 0.0
	rich_label.text        = _full_text
	rich_label.visible_characters = 0

	var is_last := (_current_line >= _lines.size() - 1)
	continue_hint.text = "[Space / Enter to close]" if is_last \
		else "[Space / Enter to continue]"

	# Show choices only on the last line if any were added.
	if is_last and not _choices.is_empty():
		_build_choices_ui()

func _advance() -> void:
	_current_line += 1
	_clear_choices_ui()
	_show_line()

func _finish_typing() -> void:
	_typing_done               = true
	rich_label.visible_characters = -1   # show all

# ══════════════════════════════════════════════════════════════════════════════
# CHOICES UI
# ══════════════════════════════════════════════════════════════════════════════

func _build_choices_ui() -> void:
	_clear_choices_ui()
	choice_container.visible = true
	for i in _choices.size():
		var btn := Button.new()
		btn.text = _choices[i]["text"]
		var cb: Callable = _choices[i]["callback"]
		btn.pressed.connect(func():
			cb.call()
			_close()
		)
		choice_container.add_child(btn)

func _clear_choices_ui() -> void:
	choice_container.visible = false
	for child in choice_container.get_children():
		child.queue_free()
