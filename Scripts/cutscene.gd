extends Node
## Put this on the root node of every cutscene and hint scene.
##
## WITH SLIDES (CutsceneSlide children, in Scene panel order):
##   Shows them one at a time like a picture book. Pictures fade from one
##   slide to the next, and each slide's text types out in a dialogue box at
##   the bottom, in the same style as the rest of the game.
##     Click / Space / Enter: finish the text, or go to the next slide.
##     Esc or the Skip button: skip the whole cutscene.
##
## WITHOUT SLIDES (the old placeholder way, still works):
##   Plays Animation Player if set, otherwise waits Duration seconds.
##   Click or press a key to skip.
##
## When it's over, it tells GameManager, which moves on (hint, next day, or
## credits after the ending).

## Optional AnimationPlayer (only used when there are no slides).
@export var animation_player: AnimationPlayer
## Which animation to play.
@export var animation_name: StringName = &"cutscene"
## How long a cutscene with no slides and no AnimationPlayer lasts, in seconds.
@export var duration: float = 3.0
## Let the player skip.
@export var can_skip: bool = true

@export_group("Dialogue box")
## How fast the text types out, in letters per second.
@export var letters_per_second: float = 40.0
## Size of the dialogue text.
@export var text_size: int = 28
## Size of the speaker's name.
@export var name_size: int = 24
## Optional font for the text and name.
@export var font: Font
## Optional sound for each letter typed (keep it very short). Plays every few letters.
@export var type_sound: AudioStream

@export_group("Fades")
## Seconds for the fade from black at the start and to black at the end.
@export var fade_time: float = 0.5
## Seconds for the cross-fade between slides.
@export var slide_fade_time: float = 0.4

var _finished := false
var _slides: Array[CutsceneSlide] = []
var _index := -1
var _typing := false
var _waiting_auto := 0.0   # > 0 while counting down to an auto-advance
var _waiting_anim := false  # true while the text waits for an animation
var _busy := false         # true during a slide change

var _box: PanelContainer
var _name_tag: Label
var _text: Label
var _arrow: Control  # the blinking "continue" triangle
var _black: ColorRect
var _skip_button: Button
var _type_tween: Tween
var _sound_player: AudioStreamPlayer
var _type_player: AudioStreamPlayer
var _last_letters := 0


func _ready() -> void:
	for child in get_children():
		if child is CutsceneSlide:
			_slides.append(child)
	_print_what_is_showing()

	if _slides.is_empty():
		_play_old_way()
		return
	var me: Node = self  # plain Node type, so Godot allows the Control check
	if me is Control:
		(me as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE  # let clicks through
	_build_ui()
	_start.call_deferred()


# ===== Old placeholder way (no slides) =====

func _play_old_way() -> void:
	if animation_player:
		animation_player.animation_finished.connect(func(_name): _finish())
		animation_player.play(animation_name)
	else:
		get_tree().create_timer(duration).timeout.connect(_finish)


# ===== Slides =====

func _start() -> void:
	_black.modulate.a = 1.0
	_show_slide(0)
	var t := create_tween()
	t.tween_property(_black, "modulate:a", 0.0, fade_time)


func _show_slide(index: int) -> void:
	_busy = true
	var old: CutsceneSlide = _slides[_index] if _index >= 0 else null
	_index = index
	var slide := _slides[index]

	# Cross-fade: the new slide fades in on top of the old one.
	slide.visible = true
	slide.modulate.a = 0.0 if old else 1.0
	slide.start_movers()
	var t := create_tween()
	if old:
		t.tween_property(slide, "modulate:a", 1.0, slide_fade_time)
		t.tween_callback(func(): old.visible = false)
	else:
		t.tween_interval(0.0)
	t.tween_callback(func(): _busy = false)

	if slide.sound:
		_sound_player.stream = slide.sound
		_sound_player.play()

	_show_text(slide)


func _show_text(slide: CutsceneSlide) -> void:
	_waiting_auto = 0.0
	_arrow.visible = false
	# The text waits until the slide's animations are done.
	if slide.is_waiting():
		_box.visible = false
		_name_tag.visible = false
		_waiting_anim = true
		slide.animations_done.connect(_on_animations_done.bind(slide), CONNECT_ONE_SHOT)
		return
	_waiting_anim = false
	if slide.text.strip_edges() == "":
		_box.visible = false
		_typing = false
		_text_done()
		return

	_box.visible = true
	_name_tag.text = slide.speaker
	_name_tag.visible = slide.speaker != ""
	_place_extras.call_deferred()
	_text.text = slide.text
	_text.visible_characters = 0
	_last_letters = 0
	_typing = true
	if _type_tween:
		_type_tween.kill()
	var letters := _text.get_total_character_count()
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_characters", letters,
		letters / max(letters_per_second, 1.0))
	_type_tween.tween_callback(_text_done)


## The slide's animations finished: now show its text (if it's still showing).
func _on_animations_done(slide: CutsceneSlide) -> void:
	if _finished or _slides[_index] != slide:
		return
	_waiting_anim = false
	_show_text(slide)


## Text finished typing (or the slide has no text).
func _text_done() -> void:
	_typing = false
	_text.visible_characters = -1  # show it all
	_arrow.visible = _box.visible
	var slide := _slides[_index]
	if slide.auto_advance_after > 0.0:
		_waiting_auto = slide.auto_advance_after


