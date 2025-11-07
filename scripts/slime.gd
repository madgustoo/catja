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
func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body) or not body.is_in_group("player"):
		return
	
	# Check if player is already dead - IMPORTANT!
	if body.has_method("is_dead") or body.get("is_dead") == true:
		return
	
	if body.has_node("CollisionShape2D"):
		var collision = body.get_node("CollisionShape2D")
		if not is_instance_valid(collision) or collision.disabled:
			return
	
	if body.has_method("die"):
		body.die()  # Call directly, not deferred
