extends CharacterBody2D


const SPEED = 100.0
const JUMP_VELOCITY = -300.0
const MAX_JUMP_LEVEL = 2

@onready var animated_stripe = $AnimatedSprite2D
@onready var ray_cast_down: RayCast2D = $RayCast2D
@onready var coyote_timer: Timer = $CoyoteTimer

var jump_level = 0

func bounce(force: Vector2):
	velocity = force
	
func _draw():
	if velocity.length() > 0:
		draw_line(Vector2.ZERO, velocity.normalized() * 50, Color.RED, 2)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump"):
		if is_on_floor() || !coyote_timer.is_stopped():
			velocity.y = JUMP_VELOCITY
			jump_level = 1
		#elif (jump_level < MAX_JUMP_LEVEL):
			#velocity.y = JUMP_VELOCITY
			#jump_level += 1

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
		# Flip sprite depending on direction
		animated_stripe.flip_h = direction < 0
	elif not is_on_floor():
		pass
		# normal jump animation (bouncy feeling)
		# animated_stripe.play("jump")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		animated_stripe.play("idle")
		
	#if ray_cast_down.is_colliding():
		## Prepare for impact
		#animated_stripe.play("land")

	var was_on_floor = is_on_floor() 
	# This updates collision and floor detection (to use methods like is_on_floor, etc)
	move_and_slide()
	
	if was_on_floor && not is_on_floor():
		coyote_timer.start()
	
	#queue_redraw()
