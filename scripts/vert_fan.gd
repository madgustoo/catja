extends Area2D

@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export var upward_force = -30

var player = null

func _physics_process(delta: float) -> void:
	if player:
		player.push_upward(upward_force)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		animated_sprite_2d.play("on")
		gpu_particles_2d.emitting =true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = null
		animated_sprite_2d.play("off")
		gpu_particles_2d.emitting = false
