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
## Child nodes, both optional (missing ones are skipped):
##   GrandmaPicture      any Control (e.g. TextureRect) - shown while she's in the room
##   FootstepsIndicator  any Control - shown during the footsteps warning
##
## Sounds go in the Sounds slots in the Inspector (all optional):
##   coming:  Footsteps In (during the warning) -> Door Open (as she enters)
##   going:   Door Close (as she leaves) -> Footsteps Out (walking away)

## She's about to come in (footsteps_warning seconds from now).
signal footsteps_started
## She just came into the room.
signal entered
## She just left the room.
signal left

@export_group("Sounds")
## Footsteps coming toward the kitchen. Plays when the warning starts.
@export var footsteps_in_sound: AudioStream
## The door opening. Plays when she comes in.
@export var door_open_sound: AudioStream
## The door closing. Plays when she leaves.
@export var door_close_sound: AudioStream
## Footsteps walking away. Plays right after the door closes.
## (You can drop the same file as Footsteps In here.)
@export var footsteps_out_sound: AudioStream
## Seconds between the door closing and the footsteps walking away.
@export var footsteps_out_delay: float = 0.3

@onready var grandma_picture: Control = get_node_or_null("GrandmaPicture")
@onready var footsteps_indicator: Control = get_node_or_null("FootstepsIndicator")

var _footsteps_player: AudioStreamPlayer  # footsteps (in and out)
var _door_player: AudioStreamPlayer       # door open/close

var _rules: Dictionary
var _in_room := false
var _timer := 0.0          # seconds since she last came in or left
var _warned := false       # footsteps already played for this visit


func _ready() -> void:
	layer = 20  # above the kitchen (1) and the minigames (10)
	_rules = GameManager.today_rules()
	_footsteps_player = AudioStreamPlayer.new()
	_door_player = AudioStreamPlayer.new()
	add_child(_footsteps_player)
	add_child(_door_player)
	_take_old_sound_nodes()

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
		_play(_footsteps_player, footsteps_in_sound)
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
		_footsteps_player.stop()  # she's at the door now
		_play(_door_player, door_open_sound)
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
		_play(_door_player, door_close_sound)
		_play_footsteps_out()
	print("Grandma: left")  # for testing
	left.emit()


## Plays a sound on a player, if a sound is set.
func _play(player: AudioStreamPlayer, sound: AudioStream) -> void:
	if not sound:
		return
	player.stream = sound
	player.play()


## Footsteps walking away, a moment after the door closes.
func _play_footsteps_out() -> void:
	if not footsteps_out_sound:
		return
	# A tween belongs to this node, so it's cancelled safely if the kitchen closes.
	var t := create_tween()
	t.tween_interval(footsteps_out_delay)
	t.tween_callback(_footsteps_out_now)


func _footsteps_out_now() -> void:
	if not _in_room:  # she didn't come straight back in
		_play(_footsteps_player, footsteps_out_sound)


## If the old FootstepsSound / EnterSound / LeaveSound child nodes exist, use
## their sounds for any empty slot, so nothing set up earlier is lost.
func _take_old_sound_nodes() -> void:
	var old := {
		"FootstepsSound": "footsteps_in_sound",
		"EnterSound": "door_open_sound",
		"LeaveSound": "door_close_sound",
	}
	for node_name in old:
		var node := get_node_or_null(node_name) as AudioStreamPlayer
		if node and node.stream and get(old[node_name]) == null:
			set(old[node_name], node.stream)


## When the kitchen closes (day ends), she's no longer "in the room".
func _exit_tree() -> void:
	GameManager.grandma_in_room = false
