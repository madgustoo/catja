extends Area2D
@onready var timer = $Timer

func _on_body_entered(body: Node2D) -> void:
	#safety check - verify body is valid and is the player
	if not is_instance_valid(body) or not body.is_in_group("player"):
		return
	
	Engine.time_scale = 0.5
	body.rotate(deg_to_rad(-45))
	
	#safety check - NEVER queue_free the collision shape, just disable it
	if body.has_node("CollisionShape2D"):
		var collision = body.get_node("CollisionShape2D")
		if is_instance_valid(collision):
			collision.set_deferred("disabled", true)  # Disable instead of freeing
	
	#safety check - disable player physics immediately
	body.set_physics_process(false)
	
	timer.start()

func _on_timer_timeout() -> void:
	Engine.time_scale = 1
	get_tree().reload_current_scene()
