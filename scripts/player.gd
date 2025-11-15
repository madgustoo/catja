extends CharacterBody2D

@onready var animated_stripe = $AnimatedSprite2D
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var camera: Camera2D = $Camera2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var jump_buffer_timer: Timer = $JumpBufferTimer

@onready var ray_cast_down: RayCast2D = $RayCastDown
@onready var crouch_ray_cast_1: RayCast2D = $CrouchRayCast1
@onready var crouch_ray_cast_2: RayCast2D = $CrouchRayCast2

@export_range(0, 1) var acceleration = 1
@export_range(0, 1) var deceleration = 1
@export_range(0, 1) var decelerate_on_jump_release = 0.5

enum State {
	NORMAL,
	JUMPING,
	SNEAK,
	WALL_CLIMB,
	WALL_SLIDE,
	LANDED,
	DEATH
}

var state = State.NORMAL

const SPEED = 120.0
const MAX_FALL_SPEED = 600.0
const JUMP_VELOCITY = -320.0
const WALL_JUMP_VELOCITY = -250.0
const FALL_GRAVITY = 1000
const SNEAK_SPEED = 60.0
const WALL_CLIMB_SPEED = 100.0
const WALL_SLIDE_SPEED = 80.0
const WALL_GRAVITY = 200.0
const WALL_JUMP_PUSH_FORCE = 120.0

var facing_direction = 1 # Looking right by default
var wall_direction = 0
var elapsed_time = 0.0 # Time in seconds (delta is 1/60s)

var isCrouchBlocked = false

var standing_collision_shape = preload("res://resources/collisions/player_standing.tres")
var crouching_collision_shape = preload("res://resources/collisions/player_crouching.tres")

func die() -> void:
	if state == State.DEATH:
		return
	state = State.DEATH
	collision_shape.disabled = true
	if !ray_cast_down.is_colliding():
		# Don't play death animation as he's falling
		animated_stripe.play("death")

func bounce(force: Vector2):
	velocity = force
	
func _ready() -> void:
	crouch_ray_cast_1.enabled = false
	crouch_ray_cast_2.enabled = false

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		if velocity.y < 0:
			# Apply down gravity
			velocity += get_gravity() * delta
		else:
			# Make falling faster and caps at MAX_FALL_SPEED
			velocity.y += FALL_GRAVITY * delta
			if velocity.y > MAX_FALL_SPEED:
				velocity.y = MAX_FALL_SPEED
				
	if state == State.DEATH:
		velocity.x = 0
		move_and_slide()
		return
			
	# Handle variable jump
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= decelerate_on_jump_release
	
	# Get the input direction and handle the movement/deceleration
	# As good practice, you should replace UI actions with custom gameplay actions
	var direction := Input.get_axis("move_left", "move_right")
	
	match state:
		State.NORMAL:
			crouch_ray_cast_1.enabled = false
			crouch_ray_cast_2.enabled = false
			if is_on_floor() or !coyote_timer.is_stopped():
				# If the jump buffer still hasn't completed yet once he lands, 
				# it means he registered the jump right before landing and we make him jump again
				if Input.is_action_just_pressed("jump") or !jump_buffer_timer.is_stopped():
					state = State.JUMPING
					velocity.y = JUMP_VELOCITY
					animated_stripe.play("jump")
					elapsed_time = 0
				elif Input.is_action_pressed("sneak"):
					state = State.SNEAK
					elapsed_time = 0
				elif direction:
					velocity.x = move_toward(velocity.x, direction * SPEED, SPEED * acceleration)
					animated_stripe.flip_h = direction < 0
					animated_stripe.play("run")
					facing_direction = sign(direction)
					elapsed_time = 0
				else:
					velocity.x = move_toward(velocity.x, 0, SPEED * deceleration)
					if abs(velocity.x) == 0:
						elapsed_time += delta
						if elapsed_time >= 60:
							animated_stripe.play("sit")
						else:
							animated_stripe.play("idle")
			else:
				state = State.JUMPING
		State.JUMPING:
			if Input.is_action_just_pressed("jump"):
				# Jump buffer registered while he's still in the "Jumping" state (still in the air)
				jump_buffer_timer.start()
			if direction != 0:
				velocity.x = move_toward(velocity.x, direction * SPEED, SPEED * acceleration * 0.5)
				animated_stripe.flip_h = direction < 0
			if velocity.y < 0:
				animated_stripe.play("jump")
			else:
				animated_stripe.play("fall")
			if not is_on_floor() and is_on_wall() and velocity.y > 0 and velocity.x != 0:
				# Landed on wall
				facing_direction = sign(direction)
				state = State.WALL_CLIMB
			elif is_on_floor():
				state = State.NORMAL
		State.SNEAK:
			crouch_ray_cast_1.enabled = true
			crouch_ray_cast_2.enabled = true
			if direction:
				velocity.x = direction * SNEAK_SPEED
				animated_stripe.flip_h = direction < 0
				# Crouch walk
				animated_stripe.play("sneak")
				collision_shape.shape = crouching_collision_shape
				collision_shape.position = Vector2(0.0, -4.0)
			else:
				velocity.x = 0
				animated_stripe.play("crouch")
				collision_shape.shape = crouching_collision_shape
				collision_shape.position = Vector2(0.0, -4.0)
			if Input.is_action_just_released("sneak"):
				isCrouchBlocked = crouch_ray_cast_1.is_colliding() or crouch_ray_cast_2.is_colliding()
				# Sneak button is not pressed anymore, but if he's still coliding with something, don't change the state back
				if !isCrouchBlocked:
					state = State.NORMAL
					collision_shape.shape = standing_collision_shape
					collision_shape.position = Vector2(0.0, -7.0)
