extends Control
## The boiling minigame. Opened on top of the kitchen by cauldron.gd when the
## 4th ingredient goes in.
##
## Drag logs from the wood pile onto the fire (or the cauldron). Each log plays the growing
## animation and gives the fire some burn time. While the fire is big
## (boiling), the brew bar fills. When the burn time runs out, the fire
## shrinks, and while it's small the brew bar drains backwards.
## When the brew bar is full, the potion is done.
## Don't overfeed it: a log that would go over Max Burn Seconds makes the pot
## boil over, and the brew bar loses some progress. The hint warns you first.
##
## While you drag a log from the pile, the mouse cursor is a log (log_final.png),
## and a bubbling sound plays while the potion is boiling.
##
## Fire animation (frames 0-5 set in Fire Frames):
##   Small:     loops 1, 0, 1, 0 ...       brew bar drains
##   Growing:   0, 2, 3, 4, 5 once         brew bar paused   (a log added to a small fire)
##   Big:       loops 2, 3, 2, 3 ...       brew bar fills
##   Flaring:   4, 5 once, then Big        brew bar fills    (a log added to a big fire)
##   Shrinking: 2, 1, 0 once               brew bar paused   (when the burn time runs out)
##
## Needs (with Access as Unique Name on):
##   %CauldronPicture  a TextureRect (in the potion's color, set by the cauldron:
##                     stage 2 while the fire is small, stage 3 bubbling while it's big)
##   %Fire             a TextureRect under the cauldron - drop logs here
##   %WoodPile         a TextureRect (your wood pile picture) - drag logs from here
##   %BrewBar          a ProgressBar (how done the potion is)
##   %Hint             a Label

## Tells the cauldron the potion has finished boiling.
signal finished

enum FireState { SMALL, GROWING, BIG, FLARING, SHRINKING }

## The 6 fire pictures, in order: frame 0 in slot 0, up to frame 5 in slot 5.
@export var fire_frames: Array[Texture2D] = []
## Picture of one log, used as the cursor while dragging. Leave empty to use log_final.png.
@export var log_texture: Texture2D

## How many seconds of big fire one log gives.
@export var burn_seconds_per_log: float = 3.0
## The most burn time the fire can hold. A log that would go over this makes
## the pot boil over (see Boil Over Penalty), so you can't just pile on wood.
@export var max_burn_seconds: float = 7.0
## How many seconds of big fire the potion needs in total.
@export var brew_seconds: float = 15.0
## How fast the brew bar drains while the fire is small (seconds lost per second).
@export var brew_drain_per_second: float = 2.0
## How much brewing (in seconds) is lost when the pot boils over.
@export var boil_over_penalty: float = 3.0

## How long each frame shows in the growing and shrinking animations.
@export var change_frame_time: float = 0.1
## How long each frame shows in the small and big loops.
@export var loop_frame_time: float = 0.25
## How long each cauldron bubbling frame shows.
@export var cauldron_frame_time: float = 0.15

@export_group("Log cursor")
## How big the log cursor is on screen.
@export var log_cursor_size: Vector2 = Vector2(96, 96)
## Where the log sits relative to the mouse point. (-48, -48) centers it on the mouse.
@export var log_cursor_offset: Vector2 = Vector2(-48, -48)

@export_group("Sounds")
## Bubbling pot. Plays on repeat while the fire is big (the potion is boiling).
@export var boil_sound: AudioStream
## Optional: plays when a log lands on the fire.
@export var log_sound: AudioStream
## Optional: plays when too much wood makes the pot boil over.
@export var boil_over_sound: AudioStream

@export_group("Look")
## Color of the brew bar's fill.
@export var bar_color: Color = Color(0.95, 0.45, 0.65)
## Font for the hint text at the top. Leave empty for the default font.
@export var hint_font: Font
## Size of the hint text.
@export var hint_font_size: int = 34
## How far down from the top of the screen the hint text sits (it's always centered).
@export var hint_top: float = 24.0

const LOG_PICTURE := "log_final"

## Set by the cauldron before the minigame opens: its 4 bubbling frames in the
## potion's color. If empty, CauldronPicture keeps whatever it shows in the editor.
var cauldron_frames: Array[Texture2D] = []
## Set by the cauldron: the stage 2 picture, shown while the fire isn't big.
var cauldron_still: Texture2D
var _cauldron_index := 0
var _cauldron_timer := 0.0

const GROW_FRAMES := [0, 2, 3, 4, 5]
const BIG_LOOP := [2, 3]
const FLARE_FRAMES := [4, 5]
const SHRINK_FRAMES := [2, 1, 0]
const SMALL_LOOP := [1, 0]

@onready var cauldron_picture: TextureRect = %CauldronPicture
@onready var fire: TextureRect = %Fire
@onready var wood_pile: TextureRect = %WoodPile
@onready var brew_bar: ProgressBar = %BrewBar
@onready var hint: Label = %Hint

var _state := FireState.SMALL
var _burn_left := 0.0       # seconds of big fire left
var _frames: Array = []     # the frame list currently playing
var _frame_index := 0
var _frame_timer := 0.0
var _done := false
var _message_left := 0.0    # > 0 while a special message (boil over) stays up

