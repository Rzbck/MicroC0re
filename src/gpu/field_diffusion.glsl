#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer InputField {
	float values[];
} input_field;

layout(set = 0, binding = 1, std430) restrict writeonly buffer OutputField {
	float values[];
} output_field;

const int WIDTH = 96;
const int HEIGHT = 64;
const float ALPHA = 0.0416666667;
const float DECAY = 0.00005;

int idx(int x, int y) {
	return y * WIDTH + x;
}

void main() {
	ivec2 p = ivec2(gl_GlobalInvocationID.xy);
	if (p.x >= WIDTH || p.y >= HEIGHT) {
		return;
	}

	int xl = max(p.x - 1, 0);
	int xr = min(p.x + 1, WIDTH - 1);
	int yu = max(p.y - 1, 0);
	int yd = min(p.y + 1, HEIGHT - 1);

	int center_i = idx(p.x, p.y);
	float center = input_field.values[center_i];
	float lap = (
		input_field.values[idx(xl, p.y)]
		+ input_field.values[idx(xr, p.y)]
		+ input_field.values[idx(p.x, yu)]
		+ input_field.values[idx(p.x, yd)]
		- 4.0 * center
	);

	float next_value = center + ALPHA * lap - DECAY * center;
	output_field.values[center_i] = max(next_value, 0.0);
}
