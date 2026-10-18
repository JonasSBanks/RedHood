class_name MinigameStyle
extends RefCounted
## The shared look for the minigames (progress bar, hint text) and the selection
## screen (cards, buttons), so everything matches. Not attached to any node:
## the other scripts call
## these functions themselves.
##
##   MinigameStyle.style_bar(bar, color)    rounded, framed bar in that color
##   MinigameStyle.tick_bar(bar, color)     call every frame: glows when nearly full
##   MinigameStyle.style_hint(label, ...)   big outlined text on a dark banner
##   MinigameStyle.place_top_center(label, top)  keeps it centered at the top
##   MinigameStyle.set_hint(label, text)    changes the text with a little pop
##   MinigameStyle.set_banner_color(label, color)  recolors the banner
##   MinigameStyle.make_panel(...)          a rounded box with a border
##   MinigameStyle.style_button(button)     dark framed button, gold on hover
##   MinigameStyle.bounce(control, scale)   quick springy scale change
##
## To change the look of all minigames at once, change the colors below.

## The bar's empty background and frame.
const BAR_BACK := Color(0.16, 0.10, 0.07, 0.9)
const BAR_FRAME := Color(0.93, 0.80, 0.55)
## The hint text and its outline.
const TEXT_COLOR := Color(1.0, 0.95, 0.82)
const TEXT_OUTLINE := Color(0.18, 0.10, 0.06)
## The banner behind the hint text.
const BANNER_COLOR := Color(0.12, 0.07, 0.05, 0.75)
## Where the texts sit, in pixels from the top of the screen. The minigame
## hints use HINT_TOP; the kitchen timer warnings sit lower, at WARNING_TOP,
## so the two never overlap. (Each script also has its own slot to override.)
const HINT_TOP := 24.0
const WARNING_TOP := 120.0
## How full the bar has to be (0-1) before it starts to glow.
const GLOW_FROM := 0.8


## Gives a ProgressBar a rounded frame and a colored fill, and hides the "%".
static func style_bar(bar: ProgressBar, fill_color: Color, height: float = 30.0) -> void:
	bar.show_percentage = false
	bar.custom_minimum_size.y = max(bar.custom_minimum_size.y, height)
	var radius := int(height / 2.0)

	var back := StyleBoxFlat.new()
	back.bg_color = BAR_BACK
	back.border_color = BAR_FRAME
	back.set_border_width_all(4)
	back.set_corner_radius_all(radius)
	back.shadow_color = Color(0, 0, 0, 0.35)
	back.shadow_size = 4
	back.shadow_offset = Vector2(0, 3)
	bar.add_theme_stylebox_override("background", back)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.border_color = BAR_FRAME
	fill.set_border_width_all(4)
	fill.set_corner_radius_all(radius)
	bar.add_theme_stylebox_override("fill", fill)


## Call every frame. Once the bar is nearly full, the fill pulses brighter,
## so the player can feel they're almost done.
static func tick_bar(bar: ProgressBar, fill_color: Color) -> void:
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if not fill:
		return
	var ratio := 0.0
	if bar.max_value > bar.min_value:
		ratio = (bar.value - bar.min_value) / (bar.max_value - bar.min_value)
	if ratio < GLOW_FROM:
		fill.bg_color = fill_color
		return
	var pulse := (sin(Time.get_ticks_msec() / 90.0) + 1.0) / 2.0  # 0..1, fast
	fill.bg_color = fill_color.lerp(Color.WHITE, 0.15 + 0.3 * pulse)


## Big, outlined, centered text on a soft dark banner.
## font: leave null to keep the project's default font.
static func style_hint(label: Label, font: Font = null, font_size: int = 34) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 4)

	var banner := StyleBoxFlat.new()
	banner.bg_color = BANNER_COLOR
	banner.set_corner_radius_all(18)
	banner.content_margin_left = 28
	banner.content_margin_right = 28
	banner.content_margin_top = 10
	banner.content_margin_bottom = 12
	label.add_theme_stylebox_override("normal", banner)


## Keeps a label centered horizontally, `top` pixels from the top of the screen.
## If the label is inside a container (VBox etc.), it's moved out to the
## scene's root first, because containers would keep repositioning it.
static func place_top_center(label: Label, top: float) -> void:
	var parent := label.get_parent()
	if parent is Container:
		var root: Node = label.owner if label.owner else parent.get_parent()
		parent.remove_child(label)
		root.add_child(label)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF  # one line, sized to the text
	label.clip_text = false
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.position.y = top
	label.set_meta("top_center", true)
	# Re-center whenever the text makes the label wider or narrower.
	label.resized.connect(func(): _center_x(label))
	label.reset_size()
	_center_x(label)


## Puts the label in the middle of the screen (or its parent) horizontally.
static func _center_x(label: Label) -> void:
	var width := label.get_parent_area_size().x
	label.position.x = (width - label.size.x) / 2.0
	label.pivot_offset = label.size / 2.0


## Changes the banner color behind a styled label (e.g. red for urgent).
static func set_banner_color(label: Label, color: Color) -> void:
	var banner := label.get_theme_stylebox("normal") as StyleBoxFlat
	if banner:
		banner.bg_color = color


## Changes the hint text with a small pop. Does nothing if the text is the same,
## so it's safe to call every frame.
static func set_hint(label: Label, text: String) -> void:
	if label.text == text:
		return
	label.text = text
	if label.has_meta("top_center"):
		label.reset_size()  # shrink/grow to the new text; resized re-centers it
		_center_x(label)
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(1.12, 1.12)
	var t := label.create_tween()
	t.tween_property(label, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ===== Panels and buttons (used by the selection screen) =====

## Highlight color for selected / hovered things.
const GOLD := Color(1.0, 0.82, 0.35)
## Card / button / panel backgrounds (normal and picked).
const CARD_BG := Color(0.12, 0.07, 0.05, 0.75)
const CARD_BG_PICKED := Color(0.30, 0.18, 0.08, 0.9)


## A rounded box with a border. Used for cards and buttons.
static func make_panel(bg: Color, border: Color, border_width: int = 3,
		radius: int = 16, padding: float = 12.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box


## Gives a Button the game's look: dark rounded box with a cream frame, gold
## on hover, a little bounce when the mouse goes over it, faded when disabled.
static func style_button(button: Button, font: Font = null, font_size: int = 30) -> void:
	# Same boxes as the ingredient cards, so they match.
	button.add_theme_stylebox_override("normal", make_panel(CARD_BG, BAR_FRAME, 3, 16, 18))
	button.add_theme_stylebox_override("hover", make_panel(CARD_BG, GOLD, 3, 16, 18))
	button.add_theme_stylebox_override("pressed", make_panel(CARD_BG_PICKED, GOLD, 6, 16, 18))
	button.add_theme_stylebox_override("disabled", make_panel(Color(CARD_BG, 0.4), Color(BAR_FRAME, 0.4), 3, 16, 18))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if font:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color(TEXT_COLOR, 0.4))
	button.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	button.add_theme_constant_override("outline_size", 8)
	button.mouse_entered.connect(func(): bounce(button, 1.06))
	button.mouse_exited.connect(func(): bounce(button, 1.0))


## Tweens a control's scale to `to`, from its center.
static func bounce(control: Control, to: float) -> void:
	if control is BaseButton and control.disabled:
		to = 1.0
	control.pivot_offset = control.size / 2.0
	var t := control.create_tween()
	t.tween_property(control, "scale", Vector2(to, to), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
