extends Area2D

@export_file("*.tscn") var target_scene : String
@export var spawn_point_name : String = "DefaultSpawn"

func _ready() -> void :
	connect("body_entered", _on_body_entered)
	

func _process(delta: float) -> void :
	pass


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Red") :
		if target_scene:
			get_tree().change_scene_to_file(target_scene)
