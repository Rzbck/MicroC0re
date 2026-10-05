class_name LivingTerrain
extends RefCounted

const PhysicalCapabilityGenomeScript = preload("res://src/simulation/physical_capability_genome.gd")

const CELL_SIZE := 3.0
const MIN_HEIGHT := -2.5
const MAX_HEIGHT := 9.0
const WATER_LEVEL := 0.42
const TALUS_HEIGHT := 0.72
const TERRAIN_AGENT_DT_SMALL := 1.0 / 15.0
const TERRAIN_AGENT_DT_MEDIUM := 1.0 / 10.0
const TERRAIN_AGENT_DT_MASS := 1.0 / 5.0
const TERRAIN_AGENT_DT_ULTRA := 1.0 / 3.0
const TERRAIN_MEDIUM_THRESHOLD := 350
const TERRAIN_MASS_THRESHOLD := 1600
const TERRAIN_ULTRA_THRESHOLD := 4500
const FRAGMENT_BUCKET_SIZE := 4.0

const BIOME_OPEN := 0
const BIOME_PRODUCER := 1
const BIOME_BIOFILM := 2
const BIOME_DETRITAL := 3
const BIOME_FUNGAL := 4
const BIOME_ANOXIC := 5
const BIOME_DISTURBED := 6
const BIOME_STATE_COUNT := 7
const BIOME_UPDATE_INTERVAL := 1.0
const BIOME_TRANSITION_SECONDS := 9.0
const BIOME_DISTURBANCE_DECAY := 0.018
const BIOME_DISTURBANCE_THRESHOLD := 0.12

# Low-frequency hydrology. This is deliberately terrain-cell based and runs at
# 2 Hz so water can be ecological without becoming a second 60 Hz simulation.
const HYDROLOGY_INTERVAL := 0.50
const SEASON_CYCLE_SECONDS := 240.0
const RAIN_RATE := 0.0032
const EVAPORATION_RATE := 0.0022
const WATER_FLOW_RATE := 0.34
const WATER_FLOW_CELL_FRACTION := 0.18
const WATER_EPSILON := 0.008

var world_size := Vector2.ZERO
var width: int = 0
var height: int = 0
var heights := PackedFloat32Array()
var baseline_heights := PackedFloat32Array()
var fixed_seed: int = 1
var _relax_accumulator: float = 0.0
var _agent_accumulator: float = 0.0
var _terrain_tick: int = 0
var _relax_delta: PackedFloat32Array = PackedFloat32Array()
var _fragment_grid_width: int = 0
var _fragment_grid_height: int = 0
var _fragment_heads: PackedInt32Array = PackedInt32Array()
var _fragment_next: PackedInt32Array = PackedInt32Array()
var _fragment_agents: Array = []
var revision: int = 0
var excavated_total: float = 0.0
var deposited_total: float = 0.0
var biome_states: PackedByteArray = PackedByteArray()
var biome_transition_pressure: PackedFloat32Array = PackedFloat32Array()
var biome_ages: PackedFloat32Array = PackedFloat32Array()
var biome_disturbance: PackedFloat32Array = PackedFloat32Array()
var biome_transitions_total: int = 0
var _biome_accumulator: float = 0.0
var _biome_field_indices: PackedInt32Array = PackedInt32Array()
var _biome_field_signature: Vector3i = Vector3i.ZERO

var water_depths: PackedFloat32Array = PackedFloat32Array()
var soil_moisture: PackedFloat32Array = PackedFloat32Array()
var water_flux: PackedFloat32Array = PackedFloat32Array()
var _water_delta: PackedFloat32Array = PackedFloat32Array()
var _hydrology_accumulator: float = 0.0
var climate_time: float = 0.0
var season_phase: float = 0.0
var season_index: int = 0
var season_rain: float = 1.0
var season_warmth: float = 0.5
var water_moved_total: float = 0.0

# Bounded mobile physical cassettes. When an organism disappears, one sampled
# capability module can remain in the environment for a short time. Any current
# family with enough evolved assimilation expression can acquire it.
const CAPABILITY_FRAGMENT_LIMIT := 64
const CAPABILITY_FRAGMENT_LIFETIME := 22.0
var capability_fragments: Array = []
var _known_agents: Dictionary = {}
var _fragment_scan_accumulator: float = 0.0
var _next_fragment_id: int = 1


func _init(seed_value: int = 1, p_world_size: Vector2 = Vector2(192.0, 128.0)) -> void:
	fixed_seed = seed_value
	world_size = p_world_size
	width = maxi(3, ceili(world_size.x / CELL_SIZE) + 1)
	height = maxi(3, ceili(world_size.y / CELL_SIZE) + 1)
	heights.resize(width * height)
	_relax_delta.resize(width * height)
	_relax_delta.fill(0.0)
	biome_states.resize(width * height)
	biome_states.fill(BIOME_OPEN)
	biome_transition_pressure.resize(width * height)
	biome_transition_pressure.fill(0.0)
	biome_ages.resize(width * height)
	biome_ages.fill(0.0)
	biome_disturbance.resize(width * height)
	biome_disturbance.fill(0.0)
	water_depths.resize(width * height)
	water_depths.fill(0.0)
	soil_moisture.resize(width * height)
	soil_moisture.fill(0.0)
	water_flux.resize(width * height)
	water_flux.fill(0.0)
	_water_delta.resize(width * height)
	_water_delta.fill(0.0)
	_fragment_grid_width = maxi(
		1,
		ceili(world_size.x / FRAGMENT_BUCKET_SIZE)
	)
	_fragment_grid_height = maxi(
		1,
		ceili(world_size.y / FRAGMENT_BUCKET_SIZE)
	)
	_fragment_heads.resize(_fragment_grid_width * _fragment_grid_height)
	_fragment_heads.fill(-1)
	_generate_seeded_relief()
	baseline_heights = heights.duplicate()
	_initialize_hydrology()


