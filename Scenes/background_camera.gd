extends Node2D

func _ready() -> void:
	var sc = $Background.texture.get_size()   # background size
	var vc = Vector2(get_viewport().size)     # window size
	$Camera2D.zoom = vc / sc                  # final camera zoom
