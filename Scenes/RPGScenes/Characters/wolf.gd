extends CharacterBody2D


<<<<<<< Updated upstream
var max_speed = 100

var last_direction := Vector2(1,0)

##func _physics_process(delta) :
	##var direction
	##velocity = direction * max_speed
	##move_and_slide()
	
	##if direction.length() > 0 :
		##last_direction = direction
		##play_walk_animation(last_direction)
		##_wobble()
		

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$CollisionShape2D/GrandmaSprites.play("grandmaDown")
=======
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
>>>>>>> Stashed changes
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
<<<<<<< Updated upstream

func play_walk_animation(direction) :
	if direction.x > 0 :
		$CollisionShape2D/GrandmaSprites.play("grandmaRight")
	elif direction.x < 0 :
		$CollisionShape2D/GrandmaSprites.play("grandmaLeft")
	elif direction.y > 0 :
		$CollisionShape2D/GrandmaSprites.play("grandmaDown")
	elif direction.y < 0 :
		$CollisionShape2D/GrandmaSprites.play("grandmaUp")

func upscale() :
	scale = Vector2(2.0, 2.0)
=======
>>>>>>> Stashed changes
