extends Control
## The chopping minigame. Opened on top of the kitchen by cutting_board.gd.
## Click fast to fill the bar. It starts at zero and keeps draining, so you
## have to out-click the drain. Filling it is the only way out.
##
## While it's open, the mouse cursor is the knife (knife_final.png). Each click
## chops: the knife dips, a chop sound plays, and a small gash appears where you
## clicked and quickly fades.
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

@export_group("Knife cursor")
## How big the knife picture is on screen.
@export var knife_size: Vector2 = Vector2(96, 96)
## Where the knife picture sits relative to the mouse point. (0, -96) puts the
## knife's bottom-left corner on the mouse; adjust until the blade edge is
## where you click.
@export var knife_offset: Vector2 = Vector2(0, -96)
## How far the knife tilts down on each chop, in degrees.
@export var chop_tilt: float = 25.0

@export_group("Chop sound")
## The knife sound. Drag a sound file (.wav/.ogg/.mp3) here.
@export var chop_sound: AudioStream
## Each chop's pitch varies a little so repeated chops don't sound identical.
@export var pitch_variation: float = 0.1

@export_group("Gash")
## Optional gash picture. Leave empty to draw a simple dark slash instead.
@export var gash_texture: Texture2D
## Color of the drawn slash (used when Gash Texture is empty).
@export var gash_color: Color = Color(0.25, 0.08, 0.05, 0.9)
## Length of the drawn slash, in pixels.
@export var gash_length: float = 40.0
## How long a gash takes to fade away, in seconds.
@export var gash_fade_time: float = 0.4


@export_group("Look")
## Color of the progress bar's fill.
@export var bar_color: Color = Color(0.95, 0.55, 0.2)
## Font for the hint text at the top. Leave empty for the default font.
@export var hint_font: Font
## Size of the hint text.
@export var hint_font_size: int = 34
## How far down from the top of the screen the hint text sits (it's always centered).
@export var hint_top: float = 24.0

const KNIFE_PICTURE := "knife_final"

## Set by the cutting board before the minigame is shown.
var item_name: String = ""

@onready var item_picture: TextureRect = %ItemPicture
@onready var progress: ProgressBar = %Progress
@onready var hint: Label = %Hint

var _done := false  # stops clicks and draining once the bar is full
var _gash_layer: Control       # gashes are drawn here, above the ingredient
var _knife: TextureRect        # the knife that follows the mouse
var _sound_player: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # blocks clicks from reaching the kitchen
	item_picture.texture = Ingredient.get_texture(item_name)
	progress.min_value = 0
	progress.max_value = 100
	progress.step = 0.0  # no rounding, so the slow drain shows up
	progress.value = 0  # starts empty
	MinigameStyle.style_bar(progress, bar_color)
	MinigameStyle.style_hint(hint, hint_font, hint_font_size)
	MinigameStyle.place_top_center(hint, hint_top)
	MinigameStyle.set_hint(hint, "Click fast to chop the %s!" % item_name)
	_build_effects()


## Creates the gash layer, the knife cursor and the sound player in code, so
## the scene doesn't need any new nodes. Added last, so they draw on top.
func _build_effects() -> void:
	_gash_layer = Control.new()
	_gash_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gash_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gash_layer)

	_knife = TextureRect.new()
	_knife.texture = Ingredient.load_sprite(KNIFE_PICTURE)
	_knife.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_knife.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_knife.size = knife_size
	_knife.pivot_offset = Vector2(0, knife_size.y)  # tilts around the handle end
	_knife.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_knife)

	_sound_player = AudioStreamPlayer.new()
	_sound_player.stream = chop_sound
	add_child(_sound_player)

	if _knife.texture:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN  # the knife replaces the cursor
	_move_knife()


## Put the normal cursor back when the minigame closes.
func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Runs every frame: the knife follows the mouse, and the bar slowly drains.
func _process(delta: float) -> void:
	_move_knife()
	MinigameStyle.tick_bar(progress, bar_color)
	if _done:
		return
	progress.value = max(progress.value - drain_per_second * delta, 0.0)


func _move_knife() -> void:
	if _knife:
		_knife.position = get_local_mouse_position() + knife_offset


## Any left click inside the minigame counts as a chop.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_chop(get_local_mouse_position())


func _chop(at: Vector2) -> void:
	if _done:
		return
	progress.value += fill_per_click
	_wobble()
	_knife_dip()
	_play_chop_sound()
	_spawn_gash(at)
	if progress.value >= progress.max_value:
		_complete()


## Bar is full: short pause so the player sees it, then tell the board.
func _complete() -> void:
	_done = true
	MinigameStyle.set_hint(hint, "Chopped!")
	item_picture.texture = Ingredient.get_texture("Chopped " + item_name)
	await get_tree().create_timer(0.6).timeout
	finished.emit()

#why are you looking at this
# ===== Feedback =====

## Small shake on the ingredient for each chop.
func _wobble() -> void:
	item_picture.pivot_offset = item_picture.size / 2.0
	var t := create_tween()
	t.tween_property(item_picture, "rotation", 0.08, 0.04)
	t.tween_property(item_picture, "rotation", -0.08, 0.04)
	t.tween_property(item_picture, "rotation", 0.0, 0.04)


## The knife tilts down and back up.
func _knife_dip() -> void:
	if not _knife:
		return
	var t := create_tween()
	t.tween_property(_knife, "rotation", deg_to_rad(chop_tilt), 0.04)
	t.tween_property(_knife, "rotation", 0.0, 0.08)


func _play_chop_sound() -> void:
	if _sound_player.stream:
		_sound_player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
		_sound_player.play()


## A small gash where you clicked, at a random angle, that fades away quickly.
func _spawn_gash(at: Vector2) -> void:
	var gash: CanvasItem
	if gash_texture:
		var picture := TextureRect.new()
		picture.texture = gash_texture
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.size = gash_texture.get_size()
		picture.pivot_offset = picture.size / 2.0
		picture.position = at - picture.size / 2.0
		picture.rotation = randf_range(-0.6, 0.6)
		gash = picture
	else:
		var line := Line2D.new()
		var half := Vector2(gash_length / 2.0, 0).rotated(randf_range(-0.6, 0.6) + PI / 4.0)
		line.points = PackedVector2Array([at - half, at + half])
		line.width = 4.0
		line.default_color = gash_color
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		gash = line
	_gash_layer.add_child(gash)

	var t := create_tween()
	t.tween_property(gash, "modulate:a", 0.0, gash_fade_time).set_delay(0.1)
	t.tween_callback(gash.queue_free)