var _log_cursor: TextureRect
var _boil_player: AudioStreamPlayer
var _log_player: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # blocks clicks from reaching the kitchen
	if fire_frames.size() < 6:
		push_error("BoilingMinigame: put all 6 fire pictures (frames 0-5) into Fire Frames.")

	brew_bar.step = 0.0  # no rounding, so tiny per-frame changes show up
	brew_bar.max_value = brew_seconds
	brew_bar.value = 0  # starts empty
	MinigameStyle.style_bar(brew_bar, bar_color)
	MinigameStyle.style_hint(hint, hint_font, hint_font_size)
	MinigameStyle.place_top_center(hint, hint_top)

	# The wood pile hands out logs, and the fire takes them. Drag forwarding
	# lets this one script handle both nodes, so they don't need scripts.
	# Logs can be dropped on the fire OR the cauldron above it.
	wood_pile.mouse_filter = Control.MOUSE_FILTER_STOP
	fire.mouse_filter = Control.MOUSE_FILTER_STOP
	cauldron_picture.mouse_filter = Control.MOUSE_FILTER_STOP
	wood_pile.set_drag_forwarding(_get_log_drag, Callable(), Callable())
	fire.set_drag_forwarding(Callable(), _can_drop_log, _drop_log)
	cauldron_picture.set_drag_forwarding(Callable(), _can_drop_log, _drop_log)

	if cauldron_still:
		cauldron_picture.texture = cauldron_still
	elif not cauldron_frames.is_empty():
		cauldron_picture.texture = cauldron_frames[0]

	_build_effects()
	_set_state(FireState.SMALL)


## Creates the log cursor and the sound players in code, so the scene doesn't
## need any new nodes. Added last, so the cursor draws on top.
func _build_effects() -> void:
	if not log_texture:
		log_texture = Ingredient.load_sprite(LOG_PICTURE)

	_log_cursor = TextureRect.new()
	_log_cursor.texture = log_texture
	_log_cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_log_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_log_cursor.size = log_cursor_size
	_log_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_cursor.visible = false  # only shown while dragging a log
	add_child(_log_cursor)

	_boil_player = AudioStreamPlayer.new()
	_boil_player.stream = boil_sound
	# Start again when it ends, so it repeats even if the file isn't set to loop.
	_boil_player.finished.connect(func(): if _is_boiling(): _boil_player.play())
	add_child(_boil_player)

	_log_player = AudioStreamPlayer.new()
	add_child(_log_player)


## The log cursor: shown (and the normal mouse hidden) only while a log is
## being dragged from the wood pile.
func _show_log_cursor(on: bool) -> void:
	if not _log_cursor or not _log_cursor.texture:
		return
	_log_cursor.visible = on
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if on else Input.MOUSE_MODE_VISIBLE
	_move_log_cursor()


## When a drag ends (dropped on the fire or anywhere else), back to the normal mouse.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_show_log_cursor(false)


## Put the normal cursor back when the minigame closes.
func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _move_log_cursor() -> void:
	if _log_cursor:
		_log_cursor.position = get_local_mouse_position() + log_cursor_offset


## True while the fire is big, i.e. the potion is boiling.
func _is_boiling() -> bool:
	return not _done and (_state == FireState.BIG or _state == FireState.FLARING)


## The boiling sound runs only while the potion is boiling.
func _update_boil_sound() -> void:
	if not _boil_player.stream:
		return
	if _is_boiling() and not _boil_player.playing:
		_boil_player.play()
	elif not _is_boiling() and _boil_player.playing:
		_boil_player.stop()


func _process(delta: float) -> void:
	_move_log_cursor()
	_animate_cauldron(delta)
	_update_boil_sound()
	MinigameStyle.tick_bar(brew_bar, bar_color)
	if _done:
		return
	_animate(delta)
	_update_hint(delta)

	match _state:
		FireState.BIG, FireState.FLARING:
			brew_bar.value += delta
			_burn_left -= delta
			if _burn_left <= 0.0:
				_set_state(FireState.SHRINKING)
		FireState.SMALL:
			brew_bar.value = max(brew_bar.value - brew_drain_per_second * delta, 0.0)

	if brew_bar.value >= brew_bar.max_value:
		_complete()


## Switches the fire to a new state and starts that state's frames.
func _set_state(new_state: FireState) -> void:
	_state = new_state
	match new_state:
		FireState.SMALL:
			_frames = SMALL_LOOP
		FireState.GROWING:
			_frames = GROW_FRAMES
		FireState.BIG:
			_frames = BIG_LOOP
		FireState.FLARING:
			_frames = FLARE_FRAMES
		FireState.SHRINKING:
			_frames = SHRINK_FRAMES
	_frame_index = 0
	_frame_timer = 0.0
	_show_frame(_frames[0])