func sample_height(position: Vector2) -> float:
	var gx: float = clampf(position.x / CELL_SIZE, 0.0, float(width - 1))
	var gy: float = clampf(position.y / CELL_SIZE, 0.0, float(height - 1))
	var x0: int = floori(gx)
	var y0: int = floori(gy)
	var x1: int = mini(x0 + 1, width - 1)
	var y1: int = mini(y0 + 1, height - 1)
	var tx: float = gx - float(x0)
	var ty: float = gy - float(y0)
	var a: float = lerpf(_height_value(x0, y0), _height_value(x1, y0), tx)
	var b: float = lerpf(_height_value(x0, y1), _height_value(x1, y1), tx)
	return lerpf(a, b, ty)


func sample_height_nearest(position: Vector2) -> float:
	var gx: int = clampi(
		roundi(position.x / CELL_SIZE),
		0,
		width - 1
	)
	var gy: int = clampi(
		roundi(position.y / CELL_SIZE),
		0,
		height - 1
	)
	return float(heights[gy * width + gx])


func height_at_grid(x: int, y: int) -> float:
	return _height_value(clampi(x, 0, width - 1), clampi(y, 0, height - 1))


func height_delta_at_grid(x: int, y: int) -> float:
	var sx: int = clampi(x, 0, width - 1)
	var sy: int = clampi(y, 0, height - 1)
	var index: int = _index(sx, sy)
	return float(heights[index]) - float(baseline_heights[index])


func water_depth_at_grid(x: int, y: int) -> float:
	var sx: int = clampi(x, 0, width - 1)
	var sy: int = clampi(y, 0, height - 1)
	return float(water_depths[_index(sx, sy)])


func moisture_at_grid(x: int, y: int) -> float:
	var sx: int = clampi(x, 0, width - 1)
	var sy: int = clampi(y, 0, height - 1)
	return float(soil_moisture[_index(sx, sy)])


func sample_water_depth(position: Vector2) -> float:
	var gx: int = clampi(roundi(position.x / CELL_SIZE), 0, width - 1)
	var gy: int = clampi(roundi(position.y / CELL_SIZE), 0, height - 1)
	return float(water_depths[_index(gx, gy)])


func sample_moisture(position: Vector2) -> float:
	var gx: int = clampi(roundi(position.x / CELL_SIZE), 0, width - 1)
	var gy: int = clampi(roundi(position.y / CELL_SIZE), 0, height - 1)
	return float(soil_moisture[_index(gx, gy)])


func season_name() -> String:
	match season_index:
		0:
			return "spring"
		1:
			return "summer"
		2:
			return "autumn"
		_:
			return "winter"


func hydrology_metrics() -> Dictionary:
	var water_cells: int = 0
	var wet_cells: int = 0
	var water_total: float = 0.0
	var moisture_total: float = 0.0
	for i in range(water_depths.size()):
		var depth: float = float(water_depths[i])
		var moisture: float = float(soil_moisture[i])
		water_total += depth
		moisture_total += moisture
		if depth > 0.025:
			water_cells += 1
		if moisture > 0.35:
			wet_cells += 1
	var count: float = float(maxi(1, water_depths.size()))
	return {
		"water_cells": water_cells,
		"wet_cells": wet_cells,
		"water_total": water_total,
		"mean_moisture": moisture_total / count,
		"season": season_index,
		"rain": season_rain,
		"warmth": season_warmth,
		"moved": water_moved_total,
	}


func biome_state_at_grid(x: int, y: int) -> int:
	var sx: int = clampi(x, 0, width - 1)
	var sy: int = clampi(y, 0, height - 1)
	return int(biome_states[_index(sx, sy)])


func sample_biome_state(position: Vector2) -> int:
	var gx: int = clampi(roundi(position.x / CELL_SIZE), 0, width - 1)
	var gy: int = clampi(roundi(position.y / CELL_SIZE), 0, height - 1)
	return int(biome_states[_index(gx, gy)])


func biome_metrics() -> Dictionary:
	var counts := PackedInt32Array()
	counts.resize(BIOME_STATE_COUNT)
	counts.fill(0)
	for state in biome_states:
		counts[int(state)] += 1
	var disturbed_signal_cells: int = 0
	for pressure in biome_disturbance:
		if float(pressure) > BIOME_DISTURBANCE_THRESHOLD:
			disturbed_signal_cells += 1
	return {
		"open": counts[BIOME_OPEN],
		"producer": counts[BIOME_PRODUCER],
		"biofilm": counts[BIOME_BIOFILM],
		"detrital": counts[BIOME_DETRITAL],
		"fungal": counts[BIOME_FUNGAL],
		"anoxic": counts[BIOME_ANOXIC],
		"disturbed": counts[BIOME_DISTURBED],
		"recently_modified": disturbed_signal_cells,
		"transitions": biome_transitions_total,
	}


func world_position_for_grid(x: int, y: int) -> Vector2:
	return Vector2(
		clampf(float(x) * CELL_SIZE, 0.0, world_size.x),
		clampf(float(y) * CELL_SIZE, 0.0, world_size.y)
	)


func total_mass() -> float:
	var total: float = 0.0
	for value in heights:
		total += float(value)
	return total


func excavate(position: Vector2, amount: float, radius_world: float = 1.8) -> float:
	return _apply_radial_mass(position, amount, radius_world, false)


func deposit(position: Vector2, amount: float, radius_world: float = 2.0) -> float:
	return _apply_radial_mass(position, amount, radius_world, true)


