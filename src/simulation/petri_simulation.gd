class_name PetriSimulation
extends RefCounted

const ScalarFieldScript = preload("res://src/simulation/scalar_field.gd")
const BacteriumScript = preload("res://src/simulation/bacterium.gd")

const FIELD_WIDTH := 96
const FIELD_HEIGHT := 64
const FIELD_CELL_SIZE := 2.0

var world_size := Vector2(
	FIELD_WIDTH * FIELD_CELL_SIZE,
	FIELD_HEIGHT * FIELD_CELL_SIZE
)

var fixed_seed: int
var rng := RandomNumberGenerator.new()

var nutrient: Variant
var waste: Variant
var bacteria: Array = []
var nutrient_sources: Array[Vector2] = []

var simulation_time: float = 0.0
var _next_id: int = 1

# Environmental coefficients. Concentration is normalized in v0.1.
var nutrient_diffusion: float = 6.0
var nutrient_decay: float = 0.002
var waste_diffusion: float = 1.5
var waste_decay: float = 0.02
var source_rate: float = 0.70

# Motility / chemotaxis.
var run_speed: float = 10.0
var base_tumble_rate: float = 1.0
var tumble_sigma: float = 1.15
var rotational_diffusion: float = 0.12
var chemotaxis_memory_tau: float = 0.8
var chemotaxis_gain: float = 5.0

# Resource / energy / growth.
var max_uptake_rate: float = 0.12
var monod_half_saturation: float = 0.15
var energy_yield: float = 4.5
var maintenance_cost: float = 0.03
var movement_cost_per_speed: float = 0.001
var growth_per_nutrient: float = 0.80
var growth_energy_cost_per_length: float = 0.20
var division_length: float = 4.5
var division_energy: float = 3.6
var minimum_length: float = 2.2
var maximum_length: float = 6.0
var waste_fraction: float = 0.35

# Contact solver.
var mechanical_iterations: int = 4
var angular_contact_response: float = 0.06


func _init(seed_value: int = 1) -> void:
	fixed_seed = seed_value
	rng.seed = seed_value
	nutrient = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.18)
	waste = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	_build_sources()


func seed_demo(count: int = 24) -> void:
	bacteria.clear()
	simulation_time = 0.0
	_next_id = 1
	rng.seed = fixed_seed

	for _i in range(maxi(0, count)):
		var margin := 10.0
		var position := Vector2(
			rng.randf_range(margin, world_size.x - margin),
			rng.randf_range(margin, world_size.y - margin)
		)
		var cell: Variant = BacteriumScript.new(
			_allocate_id(),
			position,
			rng.randf_range(-PI, PI)
		)
		cell.energy = rng.randf_range(2.7, 3.3)
		cell.length = rng.randf_range(2.25, 2.55)
		cell.sensed_memory = nutrient.sample_world(position)
		bacteria.append(cell)


func step(dt: float) -> void:
	if dt <= 0.0:
		return

	_feed_environment(dt)
	nutrient.diffuse(nutrient_diffusion, dt, nutrient_decay)
	waste.diffuse(waste_diffusion, dt, waste_decay)

	var next_population: Array = []

	for cell in bacteria:
		if not cell.alive:
			continue

		_advance_cell(cell, dt)

		if not cell.alive:
			_recycle_dead_cell(cell)
			continue

		if _ready_to_divide(cell):
			var daughters: Array = _divide(cell)
			next_population.append_array(daughters)
		else:
			next_population.append(cell)

	bacteria = next_population

	for _iteration in range(mechanical_iterations):
		_resolve_all_contacts()

	simulation_time += dt


