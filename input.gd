extends Node
class_name PlayerInput

var movement_vector = Vector2.ZERO
var jumping = false
var sprinting = false
var charging = false
var firing = false
var action_type = ""
var aim_direction = Vector3.FORWARD
var charge_value = 0.0

var look_yaw = 0.0
var look_pitch = 0.0
var mouse_sensitivity = 0.005

var _movement_buffer = Vector2.ZERO
var _movement_samples = 0
var _was_charging = false

func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		look_yaw -= event.relative.x * mouse_sensitivity
		look_pitch -= event.relative.y * mouse_sensitivity
		look_pitch = clamp(look_pitch, deg_to_rad(-60), deg_to_rad(30))

func _process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	_movement_buffer += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_movement_samples += 1
	

func _gather():
	if not is_multiplayer_authority(): return
	
	# Média do movimento (Continuous Input)
	if _movement_samples > 0:
		movement_vector = _movement_buffer / _movement_samples
	else:
		movement_vector = Vector2.ZERO
	
	_movement_buffer = Vector2.ZERO
	_movement_samples = 0
	
	jumping = Input.is_action_pressed("ui_accept")
	sprinting = Input.is_key_pressed(KEY_SHIFT)
	charging = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	_was_charging = charging
	
	if charging:
		action_type = "kick" if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else "pass"
	
	var basis = Basis.from_euler(Vector3(look_pitch, look_yaw, 0))
	aim_direction = -basis.z