func _apply_radial_mass(
	position: Vector2,
	amount: float,
	radius_world: float,
	is_deposit: bool
) -> float:
	var safe_amount: float = maxf(0.0, amount)
	if safe_amount <= 0.0 or radius_world <= 0.0:
		return 0.0

	var gx: int = clampi(roundi(position.x / CELL_SIZE), 0, width - 1)
	var gy: int = clampi(roundi(position.y / CELL_SIZE), 0, height - 1)
	var radius_cells: int = maxi(1, ceili(radius_world / CELL_SIZE) + 1)
	var min_x: int = maxi(0, gx - radius_cells)
	var max_x: int = mini(width - 1, gx + radius_cells)
	var min_y: int = maxi(0, gy - radius_cells)
	var max_y: int = mini(height - 1, gy + radius_cells)
	var reach: float = radius_world + CELL_SIZE * 0.75
	var weight_sum: float = 0.0

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var wp := Vector2(float(x) * CELL_SIZE, float(y) * CELL_SIZE)
			var distance: float = wp.distance_to(position)
			if distance > reach:
				continue
			weight_sum += maxf(
				0.08,
				1.0 - distance / maxf(CELL_SIZE, reach)
			)

	if weight_sum <= 0.0:
		return 0.0

	var changed: float = 0.0
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var wp := Vector2(float(x) * CELL_SIZE, float(y) * CELL_SIZE)
			var distance: float = wp.distance_to(position)
			if distance > reach:
				continue
			var weight: float = maxf(
				0.08,
				1.0 - distance / maxf(CELL_SIZE, reach)
			) / weight_sum
			var index: int = y * width + x
			var share: float = safe_amount * weight
			var local_change: float = 0.0
			if is_deposit:
				var room: float = maxf(
					0.0,
					MAX_HEIGHT - float(heights[index])
				)
				var add: float = minf(room, share)
				heights[index] = float(heights[index]) + add
				local_change = add
				changed += add
			else:
				var available: float = maxf(
					0.0,
					float(heights[index]) - MIN_HEIGHT
				)
				var take: float = minf(available, share)
				heights[index] = float(heights[index]) - take
				local_change = take
				changed += take
			if local_change > 0.0:
				biome_disturbance[index] = maxf(
					float(biome_disturbance[index]),
					clampf(0.35 + local_change * 4.0, 0.35, 1.0)
				)

	if changed > 0.0:
		if is_deposit:
			deposited_total += changed
		else:
			excavated_total += changed
		revision += 1
	return changed


func _initialize_hydrology() -> void:
	for i in range(heights.size()):
		var lowland_water: float = maxf(
			0.0,
			WATER_LEVEL - float(heights[i])
		)
		water_depths[i] = minf(1.5, lowland_water)
		soil_moisture[i] = clampf(
			0.08 + lowland_water * 1.25,
			0.0,
			1.0
		)


func _update_season() -> void:
	season_phase = fposmod(
		climate_time / SEASON_CYCLE_SECONDS,
		1.0
	)
	season_index = clampi(floori(season_phase * 4.0), 0, 3)
	# Wet spring/autumn, hot/dry summer, cool winter.
	var rain_wave: float = sin(TAU * season_phase + 0.55)
	var warm_wave: float = sin(TAU * season_phase - 0.65)
	season_rain = clampf(1.0 + 0.52 * rain_wave, 0.45, 1.55)
	season_warmth = clampf(0.55 + 0.45 * warm_wave, 0.10, 1.0)


func _queue_water_pair(a: int, b: int, dt: float) -> void:
	var surface_a: float = float(heights[a]) + float(water_depths[a])
	var surface_b: float = float(heights[b]) + float(water_depths[b])
	var difference: float = surface_a - surface_b
	if absf(difference) <= WATER_EPSILON:
		return

	var source: int = a if difference > 0.0 else b
	var target: int = b if difference > 0.0 else a
	var source_water: float = float(water_depths[source])
	if source_water <= 0.00001:
		return

	var moved: float = minf(
		source_water * WATER_FLOW_CELL_FRACTION,
		(absf(difference) - WATER_EPSILON)
			* WATER_FLOW_RATE
			* minf(dt, 1.0)
	)
	if moved <= 0.0:
		return
	_water_delta[source] = float(_water_delta[source]) - moved
	_water_delta[target] = float(_water_delta[target]) + moved
	water_flux[source] = float(water_flux[source]) + moved
	water_flux[target] = float(water_flux[target]) + moved
	water_moved_total += moved


func _advance_hydrology(dt: float) -> void:
	_update_season()
	_water_delta.fill(0.0)
	water_flux.fill(0.0)

	var rain_add: float = RAIN_RATE * season_rain * dt
	var evaporation: float = (
		EVAPORATION_RATE
		* lerpf(0.45, 1.70, season_warmth)
		* dt
	)

	# Climate first. Low basins remain connected to the standing groundwater
	# level while higher cells depend on rain/runoff.
	for i in range(water_depths.size()):
		var depth: float = maxf(
			0.0,
			float(water_depths[i]) + rain_add - evaporation
		)
		var lowland_floor: float = maxf(
			0.0,
			WATER_LEVEL - float(heights[i])
		)
		if lowland_floor > 0.0:
			depth = maxf(depth, minf(1.5, lowland_floor))
		water_depths[i] = depth

	# One right/down pair per edge; direction is chosen from the current water
	# surface, so flow can still move left/up when those neighbours are lower.
	for y in range(height):
		var row: int = y * width
		for x in range(width):
			var index: int = row + x
			if x + 1 < width:
				_queue_water_pair(index, index + 1, dt)
			if y + 1 < height:
				_queue_water_pair(index, index + width, dt)

	var moisture_blend: float = clampf(dt * 0.22, 0.0, 1.0)
	for i in range(water_depths.size()):
		var depth: float = maxf(
			0.0,
			float(water_depths[i]) + float(_water_delta[i])
		)
		water_depths[i] = depth
		var lowland: float = maxf(
			0.0,
			WATER_LEVEL - float(heights[i])
		)
		var moisture_target: float = clampf(
			depth * 1.65
			+ lowland * 0.55
			+ rain_add * 22.0,
			0.0,
			1.0
		)
		soil_moisture[i] = lerpf(
			float(soil_moisture[i]),
			moisture_target,
			moisture_blend
		)
	revision += 1


