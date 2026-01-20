shader_type spatial;

void fragment() {
	// 1. O número de faixas totais (ex: 10 faixas)
	float total_faixas = 44.0;
	
	// 2. Criamos uma repetição linear de 0 a 1 em cada faixa
	// Multiplicamos a UV pela quantidade e pegamos apenas a parte fracionária
	float padrao = fract(UV.y * (total_faixas / 2.0));
	
	// 3. 'step' em 0.5 divide a faixa exatamente no meio: 
	// Metade (0.0 a 0.5) vira 0, a outra metade (0.5 a 1.0) vira 1.
	float mascara = step(0.5, padrao);
	
	// Cores do campo
	vec3 verde_escuro = vec3(0.1, 0.4, 0.1);
	vec3 verde_claro = vec3(0.15, 0.5, 0.15);
	
	// Aplica a cor final baseada na máscara binária
	ALBEDO = mix(verde_escuro, verde_claro, mascara);
}