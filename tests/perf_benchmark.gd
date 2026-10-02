extends SceneTree

const PetriSimulationScript = preload("res://src/simulation/petri_simulation.gd")

const DT := 1.0 / 60.0
const WARMUP_STEPS := 30
const MEASURE_STEPS := 120
const POPULATIONS := [100, 500, 1000]


func _init() -> void:
	print("MicroC0re simulation benchmark | dt=1/60 | realtime target >= 60 ticks/s")

	for population_variant in POPULATIONS:
		var population: int = int(population_variant)
		var sim: Variant = PetriSimulationScript.new(9000 + population)
		sim.seed_demo(population)

		for _warmup in range(WARMUP_STEPS):
			sim.step(DT)

		var start_usec: int = Time.get_ticks_usec()
		for _step in range(MEASURE_STEPS):
			sim.step(DT)
		var elapsed_usec: int = Time.get_ticks_usec() - start_usec

		var total_ms: float = float(elapsed_usec) / 1000.0
		var ms_per_tick: float = total_ms / float(MEASURE_STEPS)
		var ticks_per_second: float = 1000.0 / maxf(ms_per_tick, 0.000001)

		var realtime_factor: float = ticks_per_second / 60.0

		print(
			"population=%d final=%d | %.3f ms/tick | %.1f ticks/s | realtime x%.2f"
			% [
				population,
				sim.bacteria.size(),
				ms_per_tick,
				ticks_per_second,
				realtime_factor,
			]
		)

	quit(0)