func advance_from_sim(sim: Variant, dt: float) -> void:
	climate_time += dt
	_hydrology_accumulator += dt
	if _hydrology_accumulator >= HYDROLOGY_INTERVAL:
		var hydro_dt: float = _hydrology_accumulator
		_hydrology_accumulator = 0.0
		_advance_hydrology(hydro_dt)

	_agent_accumulator += dt
	var terrain_dt: float = _terrain_agent_dt(sim)
	while _agent_accumulator >= terrain_dt:
		_terrain_tick += 1
		var bacteria_stride: int = _terrain_bacteria_stride(sim)
		_advance_group(
			sim,
			sim.bacteria,
			terrain_dt,
			true,
			bacteria_stride
		)
		_advance_group(sim, sim.protozoa, terrain_dt, true)
		_advance_group(sim, sim.ciliates, terrain_dt, true)
		_advance_group(sim, sim.flagellates, terrain_dt, true)
		_advance_group(sim, sim.microalgae, terrain_dt, true)
		_advance_group(sim, sim.decomposers, terrain_dt, true)
		_advance_group(sim, sim.hyphae, terrain_dt, false)
		_advance_capability_fragments(sim, terrain_dt)
		_agent_accumulator -= terrain_dt

	_relax_accumulator += dt
	if _relax_accumulator >= 0.10:
		var relax_dt: float = _relax_accumulator
		_relax_accumulator = 0.0
		_relax_slopes(relax_dt)

	_biome_accumulator += dt
	if _biome_accumulator >= BIOME_UPDATE_INTERVAL:
		var biome_dt: float = _biome_accumulator
		_biome_accumulator = 0.0
		_advance_biome_succession(sim, biome_dt)



func _ensure_biome_field_indices(sim: Variant) -> void:
	var field_width: int = int(sim.nutrient.width)
	var field_height: int = int(sim.nutrient.height)
	var field_cell_milli: int = roundi(float(sim.nutrient.cell_size) * 1000.0)
	var signature := Vector3i(field_width, field_height, field_cell_milli)
	if (
		_biome_field_indices.size() == width * height
		and _biome_field_signature == signature
	):
		return

	_biome_field_signature = signature
	_biome_field_indices.resize(width * height)
	var inverse_cell: float = 1.0 / maxf(0.0001, float(sim.nutrient.cell_size))
	for y in range(height):
		var fy: int = clampi(
			floori(float(y) * CELL_SIZE * inverse_cell),
			0,
			field_height - 1
		)
		for x in range(width):
			var fx: int = clampi(
				floori(float(x) * CELL_SIZE * inverse_cell),
				0,
				field_width - 1
			)
			_biome_field_indices[_index(x, y)] = fy * field_width + fx


func _candidate_biome_state(sim: Variant, terrain_index: int) -> int:
	var field_index: int = int(_biome_field_indices[terrain_index])
	var producer: float = float(sim.producer_biomass.values[field_index])
	var eps_value: float = float(sim.eps.values[field_index])
	var detritus_value: float = float(sim.detritus.values[field_index])
	var fungal_value: float = float(sim.fungal_enzyme.values[field_index])
	var oxygen_value: float = float(sim.oxygen.values[field_index])
	var waste_value: float = float(sim.waste.values[field_index])
	var quorum_value: float = float(sim.quorum_signal.values[field_index])
	var disturbed: float = float(biome_disturbance[terrain_index])
	var local_water: float = float(water_depths[terrain_index])
	var local_moisture: float = float(soil_moisture[terrain_index])

	# These are regime thresholds, not visual-only labels. Hysteresis below
	# still requires a signal to persist before the substrate changes state.
	if (
		(local_water > 0.20 and oxygen_value < 0.24)
		or (
			oxygen_value < 0.16
			and (waste_value > 0.035 or detritus_value > 0.045)
		)
	):
		return BIOME_ANOXIC
	if (
		local_moisture > 0.20
		and (
			fungal_value > 0.012
			or (fungal_value > 0.0045 and detritus_value > 0.055)
		)
	):
		return BIOME_FUNGAL
	if eps_value > 0.025 or (eps_value > 0.012 and quorum_value > 0.025):
		return BIOME_BIOFILM
	if (
		producer > 0.060
		and oxygen_value > 0.12
		and local_moisture > 0.12
	):
		return BIOME_PRODUCER
	if detritus_value > 0.040:
		return BIOME_DETRITAL
	if disturbed > BIOME_DISTURBANCE_THRESHOLD:
		return BIOME_DISTURBED
	return BIOME_OPEN


func _advance_biome_succession(sim: Variant, dt: float) -> void:
	_ensure_biome_field_indices(sim)
	for y in range(height):
		for x in range(width):
			var index: int = _index(x, y)
			biome_disturbance[index] = maxf(
				0.0,
				float(biome_disturbance[index]) - BIOME_DISTURBANCE_DECAY * dt
			)
			var current: int = int(biome_states[index])
			var candidate: int = _candidate_biome_state(sim, index)
			biome_ages[index] = float(biome_ages[index]) + dt

			if candidate == current:
				biome_transition_pressure[index] = maxf(
					0.0,
					float(biome_transition_pressure[index]) - dt * 0.65
				)
				continue

			biome_transition_pressure[index] = (
				float(biome_transition_pressure[index]) + dt
			)
			if float(biome_transition_pressure[index]) < BIOME_TRANSITION_SECONDS:
				continue

			biome_states[index] = candidate
			biome_transition_pressure[index] = 0.0
			biome_ages[index] = 0.0
			biome_transitions_total += 1


