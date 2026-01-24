extends Node3D

@export var cena_bola: PackedScene = preload("res://Bola-synced.tscn")    
@export var cena_jogador_vermelho: PackedScene = preload("res://Jogador_vermelho.tscn")
@export var cena_jogador_azul: PackedScene = preload("res://Jogador_azul.tscn")
@onready var label_placar = $CanvasLayer/LabelPlacar
@onready var spawn_bola = $SpawnBola
@onready var nomeSala = $CanvasLayer/NomeSala
@onready var console_visual = $CanvasLayer/ConsoleVisual

var bola_atual : RigidBody3D
var resetando = false 

var numeroDeJogadores : int

signal bola_resetou(pontos_time_a, pontos_time_b)
var pontos_time_a = 0
var pontos_time_b = 0
var placar_text = str(pontos_time_a) + " - " + str(pontos_time_b)

@onready var jogadores :Array
var timeVermelho :Array
var timeAzul :Array
var cores = [Color.RED, Color.BLUE]

func _ready():
	GDSync.connected.connect(connected)
	GDSync.lobby_created.connect(lobby_created)
	
	GDSync.client_joined.connect(client_joined)
	GDSync.client_left.connect(jogador_saiu)
	
	GDSync.expose_signal(bola_resetou)	
	#GDSync.expose_var(self, "jogadores")

	GDSync.start_multiplayer()
	
	$CanvasLayer/ButtonHost.pressed.connect(criar_sala_gdsync)
	$CanvasLayer/ButtonJoin.pressed.connect(entrar_sala_gdsync)
	
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	
	$GolA.gol_marcado.connect(_ao_marcar_gol)
	$GolB.gol_marcado.connect(_ao_marcar_gol)
	
	GDSync.lobby_set_data("numeroJogadores", 0)

func connected():
	console_print("GDSync connected!")

func connection_failed(error):
	match(error):
		ENUMS.CONNECTION_FAILED.TIMEOUT:
			push_error("Connection failed (Timeout)")

func lobby_created(lobby_name):
	console_print("Created lobby " + lobby_name)
	
	GDSync.lobby_join(lobby_name)

func lobby_creation_failed(lobby_name, error):
	console_print("Failed to create lobby " + lobby_name)
	
	if error == ENUMS.LOBBY_CREATION_ERROR.LOBBY_ALREADY_EXISTS:
		GDSync.lobby_join(lobby_name)

func client_joined(_client_id):
	esconder_menu()
	
	var id = GDSync.get_client_id()
	instanciar_jogador(id)
	
	numeroDeJogadores = GDSync.lobby_get_data("numeroJogadores", 0)
	GDSync.lobby_set_data("numeroJogadores", numeroDeJogadores + 1)
	
	console_print("numeroDeJogadores depois: " + str(numeroDeJogadores))
	
func lobby_join_failed(lobby_name):
	console_print("Failed to join lobby " + lobby_name)

func criar_sala_gdsync():
	var nome_sala = nomeSala.text if nomeSala.text != "" else "SalaPadrao"
	GDSync.lobby_create(nome_sala)
	esconder_menu()

func entrar_sala_gdsync():
	var nome_sala = nomeSala.text
	GDSync.lobby_join(nome_sala)
	esconder_menu()

func console_print(texto: String, cor: String = "white"):
	# 1. console_printa no terminal do Godot para debug real
	print(texto)
	
	if not console_visual:
		return
		
	var tempo = Time.get_time_string_from_system()
	
	var mensagem_formatada = "[color=gray][" + tempo + "][/color] "
	mensagem_formatada += "[color=" + cor + "]" + texto + "[/color]\n"
	
	console_visual.append_text(mensagem_formatada)
	
	var scrollbar = console_visual.get_v_scroll_bar()
	scrollbar.value = scrollbar.max_value

func esconder_menu():
	$CanvasLayer/ButtonHost.hide()
	$CanvasLayer/ButtonJoin.hide()
	$CanvasLayer/NomeSala.hide()

