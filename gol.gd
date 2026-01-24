extends StaticBody3D

# Criamos um sinal para o Mundo "ouvir"
signal gol_marcado(time_nome)

@export var nome_do_time = "Time A" # No outro gol, mude para "Time B" no Inspector

func _on_area_gol_body_entered(body):
	if body is RigidBody3D:
		gol_marcado.emit(nome_do_time) # Agora o Mundo vai ouvir!

func resetar_bola(bola):
	await get_tree().create_timer(1.0).timeout
	bola.linear_velocity = Vector3.ZERO
	bola.angular_velocity = Vector3.ZERO
	bola.global_position = Vector3(0, 2, 0) # Centro do campo