func _biome_stability(index: int) -> float:
	match int(biome_states[index]):
		BIOME_PRODUCER:
			return 0.16
		BIOME_BIOFILM:
			return 0.22
		BIOME_FUNGAL:
			return 0.10
		BIOME_DETRITAL:
			return -0.04
		BIOME_DISTURBED:
			return -0.12
	return 0.0


func _terrain_population(sim: Variant) -> int:
	return (
		sim.bacteria.size()
		+ sim.protozoa.size()
		+ sim.ciliates.size()
		+ sim.flagellates.size()
		+ sim.microalgae.size()
		+ sim.decomposers.size()
		+ sim.hyphae.size()
	)


func _terrain_agent_dt(sim: Variant) -> float:
	var count: int = _terrain_population(sim)
	if count >= TERRAIN_ULTRA_THRESHOLD:
		return TERRAIN_AGENT_DT_ULTRA
	if count >= TERRAIN_MASS_THRESHOLD:
		return TERRAIN_AGENT_DT_MASS
	if count >= TERRAIN_MEDIUM_THRESHOLD:
		return TERRAIN_AGENT_DT_MEDIUM
	return TERRAIN_AGENT_DT_SMALL


func _terrain_bacteria_stride(sim: Variant) -> int:
	var count: int = sim.bacteria.size()
	if count >= TERRAIN_ULTRA_THRESHOLD:
		return 4
	if count >= TERRAIN_MASS_THRESHOLD:
		return 2
	return 1


func _fragment_scan_interval(sim: Variant) -> float:
	var count: int = _terrain_population(sim)
	if count >= TERRAIN_ULTRA_THRESHOLD:
		return 1.5
	if count >= TERRAIN_MASS_THRESHOLD:
		return 1.0
	if count >= TERRAIN_MEDIUM_THRESHOLD:
		return 0.50
	return 0.20


func _advance_capability_fragments(sim: Variant, dt: float) -> void:
	_fragment_scan_accumulator += dt
	for fragment in capability_fragments:
		fragment["age"] = float(fragment["age"]) + dt

	var survivors: Array = []
	for fragment in capability_fragments:
		if float(fragment["age"]) < CAPABILITY_FRAGMENT_LIFETIME:
			survivors.append(fragment)
	capability_fragments = survivors

	if _fragment_scan_accumulator < _fragment_scan_interval(sim):
		return
	var scan_dt: float = _fragment_scan_accumulator
	_fragment_scan_accumulator = 0.0

	_rebuild_fragment_agent_grid(sim)
	var current: Dictionary = {}
	for agent in _fragment_agents:
		if agent == null or bool(agent.dying) or agent.physical_genome == null:
			continue
		current[int(agent.id)] = agent

	for old_id in _known_agents.keys():
		if current.has(old_id):
			continue
		var old_agent: Variant = _known_agents[old_id]
		if old_agent == null or old_agent.physical_genome == null:
			continue
		var module_data: Dictionary = old_agent.physical_genome.module_for_transfer(
			int(old_id) + _terrain_tick
		)
		if module_data.is_empty():
			continue
		if capability_fragments.size() >= CAPABILITY_FRAGMENT_LIMIT:
			capability_fragments.pop_front()
		capability_fragments.append({
			"id": _next_fragment_id,
			"source_id": int(old_id),
			"position": Vector2(old_agent.position),
			"module": module_data,
			"age": 0.0,
		})
		_next_fragment_id += 1

	_known_agents = current
	if capability_fragments.is_empty():
		return

	var remaining: Array = []
	for fragment in capability_fragments:
		var recipient: Variant = _nearest_capability_recipient(
			Vector2(fragment["position"]),
			int(fragment["source_id"])
		)
		if recipient == null:
			remaining.append(fragment)
			continue

		var values: Array = recipient.physical_genome.evaluate_context(
			0.15,
			0.0,
			clampf(float(recipient.energy) / 4.0, 0.0, 1.0),
			clampf(
				float(sim.detritus.sample_nearest_world(
					Vector2(recipient.position)
				)) * 4.0,
				0.0,
				1.0
			),
			clampf(
				float(sim.sample_light(Vector2(recipient.position))),
				0.0,
				1.0
			),
			0.30
		)
		var assimilation: float = float(
			values[PhysicalCapabilityGenomeScript.CAP_ASSIMILATE]
		)
		if assimilation <= 0.05:
			remaining.append(fragment)
			continue

		var probability: float = 1.0 - exp(
			-(0.06 + assimilation * 0.24) * scan_dt
		)
		var roll: float = _stable_roll(
			int(fragment["id"]),
			int(recipient.id),
			_terrain_tick
		)
		if roll >= probability:
			remaining.append(fragment)
			continue

		if recipient.physical_genome.integrate_module(
			fragment["module"],
			_seeded_event_rng(
				int(fragment["id"]),
				int(recipient.id)
			)
		):
			recipient.capability_mix_events = (
				int(recipient.capability_mix_events) + 1
			)
			recipient.energy = maxf(
				0.0,
				float(recipient.energy) - 0.045
			)
		else:
			remaining.append(fragment)

	capability_fragments = remaining


