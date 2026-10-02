class_name PetriSimulation
extends RefCounted

const ScalarFieldScript = preload("res://src/simulation/scalar_field.gd")
const BacteriumScript = preload("res://src/simulation/bacterium.gd")

const FIELD_WIDTH := 96
const FIELD_HEIGHT := 64
const FIELD_CELL_SIZE := 2.0
const CHEMISTRY_DT := 1.0 / 30.0
const MECHANICS_DT := 1.0 / 60.0
const SPATIAL_BUCKET_SIZE := 3.0
# 192 x 128 world with 3-unit linked cells.
const GRID_WIDTH := 64
const GRID_HEIGHT := 43
const GRID_CELL_COUNT := GRID_WIDTH * GRID_HEIGHT
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
var _mechanics_accumulator: float = 0.0
var _next_id: int = 1
var _grid_head: PackedInt32Array = PackedInt32Array()
var _grid_next: PackedInt32Array = PackedInt32Array()
var _max_half_body_length: float = 2.0

# Latest mechanics metrics (aggregated across solver iterations for one
# mechanics update). Used by benchmark/HUD, never by simulation decisions.
var pair_candidates_last: int = 0
var pair_narrow_checks_last: int = 0
var pair_interactions_last: int = 0
var pair_contacts_last: int = 0

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

# Observable state transition durations. These do not trigger reproduction;
# they stage an already resource-triggered biological transition.
var division_duration: float = 0.70
var lysis_duration: float = 1.20

# Contact / adhesion.
var mechanical_iterations: int = 2
var angular_contact_response: float = 0.055
var adhesion_range: float = 0.55
var adhesion_pull: float = 0.17
var adhesion_memory: float = 0.22


func _init(seed_value: int = 1) -> void:
	fixed_seed = seed_value
	rng.seed = seed_value
	nutrient = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	waste = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	_grid_head.resize(GRID_CELL_COUNT)
	_grid_head.fill(-1)
	_build_sources()


func seed_demo(count: int = 36) -> void:
	bacteria.clear()
	simulation_time = 0.0
	_chemistry_accumulator = 0.0
	_mechanics_accumulator = 0.0
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
		cell.adhesion_timer = maxf(0.0, float(cell.adhesion_timer) - dt)

		if bool(cell.dying):
			_advance_lysis(cell, dt)
			if float(cell.lysis_progress) >= 1.0:
				_recycle_dead_cell(cell)
			else:
				next_population.append(cell)
			continue

		_advance_cell(cell, dt)

		if bool(cell.dying):
			next_population.append(cell)
			continue

		if bool(cell.dividing):
			cell.division_progress = minf(
				1.0,
				float(cell.division_progress) + dt / maxf(0.001, division_duration)
			)
			if (
				float(cell.division_progress) >= 1.0
				and next_population.size() < SAFETY_POPULATION_LIMIT - 1
			):
				var daughters: Array = _divide(cell)
				next_population.append_array(daughters)
			else:
				next_population.append(cell)
			continue

		if _ready_to_begin_division(cell):
			cell.begin_division()

		next_population.append(cell)

	bacteria = next_population

	_mechanics_accumulator += dt
	while _mechanics_accumulator >= MECHANICS_DT:
		pair_candidates_last = 0
		pair_narrow_checks_last = 0
		pair_interactions_last = 0
		pair_contacts_last = 0
		for _iteration in range(mechanical_iterations):
			_resolve_all_contacts()
		_mechanics_accumulator -= MECHANICS_DT

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

	if not bool(cell.dividing) and rng.randf() < tumble_probability:
		cell.angle = float(cell.angle) + rng.randfn(0.0, tumble_sigma)

	if rotational_diffusion > 0.0 and not bool(cell.dividing):
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
	var division_mobility: float = 0.16 if bool(cell.dividing) else 1.0
	var speed: float = (
		run_speed
		* float(cell.gene_speed)
		* flagella_propulsion
		* energy_speed_factor
		* division_mobility
		/ size_drag
	)

	var heading: Vector2 = Vector2.RIGHT.rotated(float(cell.angle))
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
		+ 0.006 * maxf(0.0, float(cell.gene_adhesion) - 0.7)
	)
	cell.energy = float(cell.energy) - (locomotion_cost + morphology_cost) * dt

	if consumed > 0.0 and not bool(cell.dividing):
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
		cell.begin_lysis()


