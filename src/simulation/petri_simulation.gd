class_name PetriSimulation
extends RefCounted

const ScalarFieldScript = preload("res://src/simulation/scalar_field.gd")
const BacteriumScript = preload("res://src/simulation/bacterium.gd")
const ProtozoanScript = preload("res://src/simulation/protozoan.gd")
const CiliateScript = preload("res://src/simulation/ciliate.gd")

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
# CPU-reference safety ceilings. These are performance guards, not biology.
# Raise them only after GPU-resident agent mechanics is validated.
const SAFETY_POPULATION_LIMIT := 420
const PROTOZOAN_SAFETY_LIMIT := 18
const CILIATE_SAFETY_LIMIT := 16

var world_size := Vector2(
	FIELD_WIDTH * FIELD_CELL_SIZE,
	FIELD_HEIGHT * FIELD_CELL_SIZE
)

var fixed_seed: int
var rng := RandomNumberGenerator.new()

var nutrient: Variant
var waste: Variant
var oxygen: Variant
var detritus: Variant
var eps: Variant
var damage_cue: Variant
var producer_biomass: Variant
var bacteria: Array = []
var protozoa: Array = []
var ciliates: Array = []
var _population_buffer: Array = []
var nutrient_sources: Array[Vector2] = []
var producer_sources: Array[Vector2] = []

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

# Latest subsystem timings for one simulation tick.
var chemistry_ms_last: float = 0.0
var agents_ms_last: float = 0.0
var mechanics_ms_last: float = 0.0

# Environmental coefficients. Concentration is normalized in v0.1.
var nutrient_diffusion: float = 5.0
var nutrient_decay: float = 0.0015
var waste_diffusion: float = 1.25
var waste_decay: float = 0.018
var source_rate: float = 0.22
var source_radius: float = 10.0

# Living biome fields. Values are normalized qualitative concentrations.
var oxygen_diffusion: float = 2.8
var oxygen_decay: float = 0.0015
var detritus_diffusion: float = 0.18
var detritus_decay: float = 0.004
var eps_diffusion: float = 0.035
var eps_decay: float = 0.0012
var damage_cue_diffusion: float = 3.8
var damage_cue_decay: float = 0.72
var producer_decay: float = 0.0006
var producer_growth_rate: float = 0.014
var producer_oxygen_rate: float = 0.018
var producer_leak_rate: float = 0.0035
var oxygen_half_saturation: float = 0.16
var oxygen_consumption_rate: float = 0.020
var detritus_scavenge_rate: float = 0.070
var detritus_energy_yield: float = 3.4
var eps_secretion_rate: float = 0.0045
var water_flow_strength: float = 0.42

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

# Direct-contact plasmid conjugation.
var conjugation_contact_rate: float = 0.28
var conjugation_duration: float = 1.15
var conjugation_break_distance: float = 2.8
var conjugation_pull: float = 0.10

# Amoeboid/protist ecology. This is intentionally a distinct organism class:
# bacteria do not magically fuse into blobs. The larger cell deforms, hunts,
# and visibly engulfs bacterial prey over time.
var protozoan_speed: float = 5.4
var protozoan_perception: float = 28.0
var protozoan_engulf_distance: float = 4.2
var protozoan_engulf_duration: float = 1.35
var protozoan_maintenance: float = 0.065
var protozoan_reproduction_energy: float = 18.5

# Fast ciliate-like grazer: a second predator guild that sweeps dense prey
# patches. Fewer, faster predators help regulate bacterial blooms without
# requiring hundreds of expensive predator agents.
var ciliate_speed: float = 10.5
var ciliate_perception: float = 34.0
var ciliate_feed_distance: float = 3.4
var ciliate_feed_duration: float = 0.62
var ciliate_maintenance: float = 0.090
var ciliate_reproduction_energy: float = 16.5


func _init(seed_value: int = 1) -> void:
	fixed_seed = seed_value
	rng.seed = seed_value
	nutrient = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	waste = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	oxygen = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	detritus = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	eps = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	damage_cue = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	producer_biomass = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	_grid_head.resize(GRID_CELL_COUNT)
	_grid_head.fill(-1)
	_build_sources()


