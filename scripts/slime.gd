extends Node2D
const SPEED = 30
var direction = 1
@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_left: RayCast2D = $RayCastLeft
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Connect the Area2D signal if it exists
	var area = $Area2D  # Adjust this path if your Area2D has a different name
	if area:
		area.body_entered.connect(_on_body_entered)

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
	# Check if the body is valid and is the player
	if not is_instance_valid(body):
		return
	
	if body.is_in_group("player") or body.name == "Player":
		# Check if player has die method and isn't already dead
		if body.has_method("die"):
			body.die()
		elif body.has_method("take_damage"):
			body.take_damage(1)
