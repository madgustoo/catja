extends RigidBody2D

func _integrate_forces(state):
	for i in range(state.get_contact_count()):
		var normal = state.get_contact_local_normal(i)
		var collider = state.get_contact_collider_object(i)

		# Hitting top of player: normal points upward (> 0.7)
		if collider.name == "Player" and normal.y > 0.7:
			print("Bong")
			# linear_velocity.y = -abs(linear_velocity.y)  # force upward bounce