func instanciar_jogador(idJogador):
	if has_node(str(idJogador)):
		return
	
	numeroDeJogadores = GDSync.lobby_get_data("numeroJogadores", 0)	
	var corJogador = cena_jogador_vermelho
	
	if numeroDeJogadores % 2 == 0:
		corJogador = cena_jogador_vermelho
	else:
		corJogador = cena_jogador_azul
	
	var jogador = GDSync.multiplayer_instantiate(corJogador, get_tree().current_scene, true,[], true)
	jogador.name = str(idJogador)
	
	if corJogador == cena_jogador_vermelho: jogador.add_to_group("vermelho")
	else: jogador.add_to_group("azul")
	
	GDSync.set_gdsync_owner(jogador, idJogador)	
	jogador.global_position = $SpawnJogador.global_position
	
	console_print("Jogador entrou com ID " + str(idJogador))
	
	return jogador


func jogador_saiu(idJogador):
	console_print("Jogador saiu com ID " + str(idJogador))
	
	var jogador = get_node_or_null(str(idJogador))
	
	if jogador != null:
		jogador.queue_free()
	
func instanciar_nova_bola():
	atualizar_interface_cliente(pontos_time_a, pontos_time_b)
	if not GDSync.is_host(): return
	
	bola_atual = GDSync.multiplayer_instantiate(cena_bola, get_tree().current_scene, true,[], true)
	bola_atual.global_position = $SpawnBola.global_position
	GDSync.emit_signal_remote(bola_resetou)
	

func _ao_marcar_gol(time):
	if resetando: return
	
	resetando = true
	
	if time == "Time A":
		pontos_time_a += 1
	else: 
		pontos_time_b += 1
	console_print("Gol!")
	
	atualizar_interface_cliente(pontos_time_a, pontos_time_b)
	
	if GDSync.is_host(): 
		await get_tree().create_timer(1.0).timeout
		resetar_partida_multiplayer()
		GDSync.emit_signal_remote(bola_resetou)

func atualizar_interface_cliente(pa, pb):
	pontos_time_a = pa
	pontos_time_b = pb
	label_placar.text = str(pa) + " - " + str(pb)
	piscar_placar(Color.YELLOW)
	await get_tree().create_timer(1.0).timeout
	resetando = false

func _on_area_fora_body_entered(body: Node3D) -> void:
	if resetando: return
	
	resetando = true
	
	if body.is_in_group("bolas"):
		piscar_placar(Color.RED)
		console_print("Fora!")
	
	if GDSync.is_host():
		await get_tree().create_timer(1.0).timeout
		resetar_partida_multiplayer()
	
	await get_tree().create_timer(1.0).timeout
	resetando = false
	atualizar_interface_cliente(pontos_time_a, pontos_time_b)

func resetar_partida_multiplayer():
	GDSync.multiplayer_queue_free(bola_atual)
	instanciar_nova_bola()
	resetando = false

func piscar_placar(cor_pisca: Color):
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(label_placar, "modulate", cor_pisca, 0.1)
	tween.tween_property(label_placar, "modulate", Color.WHITE, 0.1)
	
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if GDSync.is_host():
			resetar_placar_total()
		atualizar_interface_cliente(pontos_time_a, pontos_time_b)
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		if GDSync.is_host():
			posicionar_penalti()
		atualizar_interface_cliente(pontos_time_a, pontos_time_b)
	
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		get_tree().quit()

func posicionar_penalti():
	GDSync.multiplayer_queue_free(bola_atual)
	bola_atual = GDSync.multiplayer_instantiate(cena_bola, get_tree().current_scene, true,[], true)
	bola_atual.global_position = $SpawnPenalti.global_position
	resetando = false

func resetar_placar_total():
	resetando = true
	
	pontos_time_a = 0
	pontos_time_b = 0
	atualizar_interface_cliente(pontos_time_a, pontos_time_b)

	resetar_partida_multiplayer()
	console_print("Placar resetado.")