#			# If isCrouchBlocked and he stopped colliding, stand him up
			if isCrouchBlocked and !crouch_ray_cast_1.is_colliding() and !crouch_ray_cast_2.is_colliding():
				state = State.NORMAL
				collision_shape.shape = standing_collision_shape
				collision_shape.position = Vector2(0.0, -7.0)
				isCrouchBlocked = false
		State.WALL_CLIMB:
			# wall_direction is -1 for up, and +1 for down
			var wall_direction = direction
			if facing_direction > 0:
				# Climbing a right wall, we need to change the sign of the direction, left wall is kept unchanged
				wall_direction = -direction
				velocity.y = wall_direction * WALL_CLIMB_SPEED
			else:
				velocity.y = wall_direction * WALL_CLIMB_SPEED
			if wall_direction == 0:
				animated_stripe.play("wall_crouch")
			else:
				if wall_direction > 0:
					state = State.WALL_SLIDE
				else:
					animated_stripe.play("wall_climb")
			if Input.is_action_just_pressed("jump"):
				wall_jump()
			if not is_on_wall():
				animated_stripe.rotation_degrees = 0
				state = State.NORMAL
		State.WALL_SLIDE:
			animated_stripe.play("wall_slide")
			velocity.y = WALL_SLIDE_SPEED
			if facing_direction > 0:
				# Climbing a right wall
				if Input.is_action_just_pressed("move_right"):
					state = State.WALL_CLIMB
				elif Input.is_action_pressed("move_left"):
					# Make descend faster
					velocity.y *= 2
			else:
				# Climbing a left wall
				if Input.is_action_just_pressed("move_left"):
					state = State.WALL_CLIMB
				elif Input.is_action_pressed("move_right"):
					# Make descend faster
					velocity.y *= 2
			if Input.is_action_just_pressed("jump"):
				wall_jump()
			if is_on_floor():
				state = State.NORMAL
		State.LANDED:
			# Changes back to normal state in _on_animated_sprite_2d_animation_finished
			animated_stripe.play("land")
	
	var was_on_floor = is_on_floor() 
	
	# This updates collision and floor detection, resets velocity, etc (to use methods like is_on_floor, etc)
	move_and_slide()	
	
	if was_on_floor && !is_on_floor():
		coyote_timer.start()
		
	if !was_on_floor and is_on_floor() and not Input.is_action_pressed("sneak"):
		state = State.LANDED
		
func wall_jump():
	state = State.NORMAL
	velocity.y = JUMP_VELOCITY
	velocity.x = -facing_direction * WALL_JUMP_PUSH_FORCE
	animated_stripe.flip_h = true if facing_direction > 0 else false

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_stripe.animation == "land":
		state = State.NORMAL
