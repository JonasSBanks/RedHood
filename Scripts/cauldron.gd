extends DropTarget
## The cauldron. Holds up to 4 ingredients. When the 4th goes in, the boiling
## minigame opens on top of the kitchen. When boiling is done, it checks the
## recipe and reports whether the potion is good or ineffective.
##
## Honey and Fruit can't be dropped in directly: they go through the squeeze
## spot above the cauldron, which calls add_ingredient().

## Sent every time something goes in.
signal ingredient_added(ingredient_name: String)
## Sent when the 4th ingredient goes in (right before boiling starts).
signal cauldron_full
## Sent when boiling is finished. good = true if it's the correct potion.
## Right after this, the cauldron ends the day through GameManager.end_day().
signal potion_brewed(good: bool)

const MAX_INGREDIENTS := 4

## The correct potion: exactly these four, in any order.
const GOOD_RECIPE := ["Butterfly Powder", "Chopped Mushroom", "Fruit", "Honey"]

## These have to be squeezed first, so they can't be dropped in directly.
const SQUEEZE_ONLY := ["Honey", "Fruit"]

## The boiling minigame scene. Drag boiling_minigame.tscn into this slot.
@export var minigame_scene: PackedScene

## Names of everything in the cauldron, in the order added.
var contents: Array[String] = []
var _minigame_open := false


func is_full() -> bool:
	return contents.size() >= MAX_INGREDIENTS


## Takes anything except Honey and Fruit, as long as there's room.
## Wrong items are allowed in: they just make an ineffective potion.
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
	print("Cauldron now has: ", contents)  # for testing, remove later
	ingredient_added.emit(ingredient_name)
	if is_full():
		cauldron_full.emit()
		_open_minigame.call_deferred()  # wait for the drag to fully finish first


## Creates the boiling minigame on its own CanvasLayer, above the kitchen UI.
func _open_minigame() -> void:
	if minigame_scene == null:
		push_error("Cauldron: drag boiling_minigame.tscn into Minigame Scene in the Inspector.")
		return
	_minigame_open = true

	var layer := CanvasLayer.new()
	layer.layer = 10  # higher than the kitchen's UI layer, so it covers it

	var minigame := minigame_scene.instantiate()
	minigame.finished.connect(_on_minigame_finished.bind(layer))

	layer.add_child(minigame)
	get_tree().current_scene.add_child(layer)


## Boiling is done: close the minigame, check the recipe, report it, and
## end the day with the matching outcome.
func _on_minigame_finished(layer: CanvasLayer) -> void:
	layer.queue_free()
	_minigame_open = false
	var good := is_good_potion()
	print("Potion finished! Good potion: ", good)  # for testing, remove later
	potion_brewed.emit(good)
	GameManager.end_day(GameManager.Outcome.GOOD if good else GameManager.Outcome.WRONG)


## True if the 4 ingredients are exactly the good recipe (order doesn't matter).
func is_good_potion() -> bool:
	var have: Array = []
	have.assign(contents)
	var need: Array = GOOD_RECIPE.duplicate()
	have.sort()
	need.sort()
	return have == need


## Empties the cauldron, e.g. when a new day starts.
func empty() -> void:
	contents.clear()
