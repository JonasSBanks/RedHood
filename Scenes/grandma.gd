extends CanvasLayer
## Grandma coming in and out of the kitchen, following today's rules
## (GameManager.today_rules()):
##   grandma_always_in  - true: she's in the room the whole day (Day 1)
##   grandma_away_time  - seconds she's out of the room each time
##   grandma_in_time    - seconds she stays in the room each time
##   footsteps_warning  - seconds before she enters that the footsteps cue starts
##
## She starts out of the room (unless always in), so the first visit comes
## after grandma_away_time seconds.
##
## Keeps GameManager.grandma_in_room up to date, so any script can check it.
## Sits on its own layer above the minigames, so she's seen and heard there too.
##
## Child nodes, all optional (missing ones are skipped):
##   GrandmaPicture      any Control (e.g. TextureRect) - shown while she's in the room
##   FootstepsIndicator  any Control - shown during the footsteps warning
##   FootstepsSound      AudioStreamPlayer - plays when the warning starts
##   EnterSound          AudioStreamPlayer - plays when she comes in
##   LeaveSound          AudioStreamPlayer - plays when she leaves

## She's about to come in (footsteps_warning seconds from now).
signal footsteps_started
## She just came into the room.
signal entered
## She just left the room.
signal left

@onready var grandma_picture: Control = get_node_or_null("GrandmaPicture")
@onready var footsteps_indicator: Control = get_node_or_null("FootstepsIndicator")
@onready var footsteps_sound: AudioStreamPlayer = get_node_or_null("FootstepsSound")
@onready var enter_sound: AudioStreamPlayer = get_node_or_null("EnterSound")
@onready var leave_sound: AudioStreamPlayer = get_node_or_null("LeaveSound")

var _rules: Dictionary
var _in_room := false
var _timer := 0.0          # seconds since she last came in or left
var _warned := false       # footsteps already played for this visit


func _ready() -> void:
	layer = 20  # above the kitchen (1) and the minigames (10)
	_rules = GameManager.today_rules()

	# Her pictures must never catch the mouse.
	for node in [grandma_picture, footsteps_indicator]:
		if node:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if footsteps_indicator:
		footsteps_indicator.visible = false

	if _rules["grandma_always_in"]:
		_enter(false)
	else:
		_leave(false)


func _process(delta: float) -> void:
	if _rules["grandma_always_in"]:
		return
	_timer += delta

	if _in_room:
		if _timer >= _rules["grandma_in_time"]:
			_leave(true)
		return

	# Out of the room: footsteps a few seconds early, then she comes in.
	var away: float = _rules["grandma_away_time"]
	if not _warned and _timer >= away - _rules["footsteps_warning"]:
		_warned = true
		_play(footsteps_sound)
		if footsteps_indicator:
			footsteps_indicator.visible = true
		print("Grandma: footsteps...")  # for testing
		footsteps_started.emit()
	if _timer >= away:
		_enter(true)


## True while she's in the room.
func is_in_room() -> bool:
	return _in_room


func _enter(with_sound: bool) -> void:
	_in_room = true
	_timer = 0.0
	_warned = false
	GameManager.grandma_in_room = true
	if grandma_picture:
		grandma_picture.visible = true
	if footsteps_indicator:
		footsteps_indicator.visible = false
	if with_sound:
		_play(enter_sound)
	print("Grandma: entered")  # for testing
	entered.emit()


func _leave(with_sound: bool) -> void:
	_in_room = false
	_timer = 0.0
	_warned = false
	GameManager.grandma_in_room = false
	if grandma_picture:
		grandma_picture.visible = false
	if with_sound:
		_play(leave_sound)
	print("Grandma: left")  # for testing
	left.emit()


## Plays a sound if the node exists and has a sound in it.
func _play(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()


## When the kitchen closes (day ends), she's no longer "in the room".
func _exit_tree() -> void:
	GameManager.grandma_in_room = false
