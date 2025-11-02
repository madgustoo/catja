extends CharacterBody2D

@onready var animated_stripe = $AnimatedSprite2D
@onready var ray_cast_down: RayCast2D = $RayCast2D
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var camera: Camera2D = $Camera2D

@export_range(0, 1) var acceleration = 1
@export_range(0, 1) var deceleration = 1
@export_range(0, 1) var decelerate_on_jump_release = 0.5

enum State {
	NORMAL, # IDLE
	SLEEP,
	RUN,
	JUMPING,
	FALL,
	SNEAK,
	WALL_SLIDE,
	WALL_CLIMB
}

var state = State.NORMAL

const SPEED = 120.0
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

var is_sleeping: bool = true
var has_woken_up: bool = false
var is_wall_slide: bool = false
var is_wall_climbing: bool = false

func bounce(force: Vector2):
	velocity = force

func _physics_process(delta: float) -> void:
	#for action_name in InputMap.get_actions():
		#if Input.is_action_pressed(action_name):
			##is_sleeping = false
			#state = State.IDLE
			#break
			
	if not is_on_floor():
		if velocity.y < 0:
			# Apply down gravity
			velocity += get_gravity() * delta
		else:
			# Make falling faster and caps at MAX_FALL_SPEED
			velocity.y += FALL_GRAVITY * delta
			if velocity.y > MAX_FALL_SPEED:
				velocity.y = MAX_FALL_SPEED

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
	
	# Get the input direction and handle the movement/deceleration
	# As good practice, you should replace UI actions with custom gameplay actions
	var direction := Input.get_axis("move_left", "move_right")
	
	# 		if not coyote_timer.is_stopped():
	
	match state:
		State.SLEEP:
			if is_on_floor():
				animated_stripe.play("sleep")
		State.NORMAL:
			if is_on_floor():
				if Input.is_action_just_pressed("jump"):
					state = State.JUMPING
					velocity.y = JUMP_VELOCITY
					animated_stripe.play("jump")
				if direction:
					# Move from current velocity to running, using delta
					velocity.x = move_toward(velocity.x, direction * SPEED, SPEED * acceleration)
					animated_stripe.flip_h = direction < 0
					animated_stripe.play("run")
				else:
					velocity.x = move_toward(velocity.x, 0, SPEED * deceleration)
					# Only switch to idle once fully stopped
					if abs(velocity.x) < 5:
						velocity.x = 0
						animated_stripe.play("idle")
			else:
				animated_stripe.play("fall")
		State.JUMPING:
			if direction != 0:
				velocity.x = move_toward(velocity.x, direction * SPEED, SPEED * acceleration * 0.5)
				animated_stripe.flip_h = direction < 0
			if velocity.y < 0:
				animated_stripe.play("jump")
			else:
				animated_stripe.play("fall")
			if is_on_floor():
				state = State.NORMAL
				
	# This updates collision and floor detection, resets velocity, etc (to use methods like is_on_floor, etc)
	move_and_slide()	

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_stripe.animation == "land":
		print("Finished landed animation")
		animated_stripe.play("idle")
		just_landed = false
