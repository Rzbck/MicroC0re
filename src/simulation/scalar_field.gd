class_name ScalarField
extends RefCounted

var width: int
var height: int
var cell_size: float
var values: PackedFloat32Array = PackedFloat32Array()
var _scratch: PackedFloat32Array = PackedFloat32Array()


func _init(
	p_width: int = 96,
	p_height: int = 64,
	p_cell_size: float = 2.0,
	initial_value: float = 0.0
) -> void:
	width = maxi(2, p_width)
	height = maxi(2, p_height)
	cell_size = maxf(0.0001, p_cell_size)
	values.resize(width * height)
	_scratch.resize(width * height)
	fill(initial_value)


func fill(value: float) -> void:
	var safe_value := maxf(0.0, value)
	for i in range(values.size()):
		values[i] = safe_value
		_scratch[i] = safe_value


func world_size() -> Vector2:
	return Vector2(width * cell_size, height * cell_size)


func get_cell(x: int, y: int) -> float:
	var ix := clampi(x, 0, width - 1)
	var iy := clampi(y, 0, height - 1)
	return values[_index(ix, iy)]


func set_cell(x: int, y: int, value: float) -> void:
	if x < 0 or x >= width or y < 0 or y >= height:
		return
	values[_index(x, y)] = maxf(0.0, value)


func add_nearest_world(position: Vector2, amount: float) -> void:
	if amount <= 0.0:
		return
	var ix := clampi(floori(position.x / cell_size), 0, width - 1)
	var iy := clampi(floori(position.y / cell_size), 0, height - 1)
	var idx := _index(ix, iy)
	values[idx] = maxf(0.0, values[idx] + amount)


func take_nearest_world(position: Vector2, requested: float) -> float:
	if requested <= 0.0:
		return 0.0
	var ix := clampi(floori(position.x / cell_size), 0, width - 1)
	var iy := clampi(floori(position.y / cell_size), 0, height - 1)
	var idx := _index(ix, iy)
	var taken := minf(values[idx], requested)
	values[idx] -= taken
	return taken


func sample_world(position: Vector2) -> float:
	var gx := clampf(position.x / cell_size, 0.0, float(width - 1))
	var gy := clampf(position.y / cell_size, 0.0, float(height - 1))
	var x0 := floori(gx)
	var y0 := floori(gy)
	var x1 := mini(x0 + 1, width - 1)
	var y1 := mini(y0 + 1, height - 1)
	var tx := gx - float(x0)
	var ty := gy - float(y0)

	var a := lerpf(get_cell(x0, y0), get_cell(x1, y0), tx)
	var b := lerpf(get_cell(x0, y1), get_cell(x1, y1), tx)
	return lerpf(a, b, ty)


func gradient_world(position: Vector2) -> Vector2:
	var h := cell_size
	var left := sample_world(position - Vector2(h, 0.0))
	var right := sample_world(position + Vector2(h, 0.0))
	var up := sample_world(position - Vector2(0.0, h))
	var down := sample_world(position + Vector2(0.0, h))
	return Vector2((right - left) / (2.0 * h), (down - up) / (2.0 * h))


func diffuse(diffusion_coefficient: float, dt: float, decay_rate: float = 0.0) -> void:
	if dt <= 0.0:
		return

	var diffusion := maxf(0.0, diffusion_coefficient)
	var decay := maxf(0.0, decay_rate)

	if diffusion <= 0.0:
		if decay > 0.0:
			var decay_factor := exp(-decay * dt)
			for i in range(values.size()):
				values[i] = maxf(0.0, values[i] * decay_factor)
		return

	# Explicit 2D diffusion is stable around D*dt/h^2 <= 1/4.
	var max_stable_dt := (cell_size * cell_size) / (4.0 * diffusion)
	var substeps := maxi(1, ceili(dt / (max_stable_dt * 0.95)))
	var sub_dt := dt / float(substeps)
	var inv_h2 := 1.0 / (cell_size * cell_size)

	for _substep in range(substeps):
		for y in range(height):
			for x in range(width):
				var idx := _index(x, y)
				var center := values[idx]
				var laplacian := (
					get_cell(x - 1, y)
					+ get_cell(x + 1, y)
					+ get_cell(x, y - 1)
					+ get_cell(x, y + 1)
					- 4.0 * center
				) * inv_h2
				var next_value := center + sub_dt * (diffusion * laplacian - decay * center)
				_scratch[idx] = maxf(0.0, next_value)

		var previous := values
		values = _scratch
		_scratch = previous


func total() -> float:
	var sum := 0.0
	for value in values:
		sum += value
	return sum


func min_value() -> float:
	var minimum := INF
	for value in values:
		minimum = minf(minimum, value)
	return minimum


func max_value() -> float:
	var maximum := -INF
	for value in values:
		maximum = maxf(maximum, value)
	return maximum


func _index(x: int, y: int) -> int:
	return y * width + x
