class_name LivingTerrain
extends RefCounted

const PhysicalCapabilityGenomeScript = preload("res://src/simulation/physical_capability_genome.gd")

const CELL_SIZE := 3.0
const MIN_HEIGHT := -2.5
const MAX_HEIGHT := 9.0
const WATER_LEVEL := 0.42
const TALUS_HEIGHT := 0.72

var world_size := Vector2.ZERO
var width: int = 0
var height: int = 0
var heights := PackedFloat32Array()
var fixed_seed: int = 1
var _relax_accumulator: float = 0.0
var _terrain_tick: int = 0
var revision: int = 0
var excavated_total: float = 0.0
var deposited_total: float = 0.0

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
	_generate_seeded_relief()


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


func height_at_grid(x: int, y: int) -> float:
	return _height_value(clampi(x, 0, width - 1), clampi(y, 0, height - 1))


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
	var remaining: float = maxf(0.0, amount)
	if remaining <= 0.0:
		return 0.0

	var cells: Array = _radial_cells(position, radius_world)
	var removed: float = 0.0
	for entry in cells:
		if remaining <= 0.000001:
			break
		var index: int = int(entry[0])
		var weight: float = float(entry[1])
		var available: float = maxf(0.0, float(heights[index]) - MIN_HEIGHT)
		var take: float = minf(available, amount * weight)
		if take <= 0.0:
			continue
		heights[index] = float(heights[index]) - take
		remaining -= take
		removed += take

	if removed > 0.0:
		excavated_total += removed
		revision += 1
	return removed


func deposit(position: Vector2, amount: float, radius_world: float = 2.0) -> float:
	var remaining: float = maxf(0.0, amount)
	if remaining <= 0.0:
		return 0.0

	var cells: Array = _radial_cells(position, radius_world)
	var placed: float = 0.0
	for entry in cells:
		if remaining <= 0.000001:
			break
		var index: int = int(entry[0])
		var weight: float = float(entry[1])
		var room: float = maxf(0.0, MAX_HEIGHT - float(heights[index]))
		var add: float = minf(room, amount * weight)
		if add <= 0.0:
			continue
		heights[index] = float(heights[index]) + add
		remaining -= add
		placed += add

	if placed > 0.0:
		deposited_total += placed
		revision += 1
	return placed


func advance_from_sim(sim: Variant, dt: float) -> void:
	_terrain_tick += 1
	_advance_group(sim, sim.bacteria, dt, true)
	_advance_group(sim, sim.protozoa, dt, true)
	_advance_group(sim, sim.ciliates, dt, true)
	_advance_group(sim, sim.flagellates, dt, true)
	_advance_group(sim, sim.microalgae, dt, true)
	_advance_group(sim, sim.decomposers, dt, true)
	_advance_group(sim, sim.hyphae, dt, false)

	_advance_capability_fragments(sim, dt)

	_relax_accumulator += dt
	if _relax_accumulator >= 0.10:
		var relax_dt: float = _relax_accumulator
		_relax_accumulator = 0.0
		_relax_slopes(relax_dt)



