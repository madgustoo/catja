extends CharacterBody2D

@onready var animated_stripe = $AnimatedSprite2D
@onready var ray_cast_down: RayCast2D = $RayCast2D
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var camera: Camera2D = $Camera2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


@export_range(0, 1) var acceleration = 1
@export_range(0, 1) var deceleration = 1
@export_range(0, 1) var decelerate_on_jump_release = 0.5

enum State {
	NORMAL,
	JUMPING,
	FALL,
	SNEAK,
	WALL_CLIMB,
	WALL_SLIDE
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

var just_landed = false

var facing_direction = 1 # Looking right by default
var wall_direction = 0
var elapsed_time = 0.0

# Store original collision shape values
var original_shape_height = 0.0
var original_shape_position = Vector2.ZERO

#death safety-check
var is_dead = false
var is_crouching = false

func _ready():
	# Store original collision shape values
	if collision_shape.shape is CapsuleShape2D:
		original_shape_height = collision_shape.shape.height
		original_shape_position = collision_shape.position
	
	#safety check - add player to group so enemy can identify it
	add_to_group("player")

#safety check - only modify collision shape once when entering crouch
func enter_crouch():
	if is_crouching or is_dead:
		return
	is_crouching = true
	if collision_shape.shape is CapsuleShape2D:
		collision_shape.shape.height = 60
		collision_shape.position = Vector2(0.0, 16.0)

#safety check - only modify collision shape once when exiting crouch
func exit_crouch():
	if not is_crouching or is_dead:
		return
	is_crouching = false
	if collision_shape.shape is CapsuleShape2D:
		collision_shape.shape.height = original_shape_height
		collision_shape.position = original_shape_position

#safety check - handle death properly
func die():
	if is_dead:
		return
	is_dead = true
	
	#safety check - exit crouch before dying
	if is_crouching:
		exit_crouch()
	
	#safety check - disable all processing and input
	set_physics_process(false)
	set_process(false)
	set_process_input(false)
	collision_shape.set_deferred("disabled", true)
	
	await get_tree().create_timer(0.5).timeout
	queue_free()

func bounce(force: Vector2):
	velocity = force

func _physics_process(delta: float) -> void:
	#safety check - stop all physics when dead
	if is_dead:
		return
		
	if not is_on_floor():
		if velocity.y < 0:
			# Apply down gravity
			velocity += get_gravity() * delta
		else:
			# Make falling faster and caps at MAX_FALL_SPEED
			velocity.y += FALL_GRAVITY * delta
			if velocity.y > MAX_FALL_SPEED:
				velocity.y = MAX_FALL_SPEED
			
	# Handle variable jump
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= decelerate_on_jump_release
	
	# Get the input direction and handle the movement/deceleration
	# As good practice, you should replace UI actions with custom gameplay actions
	var direction := Input.get_axis("move_left", "move_right")
	
	match state:
		State.NORMAL:
			if is_on_floor() or !coyote_timer.is_stopped():
				if Input.is_action_just_pressed("jump"):
					exit_crouch()  #safety check
					state = State.JUMPING
					velocity.y = JUMP_VELOCITY
					animated_stripe.play("jump")
					elapsed_time = 0
				elif Input.is_action_pressed("sneak") && is_on_floor():
					enter_crouch() #safety check
					state = State.SNEAK
					elapsed_time = 0
				elif direction:
					exit_crouch() #safety check
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
							animated_stripe.play("sleep")
						else:
							animated_stripe.play("idle")
			else:
				exit_crouch() #safety check
				state = State.JUMPING
		State.JUMPING:
			exit_crouch() #safety check
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
			if direction:
				velocity.x = direction * SNEAK_SPEED
				animated_stripe.flip_h = direction < 0
				animated_stripe.play("sneak")
			else:
				velocity.x = 0
				animated_stripe.play("crouch")

			if Input.is_action_just_released("sneak"):
				exit_crouch() #safety check
				state = State.NORMAL
		State.WALL_CLIMB:
			exit_crouch() #safety check
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
			exit_crouch() #safety check
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
	
	var was_on_floor = is_on_floor() 
	
	# This updates collision and floor detection, resets velocity, etc (to use methods like is_on_floor, etc)
	move_and_slide()	
	
	if was_on_floor && not is_on_floor():
		coyote_timer.start()
		
func wall_jump():
	state = State.NORMAL
	velocity.y = JUMP_VELOCITY
	velocity.x = -facing_direction * WALL_JUMP_PUSH_FORCE
	animated_stripe.flip_h = true if facing_direction > 0 else false
	
func push_upward(vertical_force):
	velocity.y += vertical_force

func _on_animated_sprite_2d_animation_finished() -> void:
	pass
