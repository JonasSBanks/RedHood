extends DropTarget
## The cauldron. Holds up to 4 ingredients and fills up as they go in, changing
## color depending on which potion it's heading toward:
##   good  (pink)   - still on track for the good potion
##   bad   (purple) - on track for the poison
##   green          - ruined, it can't become either
## When the 4th goes in, the boiling minigame opens (the kitchen cauldron hides
## while it's open; the minigame's cauldron bubbles once the fire is lit).
## When boiling is done, the day ends as GOOD, POISON or WRONG.
##
## Honey and Fruit (good or bad) can't be dropped in directly: they go through
## the squeeze spot above the cauldron, which calls add_ingredient().

## Sent every time something goes in.
signal ingredient_added(ingredient_name: String)
## Sent when the 4th ingredient goes in (right before boiling starts).
signal cauldron_full
## Sent when boiling is finished, with GameManager.Outcome GOOD, POISON or WRONG.
## Right after this, the cauldron ends the day through GameManager.end_day().
signal potion_brewed(outcome: int)

const MAX_INGREDIENTS := 4

## Recipes are written as slots: each inner list is one slot, and any ONE item
## from it fills that slot. Order doesn't matter.
## The good potion: exactly these four.
const GOOD_RECIPE := [
	["Butterfly Powder"],
	["Chopped Mushroom"],
	["Fruit"],
	["Honey"],
]
## The poison: Wolfsbane Powder plus the good or bad version of the other three
## (they can be mixed, e.g. Bad Honey with a good Chopped Mushroom).
const POISON_RECIPE := [
	["Wolfsbane Powder"],
	["Chopped Mushroom", "Chopped Bad Mushroom"],
	["Fruit", "Fermented Fruit"],
	["Honey", "Bad Honey"],
]

## These have to be squeezed first, so they can't be dropped in directly.
const SQUEEZE_ONLY := ["Honey", "Bad Honey", "Fruit", "Fermented Fruit"]

## Which picture set each potion uses (the color word in the file names).
## The "bad" files are pink and the "good" files are purple, so:
const COLOR_GOOD := "bad"      ## good potion  -> pink
const COLOR_POISON := "good"   ## poison       -> purple
const COLOR_RUINED := "green"  ## wrong potion -> green

## The boiling minigame scene. Drag boiling_minigame.tscn into this slot.
@export var minigame_scene: PackedScene

## Names of everything in the cauldron, in the order added.
var contents: Array[String] = []
var _minigame_open := false


func _ready() -> void:
	super()
	_update_picture()


func is_full() -> bool:
	return contents.size() >= MAX_INGREDIENTS


## Takes anything except Honey and Fruit, as long as there's room.
## Wrong items are allowed in: they turn the potion green.
func can_accept(data: Dictionary) -> bool:
	return not is_full() and not data["name"] in SQUEEZE_ONLY


func on_drop(data: Dictionary) -> void:
	add_ingredient(data["name"])


## Adds an ingredient. Used by drops here and by the squeeze spot.
## The 4th one starts the boiling minigame.
func add_ingredient(ingredient_name: String) -> void:
	if is_full():
		return
	contents.append(ingredient_name)
	_update_picture()
	print("Cauldron now has: ", contents, "  color: ", potion_color_name())  # for testing
	ingredient_added.emit(ingredient_name)
	if is_full():
		cauldron_full.emit()
		_open_minigame.call_deferred()  # wait for the drag to fully finish first


# ===== Recipes =====

## True if everything in the cauldron so far fits the recipe: each item
## fills a different slot. (The recipe doesn't have to be finished yet.)
func _fits(recipe: Array) -> bool:
	var used := []
	for item in contents:
		var slot := -1
		for i in recipe.size():
			if item in recipe[i] and not i in used:
				slot = i
				break
		if slot == -1:
			return false
		used.append(slot)
	return true


## True if the cauldron holds exactly that finished recipe.
func _matches(recipe: Array) -> bool:
	return contents.size() == recipe.size() and _fits(recipe)


## Which way the potion is heading: COLOR_GOOD, COLOR_POISON or COLOR_RUINED.
## If it could still be either (e.g. only Honey so far), it shows good.
func potion_color() -> String:
	if _fits(GOOD_RECIPE):
		return COLOR_GOOD
	if _fits(POISON_RECIPE):
		return COLOR_POISON
	return COLOR_RUINED


## The color as a readable word, for the test prints.
func potion_color_name() -> String:
	match potion_color():
		COLOR_GOOD:
			return "pink (good potion)"
		COLOR_POISON:
			return "purple (poison)"
	return "green (wrong)"


## The finished potion's outcome: GOOD, POISON or WRONG.
func potion_outcome() -> int:
	if _matches(GOOD_RECIPE):
		return GameManager.Outcome.GOOD
	if _matches(POISON_RECIPE):
		return GameManager.Outcome.POISON
	return GameManager.Outcome.WRONG


# ===== Pictures =====

## Shows the right picture for how full the cauldron is and its color:
##   0 items -> cauldron_empty_final
##   1 item  -> cauldron_stage_1_<color>_final
##   2 items -> cauldron_stage_2_<color>_final
##   3-4     -> cauldron_stage_2_<color>_final  (stage 3 only appears in the
##              boiling minigame, bubbling once the fire is lit)
func _update_picture() -> void:
	var count := contents.size()
	var color := potion_color()
	var file_name := ""
	match count:
		0:
			file_name = "cauldron_empty_final"
		1:
			file_name = "cauldron_stage_1_%s_final" % color
		_:
			file_name = "cauldron_stage_2_%s_final" % color

	var picture := Ingredient.load_sprite(file_name)
	if picture:
		texture = picture
	else:
		print("Missing cauldron picture: ", file_name)  # for testing


## The 4 bubbling frames for a color. Handed to the boiling minigame.
func get_bubble_frames(color: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for i in range(1, 5):
		var picture := Ingredient.load_sprite("cauldron_stage_3_%s_frame_%d_final" % [color, i])
		if picture:
			frames.append(picture)
	return frames



# ===== Boiling =====

## Creates the boiling minigame on its own CanvasLayer, above the kitchen UI.
## The minigame's cauldron uses the same color, and the kitchen cauldron hides
## so it doesn't show through the minigame's see-through background.
func _open_minigame() -> void:
	if minigame_scene == null:
		push_error("Cauldron: drag boiling_minigame.tscn into Minigame Scene in the Inspector.")
		return
	_minigame_open = true
	visible = false

	var layer := CanvasLayer.new()
	layer.layer = 10  # higher than the kitchen's UI layer, so it covers it

	var minigame := minigame_scene.instantiate()
	minigame.cauldron_frames = get_bubble_frames(potion_color())
	minigame.cauldron_still = texture  # the stage 2 picture, shown until the fire is lit
	minigame.finished.connect(_on_minigame_finished.bind(layer))

	layer.add_child(minigame)
	get_tree().current_scene.add_child(layer)


## Boiling is done: close the minigame, work out the potion, report it, and
## end the day with that outcome.
func _on_minigame_finished(layer: CanvasLayer) -> void:
	layer.queue_free()
	_minigame_open = false
	visible = true
	var outcome := potion_outcome()
	print("Potion finished! Result: ", GameManager.Outcome.keys()[outcome])  # for testing
	potion_brewed.emit(outcome)
	GameManager.end_day(outcome)


## Empties the cauldron, e.g. when a new day starts.
func empty() -> void:
	contents.clear()
	_update_picture()
