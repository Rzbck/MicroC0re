class_name PetriSimulation
extends RefCounted

const ScalarFieldScript = preload("res://src/simulation/scalar_field.gd")
const BacteriumScript = preload("res://src/simulation/bacterium.gd")

const FIELD_WIDTH := 96
const FIELD_HEIGHT := 64
const FIELD_CELL_SIZE := 2.0
const CHEMISTRY_DT := 1.0 / 60.0
const SPATIAL_BUCKET_SIZE := 8.0
const SAFETY_POPULATION_LIMIT := 1200

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
var _chemistry_accumulator: float = 0.0
var _next_id: int = 1
var _spatial_buckets: Dictionary = {}

# Environmental coefficients. Concentration is normalized in v0.1.
var nutrient_diffusion: float = 5.0
var nutrient_decay: float = 0.0015
var waste_diffusion: float = 1.25
var waste_decay: float = 0.018
var source_rate: float = 0.22
var source_radius: float = 10.0

# Motility / chemotaxis.
var run_speed: float = 11.0
var base_tumble_rate: float = 0.85
var tumble_sigma: float = 1.10
var rotational_diffusion: float = 0.10
var chemotaxis_memory_tau: float = 0.75
var chemotaxis_gain: float = 5.4

# Resource / energy / growth.
var max_uptake_rate: float = 0.20
var monod_half_saturation: float = 0.12
var energy_yield: float = 5.0
var maintenance_cost: float = 0.035
var movement_cost_per_speed: float = 0.0015
var appendage_cost: float = 0.0015
var uptake_capacity_cost: float = 0.012
var growth_per_nutrient: float = 1.0
var growth_energy_cost_per_length: float = 0.18
var base_division_length: float = 4.2
var base_division_energy: float = 3.35
var minimum_length: float = 2.15
var maximum_length: float = 7.0
var waste_fraction: float = 0.30

# Contact solver.
var mechanical_iterations: int = 2
var angular_contact_response: float = 0.055


func _init(seed_value: int = 1) -> void:
	fixed_seed = seed_value
	rng.seed = seed_value
	nutrient = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	waste = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	_build_sources()


func seed_demo(count: int = 36) -> void:
	bacteria.clear()
	simulation_time = 0.0
	_chemistry_accumulator = 0.0
	_next_id = 1
	rng.seed = fixed_seed
	nutrient.fill(0.012)
	waste.fill(0.0)
	_prime_environment()

	for _i in range(maxi(0, count)):
		var margin: float = 8.0
		var position := Vector2(
			rng.randf_range(margin, world_size.x - margin),
			rng.randf_range(margin, world_size.y - margin)
		)
		var cell: Variant = BacteriumScript.new(
			_allocate_id(),
			position,
			rng.randf_range(-PI, PI)
		)
		cell.configure_founder(rng)
		cell.energy = rng.randf_range(2.6, 3.5)
		cell.length = minimum_length * float(cell.gene_size) * rng.randf_range(0.96, 1.08)
		cell.sensed_memory = nutrient.sample_world(position)
		bacteria.append(cell)

	_resolve_all_contacts()


func step(dt: float) -> void:
	if dt <= 0.0:
		return

	_chemistry_accumulator += dt
	while _chemistry_accumulator >= CHEMISTRY_DT:
		_feed_environment(CHEMISTRY_DT)
		nutrient.diffuse(nutrient_diffusion, CHEMISTRY_DT, nutrient_decay)
		waste.diffuse(waste_diffusion, CHEMISTRY_DT, waste_decay)
		_chemistry_accumulator -= CHEMISTRY_DT

	var next_population: Array = []

	for cell in bacteria:
		if not bool(cell.alive):
			continue

		_advance_cell(cell, dt)

		if not bool(cell.alive):
			_recycle_dead_cell(cell)
			continue

		if _ready_to_divide(cell) and next_population.size() < SAFETY_POPULATION_LIMIT - 1:
			var daughters: Array = _divide(cell)
			next_population.append_array(daughters)
		else:
			next_population.append(cell)

	bacteria = next_population

	for _iteration in range(mechanical_iterations):
		_resolve_all_contacts()

	simulation_time += dt


