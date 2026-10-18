extends Node

# This dictionary stores your state in RAM while the game runs
var pocket = {
	"Wolfs Bane": 1,
	"Butterfly": 1,
	"Bad Butterfly": 1,
	"Honey": 1,
	"Bad Honey": 1,
	"Mushroom": 1,
	"Bad Mushroom": 1,
	"Fruit": 1,
	"Fermented Fruit": 1,
}

# Tracks the keys of the ingredients the player has selected
var selected_ingredients: Array[String] = []

var current_recipe = {
	"Wolfs Bane": 0,
	"Butterfly": 0,
	"Honey": 0,
	"Mushroom": 1,
	"Fruit": 0
}


## ===== TESTING =====

## TEMP: while there's no foraging yet, every new day refills the pocket with
## TEST_POCKET so you can keep testing. Set to false once foraging exists.
const USE_TEST_REFILL := true
const TEST_POCKET := {
	"Wolfs Bane": 1,
	"Butterfly": 1,
	"Bad Butterfly": 1,
	"Honey": 1,
	"Bad Honey": 1,
	"Mushroom": 1,
	"Bad Mushroom": 1,
	"Fruit": 1,
	"Fermented Fruit": 1,
}

## TEMP: test shortcuts. Set to false before releasing the game.
## They only work outside cutscenes and hints.
##   Ctrl + 1-6   end the day: 1 Good  2 Wrong  3 Time up  4 Snatched  5 Caught  6 Poison
##   Alt + 1-9    jump to that day (starts it fresh)
##   Ctrl + P     switch "page 2 read" on/off
##   Ctrl + I     print the current state to the Output
## Also shows a small label in the top-left corner with the day and page 2.
const DEBUG_KEYS := true

var _debug_label: Label


## ===== DAY SYSTEM =====

## Every way a day can end.
enum Outcome {
	GOOD,      ## correct potion: day goes up by 1
	WRONG,     ## wrong potion: day restarts
	TIME_UP,   ## time ran out, Grandma came back for the book: day restarts
	SNATCHED,  ## flipped the book while Grandma was in the room: day restarts
	CAUGHT,    ## cooked with Wolfs Bane while Grandma was in the room: day restarts
	POISON,    ## poison potion: ending, then credits
}

## Which cutscene plays for each ending.
const CUTSCENES := {
	Outcome.GOOD: "res://Scenes/cutscene_good.tscn",
	Outcome.WRONG: "res://Scenes/cutscene_wrong.tscn",
	Outcome.TIME_UP: "res://Scenes/cutscene_wolf.tscn",
	Outcome.SNATCHED: "res://Scenes/cutscene_snatched.tscn",
	Outcome.CAUGHT: "res://Scenes/cutscene_caught.tscn",
	Outcome.POISON: "res://Scenes/cutscene_ending.tscn",
}

## The hint scene for each day. Plays after that day's cutscene.
## Days without an entry (5 and later) have no hint.
const HINT_SCENES := {
	1: "res://Scenes/hint_1.tscn",
	2: "res://Scenes/hint_2.tscn",
	3: "res://Scenes/hint_3.tscn",
	4: "res://Scenes/hint_4.tscn",
}
## Which endings are followed by a hint scene.
const OUTCOMES_WITH_HINTS := [Outcome.GOOD, Outcome.WRONG]

## The first scene of every day (new or restarted).
## TEMP: using the selection page until the real day-start scene exists.
const DAY_START_SCENE := "res://Scenes/Selection.tscn"
## Plays after the ending cutscene.
const CREDITS_SCENE := "res://Scenes/credits.tscn"

## The current day. Starts at 1. Only a good potion makes it go up.
var day: int = 1

## True once the player has read page 2 of the recipe book (set by the book
## in step 9). Never resets, so it carries across days and restarts.
## Your partner's foraging uses this (with `day`) to decide when Wolfs Bane
## can be found.
var has_read_page_2: bool = false

## True while Grandma is in the kitchen. Kept up to date by grandma.gd;
## the book and the Wolfs Bane check read it.
var grandma_in_room: bool = false

## Seconds left on the kitchen clock (0 outside the kitchen). Set by kitchen_timer.gd.
var kitchen_time_left: float = 0.0


## ===== DAY RULES =====

## The rules every day uses, unless DAY_RULES changes some of them.
## All times are in seconds.
const DEFAULT_RULES := {
	"time_limit": 120.0,          ## how long the player has in the kitchen
	"grandma_always_in": false,   ## true = she never leaves the room
	"grandma_away_time": 20.0,    ## how long she's out of the room each time
	"grandma_in_time": 10.0,      ## how long she stays in the room each time
	"footsteps_warning": 3.0,     ## how long before she enters the footsteps cue plays
}

## Per-day changes. Only list what's different from DEFAULT_RULES.
## Days not listed (including 5 and later) use DEFAULT_RULES as they are.
const DAY_RULES := {
	1: {"grandma_always_in": true},
	# Examples of what you could change later:
	# 3: {"grandma_away_time": 30.0},
	# 4: {"grandma_away_time": 40.0, "time_limit": 150.0},
}


