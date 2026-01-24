shader_type spatial;

void fragment() {
	float total_faixas = 44.0;
	
	float padrao = fract(UV.y * (total_faixas / 2.0));
	
	float mascara = step(0.5, padrao);
	
	vec3 verde_escuro = vec3(0.1, 0.4, 0.1);
	vec3 verde_claro = vec3(0.15, 0.5, 0.15);
	
	ALBEDO = mix(verde_escuro, verde_claro, mascara);
	
	// Aumenta a rugosidade para remover o brilho reflexivo (0.0 a 1.0)
	ROUGHNESS = 1.0;
	// Opcional: diminui o brilho especular para ajudar a tirar o reflexo
	SPECULAR = 0.0;
}