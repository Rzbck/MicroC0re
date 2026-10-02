extends SceneTree

const PetriSimulationScript = preload("res://src/simulation/petri_simulation.gd")
# Compile the visible app stack during every headless smoke run so renderer
# script parse errors cannot survive until the manual GUI test.
const PixelMicroscopeScript = preload("res://src/app/pixel_microscope.gd")
const PixelAtlasScript = preload("res://src/app/pixel_microbe_atlas.gd")
const FarMultiMeshRendererScript = preload("res://src/app/far_multimesh_renderer.gd")
const ProtozoanScript = preload("res://src/simulation/protozoan.gd")
const CiliateScript = preload("res://src/simulation/ciliate.gd")
const MicroalgaScript = preload("res://src/simulation/microalga.gd")
const DecomposerYeastScript = preload("res://src/simulation/decomposer_yeast.gd")
const PixelProtozoaAtlasScript = preload("res://src/app/pixel_protozoa_atlas.gd")
const PixelCiliateAtlasScript = preload("res://src/app/pixel_ciliate_atlas.gd")
const PixelEcologyAtlasScript = preload("res://src/app/pixel_ecology_atlas.gd")

const STEPS := 600
const DT := 1.0 / 60.0


func _init() -> void:
	var first = PetriSimulationScript.new(424242)
	var second = PetriSimulationScript.new(424242)
	first.seed_demo(24)
	second.seed_demo(24)

	for _i in range(STEPS):
		first.step(DT)
		second.step(DT)

	var errors := PackedStringArray()

	# Regression: ciliate prey lookup must remain generic after capture.
	# Otherwise algae/yeast can become permanently "engulfed" after the
	# first frame because the feeding continuation only searches bacteria.
	var trophic = PetriSimulationScript.new(5150)
	trophic.seed_demo(0)
	trophic.protozoa.clear()
	trophic.decomposers.clear()
	if trophic.ciliates.is_empty() or trophic.microalgae.is_empty():
		errors.append("ecology: missing ciliate/alga regression fixtures")
	else:
		var grazer = trophic.ciliates[0]
		var alga = trophic.microalgae[0]
		grazer.position = Vector2(alga.position)
		grazer.cooldown = 0.0
		trophic._advance_ciliates(DT)
		if int(grazer.feeding_target_id) != int(alga.id):
			errors.append("ecology: ciliate failed to capture microalga")
		else:
			var before_progress: float = float(grazer.feeding_progress)
			trophic._advance_ciliates(DT)
			if float(grazer.feeding_progress) <= before_progress:
				errors.append("ecology: ciliate lost non-bacterial prey after capture")
			if int(alga.engulfed_by_id) != int(grazer.id):
				errors.append("ecology: microalga capture ownership was lost")

	if first.state_signature() != second.state_signature():
		errors.append("determinism: identical seeds produced different signatures")

	if first.bacteria.is_empty():
		errors.append("population: all bacteria died during the smoke window")
	if first.protozoa.is_empty():
		errors.append("ecology: amoeboid predator guild disappeared during smoke")
	if first.ciliates.is_empty():
		errors.append("ecology: ciliate predator guild disappeared during smoke")
	if first.microalgae.is_empty():
		errors.append("ecology: explicit microalgae guild disappeared during smoke")
	if first.decomposers.is_empty():
		errors.append("ecology: decomposer guild disappeared during smoke")
	if first.bacteria.size() > 420:
		errors.append("population guard: bacterial hard ceiling exceeded")
	if first.protozoa.size() > 18:
		errors.append("population guard: protozoan hard ceiling exceeded")
	if first.ciliates.size() > 16:
		errors.append("population guard: ciliate hard ceiling exceeded")
	if first.microalgae.size() > 64:
		errors.append("population guard: microalgae hard ceiling exceeded")
	if first.decomposers.size() > 48:
		errors.append("population guard: decomposer hard ceiling exceeded")

	if first.nutrient.min_value() < -0.000001:
		errors.append("nutrient: negative concentration detected")

	if first.waste.min_value() < -0.000001:
		errors.append("waste: negative concentration detected")
	if first.oxygen.min_value() < -0.000001:
		errors.append("biome: negative oxygen detected")
	if first.detritus.min_value() < -0.000001:
		errors.append("biome: negative detritus detected")
	if first.eps.min_value() < -0.000001:
		errors.append("biome: negative EPS detected")
	if first.damage_cue.min_value() < -0.000001:
		errors.append("biome: negative damage cue detected")
	if first.producer_biomass.min_value() < -0.000001:
		errors.append("biome: negative producer biomass detected")
	if first.producer_biomass.total() <= 0.0:
		errors.append("biome: producer mat disappeared")

	var ids := {}
	var saw_genotype_variation: bool = false
	for cell in first.bacteria:
		if ids.has(cell.id):
			errors.append("identity: duplicate cell id %d" % cell.id)
		ids[cell.id] = true

		if not _finite_vector(cell.position):
			errors.append("state: non-finite position for cell %d" % cell.id)
		if not is_finite(cell.angle):
			errors.append("state: non-finite angle for cell %d" % cell.id)
		if not is_finite(cell.length) or cell.length <= 0.0:
			errors.append("state: invalid length for cell %d" % cell.id)
		if not is_finite(cell.energy) or cell.energy < 0.0:
			errors.append("state: invalid energy for cell %d" % cell.id)
		if (
			not is_finite(float(cell.division_progress))
			or float(cell.division_progress) < 0.0
			or float(cell.division_progress) > 1.000001
		):
			errors.append("state: invalid division progress for cell %d" % cell.id)
		if (
			not is_finite(float(cell.lysis_progress))
			or float(cell.lysis_progress) < 0.0
			or float(cell.lysis_progress) > 1.000001
		):
			errors.append("state: invalid lysis progress for cell %d" % cell.id)

		if int(cell.guild) < 0 or int(cell.guild) > 3:
			errors.append("ecology: invalid bacterial guild for cell %d" % cell.id)
		if int(cell.plasmid_mask) < 0 or int(cell.plasmid_mask) > 15:
			errors.append("evolution: invalid plasmid mask for cell %d" % cell.id)
		if int(cell.transfer_role) < 0 or int(cell.transfer_role) > 2:
			errors.append("evolution: invalid transfer role for cell %d" % cell.id)
		if (
			float(cell.transfer_progress) < 0.0
			or float(cell.transfer_progress) > 1.000001
		):
			errors.append("evolution: invalid transfer progress for cell %d" % cell.id)

		if absf(float(cell.gene_speed) - 1.0) > 0.001:
			saw_genotype_variation = true

	if not saw_genotype_variation:
		errors.append("genetics: founders did not expose any trait variation")

	for proto in first.protozoa:
		if not _finite_vector(proto.position) or not is_finite(proto.energy):
			errors.append("ecology: invalid protozoan state %d" % proto.id)
		if (
			not is_finite(float(proto.lysis_progress))
			or float(proto.lysis_progress) < 0.0
			or float(proto.lysis_progress) > 1.000001
		):
			errors.append("ecology: invalid protozoan lysis state %d" % proto.id)
	for ciliate in first.ciliates:
		if not _finite_vector(ciliate.position) or not is_finite(ciliate.energy):
			errors.append("ecology: invalid ciliate state %d" % ciliate.id)
		if (
			not is_finite(float(ciliate.lysis_progress))
			or float(ciliate.lysis_progress) < 0.0
			or float(ciliate.lysis_progress) > 1.000001
		):
			errors.append("ecology: invalid ciliate lysis state %d" % ciliate.id)
		if (
			not is_finite(float(ciliate.engulf_progress))
			or float(ciliate.engulf_progress) < 0.0
			or float(ciliate.engulf_progress) > 1.000001
		):
			errors.append("ecology: invalid ciliate engulf state %d" % ciliate.id)
		if bool(ciliate.consumed) and int(ciliate.engulfed_by_id) >= 0:
			errors.append("ecology: consumed ciliate still owned by predator %d" % ciliate.id)

	for alga in first.microalgae:
		if not _finite_vector(alga.position) or not is_finite(alga.energy):
			errors.append("ecology: invalid microalga state %d" % alga.id)
		if (
			float(alga.lysis_progress) < 0.0
			or float(alga.lysis_progress) > 1.000001
			or float(alga.reproduction_progress) < 0.0
			or float(alga.reproduction_progress) > 1.000001
			or float(alga.engulf_progress) < 0.0
			or float(alga.engulf_progress) > 1.000001
		):
			errors.append("ecology: invalid microalga transition state %d" % alga.id)

	for yeast in first.decomposers:
		if not _finite_vector(yeast.position) or not is_finite(yeast.energy):
			errors.append("ecology: invalid decomposer state %d" % yeast.id)
		if (
			float(yeast.lysis_progress) < 0.0
			or float(yeast.lysis_progress) > 1.000001
			or float(yeast.budding_progress) < 0.0
			or float(yeast.budding_progress) > 1.000001
			or float(yeast.engulf_progress) < 0.0
			or float(yeast.engulf_progress) > 1.000001
		):
			errors.append("ecology: invalid decomposer transition state %d" % yeast.id)

	if errors.is_empty():
		print(
			"MicroC0re smoke PASS | steps=%d bac=%d amoeba=%d ciliates=%d algae=%d yeast=%d nutrient=%.3f oxygen=%.3f detritus=%.3f producer=%.3f"
			% [
				STEPS,
				first.bacteria.size(),
				first.protozoa.size(),
				first.ciliates.size(),
				first.microalgae.size(),
				first.decomposers.size(),
				first.nutrient.total(),
				first.oxygen.total(),
				first.detritus.total(),
				first.producer_biomass.total(),
			]
		)
		quit(0)
	else:
		for message in errors:
			push_error(message)
		quit(1)


func _finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