func _advance_cell(cell: Variant, dt: float) -> void:
	cell.age = float(cell.age) + dt

	var sensed: float = float(nutrient.sample_world(Vector2(cell.position)))
	var improvement: float = sensed - float(cell.sensed_memory)
	var memory_alpha: float = 1.0 - exp(-dt / maxf(0.001, chemotaxis_memory_tau))
	cell.sensed_memory = lerpf(float(cell.sensed_memory), sensed, memory_alpha)

	var bounded_improvement: float = clampf(improvement, -0.25, 0.25)
	var tumble_rate: float = (
		base_tumble_rate
		* float(cell.gene_tumble)
		* exp(-chemotaxis_gain * float(cell.gene_chemotaxis) * bounded_improvement)
	)
	tumble_rate = clampf(tumble_rate, 0.025, 8.0)
	var tumble_probability: float = 1.0 - exp(-tumble_rate * dt)

	if rng.randf() < tumble_probability:
		cell.angle = float(cell.angle) + rng.randfn(0.0, tumble_sigma)

	if rotational_diffusion > 0.0:
		var sigma: float = sqrt(2.0 * rotational_diffusion * dt)
		cell.angle = float(cell.angle) + rng.randfn(0.0, sigma)

	cell.angle = wrapf(float(cell.angle), -PI, PI)

	var flagella_propulsion: float = (
		0.66
		+ 0.085 * float(cell.flagella_count)
		+ 0.15 * float(cell.flagella_length)
	)
	var size_drag: float = 0.84 + 0.20 * float(cell.gene_size)
	var energy_speed_factor: float = clampf(float(cell.energy) / 1.6, 0.18, 1.0)
	var speed: float = (
		run_speed
		* float(cell.gene_speed)
		* flagella_propulsion
		* energy_speed_factor
		/ size_drag
	)

	var heading: Vector2 = Vector2(cell.axis())
	cell.position = Vector2(cell.position) + heading * speed * dt
	_constrain_to_world(cell)

	var local_nutrient: float = float(nutrient.sample_world(Vector2(cell.position)))
	var uptake_rate: float = 0.0
	if local_nutrient > 0.0:
		uptake_rate = (
			max_uptake_rate
			* float(cell.gene_uptake)
			* local_nutrient
			/ (monod_half_saturation + local_nutrient)
		)

	var consumed: float = float(
		nutrient.take_nearest_world(Vector2(cell.position), uptake_rate * dt)
	)
	cell.energy = float(cell.energy) + consumed * energy_yield

	var locomotion_cost: float = (
		movement_cost_per_speed
		* speed
		* (
			0.55
			+ 0.12 * float(cell.flagella_count)
			+ 0.18 * float(cell.flagella_length)
		)
	)
	var morphology_cost: float = (
		maintenance_cost * float(cell.gene_size)
		+ appendage_cost * (
			float(cell.flagella_count)
			+ 0.22 * float(cell.pili_count)
		)
		+ uptake_capacity_cost * maxf(0.0, float(cell.gene_uptake) - 0.75)
	)
	cell.energy = float(cell.energy) - (locomotion_cost + morphology_cost) * dt

	if consumed > 0.0:
		var growth_delta: float = (
			growth_per_nutrient
			* float(cell.gene_growth)
			* consumed
		)
		var max_length_for_cell: float = maximum_length * float(cell.gene_size)
		growth_delta = minf(growth_delta, maxf(0.0, max_length_for_cell - float(cell.length)))

		if growth_delta > 0.0 and float(cell.energy) > 0.35:
			cell.length = float(cell.length) + growth_delta
			cell.energy = float(cell.energy) - growth_delta * growth_energy_cost_per_length

		waste.add_nearest_world(
			Vector2(cell.position),
			consumed * waste_fraction
		)

	if float(cell.energy) <= 0.0:
		cell.energy = 0.0
		cell.alive = false


