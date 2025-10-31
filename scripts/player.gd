extends CharacterBody2D

@onready var animated_stripe = $AnimatedSprite2D
@onready var ray_cast_down: RayCast2D = $RayCast2D
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var camera: Camera2D = $Camera2D

@export_range(0, 1) var acceleration = 0.1
@export_range(0, 1) var deceleration = 0.1
@export_range(0, 1) var decelerate_on_jump_release = 0.5

enum {
	SLEEP,
	IDLE,
	RUN,
	JUMP,
	FALL,
	SNEAK,
	WALL_SLIDE,
	WALL_CLIMB
}

const SPEED = 100.0
const MAX_FALL_SPEED = 600.0
const JUMP_VELOCITY = -320.0
const WALL_JUMP_VELOCITY = -250.0
const FALL_GRAVITY = 1000
const SNEAK_SPEED: float = 60.0
const JUMP_BUFFER_TIME: float = 0.1

const WALL_CLIMB_SPEED: float = 80.0
const WALL_SLIDE_SPEED: float = 60
const WALL_GRAVITY: float = 200.0
const WALL_JUMP_PUSH_FORCE: float = 120.0

var is_sneaking = false
var just_landed = false # Used to play the land animation

# Looking right by default
var look_dir_x: int = 1

# This is so the player has a little more time after leaving a wall to still perform a wall jump
# The amount of time we still consider the player on the wall
var wall_contact_coyote: float = 0.0
# The amount of time we provide to wall_contact_coyote
const WALL_CONTACT_COYOTE_TIME: float = 0.2

# This is to to allow the push force from the wall to work
# The amount of time left that we still limit the horizontal movement
var wall_jump_lock: float = 0.0
# Wall jump & slide
const WALL_JUMP_LOCK_TIME: float = 0.05

# Charge jump
var is_charge_jumping = false
var jump_held_time: float
var last_direction: float

var is_sleeping: bool = true
var has_woken_up: bool = false
var is_wall_slide: bool = false
var is_wall_climbing: bool = false

func bounce(force: Vector2):
	velocity = force
	
func _draw():
	if velocity.length() > 0:
		# Draw the direction of the velocity of the player for debug purposes
		draw_line(Vector2.ZERO, velocity.normalized() * 50, Color.RED, 2)

func start_charge_jump():
	print("start_charge_jump")
	# Charge jump logic with directions, we can jump up, right or left
	last_direction = 0
	if Input.is_action_just_pressed("move_right") or Input.is_action_pressed("move_right"):
		last_direction = 1
	if Input.is_action_just_pressed("move_left") or Input.is_action_pressed("move_left"):
		last_direction = -1
	
	velocity.y = JUMP_VELOCITY * jump_held_time
	velocity.x = last_direction * (SPEED / 100)
	
	jump_held_time = 0
	is_charge_jumping = false

func _ready():
	animated_stripe.play("sleep")

