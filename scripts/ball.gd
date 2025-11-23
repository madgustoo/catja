extends CharacterBody2D

@export var mass: float = 1 # In kg 
@export_range(0, 1) var damping: float = 0.8 # Damping (like friction) to reduce the movement overtime

const SPEED = 100.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	var collision = move_and_collide(velocity * delta)
	if collision:
		velocity = velocity.bounce(collision.get_normal())
		velocity *= damping
		
func hit(force: Vector2):
	velocity += force / mass
	
