extends Control
## The grinding minigame. Opened on top of the kitchen by mortar.gd.
## Move the mouse in circles around the mortar to fill the bar. It starts at
## zero and keeps draining, so you have to keep circling. Filling it is the
## only way out. Either direction works, and no mouse button is needed.
##
## While it's open, the mouse cursor is the pestle (pestle_final.png). While
## you're grinding, the ingredient spins around its center, a grinding sound
## plays, and dust puffs off it.
##
## Needs (with Access as Unique Name on):
##   %MortarPicture  a TextureRect (set its Texture to mortar_final.png)
##   %ItemPicture    a TextureRect on top of the mortar (shows the ingredient)
##   %Progress       a ProgressBar
##   %Hint           a Label

## Tells the mortar the grinding is complete.
signal finished

## How much one full circle adds to the bar (the bar goes from 0 to 100).
@export var fill_per_circle: float = 12.0
## How much the bar drains every second.
@export var drain_per_second: float = 12.0
## Circling closer than this to the center doesn't count. Stops tiny wiggles
## right in the middle from counting as huge spins.
@export var min_radius: float = 40.0

@export_group("Pestle cursor")
## How big the pestle picture is on screen.
@export var pestle_size: Vector2 = Vector2(96, 96)
## Where the pestle picture sits relative to the mouse point. (-48, -96)
## centers it horizontally with its bottom tip on the mouse.
@export var pestle_offset: Vector2 = Vector2(-48, -96)

@export_group("Grinding sound")
## The grinding sound. Drag a sound file here. It plays while you're grinding
## and stops shortly after you stop (a looping sound works best).
@export var grind_sound: AudioStream

@export_group("Dust")
## Color of the dust puffs.
@export var dust_color: Color = Color(0.85, 0.8, 0.7)
## How many dust bits per second while grinding.
@export var dust_amount: int = 24


@export_group("Look")
## Color of the progress bar's fill.
@export var bar_color: Color = Color(0.7, 0.5, 0.9)
## Font for the hint text at the top. Leave empty for the default font.
@export var hint_font: Font
## Size of the hint text.
@export var hint_font_size: int = 34
## How far down from the top of the screen the hint text sits (it's always centered).
@export var hint_top: float = 24.0

const PESTLE_PICTURE := "pestle_final"
## How long after the last movement it still counts as "grinding" (seconds).
const GRIND_GRACE := 0.15

## Set by the mortar before the minigame is shown.
var item_name: String = ""

@onready var mortar_picture: TextureRect = %MortarPicture
@onready var item_picture: TextureRect = %ItemPicture
@onready var progress: ProgressBar = %Progress
@onready var hint: Label = %Hint

var _last_angle := 0.0
var _has_last_angle := false  # false until the mouse is far enough from the center
var _done := false
var _grind_time_left := 0.0   # > 0 while the player is actively grinding

var _pestle: TextureRect
var _sound_player: AudioStreamPlayer
var _dust: CPUParticles2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # blocks clicks from reaching the kitchen
	item_picture.texture = Ingredient.get_texture(item_name)
	progress.min_value = 0
	progress.max_value = 100
	progress.step = 0.0  # no rounding, so small changes show up
	progress.value = 0  # starts empty
	MinigameStyle.style_bar(progress, bar_color)
	MinigameStyle.style_hint(hint, hint_font, hint_font_size)
	MinigameStyle.place_top_center(hint, hint_top)
	MinigameStyle.set_hint(hint, "Circle the mouse to grind the %s!" % item_name)
	_build_effects()


## Creates the dust, the pestle cursor and the sound player in code, so the
## scene doesn't need any new nodes. Added last, so they draw on top.
func _build_effects() -> void:
	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.amount = dust_amount
	_dust.lifetime = 0.7
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_dust.emission_sphere_radius = 20.0
	_dust.direction = Vector2.UP
	_dust.spread = 70.0
	_dust.initial_velocity_min = 40.0
	_dust.initial_velocity_max = 90.0
	_dust.gravity = Vector2(0, 160)
	_dust.scale_amount_min = 2.0
	_dust.scale_amount_max = 5.0
	var fade := Gradient.new()
	fade.set_color(0, dust_color)
	fade.set_color(1, Color(dust_color, 0.0))
	_dust.color_ramp = fade
	add_child(_dust)

	_pestle = TextureRect.new()
	_pestle.texture = Ingredient.load_sprite(PESTLE_PICTURE)
	_pestle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pestle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pestle.size = pestle_size
	_pestle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pestle)

	_sound_player = AudioStreamPlayer.new()
	_sound_player.stream = grind_sound
	add_child(_sound_player)

	if _pestle.texture:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN  # the pestle replaces the cursor
	_move_pestle()


## Put the normal cursor back when the minigame closes.
func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Every frame: move the pestle, drain the bar, then add however far the mouse
## moved around the center of the mortar since last frame.
func _process(delta: float) -> void:
	_move_pestle()
	MinigameStyle.tick_bar(progress, bar_color)
	# Spin around the middle of the picture, not its corner.
	item_picture.pivot_offset = item_picture.size / 2.0
	_dust.position = item_picture.position + item_picture.size / 2.0

	_grind_time_left = max(_grind_time_left - delta, 0.0)
	_update_grind_effects()
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
		if abs(turn) > 0.01:
			_grind_time_left = GRIND_GRACE
	_last_angle = angle
	_has_last_angle = true

	if progress.value >= progress.max_value:
		_complete()


func _move_pestle() -> void:
	if _pestle:
		_pestle.position = get_local_mouse_position() + pestle_offset


## Dust and sound run only while the player is actively grinding.
func _update_grind_effects() -> void:
	var grinding := _grind_time_left > 0.0 and not _done
	_dust.emitting = grinding
	if not _sound_player.stream:
		return
	if grinding and not _sound_player.playing:
		_sound_player.play()
	elif not grinding and _sound_player.playing:
		_sound_player.stop()


## Bar is full: short pause so the player sees it, then tell the mortar.
func _complete() -> void:
	_done = true
	MinigameStyle.set_hint(hint, "Ground!")
	await get_tree().create_timer(0.6).timeout
	finished.emit()
