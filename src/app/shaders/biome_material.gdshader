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

float box_shape(vec2 p, vec2 center, vec2 half_size) {
	vec2 d = abs(p - center);
	return step(d.x, half_size.x) * step(d.y, half_size.y);
}

float field_strength(float value, float low, float high) {
	return smoothstep(low, high, value);
}

float island16(vec2 local, vec2 cell, float variant) {
	vec2 center = vec2(
		6.0 + floor(hash21(cell + vec2(2.0, 9.0) + variant) * 4.0),
		6.0 + floor(hash21(cell + vec2(8.0, 3.0) + variant) * 4.0)
	);
	float a = box_shape(local, center, vec2(4.6, 2.4));
	float b = box_shape(
		local,
		center + vec2(
			-3.0 + floor(hash21(cell + 12.0 + variant) * 7.0),
			-3.0 + floor(hash21(cell + 27.0 + variant) * 7.0)
		),
		vec2(2.3, 2.8)
	);
	float c = box_shape(
		local,
		center + vec2(
			-4.0 + floor(hash21(cell + 31.0 + variant) * 8.0),
			-2.0 + floor(hash21(cell + 44.0 + variant) * 5.0)
		),
		vec2(2.0, 1.5)
	);

	// Carve one chunk out so every island is asymmetric and reads as an
	// organic pixel cluster rather than a rectangle/icon.
	vec2 bite_center = center + vec2(
		-3.0 + floor(hash21(cell + 63.0 + variant) * 7.0),
		-2.0 + floor(hash21(cell + 71.0 + variant) * 5.0)
	);
	float bite = box_shape(local, bite_center, vec2(1.2, 1.2));
	return clamp(max(a, max(b, c)) - bite, 0.0, 1.0);
}

