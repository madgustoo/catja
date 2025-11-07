extends CharacterBody2D

# Node references
@onready var animated_stripe = $AnimatedSprite2D
@onready var ray_cast_down: RayCast2D = $RayCast2D
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var camera: Camera2D = $Camera2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Exported variables
@export_range(0, 1) var acceleration = 1
@export_range(0, 1) var deceleration = 1
@export_range(0, 1) var decelerate_on_jump_release = 0.5

# State management
enum State {
	NORMAL,
	JUMPING,
	FALL,
	SNEAK,
	WALL_CLIMB,
	WALL_SLIDE
}

var state = State.NORMAL

# Movement constants
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

# Player state
var facing_direction = 1
var elapsed_time = 0.0
var is_dead = false
var is_crouching = false

# Collision shape backup
var original_shape_height = 0.0
var original_shape_position = Vector2.ZERO

func _ready():
	# Store original collision shape for crouch/stand transitions
	if collision_shape.shape is CapsuleShape2D:
		original_shape_height = collision_shape.shape.height
		original_shape_position = collision_shape.position
	
	add_to_group("player")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	apply_gravity(delta)
	handle_variable_jump()
	
	var direction := Input.get_axis("move_left", "move_right")
	handle_state(direction, delta)
	
	var was_on_floor = is_on_floor()
	move_and_slide()
	
	if was_on_floor and not is_on_floor():
		coyote_timer.start()

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		if velocity.y < 0:
			velocity += get_gravity() * delta
		else:
			velocity.y += FALL_GRAVITY * delta
			if velocity.y > MAX_FALL_SPEED:
				velocity.y = MAX_FALL_SPEED

func handle_variable_jump() -> void:
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= decelerate_on_jump_release

func handle_state(direction: float, delta: float) -> void:
	match state:
		State.NORMAL:
			handle_normal_state(direction, delta)
		State.JUMPING:
			handle_jumping_state(direction)
		State.SNEAK:
			handle_sneak_state(direction)
		State.WALL_CLIMB:
			handle_wall_climb_state(direction)
		State.WALL_SLIDE:
			handle_wall_slide_state(direction)

func handle_normal_state(direction: float, delta: float) -> void:
	if is_on_floor() or !coyote_timer.is_stopped():
		if Input.is_action_just_pressed("jump"):
			exit_crouch()
			state = State.JUMPING
			velocity.y = JUMP_VELOCITY
			animated_stripe.play("jump")
			elapsed_time = 0
		elif Input.is_action_pressed("sneak") and is_on_floor():
			enter_crouch()
			state = State.SNEAK
			elapsed_time = 0
		elif direction:
			exit_crouch()
			velocity.x = move_toward(velocity.x, direction * SPEED, SPEED * acceleration)
			animated_stripe.flip_h = direction < 0
			animated_stripe.play("run")
			facing_direction = sign(direction)
			elapsed_time = 0
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * deceleration)
			if abs(velocity.x) == 0:
				elapsed_time += delta
				animated_stripe.play("sleep" if elapsed_time >= 60 else "idle")
	else:
		exit_crouch()
		state = State.JUMPING

func handle_jumping_state(direction: float) -> void:
	exit_crouch()
	
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * SPEED, SPEED * acceleration * 0.5)
		animated_stripe.flip_h = direction < 0
	
	animated_stripe.play("jump" if velocity.y < 0 else "fall")
	
	if not is_on_floor() and is_on_wall() and velocity.y > 0 and velocity.x != 0:
		facing_direction = sign(direction)
		state = State.WALL_CLIMB
	elif is_on_floor():
		state = State.NORMAL

func handle_sneak_state(direction: float) -> void:
	if direction:
		velocity.x = direction * SNEAK_SPEED
		animated_stripe.flip_h = direction < 0
		animated_stripe.play("sneak")
	else:
		velocity.x = 0
		animated_stripe.play("crouch")
	
	if Input.is_action_just_released("sneak"):
		exit_crouch()
		state = State.NORMAL

func handle_wall_climb_state(direction: float) -> void:
	exit_crouch()
	
	var wall_direction = direction if facing_direction < 0 else -direction
	velocity.y = wall_direction * WALL_CLIMB_SPEED
	
	if wall_direction == 0:
		animated_stripe.play("wall_crouch")
	elif wall_direction > 0:
		state = State.WALL_SLIDE
	else:
		animated_stripe.play("wall_climb")
	
	if Input.is_action_just_pressed("jump"):
		wall_jump()
	
	if not is_on_wall():
		animated_stripe.rotation_degrees = 0
		state = State.NORMAL

func handle_wall_slide_state(_direction: float) -> void:
	exit_crouch()
	animated_stripe.play("wall_slide")
	velocity.y = WALL_SLIDE_SPEED
	
	var climb_input = "move_right" if facing_direction > 0 else "move_left"
	var descend_input = "move_left" if facing_direction > 0 else "move_right"
	
	if Input.is_action_just_pressed(climb_input):
		state = State.WALL_CLIMB
	elif Input.is_action_pressed(descend_input):
		velocity.y *= 2
	
	if Input.is_action_just_pressed("jump"):
		wall_jump()
	
	if is_on_floor():
		state = State.NORMAL

func wall_jump() -> void:
	state = State.NORMAL
	velocity.y = JUMP_VELOCITY
	velocity.x = -facing_direction * WALL_JUMP_PUSH_FORCE
	animated_stripe.flip_h = facing_direction > 0

func enter_crouch() -> void:
	if is_crouching or is_dead or not is_instance_valid(collision_shape):
		return
	
	is_crouching = true
	if collision_shape.shape is CapsuleShape2D:
		collision_shape.shape.height = 60
		collision_shape.position = Vector2(0.0, 16.0)

func exit_crouch() -> void:
	if not is_crouching or is_dead or not is_instance_valid(collision_shape):
		return
	
	is_crouching = false
	if collision_shape.shape is CapsuleShape2D:
		collision_shape.shape.height = original_shape_height
		collision_shape.position = original_shape_position

func die() -> void:
	if is_dead:
		return
	
	print("=== PLAYER DIE CALLED ===")
	
	# Set is_dead FIRST - this is critical!
	is_dead = true
	
	# Stop all movement
	velocity = Vector2.ZERO
	
	# Exit crouch
	if is_crouching:
		exit_crouch()
	
	# Disable collision IMMEDIATELY to prevent further enemy hits
	collision_shape.disabled = true
	
	# Stop all processing
	set_physics_process(false)
	set_process_input(false)
	
	# Play death animation
	if animated_stripe.sprite_frames.has_animation("dead"):
		animated_stripe.play("dead")
		print("Playing death animation")
		await animated_stripe.animation_finished
	else:
		print("WARNING: 'dead' animation not found!")
		await get_tree().create_timer(1.0).timeout
	
	queue_free()
	
func push_upward(vertical_force):
	velocity.y += vertical_force

func bounce(force: Vector2) -> void:
	velocity = force
