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
	var safe_value: float = maxf(0.0, value)
	for i in range(values.size()):
		values[i] = safe_value
		_scratch[i] = safe_value


func world_size() -> Vector2:
	return Vector2(width * cell_size, height * cell_size)


func get_cell(x: int, y: int) -> float:
	var ix: int = clampi(x, 0, width - 1)
	var iy: int = clampi(y, 0, height - 1)
	return values[_index(ix, iy)]


func set_cell(x: int, y: int, value: float) -> void:
	if x < 0 or x >= width or y < 0 or y >= height:
		return
	values[_index(x, y)] = maxf(0.0, value)


func add_nearest_world(position: Vector2, amount: float) -> void:
	if amount <= 0.0:
		return
	var ix: int = clampi(floori(position.x / cell_size), 0, width - 1)
	var iy: int = clampi(floori(position.y / cell_size), 0, height - 1)
	var idx: int = _index(ix, iy)
	values[idx] = maxf(0.0, values[idx] + amount)


func add_radial_world(position: Vector2, radius: float, amount: float) -> void:
	if amount <= 0.0 or radius <= 0.0:
		return

	var cx: int = clampi(floori(position.x / cell_size), 0, width - 1)
	var cy: int = clampi(floori(position.y / cell_size), 0, height - 1)
	var cell_radius: int = maxi(1, ceili(radius / cell_size))
	var radius_sq: float = radius * radius

	for y in range(maxi(0, cy - cell_radius), mini(height, cy + cell_radius + 1)):
		for x in range(maxi(0, cx - cell_radius), mini(width, cx + cell_radius + 1)):
			var cell_center := Vector2(
				(float(x) + 0.5) * cell_size,
				(float(y) + 0.5) * cell_size
			)
			var distance_sq: float = cell_center.distance_squared_to(position)
			if distance_sq > radius_sq:
				continue

			var normalized: float = 1.0 - sqrt(distance_sq) / radius
			var weight: float = normalized * normalized
			var idx: int = _index(x, y)
			values[idx] = maxf(0.0, values[idx] + amount * weight)


func take_nearest_world(position: Vector2, requested: float) -> float:
	if requested <= 0.0:
		return 0.0
	var ix: int = clampi(floori(position.x / cell_size), 0, width - 1)
	var iy: int = clampi(floori(position.y / cell_size), 0, height - 1)
	var idx: int = _index(ix, iy)
	var taken: float = minf(values[idx], requested)
	values[idx] -= taken
	return taken


func sample_world(position: Vector2) -> float:
	# Hot path: position is clamped once, then PackedFloat32Array is read
	# directly. Avoid four get_cell() calls and their repeated clamps.
	var gx: float = clampf(position.x / cell_size, 0.0, float(width - 1))
	var gy: float = clampf(position.y / cell_size, 0.0, float(height - 1))
	var x0: int = floori(gx)
	var y0: int = floori(gy)
	var x1: int = mini(x0 + 1, width - 1)
	var y1: int = mini(y0 + 1, height - 1)
	var tx: float = gx - float(x0)
	var ty: float = gy - float(y0)

	var row0: int = y0 * width
	var row1: int = y1 * width
	var v00: float = values[row0 + x0]
	var v10: float = values[row0 + x1]
	var v01: float = values[row1 + x0]
	var v11: float = values[row1 + x1]

	var a: float = v00 + (v10 - v00) * tx
	var b: float = v01 + (v11 - v01) * tx
	return a + (b - a) * ty


func gradient_world(position: Vector2) -> Vector2:
	var h: float = cell_size
	var left: float = sample_world(position - Vector2(h, 0.0))
	var right: float = sample_world(position + Vector2(h, 0.0))
	var up: float = sample_world(position - Vector2(0.0, h))
	var down: float = sample_world(position + Vector2(0.0, h))
	return Vector2((right - left) / (2.0 * h), (down - up) / (2.0 * h))


func diffuse(diffusion_coefficient: float, dt: float, decay_rate: float = 0.0) -> void:
	if dt <= 0.0:
		return

	var diffusion: float = maxf(0.0, diffusion_coefficient)
	var decay: float = maxf(0.0, decay_rate)

	if diffusion <= 0.0:
		if decay > 0.0:
			var decay_factor: float = exp(-decay * dt)
			for i in range(values.size()):
				values[i] = maxf(0.0, values[i] * decay_factor)
		return

	# Explicit 2D diffusion is stable around D*dt/h^2 <= 1/4.
	var max_stable_dt: float = (cell_size * cell_size) / (4.0 * diffusion)
	var substeps: int = maxi(1, ceili(dt / (max_stable_dt * 0.95)))
	var sub_dt: float = dt / float(substeps)
	var inv_h2: float = 1.0 / (cell_size * cell_size)

	for _substep in range(substeps):
		for y in range(height):
			var row: int = y * width
			var row_up: int = maxi(y - 1, 0) * width
			var row_down: int = mini(y + 1, height - 1) * width

			for x in range(width):
				var idx: int = row + x
				var left_idx: int = row + maxi(x - 1, 0)
				var right_idx: int = row + mini(x + 1, width - 1)
				var up_idx: int = row_up + x
				var down_idx: int = row_down + x
				var center: float = values[idx]
				var laplacian: float = (
					values[left_idx]
					+ values[right_idx]
					+ values[up_idx]
					+ values[down_idx]
					- 4.0 * center
				) * inv_h2
				var next_value: float = center + sub_dt * (
					diffusion * laplacian - decay * center
				)
				_scratch[idx] = maxf(0.0, next_value)

		var previous: PackedFloat32Array = values
		values = _scratch
		_scratch = previous


func total() -> float:
	var sum: float = 0.0
	for value in values:
		sum += value
	return sum


func min_value() -> float:
	var minimum: float = INF
	for value in values:
		minimum = minf(minimum, value)
	return minimum


func max_value() -> float:
	var maximum: float = -INF
	for value in values:
		maximum = maxf(maximum, value)
	return maximum


func _index(x: int, y: int) -> int:
	return y * width + x