func _physics_process(delta: float) -> void:
	#if velocity.y < -100:  # Jumping up fast
		#camera.offset.y = lerp(camera.offset.y, -50.0, delta * 3.0)
	#elif velocity.y > 100:  # Falling fast
		#camera.offset.y = lerp(camera.offset.y, 50.0, delta * 3.0)
	#else:
		#camera.offset.y = lerp(camera.offset.y, 0.0, delta * 5.0)
	# Add the gravity
	
	for action_name in InputMap.get_actions():
		if Input.is_action_pressed(action_name):
			is_sleeping = false
			break
	
	if not is_on_floor():
		if velocity.y < 0:
			# Apply down gravity
			velocity += get_gravity() * delta
		else:
			# Make falling faster
			velocity.y += FALL_GRAVITY * delta
			if velocity.y > MAX_FALL_SPEED:
				# Reached terminal velocity
				velocity.y = MAX_FALL_SPEED
			#if not just_landed:
				#animated_stripe.play("fall")

	# Handle jump
	if Input.is_action_just_pressed("jump"):
		if is_on_floor() || !coyote_timer.is_stopped():
			velocity.y = JUMP_VELOCITY
			
	# Handle variable jump
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= decelerate_on_jump_release
	
	# Handle sneak
	if Input.is_action_pressed("sneak") && is_on_floor():
		# Starts as crouch, then he sneaks as he walks
		is_sneaking = true
	else:
		is_sneaking = false
			
	# Handle charge jump
	#if Input.is_action_pressed("down") && is_on_floor():
		#jump_held_time = (jump_held_time - 0.2) * delta
		#is_charge_jumping = true
		## Stop horizontal movement
		#velocity.x = move_toward(velocity.x, 0, SPEED)
		#animated_stripe.play("crouch")
		#if jump_held_time > 10:
			#print("Boom!")
			## velocity.y = jump_held_time * JUMP_VELOCITY
	#else:
		#jump_held_time = 0
		#is_charge_jumping = false
	
	# Get the input direction and handle the movement/deceleration
	# As good practice, you should replace UI actions with custom gameplay actions
	var direction := Input.get_axis("move_left", "move_right")
	
	if just_landed:
		if direction:
			velocity.x = direction * SPEED
			animated_stripe.flip_h = direction < 0
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * deceleration)
	elif not is_charge_jumping:
		if direction:
			# Wall push (make sure the regular horizontal movement does not overwrite the wall push)
			#if is_wall_slide:
				#print("yo!")
				#animated_stripe.play("wall_slide")
			if is_on_wall() and not is_on_floor():
				# Wall climb and wall slide
				var climb_input = Input.is_action_pressed("up")
				if climb_input:
					# Climb upward
					is_wall_climbing = true
					velocity.y = -WALL_CLIMB_SPEED
					animated_stripe.play("wall_climb")
					print("Wall climbing!!")
				#else:
					## Slide down slowly
					#is_wall_climbing = false
					#velocity.y = move_toward(velocity.y, WALL_SLIDE_SPEED, WALL_GRAVITY * delta)
					#animated_stripe.play("wall_slide")
					#print("hehe2")
				# Keep player "sticking" to wall
				velocity.x = direction * 20
				is_wall_slide = true
			elif wall_jump_lock > 0.0:
				# Wall jump
				print("Wall jump!!")
				# animated_stripe.flip_h = look_dir_x
				wall_jump_lock -= delta
				velocity.x = lerp(velocity.x, direction * SPEED, 0.5)
				#velocity.x = direction * SPEED * 0.5
				#velocity.x = direction * SPEED * 0.5
			elif is_sneaking && is_on_floor():
				velocity.x = direction * SNEAK_SPEED
				animated_stripe.play("sneak")
			else:
				# Move from current velocity to running, using delta
				velocity.x = move_toward(velocity.x, direction * SPEED, SPEED * acceleration)
				# velocity.x = direction * SPEED
				if is_on_floor():
					animated_stripe.play("run")
				else:
					if velocity.y < 0:
						animated_stripe.play("jump")
					else:
						animated_stripe.play("fall")
			# Flip sprite depending on direction
			animated_stripe.flip_h = direction < 0
		elif not is_on_floor():
			if velocity.y < 0:
				animated_stripe.play("jump")
			else:
				animated_stripe.play("fall")
		else:
			# Move from current velocity to 0, using delta
			velocity.x = move_toward(velocity.x, 0, SPEED * deceleration)
			if is_sneaking:
				animated_stripe.play("crouch")
			elif is_sleeping:
				animated_stripe.play("sleep")
			else:
				animated_stripe.play("idle")

	# Wall jumping
	if Input.is_action_just_pressed("jump") and wall_contact_coyote > 0.0:
			# Small hops to 	player away from the wall
			velocity.y = WALL_JUMP_VELOCITY
			velocity.x = -look_dir_x * WALL_JUMP_PUSH_FORCE
			wall_jump_lock = WALL_JUMP_LOCK_TIME
			animated_stripe.flip_h = look_dir_x
				
	# Wall detecting and sliding
	# add velocity.x != 0 if you want the player to only glue to the wall as he's moving horizontally
	if not is_on_floor() and is_on_wall() and velocity.y > 0 and velocity.x != 0:
		look_dir_x = sign(velocity.x)
		# Wall detecting will be "activated here" by wall_contact_coyote being set 
		wall_contact_coyote = WALL_CONTACT_COYOTE_TIME
		velocity.y = WALL_SLIDE_SPEED
		animated_stripe.play("wall_slide")
		is_wall_slide = true
	else:
		is_wall_slide = false
		wall_contact_coyote -= delta

	var was_on_floor = is_on_floor() 
	var fall_speed = velocity.y
	
	# This updates collision and floor detection, resets velocity, etc (to use methods like is_on_floor, etc)
	move_and_slide()
		
	if was_on_floor && not is_on_floor():
		coyote_timer.start()
	
	# Detect landing (no landing animation as he falls down and crouches)
	if !was_on_floor and is_on_floor() and fall_speed > 400 and not Input.is_action_pressed("sneak"):
		print(fall_speed)
		print("landed")
		just_landed = true
		print("just landed")
		animated_stripe.play("land")

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_stripe.animation == "land":
		print("Finished landed animation")
		animated_stripe.play("idle")
		just_landed = false