func _advance_lysis(cell: Variant, dt: float) -> void:
	cell.lysis_progress = minf(
		1.0,
		float(cell.lysis_progress) + dt / maxf(0.001, lysis_duration)
	)
	cell.angle = float(cell.angle) + 0.20 * dt

	var release: float = 0.025 * dt * maxf(1.0, float(cell.length))
	waste.add_radial_world(Vector2(cell.position), 2.2, release)


func _ready_to_begin_division(cell: Variant) -> bool:
	var required_length: float = base_division_length * float(cell.gene_size)
	var required_energy: float = base_division_energy * (
		0.82 + 0.18 * float(cell.gene_size)
	)
	return (
		not bool(cell.dividing)
		and not bool(cell.dying)
		and float(cell.length) >= required_length
		and float(cell.energy) >= required_energy
		and bool(cell.alive)
	)


func _divide(parent: Variant) -> Array:
	var parent_axis: Vector2 = Vector2.RIGHT.rotated(float(parent.angle))
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
	waste.add_radial_world(Vector2(cell.position), 3.0, recycled * 0.16)


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
	_rebuild_spatial_grid()

	var count: int = bacteria.size()
	for i in range(count):
		var cell: Variant = bacteria[i]
		if bool(cell.dying):
			continue

		var position: Vector2 = Vector2(cell.position)
		var bucket_x: int = clampi(
			floori(position.x / SPATIAL_BUCKET_SIZE),
			0,
			GRID_WIDTH - 1
		)
		var bucket_y: int = clampi(
			floori(position.y / SPATIAL_BUCKET_SIZE),
			0,
			GRID_HEIGHT - 1
		)
		var search_world: float = (
			float(cell.length) * 0.5
			+ _max_half_body_length
			+ adhesion_range
		)
		var bucket_radius: int = maxi(
			1,
			ceili(search_world / SPATIAL_BUCKET_SIZE)
		)

		var min_y: int = maxi(0, bucket_y - bucket_radius)
		var max_y: int = mini(GRID_HEIGHT - 1, bucket_y + bucket_radius)
		var min_x: int = maxi(0, bucket_x - bucket_radius)
		var max_x: int = mini(GRID_WIDTH - 1, bucket_x + bucket_radius)

		for y in range(min_y, max_y + 1):
			var row_offset: int = y * GRID_WIDTH
			for x in range(min_x, max_x + 1):
				var j: int = _grid_head[row_offset + x]
				while j >= 0:
					if j > i and not bool(bacteria[j].dying):
						pair_candidates_last += 1
						_resolve_pair(cell, bacteria[j])
					j = _grid_next[j]

	for cell in bacteria:
		_constrain_to_world(cell)


func _rebuild_spatial_grid() -> void:
	_grid_head.fill(-1)
	_grid_next.resize(bacteria.size())
	_grid_next.fill(-1)
	_max_half_body_length = 0.0

	for i in range(bacteria.size()):
		var cell: Variant = bacteria[i]
		if bool(cell.dying):
			continue

		_max_half_body_length = maxf(
			_max_half_body_length,
			float(cell.length) * 0.5
		)

		var position: Vector2 = Vector2(cell.position)
		var x: int = clampi(
			floori(position.x / SPATIAL_BUCKET_SIZE),
			0,
			GRID_WIDTH - 1
		)
		var y: int = clampi(
			floori(position.y / SPATIAL_BUCKET_SIZE),
			0,
			GRID_HEIGHT - 1
		)
		var cell_index: int = y * GRID_WIDTH + x

		_grid_next[i] = _grid_head[cell_index]
		_grid_head[cell_index] = i


