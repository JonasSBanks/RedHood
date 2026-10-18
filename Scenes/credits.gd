extends Control
## The credits. Put this on the root of credits.tscn (a Control set to Full
## Rect). Write the credits in the Credits Text box in the Inspector:
##
##   # Big heading         <- a line starting with "# " is a section heading
##   Name - what they did  <- any other line is a name
##                         <- an empty line adds a gap
##
## The credits scroll up from the bottom. At the end, "Thanks for playing!"
## stays on screen, and a click (or any key) starts a new game from day 1.
## Hold the mouse button or Space to scroll faster.

@export_multiline var credits_text: String = """# Grandma's Kitchen

# Programming
Your Name

# Art
Your Name

# Story & Writing
Your Name

# Sound & Music
Your Name

# Special Thanks
Your teacher
Everyone who played"""

## The game's title, shown big at the very top. Leave empty to skip.
@export var title: String = ""
## Message that stays at the end.
@export var end_message: String = "Thanks for playing!"
## Scroll speed, in pixels per second.
@export var scroll_speed: float = 70.0
## How much faster it scrolls while holding the mouse or Space.
@export var fast_multiplier: float = 4.0
## Optional background picture.
@export var background: Texture2D
## Optional music.
@export var music: AudioStream

@export_group("Intro frames")
## Full-screen pictures shown one after another BEFORE the scrolling credits
## (e.g. your 3 ending frames). Leave empty to go straight to the credits.
@export var intro_frames: Array[Texture2D] = []
## Seconds each intro picture shows.
@export var intro_frame_time: float = 1.5
## Seconds for the fade between pictures (and into the credits).
@export var intro_fade_time: float = 0.3

@export_group("Text")
@export var font: Font
@export var title_size: int = 64
@export var heading_size: int = 36
@export var name_size: int = 28

var _list: VBoxContainer
var _end_label: Label
var _done := false
var _can_restart := false
var _started := false
var _in_intro := false
var _intro: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if not intro_frames.is_empty():
		_play_intro()
	if music:
		var player := AudioStreamPlayer.new()
		player.stream = music
		add_child(player)
		player.play()


func _build() -> void:
	# Background: the picture, or the game's dark brown.
	if background:
		var picture := TextureRect.new()
		picture.texture = background
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(picture)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.05, 0.03, 0.7 if background else 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	# The scrolling list, starting just below the screen.
	_list = VBoxContainer.new()
	_list.alignment = BoxContainer.ALIGNMENT_BEGIN
	_list.add_theme_constant_override("separation", 10)
	add_child(_list)

	if title != "":
		_add_line(title, title_size, MinigameStyle.GOLD)
		_add_gap(40)
	for line in credits_text.split("\n"):
		var text := line.strip_edges()
		if text == "":
			_add_gap(30)
		elif text.begins_with("#"):
			_add_line(text.trim_prefix("#").strip_edges(), heading_size, MinigameStyle.GOLD)
		else:
			_add_line(text, name_size, MinigameStyle.TEXT_COLOR)

	# "Thanks for playing!" fades in at the end and stays.
	_end_label = Label.new()
	_end_label.text = end_message
	_style(_end_label, heading_size + 8, MinigameStyle.TEXT_COLOR)
	_end_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_end_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_end_label.modulate.a = 0.0
	add_child(_end_label)



func _add_line(text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style(label, font_size, color)
	_list.add_child(label)


func _add_gap(height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	_list.add_child(gap)


func _style(label: Label, font_size: int, color: Color) -> void:
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", MinigameStyle.TEXT_OUTLINE)
	label.add_theme_constant_override("outline_size", 10)


func _process(delta: float) -> void:
	if _done or _in_intro:
		return
	_list.size.x = size.x
	if not _started:  # first frame: the screen size is known now
		_started = true
		_list.position = Vector2(0, size.y)
		return
	var speed := scroll_speed
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE):
		speed *= fast_multiplier
	_list.position.y -= speed * delta
	# Everything has scrolled off the top: show the end message.
	if _list.position.y + _list.size.y < 0.0:
		_finish_scroll()


## The intro pictures, full screen, on top of the credits. Each shows for
## Intro Frame Time, then the last one fades away and the credits begin.
func _play_intro() -> void:
	_in_intro = true
	_intro = TextureRect.new()
	_intro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_intro.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.texture = intro_frames[0]
	add_child(_intro)  # added last, so it covers everything

	var t := create_tween()
	for i in range(1, intro_frames.size()):
		t.tween_interval(intro_frame_time)
		t.tween_property(_intro, "modulate:a", 0.0, intro_fade_time * 0.5)
		t.tween_callback(func(): _intro.texture = intro_frames[i])
		t.tween_property(_intro, "modulate:a", 1.0, intro_fade_time * 0.5)
	t.tween_interval(intro_frame_time)
	t.tween_property(_intro, "modulate:a", 0.0, intro_fade_time)
	t.tween_callback(func():
		_intro.queue_free()
		_in_intro = false)


func _finish_scroll() -> void:
	_done = true
	var t := create_tween()
	t.tween_property(_end_label, "modulate:a", 1.0, 1.0)
	t.tween_interval(1.0)  # so a held click doesn't restart right away
	t.tween_callback(func(): _can_restart = true)


## After the end message: click or any key plays again from day 1.
func _unhandled_input(event: InputEvent) -> void:
	if not _can_restart:
		return
	if (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		_can_restart = false
		GameManager.restart_game()
