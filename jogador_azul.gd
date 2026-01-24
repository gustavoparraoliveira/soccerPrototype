extends CharacterBody3D

@export var forca_chute = 16.0
@export var forca_passe = 7.0
@export var forca_conducao = 2.0
@export var intensidade_curva = 10.0
@export var SPEED = 10.0
@export var speed_alvo = 10.0
@export var ACELERACAO = 8.0
@export var ATRITO = 8.0
@export var FORCA_PULO = 5.5

@onready var giro_camera = $GiroCamera
@onready var area_chute = $GiroCamera/AreaChute
@onready var area_conducao = $AreaConducao
@onready var spring_arm = $GiroCamera/SpringArm3D

var forca_carregada = 0.0
var carregando = false
var acao_atual = ""
@onready var barra_ui = $CanvasLayer/BarraForca

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var cooldown_drible = 0.0

@onready var mesh = $MeshInstance3D 
@export var color = Color.GREEN

func _ready():
	add_to_group("azul")
	
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
		
	SPEED = lerp(SPEED, speed_alvo, 2.0 * delta)
	
	if carregando:
		forca_carregada = move_toward(forca_carregada, 1.0, 3 * delta)
		if barra_ui:
			barra_ui.visible = true
			barra_ui.value = forca_carregada * 100
			
		
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = FORCA_PULO

	var input_dir = Vector2.ZERO
	
	if is_on_floor():
		if Input.is_key_pressed(KEY_A): input_dir.x -= 1
		if Input.is_key_pressed(KEY_D): input_dir.x += 1
		if Input.is_key_pressed(KEY_W): input_dir.y -= 1
		if Input.is_key_pressed(KEY_S): input_dir.y += 1
	
	var direcao = (spring_arm.global_transform.basis.z * input_dir.y + spring_arm.global_transform.basis.x * input_dir.x)
	direcao.y = 0
	direcao = direcao.normalized()

	if is_on_floor():
		if direcao != Vector3.ZERO:
			var dot = direcao.dot(velocity.normalized())
			var resistencia_curva = clamp(dot, 0.3, 0.7)
			
			velocity.x = lerp(velocity.x, direcao.x * SPEED, (ACELERACAO * resistencia_curva) * delta)
			velocity.z = lerp(velocity.z, direcao.z * SPEED, (ACELERACAO * resistencia_curva) * delta)
		else:
			velocity.x = lerp(velocity.x, 0.0, ATRITO * delta)
			velocity.z = lerp(velocity.z, 0.0, ATRITO * delta)

	move_and_slide()
	if not carregando:
		processar_conducao(delta)

func processar_conducao(delta):
	if not GDSync.is_gdsync_owner(self):
		return
		
	cooldown_drible -= delta
	if cooldown_drible <= 0:
		var corpos_conducao = area_conducao.get_overlapping_bodies()
		for corpo in corpos_conducao:
			if corpo is RigidBody3D and velocity.length() > 0.5:
				var cam = $GiroCamera/SpringArm3D/Camera3D
				var direcao_mira = -cam.global_transform.basis.z
				direcao_mira.y = 0
				direcao_mira = direcao_mira.normalized()
				
				var impulso = direcao_mira * (velocity.length() + forca_conducao)
				
				solicitar_impulso_servidor(corpo.get_path(), impulso, Vector3.ZERO)
				cooldown_drible = 0.2
				

func _input(event):
	if not GDSync.is_gdsync_owner(self):
		return
		
	if event is InputEventKey and event.keycode == KEY_SHIFT:	
		if event.pressed:
			speed_alvo = 14.0
			forca_conducao = 6.0
		else:
			speed_alvo = 10.0
			forca_conducao = 2.0
		
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				iniciar_carregamento("chute")
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				iniciar_carregamento("passe")
		elif not event.pressed:
			if carregando:
				tentar_finalizar_comando()

func iniciar_carregamento(tipo):
	carregando = true
	acao_atual = tipo
	forca_carregada = 0.0

func tentar_finalizar_comando():
	if not carregando: return
	carregando = false
	
	var corpos = area_chute.get_overlapping_bodies()
	var bola_detectada = false
	for corpo in corpos:
		if corpo is RigidBody3D:
			executar_chute_efetivo(corpo)
			bola_detectada = true
			break
	if barra_ui: barra_ui.visible = false

func executar_chute_efetivo(bola):
	var multi_forca = clamp(0.8 + forca_carregada, 0.8, 1.8)
	
	var desvio = calcular_efeito_lateral(bola)
	var forca_efeito = desvio * intensidade_curva * -1.0
	
	var direcao_mira = -$GiroCamera/SpringArm3D/Camera3D.global_transform.basis.z
	var impulso = direcao_mira.normalized()
	
	var f_base = 0.0
	var incl_y = 0.0
	
	if acao_atual == "chute":
		f_base = forca_chute * multi_forca 
		incl_y = 0.15 + (forca_carregada * 0.1)
	else:
		f_base = forca_passe * multi_forca 
		incl_y = 0.05 + (forca_carregada * 0.1)
	
	impulso.y = incl_y
	
	solicitar_chute_servidor(bola.get_path(), impulso * (f_base * multi_forca), forca_efeito)
	
	if bola.has_method("registrar_toque"):
		var meu_time = "vermelho" if self.is_in_group("vermelho") else "azul"
		bola.registrar_toque(self, meu_time)
	
	await get_tree().create_timer(0.2).timeout
	
	acao_atual = ""
	

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
	var transform_area = area_chute.global_transform
	var posicao_bola_local = transform_area.affine_inverse() * bola.global_position
	
	print("Posição Local da Bola no X: ", posicao_bola_local.x)
	
	return clamp(posicao_bola_local.x, -1.5, 1.5)
