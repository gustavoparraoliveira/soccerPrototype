extends NetworkRigidBody3D

@export var effect_intensity = 0.0
@export var ball_radius = 0.22 
@export var magnus_coefficient = 0.3
@export var last_player_touch = null
@export var last_team_touch = ""
var last_impulse_tick = -100
var is_set_piece = false

func _ready():
	contact_monitor = true
	max_contacts_reported = 5
	body_entered.connect(_on_body_entered)

func apply_effect(value: float):
	effect_intensity = value

func apply_impulse_synced(impulse: Vector3):
	var current_tick = NetworkTime.tick
	
	if multiplayer.is_server() and (current_tick - last_impulse_tick) > 30:
		# 1. Acorda o corpo e remove qualquer trava
		freeze = false
		sleeping = false
		
		# 2. Aplica o impulso
		apply_central_impulse(impulse)
		print("Impulso aplicado no tick: ", current_tick)
		
		# 3. Força a atualização do estado da rede para este tick
		if has_node("RollbackSynchronizer"):
			# Garante que o sincronizador veja a nova linear_velocity imediatamente
			var synchronizer = $RollbackSynchronizer
			synchronizer.process_settings() 
		
		last_impulse_tick = current_tick

func request_reset():
	var world = get_parent()
	if world.has_method("notify_ball_out_internal"):
		world.notify_ball_out_internal()
	reset_to_spawn()

func reset_to_spawn():
	var spawn_node = get_parent().get_node("BallSpawns/SpawnBola")
	if not spawn_node: return
	
	freeze = true
	global_position = spawn_node.global_position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	quaternion = Quaternion.IDENTITY
	
	if has_node("RollbackSynchronizer"):
		$RollbackSynchronizer.process_settings()
	
	await get_tree().physics_frame
	freeze = false

func _physics_rollback_tick(delta, _tick):
	if not multiplayer.is_server(): return
		
	var speed = linear_velocity.length()
	
	if abs(effect_intensity) > 0.1 and speed > 8.0:
		var move_dir = linear_velocity.normalized()
		var curve_dir = move_dir.cross(Vector3.UP) 
		var magnus_force = curve_dir * (effect_intensity * magnus_coefficient * speed)
		apply_central_impulse(magnus_force * delta)
		
		var target_rot_y = effect_intensity * 40.0
		angular_velocity.y = lerp(angular_velocity.y, target_rot_y, delta * 5.0)
		
		effect_intensity = move_toward(effect_intensity, 0.0, delta * 0.2)
	
func _on_body_entered(body):
	if not multiplayer.is_server(): return
	
	if body.is_in_group("red"):
		last_team_touch = "red"
	elif body.is_in_group("blue"):
		last_team_touch = "blue"
	
	effect_intensity *= 0.2

func register_last_touch(player, team):
	last_player_touch = player
	last_team_touch = team

func prepare_set_piece(pos):
	freeze = true
	global_position = pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	quaternion = Quaternion.IDENTITY
	
	if has_node("RollbackSynchronizer"):
		$RollbackSynchronizer.process_settings()
	
	await get_tree().physics_frame
	freeze = false
