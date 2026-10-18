extends Node
## Put this on the root node of every cutscene scene.
## When the cutscene is over, it tells GameManager, which moves on to the
## next day (or the credits after the ending).
##
## Two ways it can know the cutscene is over:
##   1. Animation Player is set: it plays Animation Name and waits for it to end.
##   2. Animation Player is empty: it just waits Duration seconds
##      (handy for placeholder cutscenes).
## Either way, the player can click or press a key to skip.

## Your cutscene's AnimationPlayer. Leave empty to use Duration instead.
@export var animation_player: AnimationPlayer
## Which animation to play.
@export var animation_name: StringName = &"cutscene"
## How long a cutscene with no AnimationPlayer lasts, in seconds.
@export var duration: float = 3.0
## Let the player skip with a click or key press.
@export var can_skip: bool = true

var _finished := false


func _ready() -> void:
	_print_what_is_showing()
	if animation_player:
		animation_player.animation_finished.connect(func(_name): _finish())
		animation_player.play(animation_name)
	else:
		get_tree().create_timer(duration).timeout.connect(_finish)


func _unhandled_input(event: InputEvent) -> void:
	if not can_skip:
		return
	if (event is InputEventMouseButton or event is InputEventKey) and event.pressed:
		_finish()


## For testing: prints which scene is showing and the text of every Label
## in it, so the Output panel shows the order things played in.
func _print_what_is_showing() -> void:
	var texts: Array[String] = []
	for label in find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	print("Showing ", scene_file_path.get_file(), ": ", " | ".join(texts))  # for testing


## Only runs once, even if skipped and the animation also ends.
func _finish() -> void:
	if _finished:
		return
	_finished = true
	GameManager.cutscene_finished()