float ribbon14(vec2 local, vec2 cell) {
	float row0 = 3.0 + floor(hash21(cell + vec2(2.0, 7.0)) * 8.0);
	float row1 = clamp(row0 + (-2.0 + floor(hash21(cell + vec2(9.0, 1.0)) * 5.0)), 2.0, 11.0);
	float col = 3.0 + floor(hash21(cell + vec2(5.0, 11.0)) * 8.0);
	float horizontal0 = box_shape(local, vec2(6.5, row0), vec2(4.8, 0.55));
	float horizontal1 = box_shape(local, vec2(7.5, row1), vec2(3.4, 0.55));
	float bridge = box_shape(local, vec2(col, (row0 + row1) * 0.5), vec2(0.55, 2.2));
	return max(horizontal0, max(horizontal1, bridge));
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

	// PRODUCER MAT — broad muted olive/green islands. The simulation field
	// controls where they can exist; hash only shapes the island edge.
	vec2 prod_cell = floor(pixel / 16.0);
	vec2 prod_local = mod(pixel, 16.0);
	float prod_strength = field_strength(producer, 0.025, 0.42);
	float prod_gate = step(
		hash21(prod_cell + vec2(3.0, 17.0)),
		clamp(prod_strength * 1.18, 0.0, 1.0)
	);
	float prod_shape = island16(prod_local, prod_cell, 0.0);
	float prod_layer = prod_shape * prod_gate * prod_strength;
	if (prod_layer > 0.008) {
		float variant = hash21(prod_cell + vec2(13.0, 5.0));
		vec3 p0 = vec3(0.075, 0.235, 0.100);
		vec3 p1 = vec3(0.18, 0.39, 0.13);
		vec3 producer_color = mix(p0, p1, step(0.54, variant));
		color = mix(color, producer_color, prod_layer);
		alpha = max(alpha, 0.30 + prod_layer * 0.52);
	}

	// EPS / BIOFILM — connected blue-green ribbons woven through a patch.
	vec2 eps_cell = floor(pixel / 14.0);
	vec2 eps_local = mod(pixel, 14.0);
	float eps_strength = field_strength(eps, 0.016, 0.30);
	float eps_gate = step(
		hash21(eps_cell + vec2(19.0, 4.0)),
		clamp(eps_strength * 1.12, 0.0, 1.0)
	);
	float eps_layer = ribbon14(eps_local, eps_cell) * eps_gate * eps_strength;
	if (eps_layer > 0.008) {
		color = mix(color, vec3(0.075, 0.30, 0.285), eps_layer * 0.82);
		alpha = max(alpha, 0.20 + eps_layer * 0.42);
	}

	// DETRITUS — brown multi-fragment clumps, not floating orange icons.
	vec2 det_cell = floor(pixel / 13.0);
	vec2 det_local = mod(pixel, 13.0);
	float det_strength = field_strength(detritus, 0.012, 0.30);
	float det_gate = step(
		hash21(det_cell + vec2(7.0, 21.0)),
		clamp(det_strength * 1.22, 0.0, 1.0)
	);
	vec2 dcenter = vec2(
		4.0 + floor(hash21(det_cell + vec2(2.0, 4.0)) * 5.0),
		4.0 + floor(hash21(det_cell + vec2(8.0, 9.0)) * 5.0)
	);
	float det_shape = max(
		box_shape(det_local, dcenter, vec2(2.3, 1.0)),
		max(
			box_shape(det_local, dcenter + vec2(-2.0, 2.0), vec2(1.0, 1.4)),
			box_shape(det_local, dcenter + vec2(2.5, -1.5), vec2(1.4, 0.7))
		)
	);
	float det_layer = det_shape * det_gate * det_strength;
	if (det_layer > 0.008) {
		color = mix(color, vec3(0.39, 0.235, 0.115), det_layer * 0.94);
		alpha = max(alpha, 0.24 + det_layer * 0.52);
	}

	// DAMAGE — irregular warm scars. Highest environmental priority because
	// they visually explain a recent mortality/disturbance event.
	vec2 dmg_cell = floor(pixel / 12.0);
	vec2 dmg_local = mod(pixel, 12.0);
	float dmg_strength = field_strength(damage, 0.010, 0.26);
	float dmg_gate = step(
		hash21(dmg_cell + vec2(4.0, 15.0)),
		clamp(dmg_strength * 1.20, 0.0, 1.0)
	);
	vec2 sc = vec2(
		3.0 + floor(hash21(dmg_cell + vec2(9.0, 2.0)) * 5.0),
		3.0 + floor(hash21(dmg_cell + vec2(1.0, 10.0)) * 5.0)
	);
	float scar = max(
		box_shape(dmg_local, sc, vec2(3.1, 0.65)),
		box_shape(dmg_local, sc + vec2(2.0, 2.0), vec2(1.7, 0.65))
	);
	float dmg_layer = scar * dmg_gate * dmg_strength;
	if (dmg_layer > 0.008) {
		vec3 damage_color = mix(
			vec3(0.42, 0.11, 0.055),
			vec3(0.78, 0.23, 0.075),
			step(0.62, hash21(dmg_cell + 23.0))
		);
		color = mix(color, damage_color, dmg_layer);
		alpha = max(alpha, 0.36 + dmg_layer * 0.50);
	}

	// EXUDATE / PHYCOSPHERE — quiet paired jade droplets near producers.
	vec2 ex_cell = floor(pixel / 11.0);
	vec2 ex_local = mod(pixel, 11.0);
	float ex_strength = field_strength(exudate, 0.025, 0.24);
	float ex_gate = step(
		hash21(ex_cell + vec2(5.0, 5.0)),
		clamp(ex_strength * 0.66, 0.0, 1.0)
	);
	vec2 ec = vec2(
		3.0 + floor(hash21(ex_cell + vec2(1.0, 6.0)) * 5.0),
		3.0 + floor(hash21(ex_cell + vec2(8.0, 3.0)) * 5.0)
	);
	float ex_shape = max(
		box_shape(ex_local, ec, vec2(0.65, 0.65)),
		box_shape(ex_local, ec + vec2(1.0, 1.0), vec2(0.65, 0.65))
	);
	float ex_layer = ex_shape * ex_gate * ex_strength;
	if (ex_layer > 0.008 && alpha < 0.55) {
		color = mix(color, vec3(0.22, 0.39, 0.22), ex_layer * 0.58);
		alpha = max(alpha, 0.10 + ex_layer * 0.22);
	}

	// Dissolved chemistry only changes the UNDER-TONE of otherwise open water.
	// It no longer draws independent bright symbols.
	if (alpha < 0.14) {
		float dissolved = clamp(
			field_strength(nutrient, 0.22, 0.76) * 0.42
			+ field_strength(oxygen, 0.26, 0.76) * 0.24
			+ field_strength(waste, 0.22, 0.68) * 0.20,
			0.0,
			0.58
		);
		if (dissolved > 0.02) {
			vec3 dissolved_color = mix(
				vec3(0.10, 0.22, 0.18),
				vec3(0.19, 0.25, 0.13),
				field_strength(nutrient, 0.22, 0.76)
			);
			color = dissolved_color;
			alpha = dissolved * 0.20;
		}
	}

	float day = mix(0.86, 1.0, clamp(scene_light, 0.0, 1.0));
	COLOR = vec4(color * day, clamp(alpha, 0.0, 0.78));
}