func _rebuild_fragment_agent_grid(sim: Variant) -> void:
	_fragment_agents.clear()
	_fragment_agents.append_array(sim.bacteria)
	_fragment_agents.append_array(sim.protozoa)
	_fragment_agents.append_array(sim.ciliates)
	_fragment_agents.append_array(sim.flagellates)
	_fragment_agents.append_array(sim.microalgae)
	_fragment_agents.append_array(sim.decomposers)
	_fragment_agents.append_array(sim.hyphae)

	_fragment_heads.fill(-1)
	_fragment_next.resize(_fragment_agents.size())
	_fragment_next.fill(-1)
	for i in range(_fragment_agents.size()):
		var agent: Variant = _fragment_agents[i]
		if agent == null or bool(agent.dying) or agent.physical_genome == null:
			continue
		var position: Vector2 = Vector2(agent.position)
		var bx: int = clampi(
			floori(position.x / FRAGMENT_BUCKET_SIZE),
			0,
			_fragment_grid_width - 1
		)
		var by: int = clampi(
			floori(position.y / FRAGMENT_BUCKET_SIZE),
			0,
			_fragment_grid_height - 1
		)
		var bucket: int = by * _fragment_grid_width + bx
		_fragment_next[i] = _fragment_heads[bucket]
		_fragment_heads[bucket] = i


func _nearest_capability_recipient(
	position: Vector2,
	source_id: int
) -> Variant:
	var best: Variant = null
	var best_distance_sq: float = 2.8 * 2.8
	var bx: int = clampi(
		floori(position.x / FRAGMENT_BUCKET_SIZE),
		0,
		_fragment_grid_width - 1
	)
	var by: int = clampi(
		floori(position.y / FRAGMENT_BUCKET_SIZE),
		0,
		_fragment_grid_height - 1
	)
	for y in range(
		maxi(0, by - 1),
		mini(_fragment_grid_height - 1, by + 1) + 1
	):
		var row: int = y * _fragment_grid_width
		for x in range(
			maxi(0, bx - 1),
			mini(_fragment_grid_width - 1, bx + 1) + 1
		):
			var i: int = _fragment_heads[row + x]
			while i >= 0:
				var agent: Variant = _fragment_agents[i]
				if (
					agent != null
					and not bool(agent.dying)
					and int(agent.id) != source_id
					and agent.physical_genome != null
				):
					var distance_sq: float = position.distance_squared_to(
						Vector2(agent.position)
					)
					if distance_sq < best_distance_sq:
						best_distance_sq = distance_sq
						best = agent
				i = _fragment_next[i]
	return best


func _stable_roll(a: int, b: int, tick: int) -> float:
	var value: int = a * 73856093
	value ^= b * 19349663
	value ^= tick * 83492791
	value &= 0x7fffffff
	return float(value % 1000003) / 1000003.0


func _seeded_event_rng(a: int, b: int) -> RandomNumberGenerator:
	var event_rng := RandomNumberGenerator.new()
	event_rng.seed = (
		int(fixed_seed) * 92821
		+ a * 68917
		+ b * 31337
		+ _terrain_tick * 17
	)
	return event_rng




func _advance_group(
	sim: Variant,
	group: Array,
	dt: float,
	can_move: bool,
	stride: int = 1
) -> void:
	var effective_stride: int = maxi(1, stride)
	for agent in group:
		if agent == null or bool(agent.dying):
			continue
		if agent.physical_genome == null:
			continue
		if (
			effective_stride > 1
			and posmod(int(agent.id) + _terrain_tick, effective_stride) != 0
		):
			continue
		_advance_agent(
			sim,
			agent,
			dt * float(effective_stride),
			can_move
		)


func _biome_affinity(agent: Variant, state: int) -> float:
	# Trait-driven habitat choice. Values are relative preferences used only for
	# steering; they do not force an organism to remain inside one biome.
	match state:
		BIOME_PRODUCER:
			if "gene_light_use" in agent:
				return 0.62 + 0.24 * clampf(float(agent.gene_light_use), 0.5, 1.8)
			if "gene_uptake" in agent:
				return 0.55 + 0.10 * clampf(float(agent.gene_uptake), 0.5, 1.8)
			if "gene_capture" in agent or "gene_engulf" in agent:
				return 0.56
			return 0.52
		BIOME_BIOFILM:
			if "gene_adhesion" in agent:
				return 0.58 + 0.26 * clampf(float(agent.gene_adhesion), 0.4, 2.0)
			if "gene_capture" in agent:
				return 0.42
			return 0.48
		BIOME_DETRITAL:
			if "gene_detritus" in agent:
				return 0.62 + 0.24 * clampf(float(agent.gene_detritus), 0.4, 1.9)
			if "gene_uptake" in agent:
				return 0.56 + 0.08 * clampf(float(agent.gene_uptake), 0.5, 1.8)
			return 0.48
		BIOME_FUNGAL:
			if "gene_branch" in agent:
				return 0.82
			if "gene_detritus" in agent:
				return 0.64 + 0.18 * clampf(float(agent.gene_detritus), 0.4, 1.9)
			return 0.44
		BIOME_ANOXIC:
			if "gene_light_use" in agent:
				return 0.12
			if "gene_dormancy" in agent:
				return 0.30 + 0.24 * clampf(float(agent.gene_dormancy), 0.4, 2.0)
			if "gene_detritus" in agent:
				return 0.50
			return 0.22
		BIOME_DISTURBED:
			if "gene_speed" in agent:
				return 0.44 + 0.08 * clampf(float(agent.gene_speed), 0.5, 1.8)
			return 0.42
	return 0.50