func _ready_to_divide(cell: Variant) -> bool:
	var required_length: float = base_division_length * float(cell.gene_size)
	var required_energy: float = base_division_energy * (
		0.82 + 0.18 * float(cell.gene_size)
	)
	return (
		float(cell.length) >= required_length
		and float(cell.energy) >= required_energy
		and bool(cell.alive)
	)


func _divide(parent: Variant) -> Array:
	var parent_axis: Vector2 = Vector2(parent.axis())
	var parent_length: float = float(parent.length)
	var daughter_energy: float = float(parent.energy) * 0.475
	var daughter_length: float = parent_length * 0.555
	var offset: Vector2 = parent_axis * (daughter_length * 0.30)

	var a: Variant = BacteriumScript.new(
		_allocate_id(),
		Vector2(parent.position) - offset,
		float(parent.angle) + rng.randfn(0.0, 0.025),
		int(parent.generation) + 1,
		int(parent.id)
	)
	var b: Variant = BacteriumScript.new(
		_allocate_id(),
		Vector2(parent.position) + offset,
		float(parent.angle) + PI + rng.randfn(0.0, 0.025),
		int(parent.generation) + 1,
		int(parent.id)
	)

	for daughter in [a, b]:
		daughter.inherit_and_mutate(parent, rng)
		var daughter_minimum: float = minimum_length * float(daughter.gene_size)
		daughter.length = maxf(daughter_minimum, daughter_length)
		daughter.energy = daughter_energy
		daughter.sensed_memory = nutrient.sample_world(Vector2(daughter.position))
		_constrain_to_world(daughter)

	var daughters: Array = [a, b]
	return daughters


func _recycle_dead_cell(cell: Variant) -> void:
	var recycled: float = maxf(0.05, float(cell.length) * 0.04)
	waste.add_radial_world(Vector2(cell.position), 2.5, recycled * 0.12)


func _feed_environment(dt: float) -> void:
	var amount_per_source: float = source_rate * dt
	for source in nutrient_sources:
		nutrient.add_radial_world(source, source_radius, amount_per_source)


func _prime_environment() -> void:
	for source in nutrient_sources:
		nutrient.add_radial_world(source, source_radius * 1.25, 0.90)


func _build_sources() -> void:
	nutrient_sources = [
		Vector2(world_size.x * 0.14, world_size.y * 0.18),
		Vector2(world_size.x * 0.48, world_size.y * 0.15),
		Vector2(world_size.x * 0.82, world_size.y * 0.23),
		Vector2(world_size.x * 0.29, world_size.y * 0.55),
		Vector2(world_size.x * 0.68, world_size.y * 0.57),
		Vector2(world_size.x * 0.19, world_size.y * 0.83),
		Vector2(world_size.x * 0.80, world_size.y * 0.82),
	]


func _allocate_id() -> int:
	var result: int = _next_id
	_next_id += 1
	return result


func _resolve_all_contacts() -> void:
	_rebuild_spatial_hash()

	var count: int = bacteria.size()
	for i in range(count):
		var cell: Variant = bacteria[i]
		var position: Vector2 = Vector2(cell.position)
		var bucket_x: int = floori(position.x / SPATIAL_BUCKET_SIZE)
		var bucket_y: int = floori(position.y / SPATIAL_BUCKET_SIZE)

		for offset_y in range(-1, 2):
			for offset_x in range(-1, 2):
				var key := Vector2i(bucket_x + offset_x, bucket_y + offset_y)
				if not _spatial_buckets.has(key):
					continue

				var bucket: Array = _spatial_buckets[key]
				for other_index_variant in bucket:
					var j: int = int(other_index_variant)
					if j <= i or j >= count:
						continue
					_resolve_pair(cell, bacteria[j])

	for cell in bacteria:
		_constrain_to_world(cell)


func _rebuild_spatial_hash() -> void:
	_spatial_buckets.clear()

	for i in range(bacteria.size()):
		var cell: Variant = bacteria[i]
		var position: Vector2 = Vector2(cell.position)
		var key := Vector2i(
			floori(position.x / SPATIAL_BUCKET_SIZE),
			floori(position.y / SPATIAL_BUCKET_SIZE)
		)

		if not _spatial_buckets.has(key):
			_spatial_buckets[key] = []

		var bucket: Array = _spatial_buckets[key]
		bucket.append(i)
		_spatial_buckets[key] = bucket


