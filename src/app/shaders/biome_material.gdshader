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

float density_alpha(float value, float h, float density) {
	float v = smoothstep(0.06, 0.90, value) * density;
	return smoothstep(h - 0.025, h + 0.025, v);
}

void fragment() {
	vec2 world = UV * world_size;
	vec2 pixel = floor(world / pixel_world);
	vec2 cluster = floor(pixel / 5.0);
	vec2 coarse = floor(pixel / 13.0);
	vec4 a = texture(mask_a, UV);
	vec4 b = texture(mask_b, UV);
	float producer = a.r;
	float detritus = a.g;
	float eps = a.b;
	float damage = a.a;
	float oxygen = b.r;
	float nutrient = b.g;
	float waste = b.b;
	float h0 = hash21(pixel);
	float h1 = hash21(pixel + vec2(19.0, 7.0));
	float h2 = hash21(cluster + vec2(5.0, 17.0));
	float h3 = hash21(coarse + vec2(11.0, 3.0));

	vec3 color = vec3(0.0);
	float alpha = 0.0;

	float producer_on = density_alpha(producer, h0, 0.46) * smoothstep(0.07, 0.18, producer);
	float producer_cluster = smoothstep(
		h2 - 0.035,
		h2 + 0.035,
		0.18 + producer * 0.76
	);
	producer_on *= producer_cluster;
	if (producer_on > 0.01) {
		float highlight = step(0.72, h1);
		vec3 producer_color = mix(
			vec3(0.055, 0.26, 0.10),
			vec3(0.26, 0.70, 0.18),
			highlight
		);
		color = mix(color, producer_color, producer_on);
		alpha = max(alpha, producer_on * (0.42 + producer * 0.40));
	}

	float line_x = step(0.80, fract((pixel.x + floor(h3 * 3.0)) / 5.0));
	float line_y = step(0.84, fract((pixel.y + floor(h2 * 4.0)) / 6.0));
	float lattice = max(line_x, line_y)
		* smoothstep(0.025, 0.10, eps)
		* density_alpha(eps, h1, 0.82);
	if (lattice > 0.01) {
		color = mix(color, vec3(0.08, 0.43, 0.39), lattice * 0.86);
		alpha = max(alpha, lattice * (0.24 + eps * 0.42));
	}

	float debris = density_alpha(detritus, h1, 0.38) * smoothstep(0.035, 0.12, detritus);
	if (debris > 0.01) {
		color = mix(color, vec3(0.50, 0.28, 0.11), debris * 0.92);
		alpha = max(alpha, debris * (0.34 + detritus * 0.44));
	}

	float wound = density_alpha(damage, h0, 0.46) * smoothstep(0.025, 0.10, damage);
	if (wound > 0.01) {
		float hot = step(0.70, h2);
		vec3 wound_color = mix(vec3(0.48, 0.08, 0.06), vec3(0.95, 0.31, 0.10), hot);
		color = mix(color, wound_color, wound);
		alpha = max(alpha, wound * (0.40 + damage * 0.48));
	}

	float oxygen_glint = density_alpha(oxygen, h0, 0.11) * smoothstep(0.08, 0.24, oxygen);
	if (oxygen_glint > 0.01 && alpha < 0.34) {
		color = mix(color, vec3(0.20, 0.62, 0.70), oxygen_glint);
		alpha = max(alpha, oxygen_glint * 0.25);
	}
	float nutrient_grain = density_alpha(nutrient, h1, 0.10) * smoothstep(0.08, 0.24, nutrient);
	if (nutrient_grain > 0.01 && alpha < 0.30) {
		color = mix(color, vec3(0.34, 0.42, 0.12), nutrient_grain);
		alpha = max(alpha, nutrient_grain * 0.22);
	}
	float waste_grain = density_alpha(waste, h2, 0.075) * smoothstep(0.08, 0.24, waste);
	if (waste_grain > 0.01 && alpha < 0.30) {
		color = mix(color, vec3(0.35, 0.19, 0.13), waste_grain);
		alpha = max(alpha, waste_grain * 0.20);
	}
	float day = mix(0.78, 1.0, clamp(scene_light, 0.0, 1.0));
	COLOR = vec4(color * day, clamp(alpha, 0.0, 0.82));
}
