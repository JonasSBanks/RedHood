extends CharacterBody2D

<<<<<<< Updated upstream

var max_speed = 200

var last_direction := Vector2(1,0)

var is_interactable = false

#movement instructions
func _physics_process(delta) :
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * max_speed
	move_and_slide()
	
	if direction.length() > 0 :
		last_direction = direction
		play_walk_animation(last_direction)
	else :
		$PhysicalCollision/PlayerAnimation.stop()
		

func play_walk_animation(direction) :
	if direction.x > 0 :
		$PhysicalCollision/PlayerAnimation.play("rightWalk")
	elif direction.x < 0 :
		$PhysicalCollision/PlayerAnimation.play("leftWalk")
	elif direction.y > 0 :
		$PhysicalCollision/PlayerAnimation.play("downWalk")
	elif direction.y < 0 :
		$PhysicalCollision/PlayerAnimation.play("upWalk")
		

func upscale() :
	scale = Vector2(2.0,2.0)
	
func changeSpeed(new_speed) :
	max_speed = new_speed
=======
var max_speed = 200

func _physics_process(delta) :
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down") 
	velocity = direction * max_speed
	move_and_slide()
	
	
>>>>>>> Stashed changes
