extends CharacterBody2D

const SPEED = 120.0
const JUMP_VELOCITY = -300.0

# Ledge grab variables
var is_grabbing_ledge = false
var ledge_grab_offset = Vector2(-8, 0)  # Horizontal and vertical offset from detection
var climb_destination = Vector2.ZERO
var can_grab_ledge = true  # Prevents repeated grabs

@onready var animated_stripe = $AnimatedSprite2D
@onready var ray_cast_down: RayCast2D = $RayCast2D

# Ledge detection raycasts
@onready var ledge_ray_wall = $LedgeRayWall
@onready var ledge_ray_ledge = $LedgeRayLedge

func _ready():
	setup_ledge_raycasts()

func setup_ledge_raycasts():
	# Create wall detection raycast (detects the wall itself)
	if not has_node("LedgeRayWall"):
		ledge_ray_wall = RayCast2D.new()
		ledge_ray_wall.name = "LedgeRayWall"
		add_child(ledge_ray_wall)
		ledge_ray_wall.target_position = Vector2(16, 0)  # Reaches forward
		ledge_ray_wall.position = Vector2(0, -8)  # At chest/upper body level
		ledge_ray_wall.enabled = true
		ledge_ray_wall.collision_mask = 1  # Only collide with walls (layer 1)
	
	# Create ledge detection raycast (checks if there's a ledge top)
	if not has_node("LedgeRayLedge"):
		ledge_ray_ledge = RayCast2D.new()
		ledge_ray_ledge.name = "LedgeRayLedge"
		add_child(ledge_ray_ledge)
		ledge_ray_ledge.target_position = Vector2(16, 0)  # Reaches forward
		ledge_ray_ledge.position = Vector2(0, -20)  # Above the wall ray (head level)
		ledge_ray_ledge.enabled = true
		ledge_ray_ledge.collision_mask = 1

func bounce(force: Vector2):
	velocity = force

func _physics_process(delta: float) -> void:
	if is_grabbing_ledge:
		handle_ledge_grab(delta)
	else:
		handle_normal_movement(delta)
		check_ledge_grab()
	
	move_and_slide()

func handle_normal_movement(delta: float) -> void:
	# Add the gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle drop-through platforms
	if Input.is_action_just_pressed("ui_down") and is_on_floor():
		set_collision_mask_value(2, false)
		position.y += 1
		await get_tree().create_timer(0.2).timeout
		set_collision_mask_value(2, true)
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Get the input direction and handle the movement/deceleration
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
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		animated_stripe.play("idle")
	
	# Re-enable ledge grabbing when on floor
	if is_on_floor():
		can_grab_ledge = true

func check_ledge_grab():
	# Only check if:
	# - Falling (positive Y velocity)
	# - Moving horizontally
	# - Not on floor
	# - Can grab ledge (prevents repeated grabs)
	if velocity.y <= 50 or abs(velocity.x) < 10 or is_on_floor() or not can_grab_ledge:
		return
	
	# Update raycast direction based on player facing
	var direction = 1 if not animated_stripe.flip_h else -1
	ledge_ray_wall.target_position.x = abs(ledge_ray_wall.target_position.x) * direction
	ledge_ray_ledge.target_position.x = abs(ledge_ray_ledge.target_position.x) * direction
	
	# Force raycast update
	ledge_ray_wall.force_raycast_update()
	ledge_ray_ledge.force_raycast_update()
	
	# Check for ledge: wall detected at chest level, no wall at head level
	if ledge_ray_wall.is_colliding() and not ledge_ray_ledge.is_colliding():
		start_ledge_grab()

func start_ledge_grab():
	is_grabbing_ledge = true
	can_grab_ledge = false
	velocity = Vector2.ZERO
	
	# Get the exact ledge position
	var ledge_position = ledge_ray_wall.get_collision_point()
	var direction = 1 if not animated_stripe.flip_h else -1
	
	# Snap player to ledge with offset
	global_position.x = ledge_position.x + (ledge_grab_offset.x * direction)
	global_position.y = ledge_position.y + ledge_grab_offset.y
	
	# Calculate where to climb to
	climb_destination = global_position + Vector2(direction * 12, -24)
	
	# Play grab animation
	animated_stripe.play("ledge_grab")

func handle_ledge_grab(delta: float):
	# Keep velocity at zero while hanging
	velocity = Vector2.ZERO
	
	# Release with down key
	if Input.is_action_just_pressed("ui_down"):
		release_ledge()
		return
	
	# Jump away from ledge
	if Input.is_action_just_pressed("jump"):
		jump_from_ledge()
		return
	
	# Climb up with up key or jump
	if Input.is_action_just_pressed("ui_up"):
		climb_ledge()

func climb_ledge():
	is_grabbing_ledge = false
	
	# Play climb animation
	animated_stripe.play("ledge_climb")
	
	# Smooth climb up using a tween
	var tween = create_tween()
	tween.tween_property(self, "global_position", climb_destination, 0.2)
	await tween.finished
	
	velocity.y = -50  # Small upward boost after climb
	animated_stripe.play("idle")

func release_ledge():
	is_grabbing_ledge = false
	velocity.y = 100  # Small downward push
	animated_stripe.play("run_fall")

func jump_from_ledge():
	is_grabbing_ledge = false
	var direction = -1 if not animated_stripe.flip_h else 1
	velocity = Vector2(direction * SPEED * 1.2, JUMP_VELOCITY * 0.7)
	animated_stripe.flip_h = direction < 0
	animated_stripe.play("run_jump")
