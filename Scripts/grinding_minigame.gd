extends Control
## The grinding minigame. Opened on top of the kitchen by mortar.gd.
## Move the mouse in circles around the mortar to fill the bar. It starts at
## zero and keeps draining, so you have to keep circling. Filling it is the
## only way out. Either direction works, and no mouse button is needed.
##
## Needs (with Access as Unique Name on):
##   %MortarPicture  a TextureRect (set its Texture to mortar_final.png)
##   %ItemPicture    a TextureRect on top of the mortar (shows the ingredient)
##   %Progress       a ProgressBar
##   %Hint           a Label

## Tells the mortar the grinding is complete.
signal finished

## How much one full circle adds to the bar (the bar goes from 0 to 100).
@export var fill_per_circle: float = 25.0
## How much the bar drains every second.
@export var drain_per_second: float = 15.0
## Circling closer than this to the center doesn't count. Stops tiny wiggles
## right in the middle from counting as huge spins.
@export var min_radius: float = 40.0

## Set by the mortar before the minigame is shown.
var item_name: String = ""

@onready var mortar_picture: TextureRect = %MortarPicture
@onready var item_picture: TextureRect = %ItemPicture
@onready var progress: ProgressBar = %Progress
@onready var hint: Label = %Hint

var _last_angle := 0.0
var _has_last_angle := false  # false until the mouse is far enough from the center
var _done := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # blocks clicks from reaching the kitchen
	item_picture.texture = Ingredient.get_texture(item_name)
	progress.min_value = 0
	progress.max_value = 100
	progress.value = 0  # starts empty
	hint.text = "Circle the mouse to grind the %s!" % item_name


## Every frame: drain the bar, then add however far the mouse moved around
## the center of the mortar since last frame.
func _process(delta: float) -> void:
	if _done:
		return
	progress.value = max(progress.value - drain_per_second * delta, 0.0)

	var center := mortar_picture.global_position + mortar_picture.size / 2.0
	var offset := get_global_mouse_position() - center

	# Too close to the middle: ignore and start fresh next time.
	if offset.length() < min_radius:
		_has_last_angle = false
		return

	var angle := offset.angle()
	if _has_last_angle:
		# How far around the circle the mouse moved, wrapped to -PI..PI so
		# crossing from one side of the angle range to the other isn't a jump.
		var turn := wrapf(angle - _last_angle, -PI, PI)
		turn = clamp(turn, -PI / 2.0, PI / 2.0)  # ignore sudden teleports
		progress.value += abs(turn) / TAU * fill_per_circle
		item_picture.rotation += turn * 0.5  # the ingredient swirls as you grind
	_last_angle = angle
	_has_last_angle = true

	if progress.value >= progress.max_value:
		_complete()


## Bar is full: short pause so the player sees it, then tell the mortar.
func _complete() -> void:
	_done = true
	hint.text = "Ground!"
	await get_tree().create_timer(0.6).timeout
	finished.emit()