func _advance_cell(cell: Variant, dt: float) -> void:
	cell.age += dt

	var sensed: float = float(nutrient.sample_world(cell.position))
	var improvement: float = sensed - float(cell.sensed_memory)
	var memory_alpha: float = 1.0 - exp(-dt / maxf(0.001, chemotaxis_memory_tau))
	cell.sensed_memory = lerpf(cell.sensed_memory, sensed, memory_alpha)

	var bounded_improvement: float = clampf(improvement, -0.25, 0.25)
	var tumble_rate: float = base_tumble_rate * exp(-chemotaxis_gain * bounded_improvement)
	tumble_rate = clampf(tumble_rate, 0.05, 8.0)
	var tumble_probability: float = 1.0 - exp(-tumble_rate * dt)

	if rng.randf() < tumble_probability:
		cell.angle += rng.randfn(0.0, tumble_sigma)

	if rotational_diffusion > 0.0:
		var sigma: float = sqrt(2.0 * rotational_diffusion * dt)
		cell.angle += rng.randfn(0.0, sigma)

	cell.angle = wrapf(cell.angle, -PI, PI)

	var energy_speed_factor: float = clampf(float(cell.energy) / 2.0, 0.20, 1.0)
	var speed: float = run_speed * energy_speed_factor
	cell.position += cell.axis() * speed * dt
	_constrain_to_world(cell)

	var local_nutrient: float = float(nutrient.sample_world(cell.position))
	var uptake_rate: float = 0.0
	if local_nutrient > 0.0:
		uptake_rate = max_uptake_rate * local_nutrient / (
			monod_half_saturation + local_nutrient
		)

	var consumed: float = float(nutrient.take_nearest_world(cell.position, uptake_rate * dt))
	cell.energy += consumed * energy_yield
	cell.energy -= (maintenance_cost + movement_cost_per_speed * speed) * dt

	if consumed > 0.0:
		var growth_delta: float = growth_per_nutrient * consumed
		growth_delta = minf(growth_delta, maximum_length - cell.length)
		if growth_delta > 0.0:
			cell.length += growth_delta
			cell.energy -= growth_delta * growth_energy_cost_per_length
		waste.add_nearest_world(cell.position, consumed * waste_fraction)

	if cell.energy <= 0.0:
		cell.energy = 0.0
		cell.alive = false


func _ready_to_divide(cell: Variant) -> bool:
	return (
		cell.length >= division_length
		and cell.energy >= division_energy
		and cell.alive
	)


func _divide(parent: Variant) -> Array:
	var daughter_length: float = maxf(minimum_length, float(parent.length) * 0.56)
	var daughter_energy: float = float(parent.energy) * 0.475
	var axis: Vector2 = parent.axis()
	var offset: Vector2 = axis * (daughter_length * 0.28)

	var a: Variant = BacteriumScript.new(
		_allocate_id(),
		parent.position - offset,
		parent.angle + rng.randfn(0.0, 0.025),
		parent.generation + 1,
		parent.id
	)
	var b: Variant = BacteriumScript.new(
		_allocate_id(),
		parent.position + offset,
		parent.angle + PI + rng.randfn(0.0, 0.025),
		parent.generation + 1,
		parent.id
	)

	for daughter in [a, b]:
		daughter.length = daughter_length
		daughter.radius = parent.radius
		daughter.energy = daughter_energy
		daughter.sensed_memory = nutrient.sample_world(daughter.position)
		_constrain_to_world(daughter)

	var daughters: Array = [a, b]
	return daughters


func _recycle_dead_cell(cell: Variant) -> void:
	# v0.1 coarse recycling: part of remaining body material enters the waste field.
	var recycled: float = maxf(0.05, float(cell.length) * 0.03)
	waste.add_nearest_world(cell.position, recycled)


func _feed_environment(dt: float) -> void:
	var amount_per_source: float = source_rate * dt
	for source in nutrient_sources:
		nutrient.add_nearest_world(source, amount_per_source)


func _build_sources() -> void:
	nutrient_sources = [
		Vector2(world_size.x * 0.18, world_size.y * 0.20),
		Vector2(world_size.x * 0.72, world_size.y * 0.18),
		Vector2(world_size.x * 0.50, world_size.y * 0.52),
		Vector2(world_size.x * 0.25, world_size.y * 0.78),
		Vector2(world_size.x * 0.82, world_size.y * 0.74),
	]


func _allocate_id() -> int:
	var result: int = _next_id
	_next_id += 1
	return result


