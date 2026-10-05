extends SceneTree

const PetriSimulationScript = preload("res://src/simulation/petri_simulation.gd")
const LivingTerrainScript = preload("res://src/simulation/living_terrain.gd")

const DT := 1.0 / 30.0
const SIM_DURATION := 600.0
const REPORT_INTERVAL := 60.0
const MAX_CONTINUOUS_BACTERIA_EXTINCTION := 420.0
const MAX_REFUGIA_RECOVERIES := 28


func _init() -> void:
	var sim: Variant = PetriSimulationScript.new(424242)
	sim.seed_demo(72)
	var terrain: Variant = LivingTerrainScript.new(525252, Vector2(sim.world_size))

	var elapsed: float = 0.0
	var next_report: float = REPORT_INTERVAL
	var bacteria_zero_since: float = -1.0
	var longest_bacteria_zero: float = 0.0
	var max_refugia: int = 0
	var min_active_guilds: int = 7
	var max_generation_seen: int = 0

	while elapsed < SIM_DURATION:
		sim.step(DT)
		terrain.advance_from_sim(sim, DT)
		elapsed += DT

		if sim.bacteria.is_empty():
			if bacteria_zero_since < 0.0:
				bacteria_zero_since = elapsed
			longest_bacteria_zero = maxf(
				longest_bacteria_zero,
				elapsed - bacteria_zero_since
			)
		else:
			bacteria_zero_since = -1.0

		max_refugia = maxi(max_refugia, int(sim.refugia_recoveries_total))
		var evolution: Dictionary = sim.evolution_metrics()
		max_generation_seen = maxi(
			max_generation_seen,
			int(evolution.get("max_generation", 0))
		)

		var active_guilds: int = 0
		for group in [
			sim.bacteria, sim.protozoa, sim.ciliates, sim.flagellates,
			sim.microalgae, sim.decomposers, sim.hyphae,
		]:
			if not group.is_empty():
				active_guilds += 1
		min_active_guilds = mini(min_active_guilds, active_guilds)

		if elapsed + 0.0001 >= next_report:
			print(
				"ecology_soak t=%ds bac=%d pro=%d cil=%d fla=%d alg=%d dec=%d hyp=%d eco=%d gen=%d refuge=%d soil=%.1f/%.1f"
				% [
					int(round(elapsed)), sim.bacteria.size(), sim.protozoa.size(),
					sim.ciliates.size(), sim.flagellates.size(), sim.microalgae.size(),
					sim.decomposers.size(), sim.hyphae.size(),
					int(evolution.get("ecotypes", 0)),
					int(evolution.get("max_generation", 0)),
					int(sim.refugia_recoveries_total),
					float(terrain.excavated_total), float(terrain.deposited_total),
				]
			)
			next_report += REPORT_INTERVAL

	var failures := PackedStringArray()
	if longest_bacteria_zero > MAX_CONTINUOUS_BACTERIA_EXTINCTION:
		failures.append(
			"bacterial active extinction lasted %.1fs (> %.1fs)"
			% [longest_bacteria_zero, MAX_CONTINUOUS_BACTERIA_EXTINCTION]
		)
	if max_refugia > MAX_REFUGIA_RECOVERIES:
		failures.append(
			"refugia churned %d times (> %d)"
			% [max_refugia, MAX_REFUGIA_RECOVERIES]
		)
	if max_generation_seen <= 0:
		failures.append("no reproductive generation advance observed")

	var events: Dictionary = sim.ecology_event_metrics()
	print(
		"ecology_soak FINAL bac=%d pro=%d cil=%d fla=%d alg=%d dec=%d hyp=%d refuge=%d longest_bacteria_zero=%.1fs min_active_guilds=%d gen=%d pred=%d/%d/%d"
		% [
			sim.bacteria.size(), sim.protozoa.size(), sim.ciliates.size(),
			sim.flagellates.size(), sim.microalgae.size(), sim.decomposers.size(),
			sim.hyphae.size(), max_refugia, longest_bacteria_zero, min_active_guilds,
			max_generation_seen,
			int(events.get("pred_proto_bacteria", 0))
				+ int(events.get("pred_proto_ciliate", 0))
				+ int(events.get("pred_proto_flagellate", 0))
				+ int(events.get("pred_proto_algae", 0))
				+ int(events.get("pred_proto_decomposer", 0)),
			int(events.get("pred_ciliate_bacteria", 0))
				+ int(events.get("pred_ciliate_flagellate", 0))
				+ int(events.get("pred_ciliate_algae", 0))
				+ int(events.get("pred_ciliate_decomposer", 0)),
			int(events.get("pred_flagellate_bacteria", 0)),
		]
	)

	if not failures.is_empty():
		for failure in failures:
			push_error("ecology_soak: " + failure)
		quit(1)
		return

	print("ecology_soak PASS")
	quit(0)
