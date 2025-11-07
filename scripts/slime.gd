extends Node2D
const SPEED = 30
var direction = 1
@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_left: RayCast2D = $RayCastLeft
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	#safety check - connect the Area2D signal if it exists
	var area = $Area2D  # Adjust this path if your Area2D has a different name
	if area and area.has_signal("body_entered"):
		area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	#safety check - make sure raycasts exist and are valid
	if not is_instance_valid(ray_cast_right) or not is_instance_valid(ray_cast_left):
		return
	
	#safety check - verify colliders are valid before changing direction
	if ray_cast_right.is_colliding():
		var collider = ray_cast_right.get_collider()
		if is_instance_valid(collider):
			direction = -1
	
	if ray_cast_left.is_colliding():
		var collider = ray_cast_left.get_collider()
		if is_instance_valid(collider):
			direction = 1
	
	position.x += direction * SPEED * delta
	
	#safety check - make sure sprite exists before flipping
	if is_instance_valid(animated_sprite_2d):
		animated_sprite_2d.flip_h = direction < 0

func _on_body_entered(body: Node2D) -> void:
	#safety check - verify body is valid and not already freed
	if not is_instance_valid(body):
		return
	
	#safety check - check if body is in player group
	if not body.is_in_group("player"):
		return
	
	#safety check - check if player has collision shape and it's enabled
	if body.has_node("CollisionShape2D"):
		var collision = body.get_node("CollisionShape2D")
		if not is_instance_valid(collision) or collision.disabled:
			return
	
	#safety check - verify player has die method and call it
	if body.has_method("die"):
		body.call_deferred("die")  # Use call_deferred for safety
