extends CanvasLayer
## The kitchen's time limit. Uses today's "time_limit" (GameManager.today_rules()).
## Shows three warnings, then ends the day as TIME_UP when time runs out.
## Keeps running during the minigames.
##
##   early warning    - a few seconds in, so the player knows there's a time limit
##   halfway warning  - at half the time
##   final warning    - right before the end, with Grandma's sound in the house
##
## Sits on its own layer above the minigames, so warnings are always seen.
##
## Child nodes, all optional (missing ones are skipped):
##   WarningLabel       a Label that shows the warning text for a few seconds
##   WarningSound       AudioStreamPlayer - plays for the early and halfway warnings
##   FinalWarningSound  AudioStreamPlayer - Grandma in the house, for the last warning

## Sent for each warning: 0 = early, 1 = halfway, 2 = final.
signal warning_shown(index: int)

## Seconds after the kitchen opens that the early warning shows.
@export var early_warning_after: float = 5.0
## Seconds before the end that the final warning shows.
@export var final_warning_before: float = 10.0
## How long each warning message stays on screen.
@export var warning_show_time: float = 3.0
## The warning messages.
@export var early_text: String = "Grandma will be back for her book before long..."
@export var halfway_text: String = "Half your time is gone."
@export var final_text: String = "She's almost home!"

@onready var warning_label: Label = get_node_or_null("WarningLabel")
@onready var warning_sound: AudioStreamPlayer = get_node_or_null("WarningSound")
@onready var final_warning_sound: AudioStreamPlayer = get_node_or_null("FinalWarningSound")

var _time_limit := 0.0
var _elapsed := 0.0
var _warnings: Array = []     # [seconds_in, text, is_final], in order
var _next_warning := 0
var _label_time_left := 0.0
var _done := false


func _ready() -> void:
	layer = 20  # above the kitchen (1) and the minigames (10)
	_time_limit = GameManager.today_rules()["time_limit"]
	_warnings = [
		[early_warning_after, early_text, false],
		[_time_limit / 2.0, halfway_text, false],
		[_time_limit - final_warning_before, final_text, true],
	]
	if warning_label:
		warning_label.visible = false
		warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	print("Kitchen timer started: ", _time_limit, " seconds")  # for testing


func _process(delta: float) -> void:
	_tick_label(delta)
	if _done:
		return

	_elapsed += delta
	GameManager.kitchen_time_left = max(_time_limit - _elapsed, 0.0)

	# Show any warning whose time has come.
	while _next_warning < _warnings.size() and _elapsed >= _warnings[_next_warning][0]:
		_show_warning(_next_warning)
		_next_warning += 1

	if _elapsed >= _time_limit:
		_done = true
		print("Kitchen timer: time's up!")  # for testing
		GameManager.end_day(GameManager.Outcome.TIME_UP)


func _show_warning(index: int) -> void:
	var text: String = _warnings[index][1]
	var is_final: bool = _warnings[index][2]
	print("Kitchen timer warning ", index + 1, ": ", text)  # for testing
	if warning_label:
		warning_label.text = text
		warning_label.visible = true
		_label_time_left = warning_show_time
	_play(final_warning_sound if is_final else warning_sound)
	warning_shown.emit(index)


## Hides the warning message once its time is up.
func _tick_label(delta: float) -> void:
	if _label_time_left <= 0.0:
		return
	_label_time_left -= delta
	if _label_time_left <= 0.0 and warning_label:
		warning_label.visible = false


func _play(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()


## Stops the clock, e.g. if something else should pause it later.
func stop() -> void:
	_done = true


func _exit_tree() -> void:
	GameManager.kitchen_time_left = 0.0
