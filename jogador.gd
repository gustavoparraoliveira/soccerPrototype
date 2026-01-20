extends CharacterBody3D

@export var velocidade = 12.0
@export var forca_chute = 20.0
@export var forca_chute_alto = 28.0
@export var intensidade_curva = 5.0

@export var SPEED = 10.0
@export var ACELERACAO = 10.0
@export var ATRITO = 8.0

@onready var giro_camera = $GiroCamera
@onready var area_chute = $GiroCamera/AreaChute
@onready var area_conducao = $AreaConducao
@onready var spring_arm = $GiroCamera/SpringArm3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var cooldown_drible = 0.0

@onready var mesh = $MeshInstance3D 
@export var color :Color

func _ready():
	add_to_group("jogadores")
	
	var minha_camera = $GiroCamera/SpringArm3D/Camera3D
	
	await get_tree().process_frame
	
	if GDSync.is_gdsync_owner(self):
		
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		minha_camera.make_current()
	else:
		minha_camera.current = false
		minha_camera.queue_free()
	
func definirCor(assigned_color):
	color = assigned_color
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	mesh.set_surface_override_material(0, material)
	
func _unhandled_input(event):
	if not GDSync.is_gdsync_owner(self):
		return
		
	if event is InputEventMouseMotion:
		giro_camera.rotate_y(-event.relative.x * 0.005)
		spring_arm.rotate_x(-event.relative.y * 0.005)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-60), deg_to_rad(30))

func _physics_process(delta):
	if not GDSync.is_gdsync_owner(self):
		return
		
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_key_pressed(KEY_S): input_dir.y += 1
	
	var direcao = (spring_arm.global_transform.basis.z * input_dir.y + spring_arm.global_transform.basis.x * input_dir.x)
	direcao.y = 0
	direcao = direcao.normalized()

	if direcao != Vector3.ZERO:
		velocity.x = lerp(velocity.x, direcao.x * SPEED, ACELERACAO * delta)
		velocity.z = lerp(velocity.z, direcao.z * SPEED, ACELERACAO * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, ATRITO * delta)
		velocity.z = lerp(velocity.z, 0.0, ATRITO * delta)

	move_and_slide()
	processar_conducao(delta)

func processar_conducao(delta):
	if not GDSync.is_gdsync_owner(self):
		return
		
	cooldown_drible -= delta
	if cooldown_drible <= 0:
		var corpos_conducao = area_conducao.get_overlapping_bodies()
		for corpo in corpos_conducao:
			if corpo is RigidBody3D and velocity.length() > 0.5:
				var vel_relativa = velocity.length() - corpo.linear_velocity.length()
				if vel_relativa > 0:
					var direcao_conducao = velocity.normalized()
					solicitar_impulso_servidor(corpo.get_path(), direcao_conducao * vel_relativa * (velocity.length() * 0.3), Vector3.ZERO)
					cooldown_drible = 0.15

func _input(event):
	if not GDSync.is_gdsync_owner(self):
		return
		
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			tentar_chutar()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			tentar_chute_alto()

func tentar_chutar():
	var multiplicador_velocidade = 0.8 + (velocity.length() / SPEED)
	preparar_chute_rpc(forca_chute * multiplicador_velocidade, 0.2)

func tentar_chute_alto():
	var multiplicador_velocidade = 0.8 + (velocity.length() / SPEED)
	preparar_chute_rpc(forca_chute_alto * multiplicador_velocidade, 0.7)

func preparar_chute_rpc(forca_base, inclinacao_y):
	var corpos_no_chute = area_chute.get_overlapping_bodies()
	for corpo in corpos_no_chute:
		if corpo is RigidBody3D:
			var desvio = calcular_efeito_lateral(corpo)
			var forca_efeito = desvio * intensidade_curva * -1.0
			
			if Input.is_key_pressed(KEY_SHIFT):
				forca_efeito *= -1.0
			
			var direcao_mira = -$GiroCamera/SpringArm3D/Camera3D.global_transform.basis.z
			var impulso = direcao_mira.normalized()
			impulso.y = inclinacao_y
			
			solicitar_chute_servidor(corpo.get_path(), impulso * forca_base, forca_efeito)

func solicitar_chute_servidor(bola_path, impulso, efeito):
	var bola = get_node_or_null(bola_path)
	if bola and bola is RigidBody3D:
		bola.apply_central_impulse_synced(impulso)
		if bola.has_method("aplicar_efeito"):
			bola.aplicar_efeito(efeito)

func solicitar_impulso_servidor(bola_path, impulso, _extra):
	var bola = get_node_or_null(bola_path)
	if bola and bola is RigidBody3D:
		bola.apply_central_impulse_synced(impulso)

func calcular_efeito_lateral(bola: RigidBody3D) -> float:
	var posicao_local = area_chute.to_local(bola.global_position)
	var desvio_suave = clamp(posicao_local.x, -1.5, 1.5)
	return desvio_suave