func _advance_agent(
	sim: Variant,
	agent: Variant,
	dt: float,
	can_move: bool
) -> void:
	var position: Vector2 = Vector2(agent.position)
	var forward := Vector2.RIGHT.rotated(float(agent.angle))
	var local_height: float = sample_height(position)
	var ahead_height: float = sample_height(position + forward * CELL_SIZE)
	var uphill: float = maxf(0.0, ahead_height - local_height)
	var carrying_signal: float = clampf(float(agent.carried_soil) / 0.42, 0.0, 1.0)
	var energy_signal: float = clampf(float(agent.energy) / 4.0, 0.0, 1.0)
	var detritus_signal: float = clampf(
		float(sim.detritus.sample_nearest_world(position)) * 4.0,
		0.0,
		1.0
	)
	var light_signal: float = clampf(float(sim.sample_light(position)), 0.0, 1.0)
	var water_signal: float = clampf(
		(WATER_LEVEL + 0.8 - local_height) / 1.6,
		0.0,
		1.0
	)
	var biome_state: int = sample_biome_state(position)
	var habitat_tolerance: float = (
		float(agent.gene_dormancy)
		if "gene_dormancy" in agent
		else 0.82
	)
	match biome_state:
		BIOME_ANOXIC:
			var anoxic_cost: float = 0.010 / maxf(0.45, habitat_tolerance)
			if "gene_light_use" in agent:
				anoxic_cost *= 1.35
			agent.energy = maxf(0.0, float(agent.energy) - anoxic_cost * dt)
		BIOME_BIOFILM:
			if "gene_adhesion" in agent:
				agent.energy = float(agent.energy) + 0.0025 * float(agent.gene_adhesion) * dt
		BIOME_PRODUCER:
			if "gene_light_use" in agent:
				agent.energy = float(agent.energy) + 0.0018 * float(agent.gene_light_use) * dt
		BIOME_DETRITAL, BIOME_FUNGAL:
			if "gene_detritus" in agent:
				agent.energy = float(agent.energy) + 0.0018 * float(agent.gene_detritus) * dt

	var values: Array = agent.physical_genome.evaluate_context(
		clampf(uphill / 1.25, 0.0, 1.0),
		carrying_signal,
		energy_signal,
		detritus_signal,
		light_signal,
		water_signal
	)
	var dig: float = float(values[PhysicalCapabilityGenomeScript.CAP_DIG])
	var carry: float = float(values[PhysicalCapabilityGenomeScript.CAP_CARRY])
	var deposit_strength: float = float(
		values[PhysicalCapabilityGenomeScript.CAP_DEPOSIT]
	)
	var burrow: float = float(values[PhysicalCapabilityGenomeScript.CAP_BURROW])
	var climb: float = float(values[PhysicalCapabilityGenomeScript.CAP_CLIMB])
	var oviposit: float = float(
		values[PhysicalCapabilityGenomeScript.CAP_OVIPOSIT]
	)
	var armor: float = float(values[PhysicalCapabilityGenomeScript.CAP_ARMOR])

	agent.physical_dig = dig
	agent.physical_deposit = deposit_strength
	agent.physical_burrow = burrow
	agent.physical_climb = climb
	agent.physical_oviposit = oviposit
	agent.physical_armor = armor

	if can_move:
		# Terrain and habitat are sensed to either side of the current heading.
		# This produces niche-oriented migration without a global pathfinder.
		var left_position: Vector2 = (
			position + forward.rotated(-0.72) * CELL_SIZE
		)
		var right_position: Vector2 = (
			position + forward.rotated(0.72) * CELL_SIZE
		)
		var left_height: float = sample_height_nearest(left_position)
		var right_height: float = sample_height_nearest(right_position)
		var terrain_turn: float = clampf(
			(left_height - right_height) * 0.34,
			-0.22,
			0.22
		)
		var left_affinity: float = _biome_affinity(
			agent,
			sample_biome_state(left_position)
		)
		var right_affinity: float = _biome_affinity(
			agent,
			sample_biome_state(right_position)
		)
		var habitat_turn: float = clampf(
			(right_affinity - left_affinity) * 0.55,
			-0.18,
			0.18
		) * clampf(dt * 4.0, 0.0, 1.0)
		agent.angle = wrapf(
			float(agent.angle)
			+ terrain_turn * (1.0 - clampf(climb * 0.22, 0.0, 0.52))
			+ habitat_turn,
			-PI,
			PI
		)
		forward = Vector2.RIGHT.rotated(float(agent.angle))
		var terrain_resistance: float = maxf(0.0, uphill - climb * 0.26 - burrow * 0.14)
		if terrain_resistance > 0.0:
			agent.energy = maxf(
				0.0,
				float(agent.energy)
				- terrain_resistance * (0.018 + 0.010 / maxf(0.25, climb + burrow)) * dt
			)

	if can_move and uphill > 0.34 + climb * 0.30 + burrow * 0.12:
		agent.position = Vector2(agent.position) - forward * minf(0.10, uphill * 0.05)
		var turn: float = sin(
			float(int(agent.id) * 37 + _terrain_tick * 11) * 0.017
		)
		agent.angle = wrapf(float(agent.angle) + turn * 0.075, -PI, PI)

	var substrate_factor: float = 1.0
	match biome_state:
		BIOME_PRODUCER:
			substrate_factor = 0.84
		BIOME_BIOFILM:
			substrate_factor = 0.76
		BIOME_FUNGAL:
			substrate_factor = 0.92
		BIOME_DETRITAL:
			substrate_factor = 1.10
		BIOME_DISTURBED:
			substrate_factor = 1.24

	var capacity: float = 0.26 + carry * 0.34
	agent.terrain_action_clock = float(agent.terrain_action_clock) + dt * (
		0.50 + dig * 0.56 + deposit_strength * 0.25
	)

	if float(agent.terrain_action_clock) < 1.0:
		agent.burrow_depth = maxf(
			0.0,
			float(agent.burrow_depth)
			- dt * (0.015 + (1.0 - minf(burrow, 1.0)) * 0.04)
		)
		return

	agent.terrain_action_clock = fmod(float(agent.terrain_action_clock), 1.0)

	var should_deposit: bool = (
		float(agent.carried_soil) > 0.015
		and deposit_strength > 0.22
		and (
			float(agent.carried_soil) >= capacity * 0.52
			or dig < 0.28
		)
	)
	if should_deposit:
		var side: float = (
			-1.0
			if posmod(int(agent.id) + _terrain_tick, 2) == 0
			else 1.0
		)
		var target: Vector2 = (
			position
			- forward * (1.1 + deposit_strength * 0.35)
			+ forward.orthogonal() * side * 0.75
		)
		var requested: float = minf(
			float(agent.carried_soil),
			0.15 + deposit_strength * 0.20
		)
		var placed: float = deposit(
			target,
			requested,
			1.45 + minf(1.0, deposit_strength) * 0.65
		)
		agent.carried_soil = maxf(
			0.0,
			float(agent.carried_soil) - placed
		)
		agent.terrain_action = "deposit"
		return

	if dig > 0.24 and float(agent.carried_soil) < capacity:
		var dig_target: Vector2 = (
			position + forward * (0.9 + burrow * 0.85)
		)
		var requested: float = minf(
			capacity - float(agent.carried_soil),
			(0.13 + dig * 0.18) * substrate_factor
		)
		var removed: float = excavate(
			dig_target,
			requested,
			1.20 + minf(1.2, dig) * 0.55
		)
		if removed > 0.0:
			agent.carried_soil = minf(
				capacity,
				float(agent.carried_soil) + removed
			)
			agent.energy = maxf(
				0.0,
				float(agent.energy)
				- removed * (0.11 + 0.08 / maxf(0.25, dig))
			)
			agent.burrow_depth = clampf(
				float(agent.burrow_depth) + removed * burrow * 1.8,
				0.0,
				3.2
			)
			agent.terrain_action = "dig"
			return

	agent.terrain_action = "none"


