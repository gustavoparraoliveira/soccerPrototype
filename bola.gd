extends RigidBody3D

var intensidade_efeito = 0.0
@export var raio_bola = 0.3

func aplicar_efeito(valor: float):
	intensidade_efeito = valor

func _physics_process(delta):
	if not GDSync.is_host():
		return
		
	if intensidade_efeito != 0:
		if linear_velocity.length() < 2.0:
			intensidade_efeito = 0
			return

		var direcao_movimento = linear_velocity.normalized()
		
		var forca_lateral = direcao_movimento.cross(Vector3.UP) * intensidade_efeito * (linear_velocity.length() * 0.2)
		forca_lateral = forca_lateral.limit_length(15.0) 
		
		var compensacao = direcao_movimento * abs(intensidade_efeito * 0.3)
		
		apply_central_force(forca_lateral)
		apply_central_force(compensacao)
		
		intensidade_efeito = lerp(intensidade_efeito, 0.0, delta * 3.0)

	if linear_velocity.length() > 0.1:
		var eixo_rotacao = linear_velocity.normalized().cross(Vector3.UP)
		var velocidade_angular = linear_velocity.length() / raio_bola
		angular_velocity = lerp(angular_velocity, -eixo_rotacao * velocidade_angular, delta)

func _on_body_entered(_body):
	intensidade_efeito = 0.0
