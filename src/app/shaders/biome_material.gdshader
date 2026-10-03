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

float density_hit(float value, float h, float density) {
	float v = smoothstep(0.10, 0.88, value);
	return step(h, v * density);
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

	float producer_on = density_hit(producer, h0, 0.34) * step(0.18, producer);
	producer_on *= step(h2, 0.30 + producer * 0.62);
	if (producer_on > 0.5) {
		float highlight = step(0.72, h1);
		color = mix(vec3(0.055, 0.26, 0.10), vec3(0.26, 0.70, 0.18), highlight);
		alpha = max(alpha, 0.38 + producer * 0.32);
	}

	float line_x = step(0.80, fract((pixel.x + floor(h3 * 3.0)) / 5.0));
	float line_y = step(0.84, fract((pixel.y + floor(h2 * 4.0)) / 6.0));
	float lattice = max(line_x, line_y) * step(0.16, eps) * step(h1, eps * 0.68);
	if (lattice > 0.5) {
		color = mix(color, vec3(0.08, 0.43, 0.39), 0.82);
		alpha = max(alpha, 0.22 + eps * 0.36);
	}

	float debris = density_hit(detritus, h1, 0.22) * step(0.12, detritus);
	if (debris > 0.5) {
		color = mix(color, vec3(0.50, 0.28, 0.11), 0.90);
		alpha = max(alpha, 0.30 + detritus * 0.42);
	}

	float wound = density_hit(damage, h0, 0.28) * step(0.10, damage);
	if (wound > 0.5) {
		float hot = step(0.70, h2);
		color = mix(vec3(0.48, 0.08, 0.06), vec3(0.95, 0.31, 0.10), hot);
		alpha = max(alpha, 0.38 + damage * 0.48);
	}

	float oxygen_glint = density_hit(max(oxygen - 0.24, 0.0), h0, 0.09);
	if (oxygen_glint > 0.5 && alpha < 0.34) {
		color = vec3(0.20, 0.62, 0.70);
		alpha = max(alpha, 0.16 + oxygen * 0.12);
	}
	float nutrient_grain = density_hit(max(nutrient - 0.20, 0.0), h1, 0.08);
	if (nutrient_grain > 0.5 && alpha < 0.30) {
		color = vec3(0.34, 0.42, 0.12);
		alpha = max(alpha, 0.13 + nutrient * 0.10);
	}
	float waste_grain = density_hit(max(waste - 0.24, 0.0), h2, 0.055);
	if (waste_grain > 0.5 && alpha < 0.30) {
		color = vec3(0.35, 0.19, 0.13);
		alpha = max(alpha, 0.13 + waste * 0.10);
	}
	float day = mix(0.78, 1.0, clamp(scene_light, 0.0, 1.0));
	COLOR = vec4(color * day, clamp(alpha, 0.0, 0.82));
}
