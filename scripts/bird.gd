extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast_down: RayCast2D = $RayCastDown
@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_left: RayCast2D = $RayCastLeft

enum State {
	NORMAL,
	FLYING,
	FALLING
}

var state = State.NORMAL
var direction = 1

const SPEED = 50.0
const JUMP_VELOCITY = -400.0
const SMALL_JUMP = -100

var jump_timer = 0.0
var jump_interval_time = 1 # Time in seconds

func _ready() -> void:
	animated_sprite.flip_h = direction < 0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.x = 0
		
	if ray_cast_right.is_colliding():
		direction = -1
	if ray_cast_left.is_colliding():
		direction = 1
		
	match state:
		State.NORMAL:
			animated_sprite.play("idle")
			# Small hops
			jump_timer -= delta
			if jump_timer <= 0.0:
				jump_timer = jump_interval_time
				velocity.y = SMALL_JUMP
				velocity.x = SPEED * direction
			if !ray_cast_down.is_colliding():
				state = State.FALLING
		State.FALLING:
			animated_sprite.play("flight")
			# if ray_cast_down.is_colliding():
			if is_on_floor():
				state = State.NORMAL
				
	animated_sprite.flip_h = direction < 0
		
	move_and_slide()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		pass
