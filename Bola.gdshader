shader_type spatial;

uniform vec3 cor_hexagono : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cor_pentagono : source_color = vec3(0.05, 0.05, 0.05);
uniform float linha_grossura : hint_range(0.0, 0.1) = 0.02;

// Função para gerar o padrão baseado na posição 3D
void fragment() {
	// Usamos a normal do objeto para determinar a cor em 3D
	vec3 p = NORMAL;
	
	// Constantes matemáticas para a geometria da bola de futebol
	float phi = (1.0 + sqrt(5.0)) / 2.0;
	
	// Definimos os eixos dos pentágonos
	vec3 pentagonos[12];
	pentagonos[0] = normalize(vec3(0, 1, phi));
	pentagonos[1] = normalize(vec3(0, 1, -phi));
	pentagonos[2] = normalize(vec3(0, -1, phi));
	pentagonos[3] = normalize(vec3(0, -1, -phi));
	pentagonos[4] = normalize(vec3(1, phi, 0));
	pentagonos[5] = normalize(vec3(1, -phi, 0));
	pentagonos[6] = normalize(vec3(-1, phi, 0));
	pentagonos[7] = normalize(vec3(-1, -phi, 0));
	pentagonos[8] = normalize(vec3(phi, 0, 1));
	pentagonos[9] = normalize(vec3(phi, 0, -1));
	pentagonos[10] = normalize(vec3(-phi, 0, 1));
	pentagonos[11] = normalize(vec3(-phi, 0, -1));

	float max_dot = 0.0;
	for(int i = 0; i < 12; i++) {
		max_dot = max(max_dot, dot(p, pentagonos[i]));
	}

	// Criamos a máscara para os pentágonos (os centros pretos)
	// 0.945 é o tamanho aproximado do pentágono na esfera
	float mascara_pentagono = step(0.945, max_dot);
	
	// Criamos a borda/costura das linhas
	float borda = step(0.935, max_dot) - mascara_pentagono;
	
	// Mix final de cores
	vec3 cor_base = mix(cor_hexagono, cor_pentagono, mascara_pentagono);
	
	// Adiciona a linha de costura (opcional, cor cinza escuro)
	cor_base = mix(cor_base, vec3(0.1), borda * 0.5);

	ALBEDO = cor_base;
	ROUGHNESS = 0.2; // Brilho de material sintético
}