extends Control
## The chopping minigame. Opened on top of the kitchen by cutting_board.gd.
## Click fast to fill the bar. It starts at zero and keeps draining, so you
## have to out-click the drain. Filling it is the only way out.
##
## Needs (with Access as Unique Name on):
##   %ItemPicture  a TextureRect (shows the ingredient being chopped)
##   %Progress     a ProgressBar
##   %Hint         a Label

## Tells the cutting board the chop is complete.
signal finished

## How much one click adds to the bar (the bar goes from 0 to 100).
@export var fill_per_click: float = 8.0
## How much the bar drains every second.
@export var drain_per_second: float = 20.0

## Set by the cutting board before the minigame is shown.
var item_name: String = ""

@onready var item_picture: TextureRect = %ItemPicture
@onready var progress: ProgressBar = %Progress
@onready var hint: Label = %Hint

var _done := false  # stops clicks and draining once the bar is full


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # blocks clicks from reaching the kitchen
	item_picture.texture = Ingredient.get_texture(item_name)
	progress.min_value = 0
	progress.max_value = 100
	progress.value = 0  # starts empty
	hint.text = "Click fast to chop the %s!" % item_name


## Runs every frame: the bar slowly drains (never below zero).
func _process(delta: float) -> void:
	if _done:
		return
	progress.value = max(progress.value - drain_per_second * delta, 0.0)


## Any left click inside the minigame counts as a chop.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_chop()


func _chop() -> void:
	if _done:
		return
	progress.value += fill_per_click
	_wobble()
	if progress.value >= progress.max_value:
		_complete()


## Bar is full: short pause so the player sees it, then tell the board.
func _complete() -> void:
	_done = true
	hint.text = "Chopped!"
	await get_tree().create_timer(0.6).timeout
	finished.emit()


## Small shake on each click for feedback.
func _wobble() -> void:
	item_picture.pivot_offset = item_picture.size / 2.0
	var t := create_tween()
	t.tween_property(item_picture, "rotation", 0.08, 0.04)
	t.tween_property(item_picture, "rotation", -0.08, 0.04)
	t.tween_property(item_picture, "rotation", 0.0, 0.04)
