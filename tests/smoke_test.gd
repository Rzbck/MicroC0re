extends SceneTree

const PetriSimulationScript = preload("res://src/simulation/petri_simulation.gd")
const ScalarFieldScript = preload("res://src/simulation/scalar_field.gd")
const PhysicalCapabilityGenomeScript = preload("res://src/simulation/physical_capability_genome.gd")
const LivingTerrainScript = preload("res://src/simulation/living_terrain.gd")
const EvolvableGenomeScript = preload("res://src/simulation/evolvable_genome.gd")
const DNAFragmentScript = preload("res://src/simulation/dna_fragment.gd")
const PhageCloudScript = preload("res://src/simulation/phage_cloud.gd")
const BacteriumScript = preload("res://src/simulation/bacterium.gd")
# Compile the visible app stack during every headless smoke run so renderer
# script parse errors cannot survive until the manual GUI test.
const PixelMicroscopeScript = preload("res://src/app/pixel_microscope.gd")
const IsometricEcosystemScript = preload("res://src/app/isometric_ecosystem.gd")
const PixelIsometricWorldScript = preload("res://src/app/pixel_isometric_world.gd")
const SessionTelemetryScript = preload("res://src/app/session_telemetry.gd")
const PixelAtlasScript = preload("res://src/app/pixel_microbe_atlas.gd")
const FarMultiMeshRendererScript = preload("res://src/app/far_multimesh_renderer.gd")
const ProtozoanScript = preload("res://src/simulation/protozoan.gd")
const CiliateScript = preload("res://src/simulation/ciliate.gd")
const FlagellateScript = preload("res://src/simulation/flagellate.gd")
const MicroalgaScript = preload("res://src/simulation/microalga.gd")
const DecomposerYeastScript = preload("res://src/simulation/decomposer_yeast.gd")
const HyphalColonyScript = preload("res://src/simulation/hyphal_colony.gd")
const PixelProtozoaAtlasScript = preload("res://src/app/pixel_protozoa_atlas.gd")
const PixelCiliateAtlasScript = preload("res://src/app/pixel_ciliate_atlas.gd")
const PixelFlagellateAtlasScript = preload("res://src/app/pixel_flagellate_atlas.gd")
const PixelEcologyAtlasScript = preload("res://src/app/pixel_ecology_atlas.gd")
const BiomeMaterialRendererScript = preload("res://src/app/biome_material_renderer.gd")
const WaterBackgroundShader = preload("res://src/app/shaders/water_background.gdshader")
const BiomeMaterialShader = preload("res://src/app/shaders/biome_material.gdshader")
const PixelEffectAtlasScript = preload("res://src/app/pixel_effect_atlas.gd")
const PixelDNAAtlasScript = preload("res://src/app/pixel_dna_atlas.gd")
const PixelHyphaAtlasScript = preload("res://src/app/pixel_hypha_atlas.gd")
const PixelPhageAtlasScript = preload("res://src/app/pixel_phage_atlas.gd")

const STEPS := 600
const DT := 1.0 / 60.0


