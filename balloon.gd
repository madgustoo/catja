extends Area2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var timer: Timer = $Timer

@export var bounce_force := 400.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		animation_player.play("pop")
		var dir = (body.global_position - global_position).normalized()
		# Checks if player is
		body.bounce(-dir * bounce_force)
		timer.start()


func _on_timer_timeout() -> void:
	animation_player.play("RESET")