func _process(delta: float) -> void:
	if _slides.is_empty() or _finished:
		return
	# Letter sound while typing.
	if _typing and type_sound and _text.visible_characters >= _last_letters + 3:
		_last_letters = _text.visible_characters
		_type_player.pitch_scale = randf_range(0.95, 1.05)
		_type_player.play()
	# Blinking "continue" arrow.
	if _arrow.visible:
		_arrow.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
	# Auto-advance.
	if _waiting_auto > 0.0:
		_waiting_auto -= delta
		if _waiting_auto <= 0.0:
			_next()


## Click: finish the typing, or go on.
func _advance() -> void:
	if _busy or _waiting_anim:
		return
	if _typing:
		_type_tween.kill()
		_text_done()
	else:
		_next()


func _next() -> void:
	_waiting_auto = 0.0
	if _index + 1 < _slides.size():
		_show_slide(_index + 1)
	else:
		_end()


## Fade to black, then move on.
func _end() -> void:
	if _finished or _busy:
		return
	_busy = true
	_box.visible = false
	_skip_button.visible = false
	var t := create_tween()
	t.tween_property(_black, "modulate:a", 1.0, fade_time)
	t.tween_callback(_finish)


# ===== Input =====

func _input(event: InputEvent) -> void:
	if _finished:
		return
	var pressed := event.is_pressed() and not event.is_echo()
	if not pressed:
		return

	if _slides.is_empty():
		# Old way: any click or key skips.
		if can_skip and (event is InputEventMouseButton or event is InputEventKey):
			_finish()
		return

	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		if can_skip:
			_busy = false
			_end()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Clicks on the Skip button are the button's, not "next".
		if _skip_button.visible and _skip_button.get_global_rect().has_point(event.position):
			return
		_advance()
	elif event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_advance()


# ===== The dialogue box, skip button and black fade, made in code =====

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Dialogue box along the bottom, 80% of the screen wide.
	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.anchor_left = 0.1
	_box.anchor_right = 0.9
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_top = -190
	_box.offset_bottom = -30
	_box.add_theme_stylebox_override("panel", MinigameStyle.make_panel(
		Color(MinigameStyle.CARD_BG, 0.9), MinigameStyle.BAR_FRAME, 4, 20, 22))
	layer.add_child(_box)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_style_label(_text, text_size, MinigameStyle.TEXT_COLOR)
	_box.add_child(_text)

	# Speaker name tag, sitting on the top edge of the box.
	_name_tag = Label.new()
	_style_label(_name_tag, name_size, MinigameStyle.GOLD)
	_name_tag.add_theme_stylebox_override("normal", MinigameStyle.make_panel(
		MinigameStyle.CARD_BG_PICKED, MinigameStyle.GOLD, 3, 12, 8))
	layer.add_child(_name_tag)

	# Blinking arrow in the box's bottom-right corner: "click to continue".
	_arrow = Control.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.size = Vector2(24, 18)
	_arrow.draw.connect(func():
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(24, 0), Vector2(12, 16)])
		_arrow.draw_colored_polygon(pts, MinigameStyle.GOLD)
		_arrow.draw_polyline(pts + PackedVector2Array([pts[0]]), MinigameStyle.TEXT_OUTLINE, 2.0))
	layer.add_child(_arrow)
	_box.resized.connect(_place_extras)

	_skip_button = Button.new()
	_skip_button.text = "Skip"
	MinigameStyle.style_button(_skip_button, font, 22)
	_skip_button.anchor_left = 1.0
	_skip_button.anchor_right = 1.0
	_skip_button.offset_left = -130
	_skip_button.offset_right = -24
	_skip_button.offset_top = 24
	_skip_button.offset_bottom = 74
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.visible = can_skip
	_skip_button.pressed.connect(func():
		_busy = false
		_end())
	layer.add_child(_skip_button)

	layer.add_child(_black)  # last, so the fade covers everything

	_sound_player = AudioStreamPlayer.new()
	add_child(_sound_player)
	_type_player = AudioStreamPlayer.new()
	_type_player.stream = type_sound
	add_child(_type_player)


## Keeps the name tag on the box's top edge and the arrow in its corner.
func _place_extras() -> void:
	_name_tag.reset_size()
	_name_tag.position = _box.position + Vector2(28, -_name_tag.size.y + 6)
	_arrow.position = _box.position + _box.size - Vector2(44, 40)


func _style_label(label: Label, size: int, color: Color) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", MinigameStyle.TEXT_OUTLINE)
	label.add_theme_constant_override("outline_size", 8)


# ===== Testing / finishing =====

## For testing: prints which scene is showing and its text.
func _print_what_is_showing() -> void:
	var texts: Array[String] = []
	for slide in _slides:
		if slide.text != "":
			texts.append(("%s: " % slide.speaker if slide.speaker else "") + slide.text)
	if texts.is_empty():
		for label in find_children("*", "Label", true, false):
			texts.append((label as Label).text)
	print("Showing ", scene_file_path.get_file(), ": ", " | ".join(texts))  # for testing


## Only runs once, even if skipped and the animation also ends.
func _finish() -> void:
	if _finished:
		return
	_finished = true
	GameManager.cutscene_finished()
