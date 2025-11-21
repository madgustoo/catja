extends RigidBody2D

#func _integrate_forces(state):
	#for i in range(state.get_contact_count()):
		#var normal = state.get_contact_local_normal(i)
		#var collider = state.get_contact_collider_object(i)
#
		#print("Hit:", collider.name, "Normal:", normal)


func _on_body_entered(body: Node) -> void:
	print("Entered")
