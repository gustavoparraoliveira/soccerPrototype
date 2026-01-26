extends RigidBody3D

var effect_intensity = 0.0
@export var ball_radius = 0.22 
@export var magnus_coefficient = 1.2
@export var last_player_touch = null
@export var last_team_touch = ""

func _ready():
	contact_monitor = true
	max_contacts_reported = 5
	body_entered.connect(_on_body_entered)

func apply_effect(value: float):
	if multiplayer.is_server():
		effect_intensity = value

func apply_impulse_synced(impulse: Vector3):
	if multiplayer.is_server():
		apply_central_impulse(impulse)

func _physics_process(delta):
	if not multiplayer.is_server(): return
		
	var speed = linear_velocity.length()
	
	if abs(effect_intensity) > 0.1 and speed > 3.0:
		var move_dir = linear_velocity.normalized()
		var curve_dir = move_dir.cross(Vector3.UP) 
		
		var final_force = curve_dir * (effect_intensity * magnus_coefficient * speed)
		
		apply_central_force(final_force)
		
		effect_intensity = move_toward(effect_intensity, 0.0, delta * 0.5)

	if speed > 0.2:
		var roll_axis = linear_velocity.normalized().cross(Vector3.UP)
		var roll_speed = clamp(speed / ball_radius, 0, 50)
		var target_rotation = -roll_axis * roll_speed
		
		target_rotation.y = effect_intensity * 15.0
		angular_velocity = angular_velocity.lerp(target_rotation, delta * 2.0)

func is_on_floor_custom() -> bool:
	return abs(linear_velocity.y) < 0.1

func _on_body_entered(body):
	if not multiplayer.is_server(): return
	
	if body.is_in_group("red"):
		last_team_touch = "red"
	elif body.is_in_group("blue"):
		last_team_touch = "blue"
		
	if not body.is_in_group("players"):
		effect_intensity = 0.0
	else:
		effect_intensity *= 0.1

func register_last_touch(player, team):
	if multiplayer.is_server():
		last_player_touch = player
		last_team_touch = team
