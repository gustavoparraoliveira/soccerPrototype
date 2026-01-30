extends CharacterBody3D

@onready var input = $PlayerInput
@onready var rollback_synchronizer = $RollbackSynchronizer
@export var peer_id = 0
@export var team = ""
@export var kick_force = 35.0
@export var pass_force = 20.0
@export var dribble_force = 7.0
@export var base_speed = 10.0
@export var acceleration = 30.0
@export var friction = 20.0
@export var jump_force = 4.5
@export var reset_pos: Vector3
@onready var input_node = $PlayerInput
@onready var camera_pivot = $CameraPivot
@onready var kick_area = $CameraPivot/AreaKick
@onready var dribble_area = $CameraPivot/AreaDribble
@onready var spring_arm = $CameraPivot/SpringArm3D
@onready var force_bar = $CanvasLayer/ForceBar

var current_speed = 10.0
var charge_value = 0.0
var is_charging = false
var was_charging = false
var is_waiting_to_shoot = false
var current_action = ""
var dribble_cooldown = 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var resetting = false

func _ready():
	await get_tree().process_frame
	peer_id = int(self.name)
	set_multiplayer_authority(1)
	input.set_multiplayer_authority(peer_id)
	
	if multiplayer.get_unique_id() == peer_id:
		$CameraPivot/SpringArm3D/Camera3D.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		$CameraPivot/SpringArm3D/Camera3D.current = false
		
	rollback_synchronizer.process_settings()
	

func _rollback_tick(delta, _tick, _is_fresh):
	camera_pivot.rotation.y = input_node.look_yaw
	spring_arm.rotation.x = input_node.look_pitch
	
	is_charging = input_node.charging
	
	_process_movement(delta)
	_process_actions(delta)
	
	if multiplayer.is_server():
		server_process_dribble(delta)
	
	if resetting:
		reset_position(reset_pos)

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity

func _process(_delta):
	if multiplayer.get_unique_id() == peer_id:
		camera_pivot.rotation.y = input_node.look_yaw
		spring_arm.rotation.x = input_node.look_pitch

func _process_movement(delta):
	var target_vel = 14.0 if input_node.sprinting else 10.0
	current_speed = move_toward(current_speed, target_vel, 10.0 * delta)
	
	var move_dir = (camera_pivot.global_transform.basis.z * input_node.movement_vector.y + camera_pivot.global_transform.basis.x * input_node.movement_vector.x)
	move_dir.y = 0
	move_dir = move_dir.normalized()

	if is_on_floor():
		if move_dir != Vector3.ZERO:
			velocity.x = move_toward(velocity.x, move_dir.x * current_speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, move_dir.z * current_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, friction * delta)
			velocity.z = move_toward(velocity.z, 0, friction * delta)
		
	move_and_slide()

func _process_actions(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif input_node.jumping:
		print("tentando pular")
		velocity.y = jump_force
	
	if input_node.charging:
		is_charging = true
		was_charging = true
		current_action = input_node.action_type
		charge_value = move_toward(charge_value, 1.2, delta)
		if multiplayer.get_unique_id() == peer_id and force_bar:
			force_bar.show()
			force_bar.value = (charge_value / 1.2) * 100
	
	if was_charging and not input_node.charging:
		if _check_and_execute_auto_kick():
			_reset_kick_state()
		was_charging = false
		_reset_kick_state()

func _check_and_execute_auto_kick() -> bool:
	for body in kick_area.get_overlapping_bodies():
		if body is RigidBody3D and body.is_in_group("ball"):
			print("chutei")
			execute_kick(current_action, charge_value, input_node.aim_direction)
			return true
	return false

func _reset_kick_state():
	charge_value = 0.0
	if multiplayer.get_unique_id() == peer_id and force_bar:
		force_bar.hide()
		force_bar.value = 0

func execute_kick(type, power, aim_dir):
	for body in kick_area.get_overlapping_bodies():
		if body is RigidBody3D:
			var base_f = kick_force 
			var impulse = aim_dir.normalized()
			if type == "kick":
				impulse.y += 0.2 + (power * 0.3)
			else:
				base_f = pass_force 
				impulse.y += 0.2 + (power * 0.2)
				
			if body.has_method("apply_impulse_synced"):
				body.apply_impulse_synced(impulse * (base_f * power))
				
				if body.has_method("apply_effect"):
					var local_ball_pos = kick_area.to_local(body.global_position)
					var side_offset = -local_ball_pos.x 
					var curve_intensity = side_offset * power
					
					body.apply_effect(curve_intensity)
					body.last_team_touch = team
			
			dribble_cooldown = 0.6
			break

func server_process_dribble(delta):
	if input_node.charging or not is_on_floor(): return
	
	dribble_cooldown -= delta
	if dribble_cooldown <= 0:
		for body in dribble_area.get_overlapping_bodies():
			if body is RigidBody3D:
				var look_dir = -spring_arm.global_transform.basis.z
				look_dir.y = 0.1
				var f = (dribble_force * 1.3) if current_speed > 11.0 else dribble_force
				if body.has_method("apply_impulse_synced"):
					body.apply_impulse_synced(look_dir.normalized() * f)
				dribble_cooldown = 0.1
				break

func reset_position(pos):	
	if not resetting: return
	
	reset_pos = pos
	
	if global_position != pos:
		global_position = pos
		velocity = Vector3.ZERO
		quaternion = Quaternion.IDENTITY
		
		if has_node("RollbackSynchronizer"):
			$RollbackSynchronizer.process_settings()
	else: 
		resetting = false