func seed_demo(count: int = 36) -> void:
	bacteria.clear()
	protozoa.clear()
	ciliates.clear()
	_population_buffer.clear()
	simulation_time = 0.0
	_chemistry_accumulator = 0.0
	_mechanics_accumulator = 0.0
	_next_id = 1
	rng.seed = fixed_seed
	nutrient.fill(0.012)
	waste.fill(0.0)
	oxygen.fill(0.42)
	detritus.fill(0.0)
	eps.fill(0.0)
	damage_cue.fill(0.0)
	producer_biomass.fill(0.0)
	_prime_environment()

	for _i in range(maxi(0, count)):
		var margin: float = 8.0
		var position: Vector2

		# Seed most founders in loose patches around food sources. This creates
		# observable competition/contact immediately instead of a uniformly
		# sparse screen, while keeping some explorers in the background.
		if _i % 4 != 0 and not nutrient_sources.is_empty():
			var source: Vector2 = nutrient_sources[_i % nutrient_sources.size()]
			var radius: float = rng.randf_range(4.0, 14.0)
			var theta: float = rng.randf_range(-PI, PI)
			position = source + Vector2.RIGHT.rotated(theta) * radius
			position.x = clampf(position.x, margin, world_size.x - margin)
			position.y = clampf(position.y, margin, world_size.y - margin)
		else:
			position = Vector2(
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

	# A few large amoeboid predators make the ecology observable immediately:
	# they chase nearby bacteria and engulf them with a staged deformation.
	for proto_index in range(2):
		var proto_margin: float = 14.0
		var proto_source: Vector2 = nutrient_sources[
			(proto_index * 2 + 1) % nutrient_sources.size()
		]
		var proto_position: Vector2 = (
			proto_source
			+ Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
			* rng.randf_range(10.0, 18.0)
		)
		proto_position.x = clampf(
			proto_position.x,
			proto_margin,
			world_size.x - proto_margin
		)
		proto_position.y = clampf(
			proto_position.y,
			proto_margin,
			world_size.y - proto_margin
		)
		var proto: Variant = ProtozoanScript.new(
			_allocate_id(),
			proto_position,
			rng.randf_range(-PI, PI),
			rng.randf_range(0.0, TAU)
		)
		proto.configure_founder(rng)
		proto.lineage_hue = wrapf(0.48 + float(proto_index) * 0.055, 0.0, 1.0)
		protozoa.append(proto)

	# Faster ciliate-like grazers patrol dense bacterial patches and create a
	# second top-down pressure with a different movement/feeding strategy.
	for ciliate_index in range(1):
		var ciliate_margin: float = 12.0
		var ciliate_source: Vector2 = nutrient_sources[
			(ciliate_index * 3 + 2) % nutrient_sources.size()
		]
		var ciliate_position: Vector2 = (
			ciliate_source
			+ Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
			* rng.randf_range(8.0, 16.0)
		)
		ciliate_position.x = clampf(
			ciliate_position.x,
			ciliate_margin,
			world_size.x - ciliate_margin
		)
		ciliate_position.y = clampf(
			ciliate_position.y,
			ciliate_margin,
			world_size.y - ciliate_margin
		)
		var ciliate: Variant = CiliateScript.new(
			_allocate_id(),
			ciliate_position,
			rng.randf_range(-PI, PI),
			rng.randf_range(0.0, TAU)
		)
		ciliate.configure_founder(rng)
		ciliates.append(ciliate)

	_resolve_all_contacts()


func step(dt: float) -> void:
	if dt <= 0.0:
		return

	var chemistry_start: int = Time.get_ticks_usec()
	_chemistry_accumulator += dt
	while _chemistry_accumulator >= CHEMISTRY_DT:
		_feed_environment(CHEMISTRY_DT)
		_advance_producer_mat(CHEMISTRY_DT)
		nutrient.diffuse(nutrient_diffusion, CHEMISTRY_DT, nutrient_decay)
		waste.diffuse(waste_diffusion, CHEMISTRY_DT, waste_decay)
		oxygen.diffuse(oxygen_diffusion, CHEMISTRY_DT, oxygen_decay)
		detritus.diffuse(detritus_diffusion, CHEMISTRY_DT, detritus_decay)
		eps.diffuse(eps_diffusion, CHEMISTRY_DT, eps_decay)
		damage_cue.diffuse(
			damage_cue_diffusion,
			CHEMISTRY_DT,
			damage_cue_decay
		)
		producer_biomass.diffuse(0.0, CHEMISTRY_DT, producer_decay)
		_chemistry_accumulator -= CHEMISTRY_DT
	chemistry_ms_last = float(Time.get_ticks_usec() - chemistry_start) / 1000.0

	var agents_start: int = Time.get_ticks_usec()
	var next_population: Array = _population_buffer
	next_population.clear()

	for cell in bacteria:
		cell.adhesion_timer = maxf(0.0, float(cell.adhesion_timer) - dt)

		if bool(cell.consumed):
			continue

		if int(cell.engulfed_by_id) >= 0:
			next_population.append(cell)
			continue

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
			if float(cell.division_progress) >= 1.0:
				if next_population.size() < SAFETY_POPULATION_LIMIT - 1:
					var daughters: Array = _divide(cell)
					next_population.append_array(daughters)
				else:
					# Explicit performance guard: suppress further fission at
					# the CPU-reference ceiling without deleting live cells.
					cell.dividing = false
					cell.division_progress = 0.0
					cell.energy = minf(float(cell.energy), base_division_energy * 0.92)
					next_population.append(cell)
			else:
				next_population.append(cell)
			continue

		if _ready_to_begin_division(cell):
			cell.begin_division()

		next_population.append(cell)

	var previous_population: Array = bacteria
	bacteria = next_population
	_population_buffer = previous_population
	_population_buffer.clear()
	agents_ms_last = float(Time.get_ticks_usec() - agents_start) / 1000.0

	var mechanics_start: int = Time.get_ticks_usec()
	_mechanics_accumulator += dt
	while _mechanics_accumulator >= MECHANICS_DT:
		pair_candidates_last = 0
		pair_narrow_checks_last = 0
		pair_interactions_last = 0
		pair_contacts_last = 0
		for _iteration in range(mechanical_iterations):
			_resolve_all_contacts()
		_mechanics_accumulator -= MECHANICS_DT
	mechanics_ms_last = float(Time.get_ticks_usec() - mechanics_start) / 1000.0

	_advance_gene_transfers(dt)
	_advance_protozoa(dt)
	_advance_ciliates(dt)

	simulation_time += dt


func _advance_protozoa(dt: float) -> void:
	var next_protozoa: Array = []
	var available_births: int = maxi(0, PROTOZOAN_SAFETY_LIMIT - protozoa.size())

	for proto in protozoa:
		if not bool(proto.alive):
			continue

		proto.age = float(proto.age) + dt
		proto.cooldown = maxf(0.0, float(proto.cooldown) - dt)
		proto.deform_phase = wrapf(
			float(proto.deform_phase)
			+ dt * (2.8 + 0.15 * float(proto.energy)),
			0.0,
			TAU
		)

		var maintenance: float = (
			protozoan_maintenance
			* float(proto.gene_metabolism)
			* (0.75 + 0.25 * float(proto.gene_size))
		)
		proto.energy = float(proto.energy) - maintenance * dt

		if float(proto.energy) <= 0.0:
			proto.alive = false
			_release_predator_prey(int(proto.feeding_target_id), int(proto.id))
			continue

		if int(proto.feeding_target_id) >= 0:
			_advance_protozoan_engulf(proto, dt)
			next_protozoa.append(proto)
			continue

		var prey: Variant = _find_protozoan_prey(proto)
		var desired_angle: float = float(proto.angle)

		if prey != null:
			var to_prey: Vector2 = Vector2(prey.position) - Vector2(proto.position)
			if to_prey.length_squared() > 0.000001:
				desired_angle = to_prey.angle()

			var engulf_distance: float = (
				protozoan_engulf_distance
				* (0.85 + 0.15 * float(proto.gene_size))
			)
			if (
				float(proto.cooldown) <= 0.0
				and to_prey.length() <= engulf_distance
			):
				proto.begin_engulf(int(prey.id))
				prey.engulfed_by_id = int(proto.id)
				prey.engulf_progress = 0.0
				next_protozoa.append(proto)
				continue
		else:
			desired_angle += sin(
				simulation_time * 0.73 + float(proto.deform_phase)
			) * 0.45

		proto.angle = lerp_angle(
			float(proto.angle),
			desired_angle,
			clampf(dt * 2.4, 0.0, 1.0)
		)

		var pulse: float = 0.82 + 0.18 * sin(float(proto.deform_phase) * 1.7)
		var speed: float = protozoan_speed * float(proto.gene_speed) * pulse
		proto.position = (
			Vector2(proto.position)
			+ Vector2.RIGHT.rotated(float(proto.angle)) * speed * dt
		)
		proto.deform_amount = lerpf(
			float(proto.deform_amount),
			0.20 + 0.12 * absf(sin(float(proto.deform_phase))),
			clampf(dt * 5.0, 0.0, 1.0)
		)
		_constrain_protozoan(proto)

		if (
			available_births > 0
			and float(proto.energy) >= protozoan_reproduction_energy
			and float(proto.age) >= 12.0
			and float(proto.cooldown) <= 0.0
		):
			next_protozoa.append_array(_divide_protozoan(proto))
			available_births -= 1
		else:
			next_protozoa.append(proto)

	protozoa = next_protozoa


func _find_protozoan_prey(proto: Variant) -> Variant:
	var best: Variant = null
	var perception: float = protozoan_perception * float(proto.gene_perception)
	var best_distance_sq: float = perception * perception
	var origin: Vector2 = Vector2(proto.position)

	for cell in bacteria:
		if (
			bool(cell.dying)
			or bool(cell.consumed)
			or int(cell.engulfed_by_id) >= 0
		):
			continue

		var distance_sq: float = origin.distance_squared_to(Vector2(cell.position))
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best = cell

	return best


func _advance_protozoan_engulf(proto: Variant, dt: float) -> void:
	var prey: Variant = find_cell_by_id(int(proto.feeding_target_id))
	if prey == null or bool(prey.consumed):
		proto.finish_engulf()
		return

	if bool(prey.dying):
		prey.engulfed_by_id = -1
		prey.engulf_progress = 0.0
		proto.finish_engulf()
		return

	var duration: float = (
		protozoan_engulf_duration
		/ maxf(0.45, float(proto.gene_engulf))
	)
	var progress: float = minf(
		1.0,
		float(proto.feeding_progress) + dt / maxf(0.001, duration)
	)
	proto.feeding_progress = progress
	proto.deform_amount = 0.35 + sin(progress * PI) * 0.55

	var prey_position: Vector2 = Vector2(prey.position)
	var proto_position: Vector2 = Vector2(proto.position)
	var pull_alpha: float = clampf(dt * (2.0 + progress * 5.0), 0.0, 1.0)
	prey.position = prey_position.lerp(proto_position, pull_alpha)
	prey.engulf_progress = progress
	prey.angle = lerp_angle(
		float(prey.angle),
		float(proto.angle) + PI * 0.5,
		clampf(dt * 4.0, 0.0, 1.0)
	)

	var wobble: float = sin(float(proto.deform_phase) * 2.3) * 0.22
	proto.angle = wrapf(float(proto.angle) + wobble * dt, -PI, PI)

	if progress >= 1.0:
		prey.consumed = true
		prey.alive = false
		prey.engulfed_by_id = -1
		proto.energy = minf(
			20.0,
			float(proto.energy) + 1.35 + float(prey.length) * 0.18
		)
		proto.finish_engulf()


func _divide_protozoan(parent: Variant) -> Array:
	var axis: Vector2 = Vector2.RIGHT.rotated(float(parent.angle))
	var offset: Vector2 = axis.orthogonal() * float(parent.radius) * 0.65
	var daughter_energy: float = float(parent.energy) * 0.44

	var a: Variant = ProtozoanScript.new(
		_allocate_id(),
		Vector2(parent.position) - offset,
		float(parent.angle) + rng.randfn(0.0, 0.18),
		rng.randf_range(0.0, TAU)
	)
	var b: Variant = ProtozoanScript.new(
		_allocate_id(),
		Vector2(parent.position) + offset,
		float(parent.angle) + PI + rng.randfn(0.0, 0.18),
		rng.randf_range(0.0, TAU)
	)

	for daughter in [a, b]:
		daughter.inherit_and_mutate(parent, rng)
		daughter.energy = daughter_energy
		daughter.cooldown = 2.8
		_constrain_protozoan(daughter)

	return [a, b]


func _constrain_protozoan(proto: Variant) -> void:
	var margin: float = float(proto.radius) + 1.0
	var position: Vector2 = Vector2(proto.position)
	var angle: float = float(proto.angle)

	if position.x < margin:
		position.x = margin
		angle = PI - angle
	elif position.x > world_size.x - margin:
		position.x = world_size.x - margin
		angle = PI - angle

	if position.y < margin:
		position.y = margin
		angle = -angle
	elif position.y > world_size.y - margin:
		position.y = world_size.y - margin
		angle = -angle

	proto.position = position
	proto.angle = wrapf(angle, -PI, PI)


func _advance_ciliates(dt: float) -> void:
	var next_ciliates: Array = []
	var available_births: int = maxi(0, CILIATE_SAFETY_LIMIT - ciliates.size())

	for ciliate in ciliates:
		if not bool(ciliate.alive):
			continue

		ciliate.age = float(ciliate.age) + dt
		ciliate.cooldown = maxf(0.0, float(ciliate.cooldown) - dt)
		ciliate.swim_phase = wrapf(
			float(ciliate.swim_phase) + dt * (8.0 + float(ciliate.gene_speed)),
			0.0,
			TAU
		)

		var maintenance: float = (
			ciliate_maintenance
			* float(ciliate.gene_metabolism)
			* (0.80 + 0.20 * float(ciliate.gene_size))
		)
		ciliate.energy = float(ciliate.energy) - maintenance * dt

		if float(ciliate.energy) <= 0.0:
			ciliate.alive = false
			_release_predator_prey(
				int(ciliate.feeding_target_id),
				int(ciliate.id)
			)
			continue

		if int(ciliate.feeding_target_id) >= 0:
			_advance_ciliate_feed(ciliate, dt)
			next_ciliates.append(ciliate)
			continue

		var prey: Variant = _find_ciliate_prey(ciliate)
		var desired_angle: float = float(ciliate.angle)

		if prey != null:
			var to_prey: Vector2 = Vector2(prey.position) - Vector2(ciliate.position)
			if to_prey.length_squared() > 0.000001:
				desired_angle = to_prey.angle()

			var feed_distance: float = (
				ciliate_feed_distance
				* (0.85 + 0.15 * float(ciliate.gene_size))
			)
			if (
				float(ciliate.cooldown) <= 0.0
				and to_prey.length() <= feed_distance
			):
				ciliate.begin_feed(int(prey.id))
				prey.engulfed_by_id = int(ciliate.id)
				prey.engulf_progress = 0.0
				next_ciliates.append(ciliate)
				continue
		else:
			desired_angle += sin(
				simulation_time * 1.9 + float(ciliate.swim_phase)
			) * 0.28

		ciliate.angle = lerp_angle(
			float(ciliate.angle),
			desired_angle,
			clampf(dt * 4.8, 0.0, 1.0)
		)

		var stroke: float = 0.88 + 0.12 * sin(float(ciliate.swim_phase))
		var speed: float = ciliate_speed * float(ciliate.gene_speed) * stroke
		ciliate.position = (
			Vector2(ciliate.position)
			+ Vector2.RIGHT.rotated(float(ciliate.angle)) * speed * dt
		)
		_constrain_ciliate(ciliate)

		if (
			available_births > 0
			and float(ciliate.energy) >= ciliate_reproduction_energy
			and float(ciliate.age) >= 10.0
			and float(ciliate.cooldown) <= 0.0
		):
			next_ciliates.append_array(_divide_ciliate(ciliate))
			available_births -= 1
		else:
			next_ciliates.append(ciliate)

	ciliates = next_ciliates


func _find_ciliate_prey(ciliate: Variant) -> Variant:
	var best: Variant = null
	var perception: float = ciliate_perception * float(ciliate.gene_perception)
	var best_distance_sq: float = perception * perception
	var origin: Vector2 = Vector2(ciliate.position)

	for cell in bacteria:
		if (
			bool(cell.dying)
			or bool(cell.consumed)
			or int(cell.engulfed_by_id) >= 0
		):
			continue

		var distance_sq: float = origin.distance_squared_to(Vector2(cell.position))
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best = cell

	return best


func _advance_ciliate_feed(ciliate: Variant, dt: float) -> void:
	var prey: Variant = find_cell_by_id(int(ciliate.feeding_target_id))
	if prey == null or bool(prey.consumed):
		ciliate.finish_feed()
		return

	if bool(prey.dying):
		prey.engulfed_by_id = -1
		prey.engulf_progress = 0.0
		ciliate.finish_feed()
		return

	var duration: float = (
		ciliate_feed_duration
		/ maxf(0.45, float(ciliate.gene_capture))
	)
	var progress: float = minf(
		1.0,
		float(ciliate.feeding_progress) + dt / maxf(0.001, duration)
	)
	ciliate.feeding_progress = progress
	prey.engulf_progress = progress

	var mouth: Vector2 = (
		Vector2(ciliate.position)
		+ Vector2.RIGHT.rotated(float(ciliate.angle))
		* float(ciliate.radius) * 0.55
	)
	prey.position = Vector2(prey.position).lerp(
		mouth,
		clampf(dt * (5.0 + progress * 8.0), 0.0, 1.0)
	)
	prey.angle = lerp_angle(
		float(prey.angle),
		float(ciliate.angle),
		clampf(dt * 7.0, 0.0, 1.0)
	)

	if progress >= 1.0:
		prey.consumed = true
		prey.alive = false
		prey.engulfed_by_id = -1
		ciliate.energy = minf(
			16.0,
			float(ciliate.energy) + 0.95 + float(prey.length) * 0.14
		)
		ciliate.finish_feed()


func _divide_ciliate(parent: Variant) -> Array:
	var axis: Vector2 = Vector2.RIGHT.rotated(float(parent.angle))
	var offset: Vector2 = axis.orthogonal() * float(parent.radius) * 0.70
	var daughter_energy: float = float(parent.energy) * 0.44

	var a: Variant = CiliateScript.new(
		_allocate_id(),
		Vector2(parent.position) - offset,
		float(parent.angle) + rng.randfn(0.0, 0.12),
		rng.randf_range(0.0, TAU)
	)
	var b: Variant = CiliateScript.new(
		_allocate_id(),
		Vector2(parent.position) + offset,
		float(parent.angle) + PI + rng.randfn(0.0, 0.12),
		rng.randf_range(0.0, TAU)
	)

	for daughter in [a, b]:
		daughter.inherit_and_mutate(parent, rng)
		daughter.energy = daughter_energy
		daughter.cooldown = 2.2
		_constrain_ciliate(daughter)

	return [a, b]


func _constrain_ciliate(ciliate: Variant) -> void:
	var margin: float = float(ciliate.radius) + 0.8
	var position: Vector2 = Vector2(ciliate.position)
	var angle: float = float(ciliate.angle)

	if position.x < margin:
		position.x = margin
		angle = PI - angle
	elif position.x > world_size.x - margin:
		position.x = world_size.x - margin
		angle = PI - angle

	if position.y < margin:
		position.y = margin
		angle = -angle
	elif position.y > world_size.y - margin:
		position.y = world_size.y - margin
		angle = -angle

	ciliate.position = position
	ciliate.angle = wrapf(angle, -PI, PI)


func _release_predator_prey(prey_id: int, predator_id: int) -> void:
	if prey_id < 0:
		return
	var prey: Variant = find_cell_by_id(prey_id)
	if prey == null:
		return
	if int(prey.engulfed_by_id) == predator_id:
		prey.engulfed_by_id = -1
		prey.engulf_progress = 0.0


func _advance_gene_transfers(dt: float) -> void:
	for recipient in bacteria:
		if int(recipient.transfer_role) != int(BacteriumScript.TRANSFER_RECIPIENT):
			continue

		if (
			bool(recipient.dying)
			or bool(recipient.consumed)
			or int(recipient.engulfed_by_id) >= 0
		):
			var stale_donor: Variant = find_cell_by_id(int(recipient.transfer_partner_id))
			if stale_donor != null:
				stale_donor.clear_transfer_state()
			recipient.clear_transfer_state()
			continue

		var donor: Variant = find_cell_by_id(int(recipient.transfer_partner_id))
		if (
			donor == null
			or bool(donor.dying)
			or bool(donor.consumed)
			or int(donor.transfer_role) != int(BacteriumScript.TRANSFER_DONOR)
			or int(donor.transfer_partner_id) != int(recipient.id)
		):
			recipient.clear_transfer_state()
			continue

		var delta: Vector2 = Vector2(recipient.position) - Vector2(donor.position)
		if delta.length() > conjugation_break_distance:
			donor.clear_transfer_state()
			recipient.clear_transfer_state()
			continue

		# Weakly hold the mating pair together while the bridge is active.
		var midpoint: Vector2 = (
			Vector2(donor.position) + Vector2(recipient.position)
		) * 0.5
		donor.position = Vector2(donor.position).lerp(
			midpoint,
			clampf(dt * conjugation_pull, 0.0, 1.0)
		)
		recipient.position = Vector2(recipient.position).lerp(
			midpoint,
			clampf(dt * conjugation_pull, 0.0, 1.0)
		)

		var progress: float = minf(
			1.0,
			float(recipient.transfer_progress)
			+ dt / maxf(0.001, conjugation_duration)
		)
		recipient.transfer_progress = progress
		donor.transfer_progress = progress

		if progress < 1.0:
			continue

		var missing_mask: int = (
			int(donor.plasmid_mask) & ~int(recipient.plasmid_mask)
		)
		var candidates := PackedInt32Array()
		for bit in [
			BacteriumScript.PLASMID_CONJUGATION,
			BacteriumScript.PLASMID_SCAVENGE,
			BacteriumScript.PLASMID_ADHESION,
			BacteriumScript.PLASMID_STRESS,
		]:
			if (missing_mask & int(bit)) != 0:
				candidates.append(int(bit))

		if not candidates.is_empty():
			var chosen: int = candidates[rng.randi_range(0, candidates.size() - 1)]
			recipient.plasmid_mask = int(recipient.plasmid_mask) | chosen
			recipient.hgt_events = int(recipient.hgt_events) + 1
			if chosen == int(BacteriumScript.PLASMID_CONJUGATION):
				recipient.pili_count = maxi(int(recipient.pili_count), 4)

		donor.clear_transfer_state()
		recipient.clear_transfer_state()


func _maybe_start_conjugation(
	a: Variant,
	b: Variant,
	distance: float,
	target_distance: float
) -> void:
	if distance > target_distance + 0.22:
		return
	if (
		int(a.transfer_role) != int(BacteriumScript.TRANSFER_NONE)
		or int(b.transfer_role) != int(BacteriumScript.TRANSFER_NONE)
		or bool(a.dividing)
		or bool(b.dividing)
		or bool(a.dying)
		or bool(b.dying)
	):
		return

	var donor: Variant = null
	var recipient: Variant = null
	var missing_ab: int = int(a.plasmid_mask) & ~int(b.plasmid_mask)
	var missing_ba: int = int(b.plasmid_mask) & ~int(a.plasmid_mask)

	if (
		a.has_plasmid(BacteriumScript.PLASMID_CONJUGATION)
		and missing_ab != 0
	):
		donor = a
		recipient = b
	elif (
		b.has_plasmid(BacteriumScript.PLASMID_CONJUGATION)
		and missing_ba != 0
	):
		donor = b
		recipient = a

	if donor == null:
		return

	var pili_factor: float = clampf(
		float(donor.pili_count) / 4.0,
		0.5,
		2.0
	)
	var probability: float = 1.0 - exp(
		-conjugation_contact_rate * pili_factor * MECHANICS_DT
	)
	if rng.randf() >= probability:
		return

	donor.transfer_role = BacteriumScript.TRANSFER_DONOR
	donor.transfer_partner_id = int(recipient.id)
	donor.transfer_progress = 0.0
	recipient.transfer_role = BacteriumScript.TRANSFER_RECIPIENT
	recipient.transfer_partner_id = int(donor.id)
	recipient.transfer_progress = 0.0


func _plasmid_uptake_factor(cell: Variant) -> float:
	return 1.16 if cell.has_plasmid(BacteriumScript.PLASMID_SCAVENGE) else 1.0


func _plasmid_adhesion_factor(cell: Variant) -> float:
	return 1.18 if cell.has_plasmid(BacteriumScript.PLASMID_ADHESION) else 1.0


func _plasmid_maintenance_factor(cell: Variant) -> float:
	return 0.88 if cell.has_plasmid(BacteriumScript.PLASMID_STRESS) else 1.0


func _plasmid_burden(cell: Variant) -> float:
	var modules: int = 0
	for bit in [
		BacteriumScript.PLASMID_CONJUGATION,
		BacteriumScript.PLASMID_SCAVENGE,
		BacteriumScript.PLASMID_ADHESION,
		BacteriumScript.PLASMID_STRESS,
	]:
		if cell.has_plasmid(bit):
			modules += 1
	return 0.0018 * float(modules)


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
	var flow: Vector2 = _water_flow(Vector2(cell.position))
	var local_eps: float = float(eps.sample_world(Vector2(cell.position)))
	var eps_drag: float = 1.0 / (1.0 + local_eps * 0.85)
	cell.position = (
		Vector2(cell.position)
		+ heading * speed * eps_drag * dt
		+ flow * dt
	)
	_constrain_to_world(cell)

	var local_nutrient: float = float(nutrient.sample_world(Vector2(cell.position)))
	var local_oxygen: float = float(oxygen.sample_world(Vector2(cell.position)))
	var oxygen_factor: float = (
		0.48
		+ 0.52 * local_oxygen / (oxygen_half_saturation + local_oxygen)
	)
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
	cell.energy = (
		float(cell.energy)
		+ consumed * energy_yield * oxygen_factor
	)

	if consumed > 0.0:
		oxygen.take_nearest_world(
			Vector2(cell.position),
			consumed * oxygen_consumption_rate
		)

	var scavenged: float = 0.0
	if cell.has_plasmid(BacteriumScript.PLASMID_SCAVENGE):
		scavenged = float(
			detritus.take_nearest_world(
				Vector2(cell.position),
				detritus_scavenge_rate * float(cell.gene_uptake) * dt
			)
		)
		cell.energy = (
			float(cell.energy)
			+ scavenged * detritus_energy_yield
		)

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
		+ _plasmid_burden(cell)
	)
	morphology_cost *= _plasmid_maintenance_factor(cell)
	cell.energy = float(cell.energy) - (locomotion_cost + morphology_cost) * dt

	if (
		float(cell.gene_adhesion) > 0.95
		or cell.has_plasmid(BacteriumScript.PLASMID_ADHESION)
	):
		var secretion: float = (
			eps_secretion_rate
			* maxf(0.0, float(cell.gene_adhesion) - 0.75)
			* clampf(float(cell.energy) / 3.0, 0.2, 1.0)
			* dt
		)
		if secretion > 0.0:
			eps.add_nearest_world(Vector2(cell.position), secretion)
			cell.energy = maxf(0.0, float(cell.energy) - secretion * 0.7)

	if (consumed > 0.0 or scavenged > 0.0) and not bool(cell.dividing):
		var growth_delta: float = (
			growth_per_nutrient
			* float(cell.gene_growth)
			* (consumed + scavenged * 0.45)
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
	detritus.add_radial_world(Vector2(cell.position), 2.6, release * 0.55)
	damage_cue.add_radial_world(Vector2(cell.position), 4.0, release * 1.8)


func _ready_to_begin_division(cell: Variant) -> bool:
	var required_length: float = base_division_length * float(cell.gene_size)
	var required_energy: float = base_division_energy * (
		0.82 + 0.18 * float(cell.gene_size)
	)
	return (
		bacteria.size() < SAFETY_POPULATION_LIMIT - 1
		and not bool(cell.dividing)
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
	var position: Vector2 = Vector2(cell.position)
	waste.add_radial_world(position, 3.0, recycled * 0.16)
	detritus.add_radial_world(position, 4.2, recycled * 0.85)
	damage_cue.add_radial_world(position, 5.0, recycled * 0.75)


func _feed_environment(dt: float) -> void:
	var amount_per_source: float = source_rate * dt
	for source in nutrient_sources:
		nutrient.add_radial_world(source, source_radius, amount_per_source)

	# Producer mats are the first vegetation-like biome component: they use
	# light to release oxygen and leak a small amount of dissolved organic
	# material back into the microbial loop.
	for source in producer_sources:
		var local_light: float = float(_sample_light(source))
		var mat: float = float(producer_biomass.sample_world(source))
		var activity: float = local_light * clampf(mat * 1.8, 0.0, 1.0)
		oxygen.add_radial_world(
			source,
			source_radius * 0.9,
			producer_oxygen_rate * activity * dt
		)
		nutrient.add_radial_world(
			source,
			source_radius * 0.7,
			producer_leak_rate * activity * dt
		)


func _advance_producer_mat(dt: float) -> void:
	var count: int = producer_biomass.values.size()
	for i in range(count):
		var light_value: float = _light_value_for_index(i)
		var biomass: float = float(producer_biomass.values[i])
		var local_nutrient: float = float(nutrient.values[i])
		var carrying: float = clampf(1.0 - biomass, 0.0, 1.0)
		var growth: float = (
			producer_growth_rate
			* light_value
			* (0.25 + 0.75 * clampf(local_nutrient * 2.0, 0.0, 1.0))
			* carrying
			* dt
		)
		producer_biomass.values[i] = clampf(
			biomass + growth,
			0.0,
			1.0
		)

		if biomass > 0.002:
			oxygen.values[i] = maxf(
				0.0,
				float(oxygen.values[i])
				+ biomass * light_value * producer_oxygen_rate * 0.20 * dt
			)


func _prime_environment() -> void:
	for source in nutrient_sources:
		nutrient.add_radial_world(source, source_radius * 1.25, 0.90)

	for source in producer_sources:
		producer_biomass.add_radial_world(source, 12.0, 0.72)
		oxygen.add_radial_world(source, 14.0, 0.55)


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
	producer_sources = [
		Vector2(world_size.x * 0.18, world_size.y * 0.28),
		Vector2(world_size.x * 0.42, world_size.y * 0.72),
		Vector2(world_size.x * 0.64, world_size.y * 0.30),
		Vector2(world_size.x * 0.86, world_size.y * 0.67),
	]


func _sample_light(position: Vector2) -> float:
	var normalized_y: float = clampf(position.y / world_size.y, 0.0, 1.0)
	var vertical: float = lerpf(1.0, 0.38, normalized_y)
	var ripple: float = (
		0.10
		* sin(position.x * 0.055 + simulation_time * 0.07)
		* cos(position.y * 0.045 - simulation_time * 0.05)
	)
	return clampf(vertical + ripple, 0.15, 1.0)


func _light_value_for_index(index: int) -> float:
	var x: int = index % FIELD_WIDTH
	var y: int = index / FIELD_WIDTH
	var position := Vector2(
		(float(x) + 0.5) * FIELD_CELL_SIZE,
		(float(y) + 0.5) * FIELD_CELL_SIZE
	)
	return _sample_light(position)


func _water_flow(position: Vector2) -> Vector2:
	# Small deterministic aqueous current. It gives the biome a water phase
	# without turning every organism into a passive particle.
	var x_wave: float = sin(
		position.y * 0.045 + simulation_time * 0.11
	)
	var y_wave: float = cos(
		position.x * 0.038 - simulation_time * 0.075
	)
	return Vector2(x_wave, y_wave) * water_flow_strength


func _damage_cue_direction(position: Vector2) -> Vector2:
	var gradient: Vector2 = Vector2(damage_cue.gradient_world(position))
	if gradient.length_squared() <= 0.0000001:
		return Vector2.ZERO
	return gradient.normalized()


func _allocate_id() -> int:
	var result: int = _next_id
	_next_id += 1
	return result


func _resolve_all_contacts() -> void:
	_rebuild_spatial_grid()

	var count: int = bacteria.size()
	for i in range(count):
		var cell: Variant = bacteria[i]
		if (
			bool(cell.dying)
			or bool(cell.consumed)
			or int(cell.engulfed_by_id) >= 0
		):
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
					if (
						j > i
						and not bool(bacteria[j].dying)
						and not bool(bacteria[j].consumed)
						and int(bacteria[j].engulfed_by_id) < 0
					):
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
		if (
			bool(cell.dying)
			or bool(cell.consumed)
			or int(cell.engulfed_by_id) >= 0
		):
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
		float(a.gene_adhesion) * _plasmid_adhesion_factor(a)
		+ float(b.gene_adhesion) * _plasmid_adhesion_factor(b)
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

	_maybe_start_conjugation(a, b, distance, target_distance)

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


func count_engulfing() -> int:
	var count: int = 0
	for proto in protozoa:
		if int(proto.feeding_target_id) >= 0:
			count += 1
	for ciliate in ciliates:
		if int(ciliate.feeding_target_id) >= 0:
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
	parts.append("p:%d" % protozoa.size())
	parts.append("c:%d" % ciliates.size())

	for cell in bacteria:
		parts.append(
			"%d:%d:%.5f:%.5f:%.5f:%.5f:%.5f:%.4f:%.4f:%.4f:%d:%.3f:%d:%.3f:pm%d:tr%d:tp%.3f:h%d"
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
				int(cell.plasmid_mask),
				int(cell.transfer_role),
				float(cell.transfer_progress),
				int(cell.hgt_events),
			]
		)

	for proto in protozoa:
		parts.append(
			"p%d:g%d:%.5f:%.5f:%.5f:%.5f:%.4f:%.4f:%d:%.3f"
			% [
				int(proto.id),
				int(proto.generation),
				float(proto.position.x),
				float(proto.position.y),
				float(proto.angle),
				float(proto.energy),
				float(proto.gene_speed),
				float(proto.gene_engulf),
				int(proto.feeding_target_id),
				float(proto.feeding_progress),
			]
		)

	for ciliate in ciliates:
		parts.append(
			"c%d:g%d:%.5f:%.5f:%.5f:%.5f:%.4f:%.4f:%d:%.3f"
			% [
				int(ciliate.id),
				int(ciliate.generation),
				float(ciliate.position.x),
				float(ciliate.position.y),
				float(ciliate.angle),
				float(ciliate.energy),
				float(ciliate.gene_speed),
				float(ciliate.gene_capture),
				int(ciliate.feeding_target_id),
				float(ciliate.feeding_progress),
			]
		)

	return "|".join(parts)
