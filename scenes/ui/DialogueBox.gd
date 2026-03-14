# DialogueBox.gd
# Simple dialogue sequencer. Advances on Space/Enter, closes when done.
extends CanvasLayer

@onready var rich_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/RichTextLabel
@onready var speaker_label: Label      = $Panel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var continue_hint: Label      = $Panel/MarginContainer/VBoxContainer/ContinueHint
@onready var panel: PanelContainer     = $Panel

var _dialogue: Array[String] = []
var _current_line: int       = 0
var _source_npc: Node        = null
var _is_open: bool           = false

func _ready() -> void:
	panel.visible = false
	EventBus.dialogue_open_requested.connect(_open_dialogue)

func _open_dialogue(dialogue: Array, npc: Node) -> void:
	_dialogue    = dialogue
	_source_npc  = npc
	_current_line = 0
	_is_open      = true
	panel.visible = true
	speaker_label.text = npc.npc_name if npc != null else ""
	_show_line()
	get_tree().paused = true

func _show_line() -> void:
	if _current_line < _dialogue.size():
		rich_label.text = _dialogue[_current_line]
		continue_hint.text = "[Space / Enter to continue]" if _current_line < _dialogue.size() - 1 else "[Space / Enter to close]"
	else:
		_close_dialogue()

func _close_dialogue() -> void:
	_is_open       = false
	panel.visible  = false
	get_tree().paused = false
	EventBus.dialogue_closed.emit()
	EventBus.npc_dialogue_ended.emit(_source_npc)

func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_accept"):
		_current_line += 1
		_show_line()
		get_viewport().set_input_as_handled()