func _init() -> void:
	var errors := PackedStringArray()
	_validate_preloaded_scripts(errors)

	if WaterBackgroundShader == null or BiomeMaterialShader == null:
		errors.append("render: biome shader resources failed to preload")

	var effect_assets = PixelEffectAtlasScript.new()
	var lysis_fx: Texture2D = effect_assets.get_texture(
		PixelEffectAtlasScript.EFFECT_LYSIS, 2
	)
	if lysis_fx == null or lysis_fx.get_width() <= 0:
		errors.append("render: lysis effect asset missing")

	# Living-terrain regression: excavation/deposition must conserve material
	# when the carried material is returned to the world.
	var terrain_probe = LivingTerrainScript.new(
		19191,
		Vector2(192.0, 128.0)
	)
	var terrain_mass_before: float = terrain_probe.total_mass()
	var removed_soil: float = terrain_probe.excavate(
		Vector2(72.0, 54.0),
		0.35,
		2.2
	)
	if removed_soil <= 0.0:
		errors.append("terrain: excavation failed to remove material")
	var terrain_mass_after_dig: float = terrain_probe.total_mass()
	if (
		absf(
			(terrain_mass_before - terrain_mass_after_dig)
			- removed_soil
		) > 0.0005
	):
		errors.append("terrain: excavation mass accounting drift")
	var returned_soil: float = terrain_probe.deposit(
		Vector2(81.0, 58.0),
		removed_soil,
		2.4
	)
	if absf(returned_soil - removed_soil) > 0.0005:
		errors.append("terrain: deposition failed to return carried mass")
	if absf(terrain_probe.total_mass() - terrain_mass_before) > 0.001:
		errors.append("terrain: dig/deposit cycle did not conserve terrain mass")

	var physical_rng := RandomNumberGenerator.new()
	physical_rng.seed = 515151
	var physical_parent = PhysicalCapabilityGenomeScript.new()
	physical_parent.configure_founder(
		physical_rng,
		PhysicalCapabilityGenomeScript.PROFILE_DECOMPOSER
	)
	var physical_child = PhysicalCapabilityGenomeScript.new()
	var saw_physical_structure: bool = false
	for i in range(120):
		physical_child.inherit_and_mutate(
			physical_parent,
			physical_rng,
			0.20
		)
		if physical_child.modules.size() != physical_parent.modules.size():
			saw_physical_structure = true
			break
	if (
		physical_child.modules.size() < 3
		or physical_child.modules.size() > 18
	):
		errors.append("evolution: physical capability genome escaped bounds")
	if not saw_physical_structure:
		errors.append("evolution: physical capability structural mutation absent")

	var recipient_physical = PhysicalCapabilityGenomeScript.new()
	recipient_physical.configure_founder(
		physical_rng,
		PhysicalCapabilityGenomeScript.PROFILE_PRODUCER
	)
	var donor_module := {
		"kind": PhysicalCapabilityGenomeScript.CAP_DIG,
		"strength": 1.7,
		"sensor": PhysicalCapabilityGenomeScript.SENSOR_ALWAYS,
		"threshold": 0.2,
		"polarity": 1,
		"innovation": 909090,
	}
	var module_count_before: int = recipient_physical.modules.size()
	if not recipient_physical.integrate_module(
		donor_module,
		physical_rng
	):
		errors.append("evolution: cross-lineage physical module merge failed")
	if recipient_physical.modules.size() < module_count_before:
		errors.append("evolution: capability merge unexpectedly lost structure")

		# Performance invariant: synchronous bacterial fission may never overshoot
	# the CPU reference ceiling even if many mothers finish division together.
	var cap_probe = PetriSimulationScript.new(880044)
	cap_probe.bacteria_population_limit = 420
	cap_probe.seed_demo(418)
	for cell in cap_probe.bacteria:
		cell.length = 8.0
		cell.energy = 12.0
		cell.begin_division()
		cell.division_progress = 1.0
	cap_probe.step(1.0 / 60.0)
	if cap_probe.bacteria.size() > cap_probe.bacteria_population_limit:
		errors.append("performance: bacterial division overshot safety ceiling")

	# 	# Hot-path scalar nearest sampling must match the exact addressed cell.
	var scalar_probe = ScalarFieldScript.new(8, 8, 2.0, 0.0)
	scalar_probe.set_cell(3, 4, 0.75)
	if absf(
		scalar_probe.sample_nearest_world(Vector2(6.4, 8.6)) - 0.75
	) > 0.0001:
		errors.append("performance: nearest scalar-field sampling mismatch")

	var id_probe = PetriSimulationScript.new(73001)
	id_probe.seed_demo(24)
	id_probe.step(1.0 / 30.0)
	if id_probe.bacteria.is_empty():
		errors.append("performance: id-map probe lost all bacteria")
	else:
		var id_cell = id_probe.bacteria[0]
		if id_probe.find_cell_by_id(int(id_cell.id)) != id_cell:
			errors.append("performance: bacteria id cache lookup mismatch")

		# High-density mechanics must switch to bounded density mode without
	# producing non-finite positions.
	var density_probe = PetriSimulationScript.new(771002)
	density_probe.seed_demo(
		PetriSimulationScript.EXACT_MECHANICS_LIMIT + 32
	)
	density_probe.step(1.0 / 30.0)
	if int(density_probe.mechanics_mode_last) != 1:
		errors.append("performance: high-density mechanics LOD did not engage")
	for density_cell in density_probe.bacteria:
		var density_position: Vector2 = Vector2(density_cell.position)
		if not (
			is_finite(density_position.x)
			and is_finite(density_position.y)
		):
			errors.append("performance: density mechanics produced invalid position")
			break

		# Indexed scalar hot APIs must conserve local add/take semantics.
	var indexed_probe = ScalarFieldScript.new(4, 4, 2.0, 0.0)
	indexed_probe.add_index(5, 0.8)
	var indexed_taken: float = indexed_probe.take_index(5, 0.3)
	if (
		absf(indexed_taken - 0.3) > 0.0001
		or absf(float(indexed_probe.values[5]) - 0.5) > 0.0001
	):
		errors.append("performance: indexed scalar add/take mismatch")

		# Regression: dense producer biomass must reduce local effective light.
	# This is a biome feedback, not a renderer-only tint.
	var shade_probe = PetriSimulationScript.new(99173)
	var shade_position := Vector2(21.0, 21.0)
	shade_probe.producer_biomass.fill(0.0)
	var open_light: float = float(shade_probe.sample_light(shade_position))
	# Fill the field so bilinear sampling observes a fully dense local patch
	# instead of averaging one occupied cell with three empty neighbors.
	shade_probe.producer_biomass.fill(1.0)
	var shaded_light: float = float(shade_probe.sample_light(shade_position))
	if shaded_light >= open_light * 0.80:
		errors.append("biome: producer self-shading did not attenuate local light")
	if shaded_light <= 0.0 or not is_finite(shaded_light):
		errors.append("biome: producer self-shading produced invalid light")

	# Regression: producer mats may grow/spread from real seeds, but an empty
	# field must not spontaneously turn into full-screen producer wallpaper.
	var mat_probe = PetriSimulationScript.new(77123)
	mat_probe.producer_biomass.fill(0.0)
	mat_probe.nutrient.fill(1.0)
	mat_probe._advance_producer_mat(5.0)
	if mat_probe.producer_biomass.total() > 0.000001:
		errors.append("biome: empty producer field nucleated without a seed")
	var mat_position := Vector2(48.0, 48.0)
	mat_probe.producer_biomass.add_nearest_world(mat_position, 0.40)
	var seeded_before: float = mat_probe.producer_biomass.total()
	mat_probe._advance_producer_mat(1.0)
	if mat_probe.producer_biomass.total() <= seeded_before:
		errors.append("biome: seeded producer mat failed to grow")

	# Cross-feeding / dormancy regression.
	var interaction_probe = PetriSimulationScript.new(88231)
	interaction_probe.seed_demo(1)
	var interaction_cell = interaction_probe.bacteria[0]
	interaction_probe.nutrient.fill(0.0)
	interaction_probe.exudate.fill(0.0)
	interaction_cell.energy = 0.30
	interaction_cell.dormant = false
	interaction_probe._advance_cell(interaction_cell, DT)
	if not bool(interaction_cell.dormant):
		errors.append("ecology: starving bacterium failed to enter dormancy")
	interaction_probe.exudate.add_radial_world(
		Vector2(interaction_cell.position), 3.0, 0.80
	)
	interaction_probe._advance_cell(interaction_cell, DT)
	if bool(interaction_cell.dormant):
		errors.append("ecology: dormant bacterium failed to wake on exudate")
	var exudate_before: float = interaction_probe.exudate.total()
	interaction_probe._advance_cell(interaction_cell, 0.50)
	if interaction_probe.exudate.total() >= exudate_before:
		errors.append("ecology: bacterium failed to consume cross-feeding exudate")

	# Succession/disturbance regression: pulses must alter local fields while
	# washout removes attached material instead of creating/deleting organisms.
	var succession_probe = PetriSimulationScript.new(7319)
	succession_probe.seed_demo(0)
	var nutrient_before_pulse: float = succession_probe.nutrient.total()
	succession_probe._trigger_disturbance(
		PetriSimulationScript.DISTURBANCE_RESOURCE_PULSE
	)
	if succession_probe.nutrient.total() <= nutrient_before_pulse:
		errors.append("biome: resource disturbance failed to enrich nutrient")
	succession_probe.producer_biomass.fill(0.60)
	succession_probe.eps.fill(0.35)
	var producer_before_washout: float = succession_probe.producer_biomass.total()
	var eps_before_washout: float = succession_probe.eps.total()
	succession_probe._trigger_disturbance(
		PetriSimulationScript.DISTURBANCE_WASHOUT
	)
	if succession_probe.producer_biomass.total() >= producer_before_washout:
		errors.append("biome: washout failed to reduce producer material")
	if succession_probe.eps.total() >= eps_before_washout:
		errors.append("biome: washout failed to reduce EPS")
	if succession_probe.detritus.total() <= 0.0:
		errors.append("biome: washout failed to create detrital opportunity")

	# Natural transformation regression: lysis DNA is bounded and recombination
	# changes a compatible trait without using plasmid-conjugation state.
	var transform_probe = PetriSimulationScript.new(9301)
	transform_probe.seed_demo(2)
	var donor = transform_probe.bacteria[0]
	var recipient = transform_probe.bacteria[1]
	donor.gene_speed = 1.62
	recipient.gene_speed = 0.72
	recipient.gene_competence = 1.5
	var dna = DNAFragmentScript.new(
		1,
		Vector2(recipient.position),
		int(donor.lineage_id),
		float(recipient.lineage_hue),
		DNAFragmentScript.TRAIT_SPEED,
		float(donor.gene_speed)
	)
	var speed_before: float = float(recipient.gene_speed)
	transform_probe._integrate_dna_fragment(recipient, dna)
	if float(recipient.gene_speed) <= speed_before:
		errors.append("evolution: transformation failed to recombine trait")
	transform_probe.dna_fragments.clear()
	for i in range(90):
		transform_probe._release_dna_fragments(donor)
	if transform_probe.dna_fragments.size() > 64:
		errors.append("evolution: extracellular DNA safety ceiling exceeded")

	# Open-ended modular-genome regression: structural mutation stays bounded,
	# expression is context-dependent, and donor modules can create a mosaic.
	var genome_probe = EvolvableGenomeScript.new()
	var genome_rng := RandomNumberGenerator.new()
	genome_rng.seed = 771177
	genome_probe.configure_founder(genome_rng)
	var founder_modules: int = genome_probe.modules.size()
	var child_genome = EvolvableGenomeScript.new()
	var saw_structural_change: bool = false
	for i in range(80):
		child_genome.inherit_and_mutate(genome_probe, genome_rng, 0.18)
		if child_genome.modules.size() != founder_modules:
			saw_structural_change = true
			break
	if child_genome.modules.size() < 2 or child_genome.modules.size() > 14:
		errors.append("evolution: modular genome escaped hard bounds")
	if not saw_structural_change:
		errors.append("evolution: structural mutation probe produced no module change")
	var context_dark: Array = [1.0, 0.2, 0.1, 0.1, 0.0, 0.0, 0.0, 0.2, 0.5]
	var context_light: Array = [1.0, 0.2, 0.1, 0.1, 1.0, 0.0, 0.0, 0.2, 0.5]
	var photo_module := {
		"kind": EvolvableGenomeScript.MODULE_PHOTOTROPHY,
		"strength": 1.2,
		"sensor": EvolvableGenomeScript.SENSOR_LIGHT,
		"threshold": 0.45,
		"polarity": 1,
		"innovation": 998877,
	}
	genome_probe.integrate_module(photo_module, genome_rng)
	if (
		genome_probe.expression(
			EvolvableGenomeScript.MODULE_PHOTOTROPHY,
			context_light
		)
		<= genome_probe.expression(
			EvolvableGenomeScript.MODULE_PHOTOTROPHY,
			context_dark
		)
	):
		errors.append("evolution: regulatory module ignored environmental context")

	# Predator/prey coevolution regression: handling defence must emerge from
	# visible costly traits and local matrix, not a hidden resistance variable.
	var defence_probe = PetriSimulationScript.new(4417)
	defence_probe.seed_demo(2)
	var defended = defence_probe.bacteria[0]
	defence_probe.eps.fill(0.0)
	defended.gene_adhesion = 0.78
	defended.gene_size = 0.92
	defended.dormant = false
	var baseline_defence: float = defence_probe._prey_handling_defense(defended)
	defended.gene_adhesion = 1.70
	defended.gene_size = 1.35
	defence_probe.eps.add_radial_world(Vector2(defended.position), 4.0, 0.75)
	var evolved_defence: float = defence_probe._prey_handling_defense(defended)
	if evolved_defence <= baseline_defence:
		errors.append("evolution: visible prey defence traits did not increase handling cost")

	# Bacteriophage regression: infection is staged, lysis creates a viral
	# burst/shunt, and the cloud representation remains hard bounded.
	var phage_probe = PetriSimulationScript.new(64021)
	phage_probe.seed_demo(1)
	phage_probe.phage_clouds.clear()
	var phage_host = phage_probe.bacteria[0]
	var phage_packet = PhageCloudScript.new(
		1,
		Vector2(phage_host.position),
		float(phage_host.lineage_hue),
		1.0,
		5.0,
		0
	)
	phage_probe._infect_cell_with_phage(phage_host, phage_packet)
	if not bool(phage_host.phage_infected):
		errors.append("ecology: phage failed to infect compatible bacterium")
	phage_host.phage_progress = 0.995
	phage_probe._advance_cell(phage_host, phage_probe.phage_latent_period * 0.01)
	if not bool(phage_host.dying) or not bool(phage_host.phage_triggered_lysis):
		errors.append("ecology: latent phage infection failed to trigger lysis")
	var viral_nutrient_before: float = phage_probe.nutrient.total()
	phage_probe._recycle_dead_cell(phage_host)
	if phage_probe.phage_clouds.is_empty():
		errors.append("ecology: viral lysis failed to release a phage cloud")
	if phage_probe.nutrient.total() <= viral_nutrient_before:
		errors.append("ecology: viral shunt failed to return dissolved nutrient")
	phage_probe.phage_clouds.clear()
	for i in range(40):
		phage_probe._spawn_phage_cloud(
			Vector2(2.0 + float(i % 10) * 18.0, 4.0 + float(i / 10) * 24.0),
			float(i) / 40.0,
			0.20,
			2.0,
			0
		)
	if phage_probe.phage_clouds.size() > 24:
		errors.append("population guard: phage cloud hard ceiling exceeded")

	var capability_founder_probe = PetriSimulationScript.new(20261003)
	capability_founder_probe.seed_demo(8)
	for group in [
		capability_founder_probe.bacteria,
		capability_founder_probe.protozoa,
		capability_founder_probe.ciliates,
		capability_founder_probe.flagellates,
		capability_founder_probe.microalgae,
		capability_founder_probe.decomposers,
		capability_founder_probe.hyphae,
	]:
		for agent in group:
			if agent.physical_genome == null:
				errors.append("evolution: founder missing shared physical genome")
				break

	var first = PetriSimulationScript.new(424242)
	var second = PetriSimulationScript.new(424242)
	first.seed_demo(24)
	second.seed_demo(24)

	for _i in range(STEPS):
		first.step(DT)
		second.step(DT)

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
	if first.flagellates.is_empty():
		errors.append("ecology: flagellate grazer guild disappeared during smoke")
	if first.microalgae.is_empty():
		errors.append("ecology: explicit microalgae guild disappeared during smoke")
	if first.decomposers.is_empty():
		errors.append("ecology: decomposer guild disappeared during smoke")
	if first.hyphae.is_empty():
		errors.append("ecology: hyphal decomposer guild disappeared during smoke")
	if first.bacteria.size() > 420:
		errors.append("population guard: bacterial hard ceiling exceeded")
	if first.protozoa.size() > 18:
		errors.append("population guard: protozoan hard ceiling exceeded")
	if first.ciliates.size() > 16:
		errors.append("population guard: ciliate hard ceiling exceeded")
	if first.flagellates.size() > 28:
		errors.append("population guard: flagellate hard ceiling exceeded")
	if first.microalgae.size() > 64:
		errors.append("population guard: microalgae hard ceiling exceeded")
	if first.decomposers.size() > 48:
		errors.append("population guard: decomposer hard ceiling exceeded")
	if first.hyphae.size() > 6:
		errors.append("population guard: hyphal colony ceiling exceeded")
	if first.phage_clouds.size() > 24:
		errors.append("population guard: phage cloud ceiling exceeded")

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
	if first.exudate.min_value() < -0.000001:
		errors.append("biome: negative exudate detected")
	if first.quorum_signal.min_value() < -0.000001:
		errors.append("biome: negative quorum signal detected")
	if first.fungal_enzyme.min_value() < -0.000001:
		errors.append("biome: negative fungal enzyme detected")
	if first.producer_biomass.total() <= 0.0:
		errors.append("biome: producer mat disappeared")
	if first.exudate.total() <= 0.0:
		errors.append("ecology: cross-feeding exudate field remained empty")
	if first.quorum_signal.total() <= 0.0:
		errors.append("ecology: quorum signal field remained empty")
	if first.fungal_enzyme.total() <= 0.0:
		errors.append("ecology: fungal enzyme field remained empty")

	for cloud in first.phage_clouds:
		if not _finite_vector(cloud.position):
			errors.append("ecology: non-finite phage cloud position %d" % cloud.id)
		if (
			not is_finite(float(cloud.concentration))
			or float(cloud.concentration) < 0.0
		):
			errors.append("ecology: invalid phage cloud concentration %d" % cloud.id)

	for colony in first.hyphae:
		if not _finite_vector(colony.position) or not is_finite(float(colony.energy)):
			errors.append("ecology: invalid hyphal colony state %d" % colony.id)
		if colony.nodes.size() > 24:
			errors.append("population guard: hyphal node ceiling exceeded")
		if colony.nodes.size() != colony.parents.size():
			errors.append("ecology: malformed hyphal graph %d" % colony.id)
		for node in colony.nodes:
			if not _finite_vector(Vector2(node)):
				errors.append("ecology: non-finite hyphal node %d" % colony.id)

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
		if cell.genome == null:
			errors.append("evolution: cell missing modular genome %d" % cell.id)
		elif cell.genome.modules.size() < 2 or cell.genome.modules.size() > 14:
			errors.append("evolution: invalid genome module count for cell %d" % cell.id)
		if int(cell.plasmid_mask) < 0 or int(cell.plasmid_mask) > 15:
			errors.append("evolution: invalid plasmid mask for cell %d" % cell.id)
		if not is_finite(float(cell.gene_dormancy)):
			errors.append("ecology: invalid dormancy trait for cell %d" % cell.id)
		if not is_finite(float(cell.gene_competence)):
			errors.append("evolution: invalid competence trait for cell %d" % cell.id)
		if (
			float(cell.phage_progress) < 0.0
			or float(cell.phage_progress) > 1.000001
		):
			errors.append("ecology: invalid phage infection progress for cell %d" % cell.id)
		if float(cell.dormant_time) < 0.0 or not is_finite(float(cell.dormant_time)):
			errors.append("ecology: invalid dormant timer for cell %d" % cell.id)
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

	for flagellate in first.flagellates:
		if not _finite_vector(flagellate.position) or not is_finite(flagellate.energy):
			errors.append("ecology: invalid flagellate state %d" % flagellate.id)
		if (
			float(flagellate.lysis_progress) < 0.0
			or float(flagellate.lysis_progress) > 1.000001
			or float(flagellate.feeding_progress) < 0.0
			or float(flagellate.feeding_progress) > 1.000001
			or float(flagellate.engulf_progress) < 0.0
			or float(flagellate.engulf_progress) > 1.000001
		):
			errors.append("ecology: invalid flagellate transition state %d" % flagellate.id)

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
			"MicroC0re smoke PASS | steps=%d bac=%d amoeba=%d ciliates=%d flagellates=%d algae=%d yeast=%d hyphae=%d phage=%d nutrient=%.3f oxygen=%.3f detritus=%.3f producer=%.3f exudate=%.3f quorum=%.3f"
			% [
				STEPS,
				first.bacteria.size(),
				first.protozoa.size(),
				first.ciliates.size(),
				first.flagellates.size(),
				first.microalgae.size(),
				first.decomposers.size(),
				first.hyphae.size(),
				first.phage_clouds.size(),
				first.nutrient.total(),
				first.oxygen.total(),
				first.detritus.total(),
				first.producer_biomass.total(),
				first.exudate.total(),
				first.quorum_signal.total(),
			]
		)
		quit(0)
	else:
		for message in errors:
			push_error(message)
		quit(1)


