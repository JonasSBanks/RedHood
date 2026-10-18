extends TextureButton
class_name Ingredient
## One draggable ingredient button on the shelf. You never place these by
## hand: item_list.gd creates one for each name in selected_ingredients.

## Where ingredient pictures live, and the ending on each file name.
## The ingredient name is turned into lowercase with underscores, so:
##   "Mushroom"   -> res://Brewing Stations Sprites/mushroom_v1.png
##   "Wolfs Bane" -> res://Brewing Stations Sprites/wolfs_bane_v1.png
const TEXTURE_FOLDER := "res://Brewing Stations Sprites/"
const TEXTURE_SUFFIX := "_v1"

## Pictures that don't follow the naming rule above. Name -> file name
## (no folder, no .png). These are checked first.
const TEXTURE_OVERRIDES := {
	"Wolfsbane Powder": "powder_wolfsbane_final",
	"Butterfly Powder": "powder_butterfly_good_final",
}
## Color of the plain square shown when an ingredient has no picture yet.
const FALLBACK_COLOR := Color(0.85, 0.3, 0.6)

var ingredient_name: String = ""
var _dragging := false  # true only on the button that started the current drag


## Called by item_list.gd right after creating the button.
func setup(item_name: String, button_size: Vector2) -> void:
	ingredient_name = item_name
	texture_normal = Ingredient.get_texture(item_name)
	custom_minimum_size = button_size
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED


## Godot calls this when the player clicks and starts moving the mouse.
## Returns the "package" that stations receive.
func _get_drag_data(_at_position: Vector2) -> Variant:
	_dragging = true
	set_drag_preview(Ingredient.make_preview(texture_normal, size))
	modulate.a = 0.4  # dim while "in hand"
	return {
		"type": "ingredient",
		"name": ingredient_name,
		"from": "shelf",
		"chopped": false,
	}


## Godot sends DRAG_END to every node when any drag finishes.
## Only the dragged button reacts: if a station took it, tell the shelf to
## remove it; if not, just un-dim (it snaps back).
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not _dragging:
		return
	_dragging = false
	modulate.a = 1.0
	if get_viewport().gui_is_drag_successful():
		get_parent().use_item(ingredient_name)


## Finds the picture for an ingredient by name. If there isn't one yet,
## returns a plain colored square so the button is still visible.
## Static so other scripts can use it too.
static func get_texture(item_name: String) -> Texture2D:
	var file_name: String = item_name.to_lower().replace(" ", "_") + TEXTURE_SUFFIX
	if TEXTURE_OVERRIDES.has(item_name):
		file_name = TEXTURE_OVERRIDES[item_name]
	var path := TEXTURE_FOLDER + file_name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(FALLBACK_COLOR)
	return ImageTexture.create_from_image(image)


## Builds the see-through picture that follows the mouse, centered on the cursor.
static func make_preview(texture: Texture2D, preview_size: Vector2) -> Control:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size = preview_size
	picture.position = -preview_size / 2.0
	picture.modulate.a = 0.8
	var holder := Control.new()  # wrapper so the offset above centers it
	holder.add_child(picture)
	return holder
