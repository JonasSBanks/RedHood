class_name CutsceneSlide
extends Control
## One slide of a cutscene. Put it directly under the cutscene's root, and put
## the slide's pictures inside it (TextureRects, laid out in the editor).
## Slides play in the order they appear in the Scene panel.
##
## Make the slide fill the screen: Layout > Anchors Preset > Full Rect.
## To make a picture slide around, give it cutscene_mover.gd.

## Who's talking, e.g. "Grandma". Leave empty for narration (no name tag).
@export var speaker: String = ""
## What's said on this slide. Leave empty for a picture-only slide.
@export_multiline var text: String = ""
## Optional sound that plays when this slide appears.
@export var sound: AudioStream
## Wait for the pictures' animations (cutscene_frames.gd, and movers that
## aren't Back And Forth) to finish before showing the text.
@export var text_waits_for_animation: bool = true
## 0 = wait for a click to go on. More than 0 = go on by itself this many
## seconds after the text has finished typing (or after the slide appears,
## if there's no text).
@export var auto_advance_after: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_ignore_mouse(self)


## Clicks pass through the pictures, so the cutscene gets them.
func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


## Sent when every animation that the text waits for has finished.
signal animations_done

var _pending := 0  # animations still running


## Called by the cutscene when this slide appears: starts every animation in it.
func start_movers() -> void:
	_pending = 0
	for node in find_children("*", "", true, false):
		if not node.has_method("start_move"):
			continue
		if node.has_method("finishes") and node.call("finishes") and node.has_signal("finished"):
			_pending += 1
			if not node.is_connected("finished", _one_done):
				node.connect("finished", _one_done)
		node.call("start_move")
	if _pending == 0:
		animations_done.emit.call_deferred()


func _one_done() -> void:
	_pending -= 1
	if _pending == 0:
		animations_done.emit()


## True while the text should still wait for animations.
func is_waiting() -> bool:
	return text_waits_for_animation and _pending > 0
