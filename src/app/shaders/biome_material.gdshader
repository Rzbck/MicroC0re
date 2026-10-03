shader_type canvas_item;
render_mode unshaded;

uniform sampler2D mask_a : filter_linear, repeat_disable;
uniform sampler2D mask_b : filter_linear, repeat_disable;
uniform vec2 world_size = vec2(384.0, 256.0);
uniform float pixel_world = 0.25;
uniform float scene_light = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 33.33);
	return fract(p.x * p.y);
}

float rect_shape(vec2 p, vec2 center, vec2 half_size) {
	vec2 d = abs(p - center);
	return step(d.x, half_size.x) * step(d.y, half_size.y);
}

float cross_shape(vec2 p, vec2 center, float arm) {
	return max(
		rect_shape(p, center, vec2(arm, 0.45)),
		rect_shape(p, center, vec2(0.45, arm))
	);
}

float field_strength(float value, float low, float high) {
	return smoothstep(low, high, value);
}

void fragment() {
	vec2 world = UV * world_size;
	vec2 pixel = floor(world / pixel_world);

	vec4 a = texture(mask_a, UV);
	vec4 b = texture(mask_b, UV);
	float producer = a.r;
	float detritus = a.g;
	float eps = a.b;
	float damage = a.a;
	float oxygen = b.r;
	float nutrient = b.g;
	float waste = b.b;
	float exudate = b.a;

	vec3 color = vec3(0.0);
	float alpha = 0.0;

	// PRODUCER MAT — deliberate tuft/plate clusters on a 10 px source grid.
	// Hash chooses which whole cluster exists; it never sprays individual pixels.
	vec2 prod_cell = floor(pixel / 10.0);
	vec2 prod_local = mod(pixel, 10.0);
	float prod_h = hash21(prod_cell + vec2(3.0, 11.0));
	float prod_strength = field_strength(producer, 0.055, 0.52);
	vec2 prod_center = vec2(
		3.0 + floor(hash21(prod_cell + vec2(1.0, 4.0)) * 4.0),
		3.0 + floor(hash21(prod_cell + vec2(7.0, 2.0)) * 4.0)
	);
	float prod_shape = max(
		cross_shape(prod_local, prod_center, 2.0),
		rect_shape(
			prod_local,
			prod_center + vec2(2.0, 2.0),
			vec2(1.0, 0.45)
		)
	);
	float prod_cluster = step(prod_h, prod_strength * 0.90);
	float prod_layer = prod_shape * prod_cluster * prod_strength;
	if (prod_layer > 0.01) {
		float highlight = step(
			0.67,
			hash21(prod_cell + vec2(13.0, 5.0))
		);
		vec3 producer_color = mix(
			vec3(0.055, 0.22, 0.09),
			vec3(0.25, 0.63, 0.18),
			highlight
		);
		color = mix(color, producer_color, prod_layer);
		alpha = max(alpha, prod_layer * 0.72);
	}

	// EPS / BIOFILM — connected short matrix strokes, not teal speckle.
	vec2 eps_cell = floor(pixel / 12.0);
	vec2 eps_local = mod(pixel, 12.0);
	float eps_strength = field_strength(eps, 0.025, 0.38);
	float eps_gate = step(
		hash21(eps_cell + vec2(9.0, 1.0)),
		eps_strength * 0.86
	);
	float eps_row = 3.0 + floor(hash21(eps_cell + vec2(2.0, 8.0)) * 6.0);
	float eps_col = 3.0 + floor(hash21(eps_cell + vec2(5.0, 6.0)) * 6.0);
	float eps_shape = max(
		rect_shape(eps_local, vec2(5.5, eps_row), vec2(4.0, 0.45)),
		rect_shape(eps_local, vec2(eps_col, 5.5), vec2(0.45, 3.0))
	);
	float eps_layer = eps_shape * eps_gate * eps_strength;
	if (eps_layer > 0.01) {
		color = mix(color, vec3(0.07, 0.37, 0.33), eps_layer * 0.88);
		alpha = max(alpha, eps_layer * 0.52);
	}

	// DETRITUS — compact particulate fragments, always multi-pixel.
	vec2 det_cell = floor(pixel / 9.0);
	vec2 det_local = mod(pixel, 9.0);
	float det_strength = field_strength(detritus, 0.025, 0.42);
	float det_gate = step(
		hash21(det_cell + vec2(4.0, 15.0)),
		det_strength * 0.88
	);
	vec2 det_center = vec2(
		2.0 + floor(hash21(det_cell + vec2(1.0, 3.0)) * 5.0),
		2.0 + floor(hash21(det_cell + vec2(8.0, 7.0)) * 5.0)
	);
	float det_shape = max(
		rect_shape(det_local, det_center, vec2(1.5, 0.45)),
		rect_shape(det_local, det_center + vec2(1.0, 1.0), vec2(0.45, 0.45))
	);
	float det_layer = det_shape * det_gate * det_strength;
	if (det_layer > 0.01) {
		color = mix(color, vec3(0.48, 0.27, 0.11), det_layer * 0.94);
		alpha = max(alpha, det_layer * 0.64);
	}

	// DAMAGE / LYSIS RESIDUE — warm cross-shaped local scars with highest
	// environmental priority because they explain recent biological events.
	vec2 dmg_cell = floor(pixel / 11.0);
	vec2 dmg_local = mod(pixel, 11.0);
	float dmg_strength = field_strength(damage, 0.018, 0.34);
	float dmg_gate = step(
		hash21(dmg_cell + vec2(6.0, 10.0)),
		dmg_strength * 0.94
	);
	vec2 dmg_center = vec2(
		3.0 + floor(hash21(dmg_cell + vec2(2.0, 9.0)) * 4.0),
		3.0 + floor(hash21(dmg_cell + vec2(12.0, 1.0)) * 4.0)
	);
	float dmg_shape = cross_shape(dmg_local, dmg_center, 1.5);
	float dmg_layer = dmg_shape * dmg_gate * dmg_strength;
	if (dmg_layer > 0.01) {
		float hot = step(0.62, hash21(dmg_cell + vec2(14.0, 4.0)));
		vec3 damage_color = mix(
			vec3(0.50, 0.075, 0.045),
			vec3(0.95, 0.28, 0.08),
			hot
		);
		color = mix(color, damage_color, dmg_layer);
		alpha = max(alpha, dmg_layer * 0.80);
	}

	// EXUDATE / PHYCOSPHERE — small jade-gold paired clusters. Kept quieter
	// than attached biomass, matrix, detritus and fresh damage.
	vec2 exu_cell = floor(pixel / 8.0);
	vec2 exu_local = mod(pixel, 8.0);
	float exu_strength = field_strength(exudate, 0.045, 0.32);
	float exu_gate = step(
		hash21(exu_cell + vec2(7.0, 7.0)),
		exu_strength * 0.58
	);
	vec2 exu_center = vec2(
		2.0 + floor(hash21(exu_cell + vec2(1.0, 12.0)) * 4.0),
		2.0 + floor(hash21(exu_cell + vec2(9.0, 2.0)) * 4.0)
	);
	float exu_shape = max(
		rect_shape(exu_local, exu_center, vec2(0.55, 0.55)),
		rect_shape(exu_local, exu_center + vec2(1.0, 1.0), vec2(0.55, 0.55))
	);
	float exu_layer = exu_shape * exu_gate * exu_strength;
	if (exu_layer > 0.01 && alpha < 0.48) {
		vec3 exu_color = mix(
			vec3(0.16, 0.35, 0.22),
			vec3(0.46, 0.52, 0.18),
			step(0.68, hash21(exu_cell + vec2(3.0, 5.0)))
		);
		color = mix(color, exu_color, exu_layer * 0.76);
		alpha = max(alpha, exu_layer * 0.30);
	}

	// DISSOLVED CHEMISTRY — only exceptional concentrations get a tiny
	// two-pixel notation. Chemistry never competes with organism silhouettes.
	vec2 chem_cell = floor(pixel / 14.0);
	vec2 chem_local = mod(pixel, 14.0);
	vec2 chem_center = vec2(
		4.0 + floor(hash21(chem_cell + vec2(5.0, 2.0)) * 6.0),
		4.0 + floor(hash21(chem_cell + vec2(1.0, 8.0)) * 6.0)
	);
	float chem_pair = max(
		rect_shape(chem_local, chem_center, vec2(0.45, 0.45)),
		rect_shape(chem_local, chem_center + vec2(1.0, 0.0), vec2(0.45, 0.45))
	);

	if (alpha < 0.18) {
		float oxygen_layer = chem_pair
			* field_strength(oxygen, 0.34, 0.82)
			* step(
				hash21(chem_cell + vec2(9.0, 4.0)),
				field_strength(oxygen, 0.34, 0.82) * 0.22
			);
		if (oxygen_layer > 0.01) {
			color = vec3(0.17, 0.48, 0.56);
			alpha = oxygen_layer * 0.18;
		}

		float nutrient_layer = chem_pair
			* field_strength(nutrient, 0.32, 0.86)
			* step(
				hash21(chem_cell + vec2(4.0, 10.0)),
				field_strength(nutrient, 0.32, 0.86) * 0.20
			);
		if (nutrient_layer > 0.01 && alpha < 0.16) {
			color = vec3(0.31, 0.37, 0.11);
			alpha = nutrient_layer * 0.16;
		}

		float waste_layer = chem_pair
			* field_strength(waste, 0.34, 0.86)
			* step(
				hash21(chem_cell + vec2(11.0, 12.0)),
				field_strength(waste, 0.34, 0.86) * 0.18
			);
		if (waste_layer > 0.01 && alpha < 0.15) {
			color = vec3(0.31, 0.16, 0.11);
			alpha = waste_layer * 0.15;
		}
	}

	float day = mix(0.80, 1.0, clamp(scene_light, 0.0, 1.0));
	COLOR = vec4(color * day, clamp(alpha, 0.0, 0.82));
}
