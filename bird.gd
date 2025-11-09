extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $Area2D

@export var fly_speed: float = 150.0
@export var despawn_height: float = 500.0  # How high before bird despawns

var state = "IDLE"
var player = null
var fly_direction = Vector2.ZERO
var start_position = Vector2.ZERO

func _ready():
	# Check if nodes exist before connecting
	if detection_area == null:
		push_error("Area2D node not found! Check the node path.")
		return
	
	if sprite == null:
		push_error("AnimatedSprite2D node not found!")
		return
	
	# Store starting position for respawn
	start_position = global_position
	
	# Connect Area2D signals
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	match state:
		"IDLE":
			sprite.play("idle")
			# Bird just waits for player to enter Area2D
			
		"START_FLIGHT":
			# Animation is playing, waiting for it to finish
			pass
			
		"FLY":
			sprite.play("flight")
			velocity = fly_direction * fly_speed
			move_and_slide()
			
			# Check if bird has flown far enough away
			if global_position.y < start_position.y - despawn_height:
				# Bird is far away, reset it
				reset_bird()

func _on_detection_area_body_entered(body):
	# Check if it's the player and they're NOT sneaking
	if body.is_in_group("Player") and state == "IDLE":
		if not body.is_sneaking():
			player = body
			start_fleeing()

func _on_detection_area_body_exited(body):
	if body == player:
		player = null

func start_fleeing():
	state = "START_FLIGHT"
	sprite.play("start_flight")
	
	# Fly straight up only
	fly_direction = Vector2.UP
	
	# Determine which way to flip sprite based on player position
	if player:
		sprite.flip_h = player.global_position.x < global_position.x

func _on_animation_finished():
	if state == "START_FLIGHT" and sprite.animation == "start_flight":
		state = "FLY"

func reset_bird():
	# Move bird back to starting position and reset state
	global_position = start_position
	velocity = Vector2.ZERO
	state = "IDLE"
	sprite.play("idle")