func _resolve_pair(a: Variant, b: Variant) -> void:
	var closest: Array = _closest_points_between_segments(
		Vector2(a.segment_start()),
		Vector2(a.segment_end()),
		Vector2(b.segment_start()),
		Vector2(b.segment_end())
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
		normal = Vector2(a.axis()).orthogonal().normalized()
		if (int(b.id) - int(a.id)) % 2 == 0:
			normal = -normal

	var overlap: float = target_distance - distance
	var correction: Vector2 = normal * (overlap * 0.5)
	a.position = Vector2(a.position) - correction
	b.position = Vector2(b.position) + correction

	var lever_a: Vector2 = point_a - Vector2(a.position)
	var lever_b: Vector2 = point_b - Vector2(b.position)
	var force_on_a: Vector2 = -normal * overlap
	var force_on_b: Vector2 = normal * overlap

	a.angle = float(a.angle) + clampf(
		lever_a.cross(force_on_a) * angular_contact_response,
		-0.045,
		0.045
	)
	b.angle = float(b.angle) + clampf(
		lever_b.cross(force_on_b) * angular_contact_response,
		-0.045,
		0.045
	)

	a.angle = wrapf(float(a.angle), -PI, PI)
	b.angle = wrapf(float(b.angle), -PI, PI)


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
			var b_dot: float = d1.dot(d2)
			var denominator: float = a * e - b_dot * b_dot
			if absf(denominator) > epsilon:
				s = clampf((b_dot * f - c * e) / denominator, 0.0, 1.0)
			else:
				s = 0.0

			t = (b_dot * s + f) / e

			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b_dot - c) / a, 0.0, 1.0)

	var closest_a: Vector2 = p1 + d1 * s
	var closest_b: Vector2 = p2 + d2 * t
	return [closest_a, closest_b]


func _constrain_to_world(cell: Variant) -> void:
	var margin: float = float(cell.length) * 0.5 + float(cell.radius) + 0.5

	if float(cell.position.x) < margin:
		cell.position.x = margin
		cell.angle = PI - float(cell.angle)
	elif float(cell.position.x) > world_size.x - margin:
		cell.position.x = world_size.x - margin
		cell.angle = PI - float(cell.angle)

	if float(cell.position.y) < margin:
		cell.position.y = margin
		cell.angle = -float(cell.angle)
	elif float(cell.position.y) > world_size.y - margin:
		cell.position.y = world_size.y - margin
		cell.angle = -float(cell.angle)

	cell.angle = wrapf(float(cell.angle), -PI, PI)


func max_generation() -> int:
	var result: int = 0
	for cell in bacteria:
		result = maxi(result, int(cell.generation))
	return result


func mean_energy() -> float:
	if bacteria.is_empty():
		return 0.0

	var total_energy: float = 0.0
	for cell in bacteria:
		total_energy += float(cell.energy)
	return total_energy / float(bacteria.size())


func find_cell_by_id(cell_id: int) -> Variant:
	for cell in bacteria:
		if int(cell.id) == cell_id:
			return cell
	return null


func state_signature() -> String:
	var parts := PackedStringArray()
	parts.append("t:%.5f" % simulation_time)
	parts.append("n:%d" % bacteria.size())
	parts.append("nut:%.5f" % nutrient.total())
	parts.append("waste:%.5f" % waste.total())

	for cell in bacteria:
		parts.append(
			"%d:%d:%.5f:%.5f:%.5f:%.5f:%.5f:%.4f:%.4f:%.4f"
			% [
				int(cell.id),
				int(cell.generation),
				float(cell.position.x),
				float(cell.position.y),
				float(cell.angle),
				float(cell.length),
				float(cell.energy),
				float(cell.gene_speed),
				float(cell.gene_uptake),
				float(cell.gene_chemotaxis),
			]
		)

	return "|".join(parts)