func _advance_capability_fragments(sim: Variant, dt: float) -> void:
	_fragment_scan_accumulator += dt
	for fragment in capability_fragments:
		fragment["age"] = float(fragment["age"]) + dt

	var survivors: Array = []
	for fragment in capability_fragments:
		if float(fragment["age"]) < CAPABILITY_FRAGMENT_LIFETIME:
			survivors.append(fragment)
	capability_fragments = survivors

	if _fragment_scan_accumulator < 0.20:
		return
	var scan_dt: float = _fragment_scan_accumulator
	_fragment_scan_accumulator = 0.0

	var agents: Array = _all_agents(sim)
	var current: Dictionary = {}
	for agent in agents:
		if agent == null or bool(agent.dying) or agent.physical_genome == null:
			continue
		var agent_id: int = int(agent.id)
		current[agent_id] = {
			"position": Vector2(agent.position),
			"module": agent.physical_genome.module_for_transfer(
				agent_id + _terrain_tick
			),
		}

	for old_id in _known_agents.keys():
		if current.has(old_id):
			continue
		var record: Dictionary = _known_agents[old_id]
		var module_data: Dictionary = (
			record.get("module", {}) as Dictionary
		)
		if module_data.is_empty():
			continue
		if capability_fragments.size() >= CAPABILITY_FRAGMENT_LIMIT:
			capability_fragments.pop_front()
		capability_fragments.append({
			"id": _next_fragment_id,
			"source_id": int(old_id),
			"position": Vector2(record["position"]),
			"module": module_data.duplicate(true),
			"age": 0.0,
		})
		_next_fragment_id += 1

	_known_agents = current
	if capability_fragments.is_empty():
		return

	var remaining: Array = []
	for fragment in capability_fragments:
		var recipient: Variant = _nearest_capability_recipient(
			agents,
			Vector2(fragment["position"]),
			int(fragment["source_id"])
		)
		if recipient == null:
			remaining.append(fragment)
			continue

		var signals: Array = [
			1.0,
			0.15,
			0.0,
			clampf(float(recipient.energy) / 4.0, 0.0, 1.0),
			clampf(
				float(sim.detritus.sample_world(
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
			0.30,
		]
		var assimilation: float = float(
			recipient.physical_genome.expression(
				PhysicalCapabilityGenomeScript.CAP_ASSIMILATE,
				signals
			)
		)
		var probability: float = clampf(
			assimilation * 0.045 * scan_dt,
			0.0,
			0.16
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
				float(recipient.energy) - 0.08
			)
		else:
			remaining.append(fragment)

	capability_fragments = remaining


func _nearest_capability_recipient(
	agents: Array,
	position: Vector2,
	source_id: int
) -> Variant:
	var best: Variant = null
	var best_distance_sq: float = 2.8 * 2.8
	for agent in agents:
		if (
			agent == null
			or bool(agent.dying)
			or int(agent.id) == source_id
			or agent.physical_genome == null
		):
			continue
		var distance_sq: float = position.distance_squared_to(
			Vector2(agent.position)
		)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best = agent
	return best


func _all_agents(sim: Variant) -> Array:
	var agents: Array = []
	agents.append_array(sim.bacteria)
	agents.append_array(sim.protozoa)
	agents.append_array(sim.ciliates)
	agents.append_array(sim.flagellates)
	agents.append_array(sim.microalgae)
	agents.append_array(sim.decomposers)
	agents.append_array(sim.hyphae)
	return agents


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
	can_move: bool
) -> void:
	for agent in group:
		if agent == null or bool(agent.dying):
			continue
		if agent.physical_genome == null:
			continue
		_advance_agent(sim, agent, dt, can_move)


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
		float(sim.detritus.sample_world(position)) * 4.0,
		0.0,
		1.0
	)
	var light_signal: float = clampf(float(sim.sample_light(position)), 0.0, 1.0)
	var water_signal: float = clampf(
		(WATER_LEVEL + 0.8 - local_height) / 1.6,
		0.0,
		1.0
	)
	var signals: Array = [
		1.0,
		clampf(uphill / 1.25, 0.0, 1.0),
		carrying_signal,
		energy_signal,
		detritus_signal,
		light_signal,
		water_signal,
	]

	var dig: float = float(agent.physical_genome.expression(
		PhysicalCapabilityGenomeScript.CAP_DIG, signals
	))
	var carry: float = float(agent.physical_genome.expression(
		PhysicalCapabilityGenomeScript.CAP_CARRY, signals
	))
	var deposit_strength: float = float(agent.physical_genome.expression(
		PhysicalCapabilityGenomeScript.CAP_DEPOSIT, signals
	))
	var burrow: float = float(agent.physical_genome.expression(
		PhysicalCapabilityGenomeScript.CAP_BURROW, signals
	))
	var climb: float = float(agent.physical_genome.expression(
		PhysicalCapabilityGenomeScript.CAP_CLIMB, signals
	))
	var oviposit: float = float(agent.physical_genome.expression(
		PhysicalCapabilityGenomeScript.CAP_OVIPOSIT, signals
	))
	var armor: float = float(agent.physical_genome.expression(
		PhysicalCapabilityGenomeScript.CAP_ARMOR, signals
	))

	agent.physical_dig = dig
	agent.physical_deposit = deposit_strength
	agent.physical_burrow = burrow
	agent.physical_climb = climb
	agent.physical_oviposit = oviposit
	agent.physical_armor = armor

	if can_move and uphill > 0.34 + climb * 0.30 + burrow * 0.12:
		agent.position = Vector2(agent.position) - forward * minf(0.10, uphill * 0.05)
		var turn: float = sin(
			float(int(agent.id) * 37 + _terrain_tick * 11) * 0.017
		)
		agent.angle = wrapf(float(agent.angle) + turn * 0.075, -PI, PI)

	var capacity: float = 0.12 + carry * 0.20
	agent.terrain_action_clock = float(agent.terrain_action_clock) + dt * (
		0.42 + dig * 0.48 + deposit_strength * 0.20
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
			0.045 + deposit_strength * 0.075
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
			0.038 + dig * 0.072
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
	var delta := PackedFloat32Array()
	delta.resize(heights.size())
	delta.fill(0.0)
	var moved: bool = false

	for y in range(height):
		for x in range(width):
			var i: int = _index(x, y)
			if x + 1 < width:
				moved = _relax_pair(
					i,
					_index(x + 1, y),
					delta,
					dt
				) or moved
			if y + 1 < height:
				moved = _relax_pair(
					i,
					_index(x, y + 1),
					delta,
					dt
				) or moved

	if not moved:
		return
	for i in range(heights.size()):
		heights[i] = clampf(
			float(heights[i]) + float(delta[i]),
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
	if absf(difference) <= TALUS_HEIGHT:
		return false

	var transfer: float = minf(
		absf(difference) * 0.12,
		(absf(difference) - TALUS_HEIGHT) * 0.5
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
