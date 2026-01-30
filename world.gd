extends Node3D

@export var player_red_scene: PackedScene = preload("res://player_red.tscn")
@export var player_blue_scene: PackedScene = preload("res://player_blue.tscn")
@export var ball_scene: PackedScene = preload("res://Bola.tscn")

@onready var score_label = $CanvasLayer/LabelPlacar
@onready var ball_spawn = $SpawnBola
@onready var visual_console = $CanvasLayer/ConsoleVisual
@onready var lobby_name_input = $CanvasLayer/LobbyName

var current_ball : RigidBody3D
var is_resetting = false
var score_a = 0
var score_b = 0

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	$CanvasLayer/ButtonHost.pressed.connect(create_server)
	$CanvasLayer/ButtonJoin.pressed.connect(join_server)
	
	if has_node("GoalA"): $GoalA.goal_scored.connect(_on_goal_scored)
	if has_node("GoalB"): $GoalB.goal_scored.connect(_on_goal_scored)
	if has_node("Field"): $Field/OutBounds.body_entered.connect(_on_ball_out)

	if DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--server"):
		create_server()

func create_server():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(4242)
	if error != OK:
		console_print("Erro ao criar servidor: " + str(error), "red")
		return
		
	multiplayer.multiplayer_peer = peer
	
	console_print("Servidor Dedicado iniciado na porta 4242", "green")
	hide_menu()
	
	if multiplayer.is_server():
		await get_tree().create_timer(0.1).timeout
		spawn_ball()

func join_server():
	var peer = ENetMultiplayerPeer.new()
	var ip = lobby_name_input.text if lobby_name_input.text != "" else "127.0.0.1"
	var error = peer.create_client(ip, 4242)
	if error != OK:
		console_print("Erro ao conectar: " + str(error), "red")
		return
		
	multiplayer.multiplayer_peer = peer
	
	hide_menu()

func _on_peer_connected(id):
	console_print("Jogador conectado: " + str(id), "cyan")
	if multiplayer.is_server():
		spawn_player(id)

func _on_peer_disconnected(id):
	console_print("Jogador desconectado: " + str(id), "orange")
	var p = get_node_or_null(str(id))
	if p: p.queue_free()

func spawn_player(id):
	if has_node(str(id)): return
	
	var player_count = get_tree().get_nodes_in_group("players").size()
	var scene = player_red_scene if player_count % 2 == 0 else player_blue_scene
	
	var player = scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	player.add_to_group("players")
	add_child(player, true)
	
	if player_count % 2 == 0:
		player.team = "red" 
		player.add_to_group("red")
		player.global_position = $SpawnRed.global_position
	else: 
		player.team = "blue" 
		player.add_to_group("blue")
		player.global_position = $SpawnBlue.global_position

func spawn_ball():
	if not is_instance_valid(current_ball):
		current_ball = ball_scene.instantiate()
		current_ball.name = "Ball"
		current_ball.add_to_group("ball")
		add_child(current_ball, true)
		current_ball.set_multiplayer_authority(1)
	
	current_ball.reset_to_spawn()

func _on_goal_scored(team):
	if not multiplayer.is_server() or is_resetting: return
	
	is_resetting = true
	if team == "Time A": score_a += 1
	else: score_b += 1
	
	update_score_ui.rpc(score_a, score_b)
	
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(current_ball):
		current_ball.reset_to_spawn()
	is_resetting = false

func reset_after_goal():
	await get_tree().create_timer(1.5).timeout
	spawn_ball()
	is_resetting = false

@rpc("authority", "call_local", "reliable")
func update_score_ui(sa, sb):
	score_a = sa
	score_b = sb
	score_label.text = str(sa) + " - " + str(sb)
	flash_score(Color.YELLOW)

func _on_ball_out(body):
	if not multiplayer.is_server() or is_resetting: return
	
	if body.is_in_group("ball"):
		notify_ball_out_internal()
	
	var pos = body.global_position
	
	if abs(pos.z) > 55.0: # Linha de fundo
		if (pos.z > 0 and body.last_team_touch == "red"):
			setup_set_piece("corner_red", pos)
		elif (pos.z < 0 and body.last_team_touch == "blue"):
			setup_set_piece("corner_blue", pos)
		elif (pos.z < 0 and body.last_team_touch == "red"):
			setup_set_piece("goal_kick_blue", pos)
		elif (pos.z > 0 and body.last_team_touch == "blue"):
			setup_set_piece("goal_kick_red", pos)
	else: # Lateral
		setup_set_piece("throw_in", pos)

func setup_set_piece(type, exit_pos):
	is_resetting = true
	var spawn_pos = exit_pos
	spawn_pos.y = 1.2
	
	match type:
		"corner_blue":
			spawn_pos = $CornerBlueLeft.global_position if exit_pos.x < 0 else $CornerBlueRight.global_position
		"corner_red":
			spawn_pos = $CornerRedLeft.global_position if exit_pos.x < 0 else $CornerRedRight.global_position
		"goal_kick_red":
			spawn_pos = $GoalKickRed.global_position # Ponto fixo na pequena área
		"goal_kick_blue":
			spawn_pos = $GoalKickBlue.global_position # Ponto fixo na pequena área
		"throw_in":
			spawn_pos.x = 34.0 if exit_pos.x > 0 else -34.0 # Linha lateral
	
	await get_tree().create_timer(1.0).timeout
	current_ball.prepare_set_piece(spawn_pos)
	is_resetting = false

func notify_ball_out_internal():
	is_resetting = true
	notify_ball_out.rpc()
	
	await get_tree().create_timer(1.0).timeout
	is_resetting = false

@rpc("authority", "call_local", "reliable")
func notify_ball_out():
	flash_score(Color.RED)
	console_print("Bola fora! Resetando...", "yellow")

func reset_match():
	await get_tree().create_timer(1.5).timeout
	spawn_ball()
	is_resetting = false

func console_print(text: String, color: String = "white"):
	print(text)
	if not visual_console: return
	var time = Time.get_time_string_from_system()
	visual_console.append_text("[color=gray][%s][/color] [color=%s]%s[/color]\n" % [time, color, text])

func hide_menu():
	$CanvasLayer/ButtonHost.hide()
	$CanvasLayer/ButtonJoin.hide()
	$CanvasLayer/LobbyName.hide()

func flash_score(flash_color: Color):
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(score_label, "modulate", flash_color, 0.1)
	tween.tween_property(score_label, "modulate", Color.WHITE, 0.1)
