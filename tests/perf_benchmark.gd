extends SceneTree

const PetriSimulationScript = preload("res://src/simulation/petri_simulation.gd")
const LivingTerrainScript = preload("res://src/simulation/living_terrain.gd")

const DT := 1.0 / 60.0
const WARMUP_STEPS := 30
const MEASURE_STEPS := 120
const POPULATIONS := [100, 500, 1000, 2000, 5000, 10000]


func _init() -> void:
	print("MicroC0re simulation benchmark | dt=1/60 | realtime target >= 60 ticks/s")

	for population_variant in POPULATIONS:
		var population: int = int(population_variant)
		var sim: Variant = PetriSimulationScript.new(9000 + population)
		sim.seed_demo(population)
		var terrain: Variant = LivingTerrainScript.new(
			19000 + population,
			Vector2(sim.world_size)
		)
		var warmup_steps: int = (
			WARMUP_STEPS
			if population <= 1000
			else 12 if population <= 2000
			else 6 if population <= 5000
			else 3
		)
		for _warmup in range(warmup_steps):
			sim.step(DT)
			terrain.advance_from_sim(sim, DT)

		var measured_steps: int = (
			MEASURE_STEPS
			if population <= 1000
			else 45 if population <= 2000
			else 20 if population <= 5000
			else 10
		)
		var candidate_sum: int = 0
		var narrow_sum: int = 0
		var interaction_sum: int = 0
		var contact_sum: int = 0
		var chemistry_ms_sum: float = 0.0
		var agents_ms_sum: float = 0.0
		var mechanics_ms_sum: float = 0.0
		var core_usec_sum: int = 0
		var terrain_usec_sum: int = 0

		var start_usec: int = Time.get_ticks_usec()
		for _step in range(measured_steps):
			var core_start: int = Time.get_ticks_usec()
			sim.step(DT)
			core_usec_sum += Time.get_ticks_usec() - core_start
			var terrain_start: int = Time.get_ticks_usec()
			terrain.advance_from_sim(sim, DT)
			terrain_usec_sum += Time.get_ticks_usec() - terrain_start
			candidate_sum += int(sim.pair_candidates_last)
			narrow_sum += int(sim.pair_narrow_checks_last)
			interaction_sum += int(sim.pair_interactions_last)
			contact_sum += int(sim.pair_contacts_last)
			chemistry_ms_sum += float(sim.chemistry_ms_last)
			agents_ms_sum += float(sim.agents_ms_last)
			mechanics_ms_sum += float(sim.mechanics_ms_last)
		var elapsed_usec: int = Time.get_ticks_usec() - start_usec

		var total_ms: float = float(elapsed_usec) / 1000.0
		var ms_per_tick: float = total_ms / float(measured_steps)
		var core_ms_per_tick: float = (
			float(core_usec_sum) / 1000.0 / float(measured_steps)
		)
		var terrain_ms_per_tick: float = (
			float(terrain_usec_sum) / 1000.0 / float(measured_steps)
		)
		var ticks_per_second: float = 1000.0 / maxf(ms_per_tick, 0.000001)

		var realtime_factor: float = ticks_per_second / 60.0

		var denom: float = float(measured_steps)
		print(
			"population=%d final=%d | %.3f ms/tick | core %.3f ms terrain %.3f ms | %.1f ticks/s | realtime x%.2f | chem %.3f ms agents %.3f ms mech %.3f ms | pairs %.0f -> narrow %.0f -> interact %.0f -> contact %.0f"
			% [
				population,
				sim.bacteria.size(),
				ms_per_tick,
				core_ms_per_tick,
				terrain_ms_per_tick,
				ticks_per_second,
				realtime_factor,
				chemistry_ms_sum / denom,
				agents_ms_sum / denom,
				mechanics_ms_sum / denom,
				float(candidate_sum) / denom,
				float(narrow_sum) / denom,
				float(interaction_sum) / denom,
				float(contact_sum) / denom,
			]
		)

	quit(0)
