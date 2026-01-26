extends StaticBody3D

signal goal_scored(time_nome)

@export var team_name = "Time A" 

func _on_area_gol_body_entered(body):
	if body is RigidBody3D:
		goal_scored.emit(team_name)

func reset_ball(ball):
	await get_tree().create_timer(1.0).timeout
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_position = Vector3(0, 2, 0) 
