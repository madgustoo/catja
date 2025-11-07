extends Node2D
const SPEED = 30
var direction = 1
@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_left: RayCast2D = $RayCastLeft
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _process(delta: float) -> void:
	# Add safety checks for colliders
	if ray_cast_right.is_colliding():
		var collider = ray_cast_right.get_collider()
		if is_instance_valid(collider):
			direction = -1
	
	if ray_cast_left.is_colliding():
		var collider = ray_cast_left.get_collider()
		if is_instance_valid(collider):
			direction = 1
	
	position.x += direction * SPEED * delta
	animated_sprite_2d.flip_h = direction < 0
