extends Control
## The boiling minigame. Opened on top of the kitchen by cauldron.gd when the
## 4th ingredient goes in.
##
## Drag logs from the wood pile onto the fire. Each log plays the growing
## animation and gives the fire some burn time. While the fire is big
## (boiling), the brew bar fills. When the burn time runs out, the fire
## shrinks, and while it's small the brew bar drains backwards.
## When the brew bar is full, the potion is done.
##
## Fire animation (frames 0-5 set in Fire Frames):
##   Small:     loops 1, 0, 1, 0 ...       brew bar drains
##   Growing:   0, 2, 3, 4, 5 once         brew bar paused   (every time a log is added)
##   Big:       loops 2, 3, 2, 3 ...       brew bar fills
##   Shrinking: 2, 1, 0 once               brew bar paused   (when the burn time runs out)
##
## Needs (with Access as Unique Name on):
##   %CauldronPicture  a TextureRect (your cauldron picture)
##   %Fire             a TextureRect under the cauldron - drop logs here
##   %WoodPile         a TextureRect (your wood pile picture) - drag logs from here
##   %BrewBar          a ProgressBar (how done the potion is)
##   %Hint             a Label

## Tells the cauldron the potion has finished boiling.
signal finished

enum FireState { SMALL, GROWING, BIG, SHRINKING }

## The 6 fire pictures, in order: frame 0 in slot 0, up to frame 5 in slot 5.
@export var fire_frames: Array[Texture2D] = []
## Picture of one log, shown while dragging. Leave empty to use the wood pile picture.
@export var log_texture: Texture2D

## How many seconds of big fire one log gives.
@export var burn_seconds_per_log: float = 4.0
## The most burn time the fire can store, so you can't stack up logs forever.
@export var max_burn_seconds: float = 12.0
## How many seconds of big fire the potion needs in total.
@export var brew_seconds: float = 10.0
## How fast the brew bar drains while the fire is small (seconds lost per second).
@export var brew_drain_per_second: float = 1.0

## How long each frame shows in the growing and shrinking animations.
@export var change_frame_time: float = 0.1
## How long each frame shows in the small and big loops.
@export var loop_frame_time: float = 0.25

const GROW_FRAMES := [0, 2, 3, 4, 5]
const BIG_LOOP := [2, 3]
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # blocks clicks from reaching the kitchen
	if fire_frames.size() < 6:
		push_error("BoilingMinigame: put all 6 fire pictures (frames 0-5) into Fire Frames.")

	brew_bar.max_value = brew_seconds
	brew_bar.value = 0  # starts empty

	# The wood pile hands out logs, and the fire takes them. Drag forwarding
	# lets this one script handle both nodes, so they don't need scripts.
	wood_pile.mouse_filter = Control.MOUSE_FILTER_STOP
	fire.mouse_filter = Control.MOUSE_FILTER_STOP
	wood_pile.set_drag_forwarding(_get_log_drag, Callable(), Callable())
	fire.set_drag_forwarding(Callable(), _can_drop_log, _drop_log)

	_set_state(FireState.SMALL)


func _process(delta: float) -> void:
	if _done:
		return
	_animate(delta)

	match _state:
		FireState.BIG:
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
			hint.text = "The fire is dying! Drag wood onto it!"
		FireState.GROWING:
			_frames = GROW_FRAMES
		FireState.BIG:
			_frames = BIG_LOOP
			hint.text = "Keep it boiling!"
		FireState.SHRINKING:
			_frames = SHRINK_FRAMES
	_frame_index = 0
	_frame_timer = 0.0
	_show_frame(_frames[0])


## Steps through the current frames. Loops repeat; growing and shrinking play
## once and then hand over to big or small.
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
		elif _state == FireState.GROWING:
			_set_state(FireState.BIG)
			return
		else:  # finished shrinking
			_set_state(FireState.SMALL)
			return
	_show_frame(_frames[_frame_index])


func _show_frame(frame: int) -> void:
	if frame < fire_frames.size():
		fire.texture = fire_frames[frame]


## Dragging from the wood pile picks up one log.
func _get_log_drag(_at_position: Vector2) -> Variant:
	if _done:
		return null
	var picture := log_texture if log_texture else wood_pile.texture
	wood_pile.set_drag_preview(Ingredient.make_preview(picture, Vector2(96, 96)))
	return {"type": "wood"}


## The fire only takes logs.
func _can_drop_log(_at_position: Vector2, data: Variant) -> bool:
	return not _done and data is Dictionary and data.get("type") == "wood"


## A log adds burn time and always plays the growing animation (0,2,3,4,5).
func _drop_log(_at_position: Vector2, _data: Variant) -> void:
	_burn_left = min(_burn_left + burn_seconds_per_log, max_burn_seconds)
	_set_state(FireState.GROWING)


## Brew bar is full: short pause so the player sees it, then tell the cauldron.
func _complete() -> void:
	_done = true
	hint.text = "The potion is ready!"
	await get_tree().create_timer(0.8).timeout
	finished.emit()
