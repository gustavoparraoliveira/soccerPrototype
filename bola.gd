extends RigidBody3D

var intensidade_efeito = 0.0
@export var raio_bola = 0.22 
@export var coeficiente_magnus = 800
@export var ultimo_jogador_toque = null
@export var ultimo_time_toque = ""

func aplicar_efeito(valor: float):
	intensidade_efeito = valor

func _physics_process(delta):
	if not GDSync.is_host():
		return
		
	if abs(intensidade_efeito) > 0.1:
		var speed = linear_velocity.length()
		
		if speed < 10.0:
			intensidade_efeito = 0.0
			return

		var direcao_movimento = linear_velocity.normalized()
		
		# Magnus proporcional ao quadrado da velocidade para compensar chutes fortes
		var forca_magnus = direcao_movimento.cross(Vector3.UP) * intensidade_efeito * coeficiente_magnus
		
		# Aumentei o multiplicador para 80.0 e usei speed * speed
		apply_central_force(forca_magnus * speed * 80.0)
		
		intensidade_efeito = lerp(intensidade_efeito, 0.0, delta * 0.2)

	if linear_velocity.length() > 0.2:
		var eixo_rolagem = linear_velocity.normalized().cross(Vector3.UP)
		var velocidade_rolagem = linear_velocity.length() / raio_bola
		
		# Inverti o sinal do efeito visual para condizer com a curva física
		var efeito_visual = Vector3.UP * (intensidade_efeito * -5.0)
		var rotacao_final = (-eixo_rolagem * velocidade_rolagem) + efeito_visual
		
		angular_velocity = lerp(angular_velocity, rotacao_final, delta * 5.0)


func _on_body_entered(body):
	if body.is_in_group("vermelho"):
		ultimo_time_toque = "vermelho"
	elif body.is_in_group("azul"):
		ultimo_time_toque = "azul"
		
	intensidade_efeito *= 0.2

func registrar_toque(jogador, time):
	ultimo_jogador_toque = jogador
	ultimo_time_toque = time