func _generate_seeded_relief() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = fixed_seed
	for y in range(height):
		for x in range(width):
			var nx: float = float(x) / float(maxi(1, width - 1))
			var ny: float = float(y) / float(maxi(1, height - 1))
			var ridge: float = (
				sin(nx * TAU * 1.7 + float(fixed_seed % 17) * 0.11)
				* cos(ny * TAU * 1.25 - float(fixed_seed % 23) * 0.07)
			)
			var basin: float = (
				cos((nx - 0.52) * PI) * cos((ny - 0.48) * PI)
			)
			var jitter: float = rng.randf_range(-0.10, 0.10)
			heights[_index(x, y)] = clampf(
				0.68 + ridge * 0.26 + basin * 0.18 + jitter,
				0.12,
				1.45
			)

	for _pass in range(3):
		var copy := heights.duplicate()
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var average: float = (
					float(copy[_index(x, y)])
					+ float(copy[_index(x - 1, y)])
					+ float(copy[_index(x + 1, y)])
					+ float(copy[_index(x, y - 1)])
					+ float(copy[_index(x, y + 1)])
				) / 5.0
				heights[_index(x, y)] = average


func _relax_slopes(dt: float) -> void:
	_relax_delta.fill(0.0)
	var moved: bool = false

	for y in range(height):
		for x in range(width):
			var i: int = _index(x, y)
			if x + 1 < width:
				moved = _relax_pair(
					i,
					_index(x + 1, y),
					_relax_delta,
					dt
				) or moved
			if y + 1 < height:
				moved = _relax_pair(
					i,
					_index(x, y + 1),
					_relax_delta,
					dt
				) or moved

	if not moved:
		return
	for i in range(heights.size()):
		heights[i] = clampf(
			float(heights[i]) + float(_relax_delta[i]),
			MIN_HEIGHT,
			MAX_HEIGHT
		)
	revision += 1


func _relax_pair(
	a: int,
	b: int,
	delta: PackedFloat32Array,
	dt: float
) -> bool:
	var ha: float = float(heights[a])
	var hb: float = float(heights[b])
	var difference: float = ha - hb
	var local_talus: float = (
		TALUS_HEIGHT
		+ (_biome_stability(a) + _biome_stability(b)) * 0.5
	)
	if absf(difference) <= local_talus:
		return false

	var transfer: float = minf(
		absf(difference) * 0.12,
		(absf(difference) - local_talus) * 0.5
	) * clampf(dt * 10.0, 0.0, 1.0)
	if transfer <= 0.0:
		return false

	if difference > 0.0:
		delta[a] -= transfer
		delta[b] += transfer
	else:
		delta[b] -= transfer
		delta[a] += transfer
	return true


func _radial_cells(position: Vector2, radius_world: float) -> Array:
	var gx: int = clampi(roundi(position.x / CELL_SIZE), 0, width - 1)
	var gy: int = clampi(roundi(position.y / CELL_SIZE), 0, height - 1)
	var radius_cells: int = maxi(1, ceili(radius_world / CELL_SIZE) + 1)
	var entries: Array = []
	var weight_sum: float = 0.0

	for y in range(
		maxi(0, gy - radius_cells),
		mini(height, gy + radius_cells + 1)
	):
		for x in range(
			maxi(0, gx - radius_cells),
			mini(width, gx + radius_cells + 1)
		):
			var wp: Vector2 = world_position_for_grid(x, y)
			var distance: float = wp.distance_to(position)
			if distance > radius_world + CELL_SIZE * 0.75:
				continue
			var weight: float = maxf(
				0.08,
				1.0
				- distance
				/ maxf(CELL_SIZE, radius_world + CELL_SIZE * 0.75)
			)
			entries.append([_index(x, y), weight])
			weight_sum += weight

	if entries.is_empty():
		entries.append([_index(gx, gy), 1.0])
		return entries

	for entry in entries:
		entry[1] = float(entry[1]) / weight_sum
	return entries


func _index(x: int, y: int) -> int:
	return y * width + x


func _height_value(x: int, y: int) -> float:
	return float(heights[_index(x, y)])
