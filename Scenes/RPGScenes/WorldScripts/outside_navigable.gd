extends Node2D
## The forest outside the house: the first scene of every day.
## Shows a small "Basket" panel in the corner listing what has been foraged
## so far, plus a reminder of what to do. Walk into the front door to go in.

const GOAL_TEXT := "Forage ingredients (E), then head inside to the kitchen."

var _basket_label: Label


func _ready() -> void:
	_build_hud()
	GameManager.pocket_changed.connect(_refresh)
	_refresh()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(24, 60)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.05, 0.03, 0.75)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", box)
	layer.add_child(panel)

	_basket_label = Label.new()
	_basket_label.add_theme_font_size_override("font_size", 28)
	_basket_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	panel.add_child(_basket_label)


func _refresh() -> void:
	var lines: Array[String] = ["Day %d" % GameManager.day, GOAL_TEXT, "", "Basket:"]
	var any := false
	for item_name in GameManager.pocket:
		var count: int = GameManager.pocket[item_name]
		if count > 0:
			any = true
			lines.append("  • %s%s" % [item_name, " x%d" % count if count > 1 else ""])
	if not any:
		lines.append("  (empty)")
	_basket_label.text = "\n".join(lines)
