extends CharacterBody2D


const SPEED = 120.0
const JUMP_VELOCITY = -300.0

@onready var animated_stripe = $AnimatedSprite2D
@onready var ray_cast_down: RayCast2D = $RayCast2D

func bounce(force: Vector2):
	velocity = force

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("move_left", "move_right")
		
	if direction:
		velocity.x = direction * SPEED
		if is_on_floor():
			animated_stripe.play("run")
		else:
			if velocity.y > 0:
				animated_stripe.play("run_jump")
			else:
				animated_stripe.play("run_fall")
		animated_stripe.flip_h = direction < 0
	elif not is_on_floor():
		pass
		# animated_stripe.play("jump")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		animated_stripe.play("idle")
		
	#if ray_cast_down.is_colliding():
		## Prepare for impact
		#animated_stripe.play("land")

	move_and_slide()