## Steps through the current frames. Loops repeat; growing, flaring and
## shrinking play once and then hand over to big or small.
func _animate(delta: float) -> void:
	var is_loop := _state == FireState.SMALL or _state == FireState.BIG
	var frame_time := loop_frame_time if is_loop else change_frame_time
	_frame_timer += delta
	if _frame_timer < frame_time:
		return
	_frame_timer = 0.0
	_frame_index += 1

	if _frame_index >= _frames.size():
		if is_loop:
			_frame_index = 0
		elif _state == FireState.GROWING or _state == FireState.FLARING:
			_set_state(FireState.BIG)
			return
		else:  # finished shrinking
			_set_state(FireState.SMALL)
			return
	_show_frame(_frames[_frame_index])


## The hint follows the fire, and warns when one more log would boil over.
func _update_hint(delta: float) -> void:
	if _message_left > 0.0:  # keep the boil-over message up for a moment
		_message_left -= delta
		return
	var text := ""
	match _state:
		FireState.SMALL, FireState.SHRINKING:
			text = "The fire is dying! Drag wood onto it!"
		FireState.GROWING:
			text = "The fire is catching..."
		_:
			if _burn_left + burn_seconds_per_log > max_burn_seconds:
				text = "It's very hot! Wait before adding more wood."
			else:
				text = "Keep it boiling!"
	MinigameStyle.set_hint(hint, text)


func _show_frame(frame: int) -> void:
	if frame < fire_frames.size():
		fire.texture = fire_frames[frame]


## Dragging from the wood pile picks up one log. The log cursor already shows
## the log in your hand, so the drag preview is left empty.
func _get_log_drag(_at_position: Vector2) -> Variant:
	if _done:
		return null
	if _log_cursor.texture:
		wood_pile.set_drag_preview(Control.new())
		_show_log_cursor(true)
	else:
		wood_pile.set_drag_preview(Ingredient.make_preview(wood_pile.texture, Vector2(96, 96)))
	return {"type": "wood"}


## The fire only takes logs.
func _can_drop_log(_at_position: Vector2, data: Variant) -> bool:
	return not _done and data is Dictionary and data.get("type") == "wood"


## A log always adds burn time. What it shows depends on the fire:
##   small or shrinking -> full grow (0,2,3,4,5), brewing paused until it's big
##   already growing    -> keep growing, don't restart the animation
##   big or flaring     -> quick flare (4,5), and brewing keeps going
func _drop_log(_at_position: Vector2, _data: Variant) -> void:
	var too_much := _burn_left + burn_seconds_per_log > max_burn_seconds
	_burn_left = min(_burn_left + burn_seconds_per_log, max_burn_seconds)
	print("Log added. Burn time left: ", _burn_left)  # for testing, remove later
	_play(log_sound)
	if too_much:
		_boil_over()
	match _state:
		FireState.SMALL, FireState.SHRINKING:
			_set_state(FireState.GROWING)
		FireState.BIG, FireState.FLARING:
			_set_state(FireState.FLARING)
		# GROWING: leave the animation running, the burn time is already added


## Too much wood: the pot boils over and some of the brewing is lost.
func _boil_over() -> void:
	brew_bar.value = max(brew_bar.value - boil_over_penalty, 0.0)
	_message_left = 1.5
	MinigameStyle.set_hint(hint, "Too much wood! It boiled over!")
	_play(boil_over_sound)
	# Shake the cauldron.
	cauldron_picture.pivot_offset = cauldron_picture.size / 2.0
	var t := create_tween()
	for i in 3:
		t.tween_property(cauldron_picture, "rotation", 0.08, 0.05)
		t.tween_property(cauldron_picture, "rotation", -0.08, 0.05)
	t.tween_property(cauldron_picture, "rotation", 0.0, 0.05)


## Plays a one-off sound (log, boil over) with a little pitch variation.
func _play(sound: AudioStream) -> void:
	if not sound:
		return
	_log_player.stream = sound
	_log_player.pitch_scale = randf_range(0.9, 1.1)
	_log_player.play()


## Brew bar is full: short pause so the player sees it, then tell the cauldron.
func _complete() -> void:
	_done = true
	MinigameStyle.set_hint(hint, "The potion is ready!")
	await get_tree().create_timer(0.8).timeout
	finished.emit()


## The cauldron bubbles (stage 3, frames 1-4) only while the fire is big under
## it. Otherwise it shows the still stage 2 picture.
func _animate_cauldron(delta: float) -> void:
	if cauldron_frames.is_empty():
		return
	var boiling := _state == FireState.BIG or _state == FireState.FLARING
	if not boiling:
		_cauldron_index = -1  # start from frame 1 next time it boils
		var still := cauldron_still if cauldron_still else cauldron_frames[0]
		if cauldron_picture.texture != still:
			cauldron_picture.texture = still
		return
	if _cauldron_index == -1:  # just started boiling: switch to stage 3 right away
		_cauldron_index = 0
		_cauldron_timer = 0.0
		cauldron_picture.texture = cauldron_frames[0]
		return
	_cauldron_timer += delta
	if _cauldron_timer >= cauldron_frame_time:
		_cauldron_timer = 0.0
		_cauldron_index = (_cauldron_index + 1) % cauldron_frames.size()
		cauldron_picture.texture = cauldron_frames[_cauldron_index]