## The rules for the current day: DEFAULT_RULES with that day's changes applied.
## Use it anywhere, e.g. GameManager.today_rules()["time_limit"]
func today_rules() -> Dictionary:
	var rules: Dictionary = DEFAULT_RULES.duplicate()
	rules.merge(DAY_RULES.get(day, {}), true)
	return rules

var _last_outcome: Outcome = Outcome.GOOD
var _day_played: int = 1       # the day that just ended (for picking its hint)
var _showing_hint := false     # true while a hint scene is playing
var _in_cutscene := false      # true from the end of a day until the next day starts


## Call this when Start Cooking is pressed, before switching to the kitchen.
## Takes one of each selected ingredient out of the pocket, so it's used up.
func take_selected_from_pocket() -> void:
	for item_name in selected_ingredients:
		var count: int = pocket.get(item_name, 0)
		pocket[item_name] = max(count - 1, 0)
	print("Pocket after selecting: ", pocket)  # for testing


## Call this whenever the day ends, from anywhere:
##   GameManager.end_day(GameManager.Outcome.SNATCHED)
## Updates the day counter, then plays the matching cutscene.
func end_day(outcome: Outcome) -> void:
	# Only the first end of the day counts (e.g. time running out in the same
	# moment the potion finishes).
	if _in_cutscene:
		print("Ignored a second end of day: ", Outcome.keys()[outcome])  # for testing
		return
	_last_outcome = outcome
	_day_played = day
	_showing_hint = false
	_in_cutscene = true
	if outcome == Outcome.GOOD:
		day += 1
	print("Day ", _day_played, " ended: ", Outcome.keys()[outcome], ". Next day: ", day)  # for testing
	get_tree().change_scene_to_file(CUTSCENES[outcome])


## Every cutscene and hint scene calls this when it finishes (cutscene.gd
## does it for you). Decides what comes next:
##   ending cutscene        -> credits
##   good/wrong cutscene    -> that day's hint scene (if it has one)
##   hint, or anything else -> start the day
func cutscene_finished() -> void:
	if _last_outcome == Outcome.POISON:
		get_tree().change_scene_to_file(CREDITS_SCENE)
		return

	var wants_hint: bool = _last_outcome in OUTCOMES_WITH_HINTS and HINT_SCENES.has(_day_played)
	if wants_hint and not _showing_hint:
		_showing_hint = true
		print("Showing hint for day ", _day_played)  # for testing
		get_tree().change_scene_to_file(HINT_SCENES[_day_played])
		return

	_showing_hint = false
	start_day()


## Starts a day (new or restarted). Ingredients brought into the kitchen
## yesterday are gone. (The stash will hook in here in steps 12-13.)
func start_day() -> void:
	_in_cutscene = false
	selected_ingredients.clear()
	if USE_TEST_REFILL:
		pocket = TEST_POCKET.duplicate()
	print("Starting day ", day, " with rules: ", today_rules())  # for testing
	get_tree().change_scene_to_file(DAY_START_SCENE)


## ===== TEST SHORTCUTS (see DEBUG_KEYS) =====

func _ready() -> void:
	if DEBUG_KEYS:
		# A small label in the top-left corner, drawn above everything.
		var layer := CanvasLayer.new()
		layer.layer = 100
		_debug_label = Label.new()
		_debug_label.position = Vector2(8, 4)
		_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_debug_label.add_theme_constant_override("outline_size", 4)
		layer.add_child(_debug_label)
		add_child(layer)


func _process(_delta: float) -> void:
	if _debug_label:
		_debug_label.text = "Day %d  |  Page 2 read: %s  |  Grandma: %s  |  Time: %s" % [
			day,
			"yes" if has_read_page_2 else "no",
			"IN THE ROOM" if grandma_in_room else "out",
			"%ds" % ceili(kitchen_time_left) if kitchen_time_left > 0.0 else "-",
		]


func _unhandled_input(event: InputEvent) -> void:
	if not DEBUG_KEYS or _in_cutscene:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var number: int = event.keycode - KEY_0   # the number key pressed, 0-9

	# Ctrl + 1-6: end the day with that outcome
	if event.ctrl_pressed and number >= 1 and number <= Outcome.size():
		end_day(Outcome.values()[number - 1])

	# Alt + 1-9: jump to that day
	elif event.alt_pressed and number >= 1 and number <= 9:
		day = number
		print("TEST: jumped to day ", day)
		start_day()

	# Ctrl + P: switch page 2 read on/off
	elif event.ctrl_pressed and event.keycode == KEY_P:
		has_read_page_2 = not has_read_page_2
		print("TEST: page 2 read = ", has_read_page_2)

	# Ctrl + I: print the current state
	elif event.ctrl_pressed and event.keycode == KEY_I:
		print("TEST STATE  day: ", day, "  page 2 read: ", has_read_page_2,
			"\n  pocket: ", pocket, "\n  selected: ", selected_ingredients)
