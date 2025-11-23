extends CharacterBody2D

@export var mass: float = 0.8 # In kg 

const SPEED = 100.0

#func _ready() -> void:
	#velocity = Vector2(SPEED * -1, SPEED)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	var collision = move_and_collide(velocity * delta)
	if collision:
		# var collider = collision.get_collider()
		velocity = velocity.bounce(collision.get_normal())
		
func hit(force: Vector2):
	print(force)
	velocity += force / mass
	
