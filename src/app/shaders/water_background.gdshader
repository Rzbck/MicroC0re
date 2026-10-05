shader_type canvas_item;
render_mode unshaded;

uniform vec2 world_size = vec2(384.0, 256.0);
uniform float pixel_world = 0.25;
uniform float scene_light = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float block_noise(vec2 cell) {
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	return (a + b + c) / 3.0;
}

void fragment() {
	vec2 world = UV * world_size;
	vec2 pixel = floor(world / pixel_world);

	// Large stationary aqueous regions. The water itself must not look like a
	// full-screen particle animation.
	vec2 macro32 = floor(pixel / 32.0);
	vec2 macro16 = floor(pixel / 16.0);
	float broad = block_noise(macro32);
	float mid = block_noise(macro16 + vec2(7.0, 3.0));

	// Gentle vertical illumination gradient, like a shallow microscope dish.
	float depth = clamp(UV.y, 0.0, 1.0);
	vec3 top_water = vec3(0.025, 0.105, 0.105);
	vec3 bottom_water = vec3(0.018, 0.070, 0.076);
	vec3 color = mix(top_water, bottom_water, depth);

	// Broad material variation: visible enough to avoid a void, quiet enough to
	// stay behind life and ecological material.
	vec3 cool_patch = vec3(0.015, 0.045, 0.050);
	vec3 warm_patch = vec3(0.020, 0.034, 0.026);
	color += cool_patch * (broad - 0.45) * 0.72;
	color += warm_patch * (mid - 0.50) * 0.28;

	// Sparse two-pixel mineral/turbidity clusters, never single-pixel TV snow.
	vec2 debris_cell = floor(pixel / 18.0);
	vec2 debris_local = mod(pixel, 18.0);
	float debris_gate = step(0.84, hash21(debris_cell + vec2(4.0, 9.0)));
	vec2 debris_center = vec2(
		3.0 + floor(hash21(debris_cell + vec2(2.0, 5.0)) * 11.0),
		3.0 + floor(hash21(debris_cell + vec2(8.0, 1.0)) * 11.0)
	);
	vec2 dd = abs(debris_local - debris_center);
	float debris = debris_gate
		* step(dd.y, 0.45)
		* step(dd.x, 1.45);
	color += vec3(0.020, 0.038, 0.032) * debris;

	// Microscope vignette gives the dish a field-of-view feeling without
	// turning the borders back to black.
	vec2 centered = UV * 2.0 - 1.0;
	float vignette = smoothstep(0.62, 1.12, length(centered));
	color *= mix(1.0, 0.76, vignette);

	float day = mix(0.84, 1.0, clamp(scene_light, 0.0, 1.0));
	COLOR = vec4(color * day, 1.0);
}
