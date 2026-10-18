extends CanvasItem
## Put this on any picture inside a cutscene slide (TextureRect, Sprite2D...)
## to make it move when the slide appears. Place the picture where it STARTS
## in the editor, then say how far it should move.
##
## Don't put moving pictures inside a container (HBox, VBox...), because the
## container would hold them in place.

## Tells the slide this move is done (so the text can show).
signal finished

enum Motion { SMOOTH, LINEAR, BOUNCE, SPRING }

## How far it moves, in pixels. (300, 0) = 300 to the right, (0, -100) = 100 up.
@export var move_by: Vector2 = Vector2.ZERO
## How long the move takes, in seconds.
@export var move_time: float = 2.0
## Wait this long after the slide appears before moving.
@export var start_delay: float = 0.0
## How it moves: Smooth (eases in and out), Linear (steady), Bounce (lands
## with a bounce), Spring (overshoots a little and settles).
@export var motion: Motion = Motion.SMOOTH
## Turn while moving, in degrees (e.g. 15). 0 = no turning.
@export var rotate_by: float = 0.0
## Fade in from invisible at the start of the move.
@export var fade_in: bool = false
## Keep going back and forth forever (good for bobbing or swaying).
@export var back_and_forth: bool = false

var _start_position: Vector2
var _start_rotation: float
var _tween: Tween


func _ready() -> void:
	_start_position = get("position")
	_start_rotation = get("rotation")


## The slide asks this to know whether to wait for it. Back-and-forth moves
## never end, so the text doesn't wait for those.
func finishes() -> bool:
	return not back_and_forth


## Called by the slide when it appears. Always starts from the editor position.
func start_move() -> void:
	if _tween:
		_tween.kill()
	set("position", _start_position)
	set("rotation", _start_rotation)
	if fade_in:
		modulate.a = 0.0
	var me: Node = self  # plain Node type, so Godot allows the Control check
	if me is Control:
		var control := me as Control
		control.pivot_offset = control.size / 2.0  # turn around the middle
	# Wait for the delay (only once, even when going back and forth), then move.
	_tween = create_tween()
	_tween.tween_interval(start_delay)
	_tween.tween_callback(_begin)


func _begin() -> void:
	_tween = create_tween()
	if back_and_forth:
		_tween.set_loops()
	# There...
	_step("position", _start_position + move_by, false)
	if rotate_by != 0.0:
		_step("rotation", _start_rotation + deg_to_rad(rotate_by), true)
	if fade_in:
		_tween.parallel().tween_property(self, "modulate:a", 1.0, min(move_time, 0.6))
	# ...and back again.
	if back_and_forth:
		_step("position", _start_position, false)
		if rotate_by != 0.0:
			_step("rotation", _start_rotation, true)
	else:
		_tween.tween_callback(finished.emit)


## Adds one movement. together = runs at the same time as the previous one.
func _step(property: String, to: Variant, together: bool) -> void:
	var step: PropertyTweener
	if together:
		step = _tween.parallel().tween_property(self, property, to, move_time)
	else:
		step = _tween.tween_property(self, property, to, move_time)
	match motion:
		Motion.SMOOTH:
			step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		Motion.LINEAR:
			step.set_trans(Tween.TRANS_LINEAR)
		Motion.BOUNCE:
			step.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Motion.SPRING:
			step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