func _validate_preloaded_scripts(errors: PackedStringArray) -> void:
	var required_scripts: Array = [
		["petri_simulation", PetriSimulationScript],
		["physical_capability_genome", PhysicalCapabilityGenomeScript],
		["living_terrain", LivingTerrainScript],
		["isometric_ecosystem", IsometricEcosystemScript],
		["pixel_isometric_world", PixelIsometricWorldScript],
		["session_telemetry", SessionTelemetryScript],
		["evolvable_genome", EvolvableGenomeScript],
		["dna_fragment", DNAFragmentScript],
		["phage_cloud", PhageCloudScript],
		["bacterium", BacteriumScript],
		["pixel_microscope", PixelMicroscopeScript],
		["pixel_microbe_atlas", PixelAtlasScript],
		["far_multimesh_renderer", FarMultiMeshRendererScript],
		["protozoan", ProtozoanScript],
		["ciliate", CiliateScript],
		["flagellate", FlagellateScript],
		["microalga", MicroalgaScript],
		["decomposer_yeast", DecomposerYeastScript],
		["hyphal_colony", HyphalColonyScript],
		["pixel_protozoa_atlas", PixelProtozoaAtlasScript],
		["pixel_ciliate_atlas", PixelCiliateAtlasScript],
		["pixel_flagellate_atlas", PixelFlagellateAtlasScript],
		["pixel_ecology_atlas", PixelEcologyAtlasScript],
		["biome_material_renderer", BiomeMaterialRendererScript],
		["pixel_effect_atlas", PixelEffectAtlasScript],
		["pixel_dna_atlas", PixelDNAAtlasScript],
		["pixel_hypha_atlas", PixelHyphaAtlasScript],
		["pixel_phage_atlas", PixelPhageAtlasScript],
	]

	for entry in required_scripts:
		var script_name: String = String(entry[0])
		var script: Variant = entry[1]
		if script == null:
			errors.append("preload: %s script is null" % script_name)
		elif not script.can_instantiate():
			errors.append("preload: %s script cannot instantiate" % script_name)


func _finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