func _resolve_all_contacts() -> void:
	var count: int = bacteria.size()
	for i in range(count):
		for j in range(i + 1, count):
			_resolve_pair(bacteria[i], bacteria[j])

	for cell in bacteria:
		_constrain_to_world(cell)


func _resolve_pair(a: Variant, b: Variant) -> void:
	var closest: Array = _closest_points_between_segments(
		a.segment_start(),
		a.segment_end(),
		b.segment_start(),
		b.segment_end()
	)

	var point_a: Vector2 = closest[0]
	var point_b: Vector2 = closest[1]
	var delta: Vector2 = point_b - point_a
	var distance: float = delta.length()
	var target_distance: float = float(a.radius) + float(b.radius)

	if distance >= target_distance:
		return

	var normal: Vector2
	if distance > 0.000001:
		normal = delta / distance
	else:
		normal = a.axis().orthogonal().normalized()
		if (b.id - a.id) % 2 == 0:
			normal = -normal

	var overlap: float = target_distance - distance
	var correction: Vector2 = normal * (overlap * 0.5)
	a.position -= correction
	b.position += correction

	var lever_a: Vector2 = point_a - Vector2(a.position)
	var lever_b: Vector2 = point_b - Vector2(b.position)
	var force_on_a: Vector2 = -normal * overlap
	var force_on_b: Vector2 = normal * overlap

	a.angle += clampf(
		lever_a.cross(force_on_a) * angular_contact_response,
		-0.05,
		0.05
	)
	b.angle += clampf(
		lever_b.cross(force_on_b) * angular_contact_response,
		-0.05,
		0.05
	)

	a.angle = wrapf(a.angle, -PI, PI)
	b.angle = wrapf(b.angle, -PI, PI)


func _closest_points_between_segments(
	p1: Vector2,
	q1: Vector2,
	p2: Vector2,
	q2: Vector2
) -> Array:
	var d1: Vector2 = q1 - p1
	var d2: Vector2 = q2 - p2
	var r: Vector2 = p1 - p2
	var a: float = d1.dot(d1)
	var e: float = d2.dot(d2)
	var f: float = d2.dot(r)
	var s: float = 0.0
	var t: float = 0.0
	var epsilon: float = 0.0000001

	if a <= epsilon and e <= epsilon:
		return [p1, p2]

	if a <= epsilon:
		s = 0.0
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c: float = d1.dot(r)
		if e <= epsilon:
			t = 0.0
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b: float = d1.dot(d2)
			var denominator: float = a * e - b * b
			if absf(denominator) > epsilon:
				s = clampf((b * f - c * e) / denominator, 0.0, 1.0)
			else:
				s = 0.0

			t = (b * s + f) / e

			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)

	var closest_a: Vector2 = p1 + d1 * s
	var closest_b: Vector2 = p2 + d2 * t
	return [closest_a, closest_b]


func _constrain_to_world(cell: Variant) -> void:
	var margin: float = float(cell.length) * 0.5 + float(cell.radius)

	if cell.position.x < margin:
		cell.position.x = margin
		cell.angle = PI - cell.angle
	elif cell.position.x > world_size.x - margin:
		cell.position.x = world_size.x - margin
		cell.angle = PI - cell.angle

	if cell.position.y < margin:
		cell.position.y = margin
		cell.angle = -cell.angle
	elif cell.position.y > world_size.y - margin:
		cell.position.y = world_size.y - margin
		cell.angle = -cell.angle

	cell.angle = wrapf(cell.angle, -PI, PI)


func state_signature() -> String:
	var parts := PackedStringArray()
	parts.append("t:%.5f" % simulation_time)
	parts.append("n:%d" % bacteria.size())
	parts.append("nut:%.5f" % nutrient.total())
	parts.append("waste:%.5f" % waste.total())

	for cell in bacteria:
		parts.append(
			"%d:%d:%.5f:%.5f:%.5f:%.5f:%.5f"
			% [
				cell.id,
				cell.generation,
				cell.position.x,
				cell.position.y,
				cell.angle,
				cell.length,
				cell.energy,
			]
		)

	return "|".join(parts)
