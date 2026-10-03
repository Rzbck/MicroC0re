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

void fragment() {
	vec2 world = UV * world_size;
	vec2 pixel = floor(world / pixel_world);
	vec2 macro = floor(pixel / 12.0);
	float fine = hash21(pixel);
	float broad = hash21(macro);
	float wave = 0.5 + 0.5 * sin(
		world.x * 0.022 + world.y * 0.017 + TIME * 0.045 + broad * 6.28318
	);
	vec3 deep = vec3(0.006, 0.030, 0.036);
	vec3 mid = vec3(0.009, 0.047, 0.052);
	vec3 cool = vec3(0.012, 0.060, 0.064);
	vec3 color = mix(deep, mid, broad * 0.34);
	color = mix(color, cool, wave * 0.10);
	if (fine > 0.986) {
		color += vec3(0.010, 0.026, 0.027);
	} else if (fine < 0.018) {
		color *= 0.82;
	}
	float day = mix(0.70, 1.0, clamp(scene_light, 0.0, 1.0));
	COLOR = vec4(color * day, 1.0);
}
