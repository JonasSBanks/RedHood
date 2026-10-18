extends TextureButton
class_name Ingredient
## One draggable ingredient button on the shelf. You never place these by
## hand: item_list.gd creates one for each name in selected_ingredients.

## Where all the sprite pictures live.
const TEXTURE_FOLDER := "res://Brewing Stations Sprites/"

## Every ingredient name -> its picture file (no folder, no .png).
## The names on the left are the exact names used in GameManager.pocket and
## everywhere else. To add an ingredient, add a line here.
const TEXTURES := {
	# Raw ingredients (what's in the pocket)
	"Butterfly": "butterfly_good_final",
	"Bad Butterfly": "butterfly_bad_final",
	"Mushroom": "mushroom_good_final",
	"Bad Mushroom": "mushroom_bad_final",
	"Honey": "honey_good_final",
	"Bad Honey": "honey_bad_final",
	"Fruit": "plum_final",
	"Fermented Fruit": "plum_fermented_final",
	"Wolfs Bane": "wolfsbane_final",
	# After the cutting board
	"Chopped Mushroom": "mushroom_chopped_good_final",
	"Chopped Bad Mushroom": "mushroom_chopped_bad_final",
	# After the mortar
	"Butterfly Powder": "powder_butterfly_good_final",
	"Bad Butterfly Powder": "powder_butterfly_bad_final",
	"Wolfsbane Powder": "powder_wolfsbane_final",
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


## Finds the picture for an ingredient by name. If there isn't one, returns
## a plain colored square so it's still visible (and prints which is missing).
## Static so other scripts can use it too.
static func get_texture(item_name: String) -> Texture2D:
	var picture := load_sprite(TEXTURES.get(item_name, ""))
	if picture:
		return picture
	print("No picture for ingredient: ", item_name)  # for testing
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(FALLBACK_COLOR)
	return ImageTexture.create_from_image(image)


## Loads a picture from the sprites folder by file name (no folder, no .png),
## or returns null if it doesn't exist. Used by the mortar and squeeze spot too.
static func load_sprite(file_name: String) -> Texture2D:
	var path := TEXTURE_FOLDER + file_name + ".png"
	if file_name != "" and ResourceLoader.exists(path):
		return load(path)
	return null


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
