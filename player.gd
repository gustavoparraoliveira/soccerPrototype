extends CharacterBody3D

@export var kick_force = 25.0
@export var pass_force = 12.0
@export var dribble_force = 8.0
@export var curve_intensity = 0.5
@export var base_speed = 10.0
@export var target_speed = 10.0
@export var acceleration = 8.0
@export var friction = 8.0
@export var jump_force = 5.5

@onready var camera_pivot = $CameraPivot
@onready var kick_area = $CameraPivot/AreaKick
@onready var dribble_area = $AreaDribble
@onready var spring_arm = $CameraPivot/SpringArm3D
@onready var mesh = $MeshInstance3D
@onready var force_bar = $CanvasLayer/ForceBar

@export var color = Color.GREEN
@export var sync_v: Vector3:
	get: return velocity
	set(v): velocity = v
@export var sync_pos: Vector3:
	get: return global_position
	set(v): global_position = v

var current_speed = 10.0
var charge_value = 0.0
var is_charging = false
var current_action = ""
var dribble_cooldown = 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var input_dir_server = Vector2.ZERO
var camera_basis_server = Basis.IDENTITY

func _enter_tree():
	var id = int(str(name))
	set_multiplayer_authority(id)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(1)

func _ready():
	await get_tree().process_frame
	
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		$CameraPivot/SpringArm3D/Camera3D.make_current()
	else:
		$CameraPivot/SpringArm3D/Camera3D.current = false
		if force_bar: force_bar.hide()

func _physics_process(delta):
	current_speed = lerp(current_speed, target_speed, 2.0 * delta)
	
	if is_multiplayer_authority():
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		update_input_server.rpc_id(1, input_dir, spring_arm.global_transform.basis)
		
		if is_charging:
			charge_value = move_toward(charge_value, 1.0, 3 * delta)
			if force_bar:
				force_bar.show()
				force_bar.value = charge_value * 100
	
	if not is_on_floor():
		velocity.y -= gravity * delta

	var final_input = input_dir_server if multiplayer.is_server() else Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var final_basis = camera_basis_server if multiplayer.is_server() else spring_arm.global_transform.basis

	var direction = (final_basis.z * final_input.y + final_basis.x * final_input.x)
	direction.y = 0
	direction = direction.normalized()

	if is_on_floor():
		if direction != Vector3.ZERO:
			var dot = direction.dot(velocity.normalized())
			var curve_resistance = clamp(dot, 0.3, 0.7)
			velocity.x = lerp(velocity.x, direction.x * current_speed, (acceleration * curve_resistance) * delta)
			velocity.z = lerp(velocity.z, direction.z * current_speed, (acceleration * curve_resistance) * delta)
		else:
			velocity.x = lerp(velocity.x, 0.0, friction * delta)
			velocity.z = lerp(velocity.z, 0.0, friction * delta)
		
		if is_multiplayer_authority() and Input.is_action_just_pressed("ui_accept"):
			server_jump.rpc_id(1)
	
	move_and_slide()
	
	if multiplayer.is_server():
		server_process_dribble(delta)

func _input(event):
	if not is_multiplayer_authority(): return
		
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		server_update_sprint.rpc_id(1, event.pressed)
		
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT: start_charging("kick")
			elif event.button_index == MOUSE_BUTTON_RIGHT: start_charging("pass")
		elif not event.pressed and is_charging:
			finish_command()

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		camera_pivot.rotate_y(-event.relative.x * 0.005)
		spring_arm.rotate_x(-event.relative.y * 0.005)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-60), deg_to_rad(30))

func start_charging(type):
	is_charging = true
	current_action = type
	charge_value = 0.0
	sync_charging_state.rpc_id(1, true)

func finish_command():
	var camera = $CameraPivot/SpringArm3D/Camera3D
	var aim_dir = -camera.global_transform.basis.z.normalized()
	
	if not aim_dir.is_finite() or aim_dir == Vector3.ZERO:
		aim_dir = -global_transform.basis.z.normalized()
		
	server_execute_kick.rpc_id(1, current_action, charge_value, aim_dir)
	is_charging = false
	sync_charging_state.rpc_id(1, false) # Avisa o servidor
	if force_bar: force_bar.hide()

@rpc("any_peer", "call_remote", "reliable")
func sync_charging_state(state: bool):
	is_charging = state

@rpc("any_peer", "call_remote", "reliable")
func server_jump():
	if not multiplayer.is_server(): return
	if is_on_floor():
		velocity.y = jump_force

@rpc("any_peer", "call_remote", "reliable")
func server_update_sprint(is_sprinting):
	target_speed = 14.0 if is_sprinting else 10.0
	dribble_force = 12.0 if is_sprinting else 8.0

@rpc("any_peer", "call_remote", "reliable")
func server_execute_kick(type, power, aim_direction):
	if not multiplayer.is_server(): return
	
	var bodies = kick_area.get_overlapping_bodies()
	for body in bodies:
		if body is RigidBody3D:
			var force_multiplier = clamp(0.8 + power, 0.8, 1.8)
			var side_curve = calculate_side_curve(body)
			var impulse = aim_direction.normalized()
			
			var base_f = kick_force if type == "kick" else pass_force
			var incl_y = (0.15 if type == "kick" else 0.05) + (power * 0.1)
			
			impulse.y = incl_y
			var total_impulse = impulse * (base_f * force_multiplier)
			
			if body.has_method("apply_impulse_synced"):
				body.apply_impulse_synced(total_impulse)
				body.apply_effect(side_curve * curve_intensity * -1.0)
			
			dribble_cooldown = 0.5
			
			if body.has_method("registrar_toque"):
				var team = "vermelho" if is_in_group("vermelho") else "azul"
				body.registrar_toque(self, team)
			break

func server_process_dribble(delta):
	if is_charging: return
	
	dribble_cooldown -= delta
	if dribble_cooldown <= 0:
		var bodies = dribble_area.get_overlapping_bodies()
		for body in bodies:
			if body is RigidBody3D:
				var player_vel_dir = velocity.normalized()
				var to_ball = (body.global_position - global_position).normalized()
				
				var dot = abs(player_vel_dir.dot(to_ball))
				
				var lateral_bonus = lerp(2.0, 1.0, dot) 
				
				var look_direction = -camera_basis_server.z
				look_direction.y = 0.1
				look_direction = look_direction.normalized()
				
				var final_force = dribble_force * lateral_bonus
				if target_speed > 11.0: final_force *= 1.5
				
				var impulse = look_direction * final_force
				
				if body.has_method("apply_impulse_synced"):
					body.apply_impulse_synced(impulse)
				
				dribble_cooldown = 0.5
				break

func calculate_side_curve(ball: RigidBody3D) -> float:
	var look_dir = -camera_basis_server.z
	look_dir.y = 0
	look_dir = look_dir.normalized()
	
	var right_dir = look_dir.cross(Vector3.UP)
	
	var to_ball = ball.global_position - global_position
	to_ball.y = 0
	
	var side_dot = to_ball.dot(right_dir)
	
	var curve = clamp(side_dot, -1.0, 1.0)
	if abs(curve) < 0.1: return 0.0
	return curve

@rpc("any_peer", "call_remote", "unreliable")
func update_input_server(id_dir, cam_basis):
	input_dir_server = id_dir
	camera_basis_server = cam_basis