func _resolve_pair(a: Variant, b: Variant) -> void:
	var position_a: Vector2 = Vector2(a.position)
	var position_b: Vector2 = Vector2(b.position)
	var length_a: float = float(a.length)
	var length_b: float = float(b.length)
	var radius_a: float = float(a.radius)
	var radius_b: float = float(b.radius)

	# Cheap center-distance rejection before any segment math.
	var max_center_distance: float = (
		length_a * 0.5
		+ length_b * 0.5
		+ adhesion_range
	)
	if position_a.distance_squared_to(position_b) > max_center_distance * max_center_distance:
		return

	pair_narrow_checks_last += 1

	var axis_a: Vector2 = Vector2.RIGHT.rotated(float(a.angle))
	var axis_b: Vector2 = Vector2.RIGHT.rotated(float(b.angle))
	var half_line_a: float = maxf(0.0, (length_a - 2.0 * radius_a) * 0.5)
	var half_line_b: float = maxf(0.0, (length_b - 2.0 * radius_b) * 0.5)

	var closest: Array = _closest_points_between_segments(
		position_a - axis_a * half_line_a,
		position_a + axis_a * half_line_a,
		position_b - axis_b * half_line_b,
		position_b + axis_b * half_line_b
	)

	var point_a: Vector2 = closest[0]
	var point_b: Vector2 = closest[1]
	var delta: Vector2 = point_b - point_a
	var distance: float = delta.length()
	var target_distance: float = radius_a + radius_b
	var interaction_distance: float = target_distance + adhesion_range

	if distance >= interaction_distance:
		return

	pair_interactions_last += 1

	var normal: Vector2
	if distance > 0.000001:
		normal = delta / distance
	else:
		normal = axis_a.orthogonal().normalized()
		if (int(b.id) - int(a.id)) % 2 == 0:
			normal = -normal

	var adhesion_gene: float = (
		float(a.gene_adhesion) + float(b.gene_adhesion)
	) * 0.5

	if adhesion_gene > 0.92:
		a.adhesion_timer = maxf(float(a.adhesion_timer), adhesion_memory)
		b.adhesion_timer = maxf(float(b.adhesion_timer), adhesion_memory)

		if distance > target_distance:
			var gap: float = distance - target_distance
			var pull_strength: float = (
				minf(gap, adhesion_range)
				* adhesion_pull
				* clampf(adhesion_gene - 0.85, 0.0, 1.1)
			)
			var pull: Vector2 = normal * pull_strength * 0.5
			a.position = Vector2(a.position) + pull
			b.position = Vector2(b.position) - pull
			return

	if distance >= target_distance:
		return

	pair_contacts_last += 1
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
	var living_count: int = 0
	for cell in bacteria:
		if bool(cell.dying):
			continue
		total_energy += float(cell.energy)
		living_count += 1

	if living_count <= 0:
		return 0.0
	return total_energy / float(living_count)


func count_dividing() -> int:
	var count: int = 0
	for cell in bacteria:
		if bool(cell.dividing):
			count += 1
	return count


func count_lysing() -> int:
	var count: int = 0
	for cell in bacteria:
		if bool(cell.dying):
			count += 1
	return count


func count_adhering() -> int:
	var count: int = 0
	for cell in bacteria:
		if float(cell.adhesion_timer) > 0.0:
			count += 1
	return count


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
			"%d:%d:%.5f:%.5f:%.5f:%.5f:%.5f:%.4f:%.4f:%.4f:%d:%.3f:%d:%.3f"
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
				1 if bool(cell.dividing) else 0,
				float(cell.division_progress),
				1 if bool(cell.dying) else 0,
				float(cell.lysis_progress),
			]
		)

	return "|".join(parts)
