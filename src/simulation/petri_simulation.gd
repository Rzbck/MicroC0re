class_name PetriSimulation
extends RefCounted

const ScalarFieldScript = preload("res://src/simulation/scalar_field.gd")
const EvolvableGenomeScript = preload("res://src/simulation/evolvable_genome.gd")
const DNAFragmentScript = preload("res://src/simulation/dna_fragment.gd")
const BacteriumScript = preload("res://src/simulation/bacterium.gd")
const ProtozoanScript = preload("res://src/simulation/protozoan.gd")
const CiliateScript = preload("res://src/simulation/ciliate.gd")
const FlagellateScript = preload("res://src/simulation/flagellate.gd")
const MicroalgaScript = preload("res://src/simulation/microalga.gd")
const DecomposerYeastScript = preload("res://src/simulation/decomposer_yeast.gd")
const HyphalColonyScript = preload("res://src/simulation/hyphal_colony.gd")
const PhageCloudScript = preload("res://src/simulation/phage_cloud.gd")

const FIELD_WIDTH := 96
const FIELD_HEIGHT := 64
const FIELD_CELL_SIZE := 2.0
const CHEMISTRY_DT_SMALL := 1.0 / 15.0
const CHEMISTRY_DT_MEDIUM := 1.0 / 10.0
const CHEMISTRY_DT_MASS := 1.0 / 8.0
const CHEMISTRY_DT_ULTRA := 1.0 / 6.0
const SLOW_BIOME_DT := 1.0 / 5.0
const MECHANICS_DT := 1.0 / 30.0
const AGENT_DT_SMALL := 1.0 / 30.0
const AGENT_DT_MEDIUM := 1.0 / 20.0
const AGENT_DT_MASS := 1.0 / 12.0
const AGENT_DT_ULTRA := 1.0 / 8.0
const AGENT_MEDIUM_THRESHOLD := 350
const AGENT_MASS_THRESHOLD := 1600
const AGENT_ULTRA_THRESHOLD := 4500
const EXACT_MECHANICS_LIMIT := 900
const DENSITY_NEIGHBOR_VISIT_CAP := 18
const DENSITY_NEIGHBOR_VISIT_CAP_ULTRA := 12
const DIRECTION_LUT_SIZE := 1024
const DRIFT_LUT_SIZE := 608
const DRIFT_LUT_PHASE_STEP := 3
const REGULATION_BUCKETS := 6
const LINEAGE_BIN_COUNT := 32
const ECOTYPE_PRESSURE_BIN_COUNT := 256
const LIVE_POPULATION_SOFT_START := 1600
const SPATIAL_BUCKET_SIZE := 3.0
# 192 x 128 world with 3-unit linked cells.
const GRID_WIDTH := 64
const GRID_HEIGHT := 43
const GRID_CELL_COUNT := GRID_WIDTH * GRID_HEIGHT
# CPU-reference safety ceilings. These are performance guards, not biology.
# Raise them only after GPU-resident agent mechanics is validated.
const SAFETY_POPULATION_LIMIT := 10000
# Technical guards are deliberately above the trophic capacities reachable at
# the current 10k bacterial CPU-reference ceiling. They must never define the
# ecological target population.
const PROTOZOAN_SAFETY_LIMIT := 48
const CILIATE_SAFETY_LIMIT := 64
const FLAGELLATE_SAFETY_LIMIT := 128
const MICROALGA_SAFETY_LIMIT := 64
const DECOMPOSER_SAFETY_LIMIT := 48
const HYPHAL_COLONY_SAFETY_LIMIT := 6
const HYPHAL_NODE_SAFETY_LIMIT := 24
const PHAGE_CLOUD_SAFETY_LIMIT := 24
const DNA_FRAGMENT_SAFETY_LIMIT := 64

# Persistent ecological refugia: inactive cyst/spore/seed-bank templates retain
# the best recent phenotype so a trophic guild can recover without resetting
# its evolutionary history.
const REFUGIA_BACTERIA_MIN := 1
const REFUGIA_PROTOZOA_MIN := 1
const REFUGIA_CILIATE_MIN := 1
const REFUGIA_FLAGELLATE_MIN := 1
const REFUGIA_MICROALGA_MIN := 1
const REFUGIA_DECOMPOSER_MIN := 1
const REFUGIA_HYPHA_MIN := 1
const REFUGIA_RECOVERY_INTERVAL := 10.0
const REFUGIA_WAKE_COOLDOWN := 180.0
const REFUGIA_BACTERIA_BANK_LIMIT := 8
const REFUGIA_GUILD_BANK_LIMIT := 6
const REFUGIA_BASAL_DIVERSITY_WAKE := 2

const DISTURBANCE_RESOURCE_PULSE := 0
const DISTURBANCE_WASHOUT := 1
const DISTURBANCE_ORGANIC_FALL := 2

var world_size := Vector2(
	FIELD_WIDTH * FIELD_CELL_SIZE,
	FIELD_HEIGHT * FIELD_CELL_SIZE
)

var fixed_seed: int
var rng := RandomNumberGenerator.new()
var bacteria_population_limit: int = SAFETY_POPULATION_LIMIT

var nutrient: Variant
var waste: Variant
var oxygen: Variant
var detritus: Variant
var eps: Variant
var damage_cue: Variant
var producer_biomass: Variant
var exudate: Variant
var quorum_signal: Variant
var fungal_enzyme: Variant
var bacteria: Array = []
var protozoa: Array = []
var ciliates: Array = []
var flagellates: Array = []
var microalgae: Array = []
var decomposers: Array = []
var hyphae: Array = []
var phage_clouds: Array = []
var dna_fragments: Array = []
var _population_buffer: Array = []
var nutrient_sources: Array[Vector2] = []
var producer_sources: Array[Vector2] = []

var simulation_time: float = 0.0
var _chemistry_accumulator: float = 0.0
var _slow_biome_accumulator: float = 0.0
var _mechanics_accumulator: float = 0.0
var _agent_accumulator: float = 0.0
var _next_id: int = 1
var _next_dna_id: int = 1
var _next_phage_id: int = 1
var _transformation_tick: int = 0
var _phage_tick: int = 0
var _grid_head: PackedInt32Array = PackedInt32Array()
var _grid_next: PackedInt32Array = PackedInt32Array()
var _max_half_body_length: float = 2.0
var _agent_tick: int = 0
var _current_agent_dt: float = AGENT_DT_SMALL
var _current_metabolic_stride: int = 1
var _current_memory_alpha: float = 0.0
var _current_rotational_sigma: float = 0.0
var _current_mechanics_dt: float = MECHANICS_DT
var _direction_lut: PackedVector2Array = PackedVector2Array()
var _drift_lut: PackedFloat32Array = PackedFloat32Array()
var mechanics_mode_last: int = 0
var _mech_positions: PackedVector2Array = PackedVector2Array()
var _mech_radii: PackedFloat32Array = PackedFloat32Array()
var _mech_active: PackedByteArray = PackedByteArray()
var _density_corrections: PackedVector2Array = PackedVector2Array()
var _density_nearest: PackedInt32Array = PackedInt32Array()
var _lineage_counts: PackedInt32Array = PackedInt32Array()
var _bacteria_by_id: Dictionary = {}
var _edible_by_id: Dictionary = {}
var _active_transfer_recipient_ids: PackedInt32Array = PackedInt32Array()
var _ecotype_counts: PackedInt32Array = PackedInt32Array()
var _refugia_bacteria: Array = []
var _refugia_bacteria_cursor: int = 0
var _refugia_guild_banks: Array = [[], [], [], [], [], []]
var _refugia_guild_cursors: PackedInt32Array = PackedInt32Array()
var _refugia_next_wake: PackedFloat32Array = PackedFloat32Array()
var _refugia_protozoan: Variant = null
var _refugia_ciliate: Variant = null
var _refugia_flagellate: Variant = null
var _refugia_microalga: Variant = null
var _refugia_decomposer: Variant = null
var _refugia_hypha: Variant = null
var _refugia_accumulator: float = 0.0
var refugia_recoveries_total: int = 0
var ecology_events: Dictionary = {}
var _flow_x_rows: PackedFloat32Array = PackedFloat32Array()
var _flow_y_cols: PackedFloat32Array = PackedFloat32Array()
var _flow_field_cache: PackedVector2Array = PackedVector2Array()
var _ambient_light_cache: PackedFloat32Array = PackedFloat32Array()
var _vertical_light_rows: PackedFloat32Array = PackedFloat32Array()
var _light_x_wave: PackedFloat32Array = PackedFloat32Array()
var _light_y_wave: PackedFloat32Array = PackedFloat32Array()
var disturbance_index: int = 0
var next_disturbance_time: float = 24.0
var last_disturbance_type: int = -1
var last_disturbance_position := Vector2.ZERO
var last_disturbance_time: float = -1.0

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
var producer_spread_diffusion: float = 0.025
var producer_growth_rate: float = 0.014
var producer_oxygen_rate: float = 0.018
var producer_leak_rate: float = 0.0035
var oxygen_half_saturation: float = 0.16
var oxygen_consumption_rate: float = 0.020
var detritus_scavenge_rate: float = 0.070
var detritus_energy_yield: float = 3.4
var eps_secretion_rate: float = 0.0045
var water_flow_strength: float = 0.42
var diel_cycle_seconds: float = 180.0
var night_light_floor: float = 0.12
var producer_self_shading_strength: float = 0.90

# Interaction fields: labile producer/decomposer metabolites and a bounded
# quorum-like signal. Both are qualitative ALife fields and run on the slow
# biome cadence to keep the CPU reference bounded.
var exudate_diffusion: float = 0.75
var exudate_decay: float = 0.065
var quorum_diffusion: float = 0.55
var quorum_decay: float = 0.18
var quorum_signal_rate: float = 0.012
var max_exudate_uptake_rate: float = 0.14
var exudate_half_saturation: float = 0.08
var exudate_energy_yield: float = 4.1
var eps_retention_bonus: float = 0.55
var eps_grazer_protection: float = 0.95

# Reversible dormancy. Trait values scale the entry threshold: lineages can
# trade rapid activity for persistence under starvation.
var dormancy_energy_threshold: float = 0.72
var dormancy_resource_threshold: float = 0.050
var dormancy_wake_threshold: float = 0.105
var dormancy_maintenance_factor: float = 0.11
var dormancy_uptake_factor: float = 0.16

# Natural transformation: bounded extracellular DNA released by lysis.
# Competence is a costly stress phenotype and remains separate from plasmid
# conjugation.
var competence_cost: float = 0.0045
var competence_capture_radius: float = 2.8
var transformation_uptake_rate: float = 1.4
var transformation_recombination_strength: float = 0.26
var dna_fragment_lifetime: float = 18.0

# Bacteriophage kill-the-winner loop. Virions are represented as bounded
# cloud packets rather than literal particles. Clouds amplify only when
# compatible hosts lyse, so abundant clonal lineages sustain stronger pressure.
var phage_cloud_decay: float = 0.045
var phage_cloud_diffusion: float = 0.34
var phage_cloud_max_radius: float = 10.5
var phage_specificity_width: float = 0.16
var phage_adsorption_rate: float = 0.42
var phage_latent_period: float = 4.8
var phage_infection_cost: float = 0.010
var phage_burst_strength: float = 0.92
var phage_eps_protection: float = 0.72

# Slow deterministic succession/disturbance cycle. These are local ecological
# events, not random screen effects: they directly alter resource/matrix fields
# and let dormancy, scavenging, producer recovery and grazing reshape the patch.
var disturbance_interval: float = 38.0
var disturbance_radius: float = 15.0

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
var mechanical_iterations: int = 1
var angular_contact_response: float = 0.055
var adhesion_range: float = 0.55
var adhesion_pull: float = 0.17
var adhesion_memory: float = 0.22

# Direct-contact plasmid conjugation.
var conjugation_contact_rate: float = 0.28
var conjugation_duration: float = 1.15
var conjugation_break_distance: float = 2.8
var conjugation_pull: float = 0.10
# Rare Hfr-like chromosomal module transfer: conjugation can occasionally add
# one ecological genome module in addition to plasmid cargo.
var conjugation_genome_recombination_rate: float = 0.16

# Amoeboid/protist ecology. This is intentionally a distinct organism class:
# bacteria do not magically fuse into blobs. The larger cell deforms, hunts,
# and visibly engulfs bacterial prey over time.
var protozoan_speed: float = 5.4
var protozoan_perception: float = 28.0
var protozoan_engulf_distance: float = 4.2
var protozoan_engulf_duration: float = 1.65
var protozoan_maintenance: float = 0.065
var protozoan_reproduction_energy: float = 18.5

# Fast ciliate-like grazer: a second predator guild that sweeps dense prey
# patches. Fewer, faster predators help regulate bacterial blooms without
# requiring hundreds of expensive predator agents.
var ciliate_speed: float = 10.5
var ciliate_perception: float = 34.0
var ciliate_feed_distance: float = 3.4
var ciliate_feed_duration: float = 1.05
var ciliate_maintenance: float = 0.090
var ciliate_reproduction_energy: float = 16.5

# Small flagellate-like bacterivore: an intermediate grazer tier that
# competes for bacterial prey and can itself be consumed by larger protists.
var flagellate_speed: float = 8.8
var flagellate_perception: float = 25.0
var flagellate_feed_distance: float = 2.4
var flagellate_feed_duration: float = 0.90
var flagellate_maintenance: float = 0.052
var flagellate_reproduction_energy: float = 8.8

# Explicit producer and decomposer guilds.
var microalga_photo_rate: float = 0.115
var microalga_nutrient_rate: float = 0.018
var microalga_maintenance: float = 0.020
var microalga_reproduction_energy: float = 5.6
var microalga_reproduction_duration: float = 0.95
var decomposer_detritus_rate: float = 0.105
var decomposer_energy_yield: float = 4.2
var decomposer_maintenance: float = 0.032
var decomposer_budding_energy: float = 5.2
var decomposer_budding_duration: float = 0.85

# True bounded hyphal decomposers. Colonies grow a small branching node graph
# toward detrital substrate and secrete a local extracellular enzyme field.
var fungal_enzyme_diffusion: float = 0.42
var fungal_enzyme_decay: float = 0.16
var fungal_enzyme_release_rate: float = 0.035
var fungal_polymer_conversion_rate: float = 0.22
var hypha_growth_interval: float = 0.65
var hypha_growth_step: float = 1.65
var hypha_tip_detritus_rate: float = 0.050
var hypha_maintenance_per_node: float = 0.0017
var hypha_sporulation_energy: float = 9.2


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
	exudate = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	quorum_signal = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	fungal_enzyme = ScalarFieldScript.new(FIELD_WIDTH, FIELD_HEIGHT, FIELD_CELL_SIZE, 0.0)
	_grid_head.resize(GRID_CELL_COUNT)
	_grid_head.fill(-1)
	_lineage_counts.resize(LINEAGE_BIN_COUNT)
	_lineage_counts.fill(0)
	_ecotype_counts.resize(ECOTYPE_PRESSURE_BIN_COUNT)
	_ecotype_counts.fill(0)
	_refugia_next_wake.resize(7)
	_refugia_next_wake.fill(0.0)
	_refugia_guild_cursors.resize(6)
	_refugia_guild_cursors.fill(0)
	_direction_lut.resize(DIRECTION_LUT_SIZE)
	for i in range(DIRECTION_LUT_SIZE):
		var lut_angle: float = (
			TAU * float(i) / float(DIRECTION_LUT_SIZE) - PI
		)
		_direction_lut[i] = Vector2(cos(lut_angle), sin(lut_angle))
	_drift_lut.resize(DRIFT_LUT_SIZE)
	for i in range(DRIFT_LUT_SIZE):
		_drift_lut[i] = sin(TAU * float(i) / float(DRIFT_LUT_SIZE))
	_flow_x_rows.resize(FIELD_HEIGHT)
	_flow_y_cols.resize(FIELD_WIDTH)
	_flow_field_cache.resize(FIELD_WIDTH * FIELD_HEIGHT)
	_ambient_light_cache.resize(FIELD_WIDTH * FIELD_HEIGHT)
	_vertical_light_rows.resize(FIELD_HEIGHT)
	_light_x_wave.resize(FIELD_WIDTH)
	_light_y_wave.resize(FIELD_HEIGHT)
	for y in range(FIELD_HEIGHT):
		var normalized_y: float = (
			(float(y) + 0.5) / float(FIELD_HEIGHT)
		)
		_vertical_light_rows[y] = lerpf(1.0, 0.38, normalized_y)
	_build_sources()
	_refresh_environment_caches()


func seed_demo(count: int = 36) -> void:
	bacteria.clear()
	protozoa.clear()
	ciliates.clear()
	flagellates.clear()
	microalgae.clear()
	decomposers.clear()
	hyphae.clear()
	phage_clouds.clear()
	dna_fragments.clear()
	_population_buffer.clear()
	_active_transfer_recipient_ids = PackedInt32Array()
	_ecotype_counts.fill(0)
	_refugia_bacteria.clear()
	_refugia_bacteria_cursor = 0
	for bank in _refugia_guild_banks:
		bank.clear()
	_refugia_guild_cursors.fill(0)
	_refugia_next_wake.fill(0.0)
	_refugia_protozoan = null
	_refugia_ciliate = null
	_refugia_flagellate = null
	_refugia_microalga = null
	_refugia_decomposer = null
	_refugia_hypha = null
	_refugia_accumulator = 0.0
	refugia_recoveries_total = 0
	_reset_ecology_events()
	simulation_time = 0.0
	_chemistry_accumulator = 0.0
	_slow_biome_accumulator = 0.0
	_mechanics_accumulator = 0.0
	_agent_accumulator = 0.0
	_agent_tick = 0
	disturbance_index = 0
	next_disturbance_time = 24.0
	last_disturbance_type = -1
	last_disturbance_position = Vector2.ZERO
	last_disturbance_time = -1.0
	_next_id = 1
	_next_dna_id = 1
	_next_phage_id = 1
	_transformation_tick = 0
	_phage_tick = 0
	rng.seed = fixed_seed
	nutrient.fill(0.012)
	waste.fill(0.0)
	oxygen.fill(0.42)
	detritus.fill(0.0)
	eps.fill(0.0)
	damage_cue.fill(0.0)
	producer_biomass.fill(0.0)
	exudate.fill(0.0)
	quorum_signal.fill(0.0)
	fungal_enzyme.fill(0.0)
	_prime_environment()
	_refresh_environment_caches()

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
		_apply_founder_niche(cell, 0, _i)
		cell.energy = rng.randf_range(2.6, 3.5)
		cell.length = minimum_length * float(cell.gene_size) * rng.randf_range(0.96, 1.08)
		cell.sensed_memory = nutrient.sample_world(position)
		bacteria.append(cell)

	# A few low-concentration phage packets start near bacterial founders.
	# They are host-lineage specific and only amplify through successful lysis.
	if not bacteria.is_empty():
		for phage_index in range(mini(3, bacteria.size())):
			var host: Variant = bacteria[(phage_index * 7) % bacteria.size()]
			var phase: float = (
				float(posmod(fixed_seed + phage_index * 97, 360)) * PI / 180.0
			)
			_spawn_phage_cloud(
				Vector2(host.position) + Vector2.RIGHT.rotated(phase) * 3.5,
				float(host.lineage_hue),
				0.34,
				5.2,
				0
			)

	# A few large amoeboid predators make the ecology observable immediately:
	# they chase nearby bacteria and engulf them with a staged deformation.
	for proto_index in range(3):
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
		_apply_founder_niche(proto, 1, proto_index)
		proto.lineage_hue = wrapf(0.48 + float(proto_index) * 0.055, 0.0, 1.0)
		protozoa.append(proto)

	# Faster ciliate-like grazers patrol dense bacterial patches and create a
	# second top-down pressure with a different movement/feeding strategy.
	for ciliate_index in range(2):
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
		_apply_founder_niche(ciliate, 2, ciliate_index)
		ciliates.append(ciliate)

	# Small flagellate bacterivores form an intermediate trophic tier. They
	# start near resource patches where bacterial prey are likely to be dense.
	for flagellate_index in range(6):
		var flag_source: Vector2 = nutrient_sources[
			(flagellate_index * 2 + 3) % nutrient_sources.size()
		]
		var flag_position: Vector2 = (
			flag_source
			+ Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
			* rng.randf_range(5.0, 13.0)
		)
		flag_position.x = clampf(flag_position.x, 6.0, world_size.x - 6.0)
		flag_position.y = clampf(flag_position.y, 6.0, world_size.y - 6.0)
		var flagellate: Variant = FlagellateScript.new(
			_allocate_id(),
			flag_position,
			rng.randf_range(-PI, PI),
			rng.randf_range(0.0, TAU)
		)
		flagellate.configure_founder(rng)
		_apply_founder_niche(flagellate, 3, flagellate_index)
		flagellate.energy = rng.randf_range(3.8, 4.8)
		flagellates.append(flagellate)

	# Two bounded filamentous decomposers start on particulate patches. Their
	# visible network only expands if local substrate can pay its growth cost.
	for hypha_index in range(3):
		var hypha_root: Vector2 = nutrient_sources[
			(hypha_index * 3 + 1) % nutrient_sources.size()
		]
		var colony: Variant = HyphalColonyScript.new(
			_allocate_id(),
			hypha_root,
			rng.randf_range(0.0, TAU)
		)
		colony.configure_founder(rng)
		_apply_founder_niche(colony, 6, hypha_index)
		colony.energy = rng.randf_range(4.4, 5.4)
		hyphae.append(colony)

	# Explicit producer cells complement the continuum producer mat. They are
	# slow drifting microalgae-like cells that oxygenate the local water and
	# can be grazed by protists.
	for algae_index in range(16):
		var source: Vector2 = producer_sources[algae_index % producer_sources.size()]
		var position: Vector2 = (
			source
			+ Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
			* rng.randf_range(2.0, 11.0)
		)
		position.x = clampf(position.x, 5.0, world_size.x - 5.0)
		position.y = clampf(position.y, 5.0, world_size.y - 5.0)
		var alga: Variant = MicroalgaScript.new(
			_allocate_id(),
			position,
			rng.randf_range(-PI, PI),
			rng.randf_range(0.0, TAU)
		)
		alga.configure_founder(rng)
		_apply_founder_niche(alga, 4, algae_index)
		alga.energy = rng.randf_range(2.8, 3.8)
		microalgae.append(alga)

	# Yeast-like decomposers start near nutrient/detrital hotspots. They are a
	# distinct trophic guild that consumes carrion and mineralizes part of it
	# back into dissolved resource.
	for yeast_index in range(10):
		var source: Vector2 = nutrient_sources[yeast_index % nutrient_sources.size()]
		var position: Vector2 = (
			source
			+ Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
			* rng.randf_range(3.0, 12.0)
		)
		position.x = clampf(position.x, 5.0, world_size.x - 5.0)
		position.y = clampf(position.y, 5.0, world_size.y - 5.0)
		var yeast: Variant = DecomposerYeastScript.new(
			_allocate_id(),
			position,
			rng.randf_range(-PI, PI),
			rng.randf_range(0.0, TAU)
		)
		yeast.configure_founder(rng)
		_apply_founder_niche(yeast, 5, yeast_index)
		yeast.energy = rng.randf_range(2.4, 3.2)
		decomposers.append(yeast)

	_refresh_refugia_memory()
	_refresh_population_metadata()
	_resolve_all_contacts()
	_rebuild_id_maps()


func step(dt: float) -> void:
	if dt <= 0.0:
		return

	var chemistry_start: int = Time.get_ticks_usec()
	var chemistry_dt: float = _chemistry_dt_for_population()
	_chemistry_accumulator += dt
	while _chemistry_accumulator >= chemistry_dt:
		_refresh_environment_caches()
		_feed_environment(chemistry_dt)
		nutrient.diffuse(nutrient_diffusion, chemistry_dt, nutrient_decay)
		waste.diffuse(waste_diffusion, chemistry_dt, waste_decay)
		oxygen.diffuse(oxygen_diffusion, chemistry_dt, oxygen_decay)
		damage_cue.diffuse(
			damage_cue_diffusion,
			chemistry_dt,
			damage_cue_decay
		)

		_slow_biome_accumulator += chemistry_dt
		while _slow_biome_accumulator >= SLOW_BIOME_DT:
			_advance_producer_mat(SLOW_BIOME_DT)
			detritus.diffuse(
				detritus_diffusion,
				SLOW_BIOME_DT,
				detritus_decay
			)
			eps.diffuse(eps_diffusion, SLOW_BIOME_DT, eps_decay)
			exudate.diffuse(exudate_diffusion, SLOW_BIOME_DT, exudate_decay)
			fungal_enzyme.diffuse(
				fungal_enzyme_diffusion,
				SLOW_BIOME_DT,
				fungal_enzyme_decay
			)
			_advance_fungal_decomposition(SLOW_BIOME_DT)
			_advance_hyphae(SLOW_BIOME_DT)
			quorum_signal.diffuse(
				quorum_diffusion,
				SLOW_BIOME_DT,
				quorum_decay
			)
			if not dna_fragments.is_empty() or not phage_clouds.is_empty():
				_rebuild_spatial_grid()
			_advance_dna_fragments(SLOW_BIOME_DT)
			_advance_phage_clouds(SLOW_BIOME_DT)
			producer_biomass.diffuse(
				producer_spread_diffusion,
				SLOW_BIOME_DT,
				producer_decay
			)
			_slow_biome_accumulator -= SLOW_BIOME_DT

		_chemistry_accumulator -= chemistry_dt
	chemistry_ms_last = float(Time.get_ticks_usec() - chemistry_start) / 1000.0

	agents_ms_last = 0.0
	mechanics_ms_last = 0.0
	_agent_accumulator += dt
	var target_agent_dt: float = _agent_dt_for_population()
	while _agent_accumulator >= target_agent_dt:
		var agent_dt: float = target_agent_dt
		_current_agent_dt = agent_dt
		_current_metabolic_stride = _metabolic_stride()
		_current_memory_alpha = (
			1.0 - exp(-agent_dt / maxf(0.001, chemotaxis_memory_tau))
		)
		_current_rotational_sigma = sqrt(
			2.0 * rotational_diffusion * agent_dt
		)
		_current_mechanics_dt = agent_dt
		_agent_tick += 1
		var agents_start: int = Time.get_ticks_usec()
		var pending_births: Array = _population_buffer
		pending_births.clear()
		var metadata_stride: int = _population_metadata_stride()
		if (
			metadata_stride <= 1
			or posmod(_agent_tick, metadata_stride) == 0
		):
			_refresh_population_metadata()
		# Use total packed population for the hard ceiling. This is conservative
		# while consumed/dying cells await compaction and cannot over-admit births.
		var available_bacterial_births: int = maxi(
			0,
			bacteria_population_limit - bacteria.size()
		)
		var bacteria_identity_changed: bool = false

		# Hot-path rule: do not rebuild/copy the population array on ordinary
		# ticks. Cells mutate in place; only completed death/division triggers
		# one stable compaction pass at the end of the tick.
		for cell in bacteria:
			cell.adhesion_timer = maxf(0.0, float(cell.adhesion_timer) - agent_dt)

			if bool(cell.consumed):
				bacteria_identity_changed = true
				continue

			if int(cell.engulfed_by_id) >= 0:
				continue

			if bool(cell.dying):
				_advance_lysis(cell, agent_dt)
				if float(cell.lysis_progress) >= 1.0:
					bacteria_identity_changed = true
					cell.alive = false
					_recycle_dead_cell(cell)
				continue

			var run_metabolism: bool = (
				_current_metabolic_stride <= 1
				or posmod(
					int(cell.id) + _agent_tick,
					_current_metabolic_stride
				) == 0
			)
			if run_metabolism:
				_advance_cell(cell, agent_dt)
			else:
				_advance_cell_motion_only(cell, agent_dt)

			if bool(cell.dying):
				continue

			if bool(cell.dividing):
				cell.division_progress = minf(
					1.0,
					float(cell.division_progress) + agent_dt / maxf(0.001, division_duration)
				)
				if float(cell.division_progress) >= 1.0:
					if available_bacterial_births > 0:
						pending_births.append_array(_divide(cell))
						available_bacterial_births -= 1
						bacteria_identity_changed = true
						cell.alive = false
					else:
						# Explicit performance guard: suppress further fission at
						# the CPU-reference ceiling without deleting live cells.
						cell.dividing = false
						cell.division_progress = 0.0
						cell.energy = minf(float(cell.energy), base_division_energy * 0.92)
				continue

			if _ready_to_begin_division(cell):
				cell.begin_division()

		if bacteria_identity_changed:
			_compact_bacteria_population(pending_births)
			_rebuild_bacteria_id_map()
		else:
			pending_births.clear()
		agents_ms_last = float(Time.get_ticks_usec() - agents_start) / 1000.0
	
		var mechanics_start: int = Time.get_ticks_usec()
		pair_candidates_last = 0
		pair_narrow_checks_last = 0
		pair_interactions_last = 0
		pair_contacts_last = 0
		var run_mechanics: bool = (
			bacteria.size() <= EXACT_MECHANICS_LIMIT
			or posmod(_agent_tick, 2) == 0
		)
		if run_mechanics:
			if bacteria.size() > EXACT_MECHANICS_LIMIT:
				_current_mechanics_dt = agent_dt * 2.0
			for _iteration in range(mechanical_iterations):
				_resolve_all_contacts()
		mechanics_ms_last = (
			float(Time.get_ticks_usec() - mechanics_start) / 1000.0
		)
		if bacteria_identity_changed and not run_mechanics:
			_rebuild_spatial_grid()
	
		_advance_gene_transfers(agent_dt)
		_advance_microalgae(agent_dt)
		_advance_decomposers(agent_dt)
		_advance_flagellates(agent_dt)
		_advance_protozoa(agent_dt)
		_advance_ciliates(agent_dt)
		_maintain_ecological_refugia(agent_dt)
	
		_rebuild_edible_id_map()
		_agent_accumulator -= target_agent_dt

	simulation_time += dt
	_advance_disturbance_schedule()


func _compact_bacteria_population(pending_births: Array) -> void:
	# Stable survivor compaction preserves relative order. New daughters are
	# appended after survivors; biological IDs remain stable and authoritative.
	var write_index: int = 0
	var original_count: int = bacteria.size()
	for read_index in range(original_count):
		var cell: Variant = bacteria[read_index]
		if (
			cell == null
			or bool(cell.consumed)
			or not bool(cell.alive)
		):
			continue
		if write_index != read_index:
			bacteria[write_index] = cell
		write_index += 1

	if write_index < original_count:
		bacteria.resize(write_index)
	if not pending_births.is_empty():
		bacteria.append_array(pending_births)
		pending_births.clear()


func _chemistry_dt_for_population() -> float:
	var count: int = bacteria.size()
	if count >= AGENT_ULTRA_THRESHOLD:
		return CHEMISTRY_DT_ULTRA
	if count >= AGENT_MASS_THRESHOLD:
		return CHEMISTRY_DT_MASS
	if count >= AGENT_MEDIUM_THRESHOLD:
		return CHEMISTRY_DT_MEDIUM
	return CHEMISTRY_DT_SMALL


func _agent_dt_for_population() -> float:
	var count: int = bacteria.size()
	if count >= AGENT_ULTRA_THRESHOLD:
		return AGENT_DT_ULTRA
	if count >= AGENT_MASS_THRESHOLD:
		return AGENT_DT_MASS
	if count >= AGENT_MEDIUM_THRESHOLD:
		return AGENT_DT_MEDIUM
	return AGENT_DT_SMALL


func _metabolic_stride() -> int:
	var count: int = bacteria.size()
	if count >= AGENT_ULTRA_THRESHOLD:
		return 5
	if count >= AGENT_MASS_THRESHOLD:
		return 3
	if count >= AGENT_MEDIUM_THRESHOLD:
		return 2
	return 1


func _should_run_metabolism(cell_id: int) -> bool:
	return (
		_current_metabolic_stride <= 1
		or posmod(cell_id + _agent_tick, _current_metabolic_stride) == 0
	)


func _advance_cell_motion_only(cell: Variant, dt: float) -> void:
	cell.age = float(cell.age) + dt
	if bool(cell.dormant):
		cell.dormant_time = float(cell.dormant_time) + dt
		return
	if bool(cell.phage_infected):
		cell.phage_progress = minf(
			1.0,
			float(cell.phage_progress)
			+ dt / maxf(0.001, phage_latent_period)
		)
		cell.energy = maxf(
			0.0,
			float(cell.energy) - phage_infection_cost * dt
		)
		if float(cell.phage_progress) >= 1.0:
			cell.phage_triggered_lysis = true
			cell.begin_lysis()
			return

	var cell_position: Vector2 = Vector2(cell.position)
	var field_index: int = _field_index_for_world(cell_position)
	var local_eps: float = float(eps.values[field_index])
	var energy_speed_factor: float = clampf(
		float(cell.energy) / 1.6,
		0.18,
		1.0
	)
	var division_mobility: float = 0.16 if bool(cell.dividing) else 1.0
	var speed: float = (
		run_speed
		* float(cell.motion_speed_base)
		* energy_speed_factor
		* division_mobility
	)
	if float(cell.expression_matrix) > 0.08:
		var local_quorum: float = float(quorum_signal.values[field_index])
		speed *= lerpf(
			1.0,
			0.56,
			clampf(local_quorum * 8.0, 0.0, 1.0)
			* clampf(float(cell.expression_matrix), 0.0, 1.0)
		)

	var drift_phase: int = posmod(
		(int(cell.id) * 17 + _agent_tick * 11) * DRIFT_LUT_PHASE_STEP,
		DRIFT_LUT_SIZE
	)
	var drift_turn: float = float(_drift_lut[drift_phase]) * 0.16 * dt
	cell.angle = wrapf(float(cell.angle) + drift_turn, -PI, PI)
	var heading: Vector2 = _direction_for_angle(float(cell.angle))
	var eps_drag: float = 1.0 / (1.0 + local_eps * 0.85)
	cell.position = (
		cell_position
		+ heading * speed * eps_drag * dt
		+ _water_flow_for_field_index(field_index) * dt * eps_drag
	)
	_constrain_to_world(cell)


func _direction_for_angle(angle: float) -> Vector2:
	var normalized: float = wrapf(angle + PI, 0.0, TAU) / TAU
	var index: int = posmod(
		floori(normalized * float(DIRECTION_LUT_SIZE)),
		DIRECTION_LUT_SIZE
	)
	return _direction_lut[index]


func _advance_microalgae(dt: float) -> void:
	var next_microalgae: Array = []
	var available_births: int = maxi(
		0,
		MICROALGA_SAFETY_LIMIT - microalgae.size()
	)

	for alga in microalgae:
		if bool(alga.consumed):
			continue

		if int(alga.engulfed_by_id) >= 0:
			next_microalgae.append(alga)
			continue

		if bool(alga.dying):
			_advance_small_lysis(alga, dt, 0.72)
			if float(alga.lysis_progress) >= 1.0:
				_recycle_small_body(
					Vector2(alga.position),
					float(alga.radius),
					0.72,
					true
				)
			else:
				next_microalgae.append(alga)
			continue

		alga.age = float(alga.age) + dt
		alga.cooldown = maxf(0.0, float(alga.cooldown) - dt)
		alga.visual_phase = wrapf(
			float(alga.visual_phase) + dt * (1.2 + 0.2 * float(alga.gene_drift)),
			0.0,
			TAU
		)

		var position: Vector2 = Vector2(alga.position)
		var light_value: float = _sample_light(position)
		var photo_gain: float = (
			microalga_photo_rate
			* light_value
			* float(alga.gene_light_use)
			* dt
		)
		var nutrient_taken: float = float(
			nutrient.take_nearest_world(
				position,
				microalga_nutrient_rate * float(alga.gene_growth) * dt
			)
		)
		var nutrient_gain: float = nutrient_taken * 1.8
		var maintenance: float = (
			microalga_maintenance
			* (0.75 + 0.25 * float(alga.gene_size))
			* dt
		)

		alga.energy = (
			float(alga.energy)
			+ photo_gain
			+ nutrient_gain
			- maintenance
		)

		oxygen.add_nearest_world(
			position,
			photo_gain * 0.42
		)
		nutrient.add_nearest_world(
			position,
			photo_gain * float(alga.gene_exudate) * 0.018
		)
		exudate.add_radial_world(
			position,
			2.6 + float(alga.radius),
			photo_gain * float(alga.gene_exudate) * 0.24
		)
		producer_biomass.add_nearest_world(
			position,
			photo_gain * 0.010
		)

		var upward_bias := Vector2(0.0, -0.08 * light_value)
		alga.position = (
			position
			+ _water_flow(position) * float(alga.gene_drift) * dt * 0.52
			+ upward_bias * dt
		)
		alga.angle = wrapf(
			float(alga.angle) + sin(float(alga.visual_phase)) * 0.12 * dt,
			-PI,
			PI
		)
		_constrain_small_organism(alga)

		if float(alga.energy) <= 0.0:
			alga.energy = 0.0
			alga.begin_lysis()
			next_microalgae.append(alga)
			continue

		if bool(alga.reproducing):
			alga.reproduction_progress = minf(
				1.0,
				float(alga.reproduction_progress)
				+ dt / maxf(0.001, microalga_reproduction_duration)
			)
			if float(alga.reproduction_progress) >= 1.0:
				if available_births > 0:
					next_microalgae.append_array(_divide_microalga(alga))
					available_births -= 1
				else:
					alga.reproducing = false
					alga.reproduction_progress = 0.0
					next_microalgae.append(alga)
			else:
				next_microalgae.append(alga)
			continue

		if (
			available_births > 0
			and float(alga.energy) >= microalga_reproduction_energy
			and float(alga.age) >= 7.0
			and float(alga.cooldown) <= 0.0
		):
			alga.begin_reproduction()

		next_microalgae.append(alga)

	microalgae = next_microalgae


func _divide_microalga(parent: Variant) -> Array:
	_event_inc("repro_algae")
	var axis: Vector2 = Vector2.RIGHT.rotated(float(parent.angle))
	var offset: Vector2 = axis * float(parent.radius) * 0.72
	var daughter_energy: float = float(parent.energy) * 0.46

	var a: Variant = MicroalgaScript.new(
		_allocate_id(),
		Vector2(parent.position) - offset,
		float(parent.angle) + rng.randfn(0.0, 0.20),
		rng.randf_range(0.0, TAU)
	)
	var b: Variant = MicroalgaScript.new(
		_allocate_id(),
		Vector2(parent.position) + offset,
		float(parent.angle) + PI + rng.randfn(0.0, 0.20),
		rng.randf_range(0.0, TAU)
	)

	for daughter in [a, b]:
		daughter.inherit_and_mutate(parent, rng)
		daughter.energy = daughter_energy
		daughter.cooldown = 1.5
		_constrain_small_organism(daughter)

	return [a, b]


func _advance_decomposers(dt: float) -> void:
	var next_decomposers: Array = []
	var available_births: int = maxi(
		0,
		DECOMPOSER_SAFETY_LIMIT - decomposers.size()
	)

	for yeast in decomposers:
		if bool(yeast.consumed):
			continue

		if int(yeast.engulfed_by_id) >= 0:
			next_decomposers.append(yeast)
			continue

		if bool(yeast.dying):
			_advance_small_lysis(yeast, dt, 0.82)
			if float(yeast.lysis_progress) >= 1.0:
				_recycle_small_body(
					Vector2(yeast.position),
					float(yeast.radius),
					0.82,
					false
				)
			else:
				next_decomposers.append(yeast)
			continue

		yeast.age = float(yeast.age) + dt
		yeast.cooldown = maxf(0.0, float(yeast.cooldown) - dt)
		yeast.visual_phase = wrapf(
			float(yeast.visual_phase) + dt * 1.7,
			0.0,
			TAU
		)

		var position: Vector2 = Vector2(yeast.position)
		var consumed_detritus: float = float(
			detritus.take_nearest_world(
				position,
				decomposer_detritus_rate
				* float(yeast.gene_detritus)
				* dt
			)
		)
		var energy_gain: float = (
			consumed_detritus
			* decomposer_energy_yield
			* float(yeast.gene_growth)
		)
		var maintenance: float = (
			decomposer_maintenance
			* float(yeast.gene_metabolism)
			* (0.78 + 0.22 * float(yeast.gene_size))
			* dt
		)
		yeast.energy = float(yeast.energy) + energy_gain - maintenance

		if consumed_detritus > 0.0:
			exudate.add_radial_world(
				position,
				2.4 + float(yeast.radius),
				consumed_detritus
				* 0.18
				* float(yeast.gene_mineralize)
			)
			nutrient.add_nearest_world(
				position,
				consumed_detritus
				* 0.24
				* float(yeast.gene_mineralize)
			)
			waste.add_nearest_world(position, consumed_detritus * 0.055)
			oxygen.take_nearest_world(position, consumed_detritus * 0.035)

		var cue_gradient: Vector2 = Vector2(detritus.gradient_world(position))
		var drift_bias := Vector2.ZERO
		if cue_gradient.length_squared() > 0.000001:
			drift_bias = cue_gradient.normalized() * 0.16
		yeast.position = (
			position
			+ _water_flow(position) * dt * 0.34
			+ drift_bias * dt
		)
		yeast.angle = wrapf(
			float(yeast.angle) + sin(float(yeast.visual_phase)) * 0.08 * dt,
			-PI,
			PI
		)
		_constrain_small_organism(yeast)

		if float(yeast.energy) <= 0.0:
			yeast.energy = 0.0
			yeast.begin_lysis()
			next_decomposers.append(yeast)
			continue

		if bool(yeast.budding):
			yeast.budding_progress = minf(
				1.0,
				float(yeast.budding_progress)
				+ dt / maxf(0.001, decomposer_budding_duration)
			)
			if float(yeast.budding_progress) >= 1.0:
				if available_births > 0:
					next_decomposers.append_array(_bud_decomposer(yeast))
					available_births -= 1
				else:
					yeast.budding = false
					yeast.budding_progress = 0.0
					next_decomposers.append(yeast)
			else:
				next_decomposers.append(yeast)
			continue

		if (
			available_births > 0
			and float(yeast.energy) >= decomposer_budding_energy
			and float(yeast.age) >= 6.0
			and float(yeast.cooldown) <= 0.0
		):
			yeast.begin_budding()

		next_decomposers.append(yeast)

	decomposers = next_decomposers


func _bud_decomposer(parent: Variant) -> Array:
	_event_inc("repro_decomposers")
	var old_energy: float = float(parent.energy)
	var axis: Vector2 = Vector2.RIGHT.rotated(
		float(parent.angle) + rng.randf_range(-0.7, 0.7)
	)
	var offset: Vector2 = axis * float(parent.radius) * 1.25
	var daughter: Variant = DecomposerYeastScript.new(
		_allocate_id(),
		Vector2(parent.position) + offset,
		float(parent.angle) + rng.randfn(0.0, 0.35),
		rng.randf_range(0.0, TAU)
	)
	daughter.inherit_and_mutate(parent, rng)
	daughter.energy = old_energy * 0.34
	daughter.cooldown = 1.4

	parent.energy = old_energy * 0.56
	parent.budding = false
	parent.budding_progress = 0.0
	parent.cooldown = 1.2
	_constrain_small_organism(parent)
	_constrain_small_organism(daughter)

	return [parent, daughter]


func _advance_small_lysis(
	organism: Variant,
	dt: float,
	speed_scale: float
) -> void:
	organism.lysis_progress = minf(
		1.0,
		float(organism.lysis_progress) + dt / 1.35
	)
	organism.position = (
		Vector2(organism.position)
		+ _water_flow(Vector2(organism.position)) * dt * 0.28 * speed_scale
	)
	damage_cue.add_radial_world(
		Vector2(organism.position),
		3.2 + float(organism.radius),
		0.009 * dt * (1.0 + float(organism.lysis_progress))
	)


func _recycle_small_body(
	position: Vector2,
	radius: float,
	scale: float,
	is_producer: bool
) -> void:
	var biomass: float = maxf(0.035, radius * 0.032 * scale)
	detritus.add_radial_world(position, 3.0 + radius, biomass)
	damage_cue.add_radial_world(position, 3.8 + radius, biomass * 0.50)
	if is_producer:
		nutrient.add_radial_world(position, 2.8 + radius, biomass * 0.12)


func _constrain_small_organism(organism: Variant) -> void:
	var margin: float = float(organism.radius) + 0.7
	var position: Vector2 = Vector2(organism.position)
	position.x = clampf(position.x, margin, world_size.x - margin)
	position.y = clampf(position.y, margin, world_size.y - margin)
	organism.position = position


func _advance_hyphae(dt: float) -> void:
	var next_hyphae: Array = []
	var available_colonies: int = maxi(
		0,
		HYPHAL_COLONY_SAFETY_LIMIT - hyphae.size()
	)

	for colony in hyphae:
		if bool(colony.dying):
			colony.lysis_progress = minf(
				1.0,
				float(colony.lysis_progress) + dt / 2.4
			)
			if float(colony.lysis_progress) >= 1.0:
				for node in colony.nodes:
					detritus.add_radial_world(Vector2(node), 2.2, 0.020)
					damage_cue.add_radial_world(Vector2(node), 2.6, 0.010)
			else:
				next_hyphae.append(colony)
			continue

		colony.age = float(colony.age) + dt
		colony.cooldown = maxf(0.0, float(colony.cooldown) - dt)
		colony.visual_phase = wrapf(float(colony.visual_phase) + dt * 0.45, 0.0, TAU)
		colony.growth_accumulator = float(colony.growth_accumulator) + dt

		var total_consumed: float = 0.0
		for tip_index in colony.tips:
			if int(tip_index) < 0 or int(tip_index) >= colony.nodes.size():
				continue
			var tip_position: Vector2 = colony.nodes[int(tip_index)]
			fungal_enzyme.add_radial_world(
				tip_position,
				2.8,
				fungal_enzyme_release_rate
				* float(colony.gene_enzyme)
				* dt
			)
			total_consumed += float(
				detritus.take_nearest_world(
					tip_position,
					hypha_tip_detritus_rate
					* float(colony.gene_efficiency)
					* dt
				)
			)

		if total_consumed > 0.0:
			colony.energy = (
				float(colony.energy)
				+ total_consumed * 4.5 * float(colony.gene_efficiency)
			)
			exudate.add_radial_world(
				Vector2(colony.position),
				4.0,
				total_consumed * 0.12
			)

		colony.energy = (
			float(colony.energy)
			- hypha_maintenance_per_node
			* float(colony.nodes.size())
			* dt
		)

		if float(colony.energy) <= 0.0:
			colony.energy = 0.0
			colony.begin_lysis()
			next_hyphae.append(colony)
			continue

		if (
			float(colony.growth_accumulator)
			>= hypha_growth_interval / maxf(0.55, float(colony.gene_growth))
			and colony.nodes.size() < HYPHAL_NODE_SAFETY_LIMIT
			and float(colony.energy) > 0.75
		):
			colony.growth_accumulator = 0.0
			_grow_hyphal_colony(colony)

		if (
			available_colonies > 0
			and colony.nodes.size() >= 12
			and float(colony.energy) >= hypha_sporulation_energy
			and float(colony.age) >= 24.0
			and float(colony.cooldown) <= 0.0
		):
			var daughter: Variant = _sporulate_hypha(colony)
			if daughter != null:
				next_hyphae.append(daughter)
				available_colonies -= 1

		next_hyphae.append(colony)

	hyphae = next_hyphae


func _grow_hyphal_colony(colony: Variant) -> void:
	if colony.tips.is_empty():
		return

	var best_tip_index: int = int(colony.tips[0])
	var best_signal: float = -INF
	for tip_index in colony.tips:
		var tip_position: Vector2 = colony.nodes[int(tip_index)]
		var substrate_signal: float = float(detritus.sample_world(tip_position))
		if substrate_signal > best_signal:
			best_signal = substrate_signal
			best_tip_index = int(tip_index)

	var origin: Vector2 = colony.nodes[best_tip_index]
	var gradient: Vector2 = Vector2(detritus.gradient_world(origin))
	var direction: Vector2
	if gradient.length_squared() > 0.000001:
		direction = gradient.normalized()
	else:
		var phase: float = (
			float(colony.id) * 0.73
			+ float(colony.nodes.size()) * 2.17
			+ float(colony.generation) * 0.41
		)
		direction = Vector2(cos(phase), sin(phase))

	var jitter_phase: float = (
		float(colony.id + colony.nodes.size() * 19) * 0.31
	)
	direction = direction.rotated(sin(jitter_phase) * 0.34)
	var step: float = hypha_growth_step * (0.86 + 0.14 * float(colony.gene_growth))
	var new_position: Vector2 = origin + direction * step
	new_position.x = clampf(new_position.x, 1.0, world_size.x - 1.0)
	new_position.y = clampf(new_position.y, 1.0, world_size.y - 1.0)
	var new_index: int = colony.add_node(best_tip_index, new_position)
	if new_index < 0:
		return

	colony.energy = maxf(0.0, float(colony.energy) - 0.075 * step)
	fungal_enzyme.add_radial_world(new_position, 2.6, 0.018 * float(colony.gene_enzyme))

	# Branching is deterministic from colony/node identity and only occurs when
	# energy/substrate support it; this is a resource rule, not a cosmetic fork.
	var branch_gate: float = (
		0.17
		* float(colony.gene_branch)
		* clampf(best_signal * 4.0 + float(colony.energy) / 8.0, 0.0, 1.0)
	)
	var branch_roll: float = _stable_event_roll(
		int(colony.id),
		colony.nodes.size() * 37,
		floori(simulation_time * 10.0)
	)
	if (
		branch_roll < branch_gate
		and colony.nodes.size() < HYPHAL_NODE_SAFETY_LIMIT
		and float(colony.energy) > 1.2
	):
		var branch_direction: Vector2 = direction.rotated(
			(0.72 if branch_roll < branch_gate * 0.5 else -0.72)
		)
		var branch_position: Vector2 = origin + branch_direction * step * 0.92
		branch_position.x = clampf(branch_position.x, 1.0, world_size.x - 1.0)
		branch_position.y = clampf(branch_position.y, 1.0, world_size.y - 1.0)
		colony.add_branch(best_tip_index, branch_position)
		colony.energy = maxf(0.0, float(colony.energy) - 0.065 * step)


func _advance_fungal_decomposition(dt: float) -> void:
	for i in range(detritus.values.size()):
		var substrate: float = float(detritus.values[i])
		var enzyme_value: float = float(fungal_enzyme.values[i])
		if substrate <= 0.000001 or enzyme_value <= 0.000001:
			continue
		var converted: float = minf(
			substrate,
			fungal_polymer_conversion_rate
			* substrate
			* clampf(enzyme_value, 0.0, 1.5)
			* dt
		)
		if converted <= 0.0:
			continue
		detritus.values[i] = maxf(0.0, substrate - converted)
		nutrient.values[i] = maxf(0.0, float(nutrient.values[i]) + converted * 0.34)
		exudate.values[i] = maxf(0.0, float(exudate.values[i]) + converted * 0.22)


func _sporulate_hypha(parent: Variant) -> Variant:
	_event_inc("repro_hyphae")
	if parent.tips.is_empty():
		return null
	var tip_index: int = int(parent.tips[posmod(parent.id + parent.generation, parent.tips.size())])
	var root: Vector2 = parent.nodes[tip_index]
	var phase: float = float(parent.id * 17 + parent.generation * 31) * 0.21
	root += Vector2(cos(phase), sin(phase)) * 4.5
	root.x = clampf(root.x, 2.0, world_size.x - 2.0)
	root.y = clampf(root.y, 2.0, world_size.y - 2.0)
	var daughter: Variant = HyphalColonyScript.new(
		_allocate_id(),
		root,
		wrapf(float(parent.visual_phase) + 1.7, 0.0, TAU)
	)
	daughter.inherit_and_mutate(parent, rng)
	daughter.energy = float(parent.energy) * 0.28
	parent.energy = float(parent.energy) * 0.62
	parent.cooldown = 8.0
	return daughter


func _flagellate_carrying_capacity() -> int:
	# Pure ecological target. The CPU guard is applied only when births are
	# admitted, never while estimating carrying capacity.
	return maxi(2, 2 + floori(float(bacteria.size()) / 110.0))


func _ciliate_carrying_capacity() -> int:
	var prey_units: float = (
		float(bacteria.size())
		+ float(flagellates.size()) * 18.0
		+ float(microalgae.size()) * 12.0
		+ float(decomposers.size()) * 10.0
	)
	return maxi(1, 1 + floori(prey_units / 240.0))


func _protozoan_carrying_capacity() -> int:
	var prey_units: float = (
		float(bacteria.size())
		+ float(flagellates.size()) * 18.0
		+ float(ciliates.size()) * 24.0
		+ float(microalgae.size()) * 14.0
		+ float(decomposers.size()) * 12.0
	)
	return maxi(1, 1 + floori(prey_units / 360.0))


func _crowding_maintenance_multiplier(current: int, capacity: int) -> float:
	if current <= capacity:
		return 1.0
	return 1.0 + clampf(
		float(current - capacity) / float(maxi(1, capacity)) * 0.55,
		0.0,
		2.0
	)


func _advance_flagellates(dt: float) -> void:
	var next_flagellates: Array = []
	var trophic_capacity: int = _flagellate_carrying_capacity()
	var available_births: int = maxi(
		0,
		mini(FLAGELLATE_SAFETY_LIMIT, trophic_capacity) - flagellates.size()
	)
	var crowding_multiplier: float = _crowding_maintenance_multiplier(
		flagellates.size(),
		trophic_capacity
	)

	for flagellate in flagellates:
		if bool(flagellate.consumed):
			continue

		if int(flagellate.engulfed_by_id) >= 0:
			next_flagellates.append(flagellate)
			continue

		if bool(flagellate.dying):
			_advance_predator_lysis(flagellate, dt)
			if float(flagellate.lysis_progress) >= 1.0:
				_recycle_predator_body(
					Vector2(flagellate.position),
					float(flagellate.radius),
					0.48
				)
			else:
				next_flagellates.append(flagellate)
			continue

		flagellate.age = float(flagellate.age) + dt
		flagellate.cooldown = maxf(0.0, float(flagellate.cooldown) - dt)
		flagellate.swim_phase = wrapf(
			float(flagellate.swim_phase) + dt * (7.2 + float(flagellate.gene_speed)),
			0.0,
			TAU
		)

		var maintenance: float = (
			flagellate_maintenance
			* float(flagellate.gene_metabolism)
			* (0.82 + 0.18 * float(flagellate.gene_size))
			* crowding_multiplier
		)
		flagellate.energy = float(flagellate.energy) - maintenance * dt

		if float(flagellate.energy) <= 0.0:
			_release_predator_prey(
				int(flagellate.feeding_target_id),
				int(flagellate.id)
			)
			flagellate.finish_feed()
			flagellate.begin_lysis()
			next_flagellates.append(flagellate)
			continue

		if int(flagellate.feeding_target_id) >= 0:
			_advance_flagellate_feed(flagellate, dt)
			next_flagellates.append(flagellate)
			continue

		var prey: Variant = _find_flagellate_prey(flagellate)
		var desired_angle: float = float(flagellate.angle)

		if prey != null:
			var to_prey: Vector2 = Vector2(prey.position) - Vector2(flagellate.position)
			if to_prey.length_squared() > 0.000001:
				desired_angle = to_prey.angle()
			if (
				float(flagellate.cooldown) <= 0.0
				and to_prey.length() <= flagellate_feed_distance
			):
				flagellate.begin_feed(int(prey.id))
				prey.engulfed_by_id = int(flagellate.id)
				prey.engulf_progress = 0.0
				next_flagellates.append(flagellate)
				continue
		else:
			# Flagellates do not eat the exudate directly; following its gradient
			# keeps them near producer phycospheres where bacterial prey accumulate.
			var exudate_gradient: Vector2 = Vector2(
				exudate.gradient_world(Vector2(flagellate.position))
			)
			if exudate_gradient.length_squared() > 0.000001:
				desired_angle = lerp_angle(
					desired_angle,
					exudate_gradient.angle(),
					0.36
				)
			else:
				desired_angle += sin(
					simulation_time * 1.35 + float(flagellate.swim_phase)
				) * 0.34

		flagellate.angle = lerp_angle(
			float(flagellate.angle),
			desired_angle,
			clampf(dt * 4.0, 0.0, 1.0)
		)
		var stroke: float = 0.86 + 0.14 * sin(float(flagellate.swim_phase))
		var starvation: float = clampf(float(flagellate.energy) / 1.4, 0.28, 1.0)
		var speed: float = (
			flagellate_speed
			* float(flagellate.gene_speed)
			* stroke
			* starvation
		)
		flagellate.position = (
			Vector2(flagellate.position)
			+ Vector2.RIGHT.rotated(float(flagellate.angle)) * speed * dt
			+ _water_flow(Vector2(flagellate.position)) * dt * 0.72
		)
		_constrain_flagellate(flagellate)

		if (
			available_births > 0
			and float(flagellate.energy) >= flagellate_reproduction_energy
			and float(flagellate.age) >= 8.0
			and float(flagellate.cooldown) <= 0.0
		):
			next_flagellates.append_array(_divide_flagellate(flagellate))
			available_births -= 1
		else:
			next_flagellates.append(flagellate)

	flagellates = next_flagellates


func _find_flagellate_prey(flagellate: Variant) -> Variant:
	var perception: float = (
		flagellate_perception * float(flagellate.gene_perception)
	)
	return _nearest_bacterium_spatial(
		Vector2(flagellate.position),
		perception
	)


func _advance_flagellate_feed(flagellate: Variant, dt: float) -> void:
	var prey: Variant = find_cell_by_id(int(flagellate.feeding_target_id))
	if prey == null or bool(prey.consumed) or bool(prey.dying):
		if prey != null:
			prey.engulfed_by_id = -1
			prey.engulf_progress = 0.0
		flagellate.finish_feed()
		return

	var defense_factor: float = _prey_handling_defense(prey)
	var duration: float = (
		flagellate_feed_duration
		* defense_factor
		/ maxf(0.45, float(flagellate.gene_capture))
	)
	var progress: float = minf(
		1.0,
		float(flagellate.feeding_progress) + dt / maxf(0.001, duration)
	)
	flagellate.feeding_progress = progress
	prey.engulf_progress = progress

	if _prey_escapes_handling(
		prey,
		float(flagellate.gene_capture),
		defense_factor,
		dt
	):
		_event_inc("escape_flagellate")
		prey.engulfed_by_id = -1
		prey.engulf_progress = 0.0
		var escape_axis: Vector2 = (
			Vector2(prey.position) - Vector2(flagellate.position)
		).normalized()
		if escape_axis.length_squared() <= 0.000001:
			escape_axis = Vector2.RIGHT.rotated(float(prey.angle))
		prey.position = Vector2(prey.position) + escape_axis * 0.70
		flagellate.finish_feed()
		return

	damage_cue.add_radial_world(
		Vector2(prey.position),
		2.4,
		0.005 * dt * (1.0 + progress * 2.0)
	)
	var mouth: Vector2 = (
		Vector2(flagellate.position)
		+ Vector2.RIGHT.rotated(float(flagellate.angle))
		* float(flagellate.radius) * 0.72
	)
	prey.position = Vector2(prey.position).lerp(
		mouth,
		clampf(dt * (4.0 + progress * 6.0), 0.0, 1.0)
	)

	if progress >= 1.0:
		_record_predation("flagellate", prey)
		prey.consumed = true
		prey.alive = false
		prey.engulfed_by_id = -1
		detritus.add_radial_world(
			Vector2(prey.position),
			1.8,
			0.010 + float(prey.biomass_size()) * 0.0035
		)
		damage_cue.add_radial_world(Vector2(prey.position), 3.0, 0.022)
		flagellate.energy = minf(
			11.0,
			float(flagellate.energy) + 0.62 + float(prey.biomass_size()) * 0.10
		)
		flagellate.finish_feed()


func _divide_flagellate(parent: Variant) -> Array:
	_event_inc("repro_flagellates")
	var axis: Vector2 = Vector2.RIGHT.rotated(float(parent.angle))
	var offset: Vector2 = axis.orthogonal() * float(parent.radius) * 0.72
	var daughter_energy: float = float(parent.energy) * 0.44
	var a: Variant = FlagellateScript.new(
		_allocate_id(),
		Vector2(parent.position) - offset,
		float(parent.angle) + rng.randfn(0.0, 0.16),
		rng.randf_range(0.0, TAU)
	)
	var b: Variant = FlagellateScript.new(
		_allocate_id(),
		Vector2(parent.position) + offset,
		float(parent.angle) + PI + rng.randfn(0.0, 0.16),
		rng.randf_range(0.0, TAU)
	)
	for daughter in [a, b]:
		daughter.inherit_and_mutate(parent, rng)
		daughter.energy = daughter_energy
		daughter.cooldown = 1.8
		_constrain_flagellate(daughter)
	return [a, b]


func _constrain_flagellate(flagellate: Variant) -> void:
	var margin: float = float(flagellate.radius) + 0.7
	var position: Vector2 = Vector2(flagellate.position)
	var angle: float = float(flagellate.angle)
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
	flagellate.position = position
	flagellate.angle = wrapf(angle, -PI, PI)


func _advance_protozoa(dt: float) -> void:
	var next_protozoa: Array = []
	var trophic_capacity: int = _protozoan_carrying_capacity()
	var available_births: int = maxi(
		0,
		mini(PROTOZOAN_SAFETY_LIMIT, trophic_capacity) - protozoa.size()
	)
	var crowding_multiplier: float = _crowding_maintenance_multiplier(
		protozoa.size(),
		trophic_capacity
	)

	for proto in protozoa:
		if bool(proto.dying):
			_advance_predator_lysis(proto, dt)
			if float(proto.lysis_progress) >= 1.0:
				_recycle_predator_body(
					Vector2(proto.position),
					float(proto.radius),
					1.0
				)
			else:
				next_protozoa.append(proto)
			continue

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
			* crowding_multiplier
		)
		proto.energy = float(proto.energy) - maintenance * dt

		if float(proto.energy) <= 0.0:
			_release_predator_prey(int(proto.feeding_target_id), int(proto.id))
			proto.finish_engulf()
			proto.begin_lysis()
			next_protozoa.append(proto)
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
				if prey.has_method("finish_feed"):
					_release_predator_prey(
						int(prey.feeding_target_id),
						int(prey.id)
					)
					prey.finish_feed()
				proto.begin_engulf(int(prey.id))
				prey.engulfed_by_id = int(proto.id)
				prey.engulf_progress = 0.0
				next_protozoa.append(proto)
				continue
		else:
			var cue_direction: Vector2 = _damage_cue_direction(
				Vector2(proto.position)
			)
			if cue_direction.length_squared() > 0.0:
				desired_angle = lerp_angle(
					desired_angle,
					cue_direction.angle(),
					0.58
				)
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
		var starvation_factor: float = clampf(
			float(proto.energy) / 2.2,
			0.24,
			1.0
		)
		var speed: float = (
			protozoan_speed
			* float(proto.gene_speed)
			* pulse
			* starvation_factor
		)
		proto.position = (
			Vector2(proto.position)
			+ Vector2.RIGHT.rotated(float(proto.angle)) * speed * dt
			+ _water_flow(Vector2(proto.position)) * dt
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


func _nearest_bacterium_spatial(
	origin: Vector2,
	radius: float,
	require_competent: bool = false
) -> Variant:
	if _grid_next.size() != bacteria.size():
		_rebuild_spatial_grid()
	var best: Variant = null
	var best_distance_sq: float = radius * radius
	var bucket_x: int = clampi(
		floori(origin.x / SPATIAL_BUCKET_SIZE),
		0,
		GRID_WIDTH - 1
	)
	var bucket_y: int = clampi(
		floori(origin.y / SPATIAL_BUCKET_SIZE),
		0,
		GRID_HEIGHT - 1
	)
	var bucket_radius: int = maxi(
		1,
		ceili(radius / SPATIAL_BUCKET_SIZE)
	)
	for y in range(
		maxi(0, bucket_y - bucket_radius),
		mini(GRID_HEIGHT - 1, bucket_y + bucket_radius) + 1
	):
		var row: int = y * GRID_WIDTH
		for x in range(
			maxi(0, bucket_x - bucket_radius),
			mini(GRID_WIDTH - 1, bucket_x + bucket_radius) + 1
		):
			var j: int = _grid_head[row + x]
			while j >= 0:
				var cell: Variant = bacteria[j]
				if (
					not bool(cell.dying)
					and not bool(cell.consumed)
					and int(cell.engulfed_by_id) < 0
					and (
						not require_competent
						or (
							bool(cell.competent)
							and not bool(cell.dormant)
						)
					)
				):
					var distance_sq: float = origin.distance_squared_to(
						Vector2(cell.position)
					)
					if distance_sq < best_distance_sq:
						best_distance_sq = distance_sq
						best = cell
				j = _grid_next[j]
	return best


func _find_protozoan_prey(proto: Variant) -> Variant:
	var best: Variant = null
	var perception: float = protozoan_perception * float(proto.gene_perception)
	var best_distance_sq: float = perception * perception
	var origin: Vector2 = Vector2(proto.position)
	var max_prey_biomass: float = float(proto.radius) * 2.10

	var bacterial_prey: Variant = _nearest_bacterium_spatial(
		origin,
		perception
	)
	if bacterial_prey != null:
		best = bacterial_prey
		best_distance_sq = origin.distance_squared_to(
			Vector2(bacterial_prey.position)
		)

	for flagellate in flagellates:
		if (
			bool(flagellate.dying)
			or bool(flagellate.consumed)
			or int(flagellate.engulfed_by_id) >= 0
			or float(flagellate.biomass_size()) > max_prey_biomass
		):
			continue
		var flag_distance_sq: float = origin.distance_squared_to(
			Vector2(flagellate.position)
		)
		if flag_distance_sq < best_distance_sq:
			best_distance_sq = flag_distance_sq
			best = flagellate

	# A sufficiently large amoeba can also handle a smaller ciliate. This
	# establishes a real second trophic edge instead of hard-coding every
	# predator to bacteria only.
	for grazer in ciliates:
		if (
			bool(grazer.dying)
			or bool(grazer.consumed)
			or int(grazer.engulfed_by_id) >= 0
			or float(grazer.biomass_size()) > max_prey_biomass
		):
			continue

		var distance_sq: float = origin.distance_squared_to(
			Vector2(grazer.position)
		)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best = grazer

	for alga in microalgae:
		if (
			bool(alga.dying)
			or bool(alga.consumed)
			or int(alga.engulfed_by_id) >= 0
			or float(alga.biomass_size()) > max_prey_biomass
		):
			continue
		var distance_sq: float = origin.distance_squared_to(
			Vector2(alga.position)
		)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best = alga

	for yeast in decomposers:
		if (
			bool(yeast.dying)
			or bool(yeast.consumed)
			or int(yeast.engulfed_by_id) >= 0
			or float(yeast.biomass_size()) > max_prey_biomass
		):
			continue
		var distance_sq: float = origin.distance_squared_to(
			Vector2(yeast.position)
		)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best = yeast

	return best


func _advance_protozoan_engulf(proto: Variant, dt: float) -> void:
	var prey: Variant = find_edible_by_id(int(proto.feeding_target_id))
	if prey == null or bool(prey.consumed):
		proto.finish_engulf()
		return

	if bool(prey.dying):
		prey.engulfed_by_id = -1
		prey.engulf_progress = 0.0
		proto.finish_engulf()
		return

	var defense_factor: float = _prey_handling_defense(prey)
	var duration: float = (
		protozoan_engulf_duration
		* defense_factor
		/ maxf(0.45, float(proto.gene_engulf))
	)
	var progress: float = minf(
		1.0,
		float(proto.feeding_progress) + dt / maxf(0.001, duration)
	)
	proto.feeding_progress = progress
	proto.deform_amount = 0.35 + sin(progress * PI) * 0.55

	if _prey_escapes_handling(
		prey,
		float(proto.gene_engulf),
		defense_factor,
		dt
	):
		_event_inc("escape_proto")
		prey.engulfed_by_id = -1
		prey.engulf_progress = 0.0
		var escape_axis: Vector2 = (
			Vector2(prey.position) - Vector2(proto.position)
		).normalized()
		if escape_axis.length_squared() <= 0.000001:
			escape_axis = Vector2.RIGHT.rotated(float(prey.angle))
		prey.position = Vector2(prey.position) + escape_axis * 1.2
		proto.finish_engulf()
		return

	var prey_position: Vector2 = Vector2(prey.position)
	var proto_position: Vector2 = Vector2(proto.position)
	var pull_alpha: float = clampf(dt * (2.0 + progress * 5.0), 0.0, 1.0)
	prey.position = prey_position.lerp(proto_position, pull_alpha)
	prey.engulf_progress = progress
	damage_cue.add_radial_world(
		Vector2(prey.position),
		3.4,
		0.010 * dt * (1.0 + progress * 2.0)
	)
	prey.angle = lerp_angle(
		float(prey.angle),
		float(proto.angle) + PI * 0.5,
		clampf(dt * 4.0, 0.0, 1.0)
	)

	var wobble: float = sin(float(proto.deform_phase) * 2.3) * 0.22
	proto.angle = wrapf(float(proto.angle) + wobble * dt, -PI, PI)

	if progress >= 1.0:
		_record_predation("proto", prey)
		prey.consumed = true
		prey.alive = false
		prey.engulfed_by_id = -1
		detritus.add_radial_world(
			Vector2(prey.position),
			2.6,
			0.020 + float(prey.biomass_size()) * 0.006
		)
		damage_cue.add_radial_world(
			Vector2(prey.position),
			4.6,
			0.045
		)
		proto.energy = minf(
			20.0,
			float(proto.energy) + 1.35 + float(prey.biomass_size()) * 0.18
		)
		proto.finish_engulf()


func _divide_protozoan(parent: Variant) -> Array:
	_event_inc("repro_protozoa")
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
	var trophic_capacity: int = _ciliate_carrying_capacity()
	var available_births: int = maxi(
		0,
		mini(CILIATE_SAFETY_LIMIT, trophic_capacity) - ciliates.size()
	)
	var crowding_multiplier: float = _crowding_maintenance_multiplier(
		ciliates.size(),
		trophic_capacity
	)

	for ciliate in ciliates:
		if bool(ciliate.consumed):
			continue

		if int(ciliate.engulfed_by_id) >= 0:
			next_ciliates.append(ciliate)
			continue

		if bool(ciliate.dying):
			_advance_predator_lysis(ciliate, dt)
			if float(ciliate.lysis_progress) >= 1.0:
				_recycle_predator_body(
					Vector2(ciliate.position),
					float(ciliate.radius),
					0.75
				)
			else:
				next_ciliates.append(ciliate)
			continue

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
			* crowding_multiplier
		)
		ciliate.energy = float(ciliate.energy) - maintenance * dt

		if float(ciliate.energy) <= 0.0:
			_release_predator_prey(
				int(ciliate.feeding_target_id),
				int(ciliate.id)
			)
			ciliate.finish_feed()
			ciliate.begin_lysis()
			next_ciliates.append(ciliate)
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
				if prey.has_method("finish_feed"):
					_release_predator_prey(
						int(prey.feeding_target_id),
						int(prey.id)
					)
					prey.finish_feed()
				ciliate.begin_feed(int(prey.id))
				prey.engulfed_by_id = int(ciliate.id)
				prey.engulf_progress = 0.0
				next_ciliates.append(ciliate)
				continue
		else:
			var cue_direction: Vector2 = _damage_cue_direction(
				Vector2(ciliate.position)
			)
			if cue_direction.length_squared() > 0.0:
				desired_angle = lerp_angle(
					desired_angle,
					cue_direction.angle(),
					0.42
				)
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
		var starvation_factor: float = clampf(
			float(ciliate.energy) / 1.8,
			0.26,
			1.0
		)
		var speed: float = (
			ciliate_speed
			* float(ciliate.gene_speed)
			* stroke
			* starvation_factor
		)
		ciliate.position = (
			Vector2(ciliate.position)
			+ Vector2.RIGHT.rotated(float(ciliate.angle)) * speed * dt
			+ _water_flow(Vector2(ciliate.position)) * dt
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
	var max_prey_biomass: float = float(ciliate.radius) * 1.95

	var bacterial_prey: Variant = _nearest_bacterium_spatial(
		origin,
		perception
	)
	if bacterial_prey != null:
		best = bacterial_prey
		best_distance_sq = origin.distance_squared_to(
			Vector2(bacterial_prey.position)
		)

	for flagellate in flagellates:
		if (
			bool(flagellate.dying)
			or bool(flagellate.consumed)
			or int(flagellate.engulfed_by_id) >= 0
			or float(flagellate.biomass_size()) > max_prey_biomass
		):
			continue
		var flag_distance_sq: float = origin.distance_squared_to(
			Vector2(flagellate.position)
		)
		if flag_distance_sq < best_distance_sq:
			best_distance_sq = flag_distance_sq
			best = flagellate

	for alga in microalgae:
		if (
			bool(alga.dying)
			or bool(alga.consumed)
			or int(alga.engulfed_by_id) >= 0
			or float(alga.biomass_size()) > max_prey_biomass
		):
			continue
		var distance_sq: float = origin.distance_squared_to(Vector2(alga.position))
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best = alga

	for yeast in decomposers:
		if (
			bool(yeast.dying)
			or bool(yeast.consumed)
			or int(yeast.engulfed_by_id) >= 0
			or float(yeast.biomass_size()) > max_prey_biomass
		):
			continue
		var distance_sq: float = origin.distance_squared_to(Vector2(yeast.position))
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best = yeast

	return best


func _advance_ciliate_feed(ciliate: Variant, dt: float) -> void:
	var prey: Variant = find_edible_by_id(int(ciliate.feeding_target_id))
	if prey == null or bool(prey.consumed):
		ciliate.finish_feed()
		return

	if bool(prey.dying):
		prey.engulfed_by_id = -1
		prey.engulf_progress = 0.0
		ciliate.finish_feed()
		return

	var defense_factor: float = _prey_handling_defense(prey)
	var duration: float = (
		ciliate_feed_duration
		* defense_factor
		/ maxf(0.45, float(ciliate.gene_capture))
	)
	var progress: float = minf(
		1.0,
		float(ciliate.feeding_progress) + dt / maxf(0.001, duration)
	)
	ciliate.feeding_progress = progress
	prey.engulf_progress = progress

	if _prey_escapes_handling(
		prey,
		float(ciliate.gene_capture),
		defense_factor,
		dt
	):
		_event_inc("escape_ciliate")
		prey.engulfed_by_id = -1
		prey.engulf_progress = 0.0
		var escape_axis: Vector2 = (
			Vector2(prey.position) - Vector2(ciliate.position)
		).normalized()
		if escape_axis.length_squared() <= 0.000001:
			escape_axis = Vector2.RIGHT.rotated(float(prey.angle))
		prey.position = Vector2(prey.position) + escape_axis * 0.95
		ciliate.finish_feed()
		return

	damage_cue.add_radial_world(
		Vector2(prey.position),
		3.0,
		0.008 * dt * (1.0 + progress * 2.5)
	)

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
		_record_predation("ciliate", prey)
		prey.consumed = true
		prey.alive = false
		prey.engulfed_by_id = -1
		detritus.add_radial_world(
			Vector2(prey.position),
			2.2,
			0.016 + float(prey.biomass_size()) * 0.005
		)
		damage_cue.add_radial_world(
			Vector2(prey.position),
			4.0,
			0.036
		)
		ciliate.energy = minf(
			16.0,
			float(ciliate.energy) + 0.95 + float(prey.biomass_size()) * 0.14
		)
		ciliate.finish_feed()


func _divide_ciliate(parent: Variant) -> Array:
	_event_inc("repro_ciliates")
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


func _advance_predator_lysis(organism: Variant, dt: float) -> void:
	organism.lysis_progress = minf(
		1.0,
		float(organism.lysis_progress) + dt / 1.55
	)
	organism.position = (
		Vector2(organism.position)
		+ _water_flow(Vector2(organism.position)) * dt * 0.38
	)
	damage_cue.add_radial_world(
		Vector2(organism.position),
		5.0 + float(organism.radius),
		0.020 * dt * (1.0 + float(organism.lysis_progress) * 2.0)
	)
	detritus.add_radial_world(
		Vector2(organism.position),
		3.0 + float(organism.radius),
		0.005 * dt
	)


func _recycle_predator_body(
	position: Vector2,
	radius: float,
	scale: float
) -> void:
	var biomass: float = maxf(0.08, radius * 0.055 * scale)
	detritus.add_radial_world(position, 4.8 + radius, biomass)
	waste.add_radial_world(position, 3.6 + radius, biomass * 0.20)
	damage_cue.add_radial_world(position, 6.0 + radius, biomass * 0.85)


func _release_predator_prey(prey_id: int, predator_id: int) -> void:
	if prey_id < 0:
		return
	var prey: Variant = find_edible_by_id(prey_id)
	if prey == null:
		return
	if int(prey.engulfed_by_id) == predator_id:
		prey.engulfed_by_id = -1
		prey.engulf_progress = 0.0


func _advance_gene_transfers(dt: float) -> void:
	if _active_transfer_recipient_ids.is_empty():
		return

	var next_active := PackedInt32Array()
	for recipient_id in _active_transfer_recipient_ids:
		var recipient: Variant = find_cell_by_id(int(recipient_id))
		if (
			recipient == null
			or int(recipient.transfer_role) != int(BacteriumScript.TRANSFER_RECIPIENT)
		):
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
		if delta.length_squared() > conjugation_break_distance * conjugation_break_distance:
			donor.clear_transfer_state()
			recipient.clear_transfer_state()
			continue

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
			next_active.append(int(recipient.id))
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

		if (
			donor.genome != null
			and recipient.genome != null
			and rng.randf() < conjugation_genome_recombination_rate
		):
			var donor_module: Dictionary = donor.genome.module_for_transfer(
				rng.randi_range(0, maxi(0, donor.genome.modules.size() - 1))
			)
			if recipient.integrate_genome_module(donor_module, rng):
				recipient.hgt_events = int(recipient.hgt_events) + 1

		donor.clear_transfer_state()
		recipient.clear_transfer_state()

	_active_transfer_recipient_ids = next_active

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
		-conjugation_contact_rate * pili_factor * _current_mechanics_dt
	)
	if rng.randf() >= probability:
		return

	donor.transfer_role = BacteriumScript.TRANSFER_DONOR
	donor.transfer_partner_id = int(recipient.id)
	donor.transfer_progress = 0.0
	recipient.transfer_role = BacteriumScript.TRANSFER_RECIPIENT
	recipient.transfer_partner_id = int(donor.id)
	recipient.transfer_progress = 0.0
	_active_transfer_recipient_ids.append(int(recipient.id))


func _plasmid_uptake_factor(cell: Variant) -> float:
	return 1.16 if cell.has_plasmid(BacteriumScript.PLASMID_SCAVENGE) else 1.0


func _plasmid_adhesion_factor(cell: Variant) -> float:
	return 1.18 if cell.has_plasmid(BacteriumScript.PLASMID_ADHESION) else 1.0


func _plasmid_maintenance_factor(cell: Variant) -> float:
	return 0.88 if cell.has_plasmid(BacteriumScript.PLASMID_STRESS) else 1.0


func _plasmid_burden(cell: Variant) -> float:
	var mask: int = int(cell.plasmid_mask)
	var modules: int = 0
	modules += 1 if (mask & int(BacteriumScript.PLASMID_CONJUGATION)) != 0 else 0
	modules += 1 if (mask & int(BacteriumScript.PLASMID_SCAVENGE)) != 0 else 0
	modules += 1 if (mask & int(BacteriumScript.PLASMID_ADHESION)) != 0 else 0
	modules += 1 if (mask & int(BacteriumScript.PLASMID_STRESS)) != 0 else 0
	return 0.0018 * float(modules)


func _advance_cell(cell: Variant, dt: float) -> void:
	var metabolic_dt: float = dt * float(_current_metabolic_stride)
	cell.age = float(cell.age) + dt

	if bool(cell.phage_infected):
		cell.phage_progress = minf(
			1.0,
			float(cell.phage_progress) + dt / maxf(0.001, phage_latent_period)
		)
		cell.energy = maxf(
			0.0,
			float(cell.energy) - phage_infection_cost * dt
		)
		cell.competent = false
		if float(cell.phage_progress) >= 1.0:
			cell.phage_triggered_lysis = true
			cell.begin_lysis()
			return

	var cell_position: Vector2 = Vector2(cell.position)
	var field_index: int = _field_index_for_world(cell_position)
	var local_nutrient_before: float = float(nutrient.values[field_index])
	var local_exudate_before: float = float(exudate.values[field_index])
	var local_detritus_before: float = float(detritus.values[field_index])
	var local_light_before: float = _apply_producer_shading(
		float(_ambient_light_cache[field_index]),
		float(producer_biomass.values[field_index])
	)
	var local_quorum_before: float = float(quorum_signal.values[field_index])
	var local_damage_before: float = float(damage_cue.values[field_index])
	var local_oxygen_before: float = float(oxygen.values[field_index])
	var resource_signal: float = local_nutrient_before + local_exudate_before * 1.25

	var refresh_regulation: bool = (
		cell.genome != null
		and (
			String(cell.ecotype_label) == "founder"
			or posmod(int(cell.id) + _agent_tick, REGULATION_BUCKETS) == 0
		)
	)
	if refresh_regulation:
		var genome_values: Array = cell.genome.evaluate_context(
			clampf(local_nutrient_before * 2.2, 0.0, 1.0),
			clampf(local_exudate_before * 4.0, 0.0, 1.0),
			clampf(local_detritus_before * 4.5, 0.0, 1.0),
			clampf(local_light_before, 0.0, 1.0),
			clampf(local_quorum_before * 8.0, 0.0, 1.0),
			clampf(local_damage_before * 7.0, 0.0, 1.0),
			clampf(1.0 - float(cell.energy) / 2.4, 0.0, 1.0),
			clampf(local_oxygen_before, 0.0, 1.0)
		)
		cell.expression_nutrient = float(
			genome_values[EvolvableGenomeScript.MODULE_NUTRIENT_UPTAKE]
		)
		cell.expression_exudate = float(
			genome_values[EvolvableGenomeScript.MODULE_EXUDATE_UPTAKE]
		)
		cell.expression_detritus = float(
			genome_values[EvolvableGenomeScript.MODULE_DETRITUS_SCAVENGE]
		)
		cell.expression_photo = float(
			genome_values[EvolvableGenomeScript.MODULE_PHOTOTROPHY]
		)
		cell.expression_matrix = float(
			genome_values[EvolvableGenomeScript.MODULE_MATRIX]
		)
		cell.expression_quorum = float(
			genome_values[EvolvableGenomeScript.MODULE_QUORUM_SIGNAL]
		)
		cell.refresh_motion_speed_cache()
		var previous_guild: int = int(cell.guild)
		cell.guild = int(
			cell.genome.dominant_guild_from_values(genome_values)
		)
		if int(cell.guild) != previous_guild:
			cell.phenotype_species_dirty = true
		cell.ecotype_label = String(
			cell.genome.phenotype_label_from_values(genome_values)
		)

	var dormancy_trait: float = clampf(float(cell.gene_dormancy), 0.45, 1.80)

	# Reversible starvation survival. Dormant cells barely move/metabolize but
	# retain a small maintenance uptake and wake when local resource returns.
	if bool(cell.dormant):
		cell.dormant_time = float(cell.dormant_time) + dt
		if resource_signal >= dormancy_wake_threshold / dormancy_trait:
			cell.dormant = false
			cell.dormant_time = 0.0
		else:
			var dormant_exudate: float = float(
				exudate.take_index(
					field_index,
					max_exudate_uptake_rate
					* dormancy_uptake_factor
					* float(cell.gene_uptake)
					* maxf(0.15, float(cell.expression_exudate))
					* metabolic_dt
				)
			)
			var dormant_nutrient: float = float(
				nutrient.take_index(
					field_index,
					max_uptake_rate
					* dormancy_uptake_factor
					* float(cell.gene_uptake)
					* maxf(0.15, float(cell.expression_nutrient))
					* metabolic_dt
				)
			)
			cell.energy = (
				float(cell.energy)
				+ dormant_exudate * exudate_energy_yield * 0.55
				+ dormant_nutrient * energy_yield * 0.45
				- maintenance_cost
				* float(cell.gene_size)
				* dormancy_maintenance_factor
				* metabolic_dt
			)
			if float(cell.energy) <= 0.0:
				cell.energy = 0.0
				cell.begin_lysis()
			return
	elif (
		not bool(cell.dividing)
		and int(cell.transfer_role) == int(BacteriumScript.TRANSFER_NONE)
		and float(cell.energy) <= dormancy_energy_threshold * dormancy_trait
		and resource_signal <= dormancy_resource_threshold
	):
		cell.dormant = true
		cell.dormant_time = 0.0
		return

	var sensed: float = (
		local_nutrient_before * maxf(0.25, float(cell.expression_nutrient))
		+ local_exudate_before * 0.72 * maxf(0.20, float(cell.expression_exudate))
	)
	if (
		float(cell.expression_detritus) > 0.06
		or cell.has_plasmid(BacteriumScript.PLASMID_SCAVENGE)
	):
		sensed += (
			local_detritus_before
			* 1.30
			* maxf(0.30, float(cell.expression_detritus))
		)
		sensed += (
			local_damage_before
			* 0.72
			* maxf(0.30, float(cell.expression_detritus))
		)
	if float(cell.expression_photo) > 0.06:
		sensed += (
			local_light_before
			* 0.18
			* maxf(0.30, float(cell.expression_photo))
		)

	var improvement: float = sensed - float(cell.sensed_memory)
	cell.sensed_memory = lerpf(
		float(cell.sensed_memory),
		sensed,
		_current_memory_alpha
	)

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
		cell.angle = (
			float(cell.angle)
			+ rng.randfn(0.0, _current_rotational_sigma)
		)

	cell.angle = wrapf(float(cell.angle), -PI, PI)

	var energy_speed_factor: float = clampf(float(cell.energy) / 1.6, 0.18, 1.0)
	var division_mobility: float = 0.16 if bool(cell.dividing) else 1.0

	var local_eps: float = float(eps.values[field_index])
	var local_quorum: float = local_quorum_before
	var local_damage: float = local_damage_before
	var quorum_response: float = clampf(local_quorum * 8.0, 0.0, 1.0)
	var competence_drive: float = clampf(
		(1.55 - float(cell.energy)) * 0.72 + local_damage * 0.65,
		0.0,
		1.0
	)
	cell.competent = (
		not bool(cell.dividing)
		and int(cell.transfer_role) == int(BacteriumScript.TRANSFER_NONE)
		and competence_drive * float(cell.gene_competence) >= 0.52
	)
	var speed: float = (
		run_speed
		* float(cell.motion_speed_base)
		* energy_speed_factor
		* division_mobility
	)
	if float(cell.expression_matrix) > 0.08:
		speed *= lerpf(
			1.0,
			0.56,
			quorum_response * clampf(float(cell.expression_matrix), 0.0, 1.0)
		)

	var heading: Vector2 = _direction_for_angle(float(cell.angle))
	var flow: Vector2 = _water_flow_for_field_index(field_index)
	var eps_drag: float = 1.0 / (1.0 + local_eps * 0.85)
	cell.position = (
		cell_position
		+ heading * speed * eps_drag * dt
		+ flow * dt * eps_drag
	)
	_constrain_to_world(cell)
	cell_position = Vector2(cell.position)
	field_index = _field_index_for_world(cell_position)

	var local_nutrient: float = float(nutrient.values[field_index])
	var local_exudate: float = float(exudate.values[field_index])
	var local_oxygen: float = float(oxygen.values[field_index])
	var oxygen_factor: float = (
		0.48
		+ 0.52 * local_oxygen / (oxygen_half_saturation + local_oxygen)
	)
	var uptake_rate: float = 0.0
	if local_nutrient > 0.0:
		uptake_rate = (
			max_uptake_rate
			* float(cell.gene_uptake)
			* maxf(0.08, float(cell.expression_nutrient))
			* _plasmid_uptake_factor(cell)
			* local_nutrient
			/ (monod_half_saturation + local_nutrient)
		)

	var consumed: float = float(
		nutrient.take_index(field_index, uptake_rate * metabolic_dt)
	)
	var exudate_rate: float = 0.0
	if local_exudate > 0.0:
		exudate_rate = (
			max_exudate_uptake_rate
			* float(cell.gene_uptake)
			* maxf(0.05, float(cell.expression_exudate))
			* local_exudate
			/ (exudate_half_saturation + local_exudate)
			* (1.0 + clampf(local_eps, 0.0, 1.5) * eps_retention_bonus)
		)
	var crossfed: float = float(
		exudate.take_index(field_index, exudate_rate * metabolic_dt)
	)
	cell.energy = (
		float(cell.energy)
		+ consumed * energy_yield * oxygen_factor
		+ crossfed * exudate_energy_yield * oxygen_factor
	)

	if consumed > 0.0 or crossfed > 0.0:
		oxygen.take_index(
			field_index,
			(consumed + crossfed * 0.7) * oxygen_consumption_rate
		)

	var scavenged: float = 0.0
	if (
		float(cell.expression_detritus) > 0.04
		or cell.has_plasmid(BacteriumScript.PLASMID_SCAVENGE)
	):
		scavenged = float(
			detritus.take_index(
				field_index,
				detritus_scavenge_rate
				* float(cell.gene_uptake)
				* maxf(0.18, float(cell.expression_detritus))
				* metabolic_dt
			)
		)
		cell.energy = float(cell.energy) + scavenged * detritus_energy_yield

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
	if cell.genome != null:
		var expressed_total: float = (
			float(cell.expression_nutrient)
			+ float(cell.expression_exudate)
			+ float(cell.expression_detritus)
			+ float(cell.expression_photo)
			+ float(cell.expression_matrix)
			+ float(cell.expression_quorum)
		)
		morphology_cost += (
			0.00055 * float(cell.genome.modules.size())
			+ 0.00040 * expressed_total
		)
	morphology_cost *= _plasmid_maintenance_factor(cell)
	if bool(cell.competent):
		morphology_cost += competence_cost * float(cell.gene_competence)
	cell.energy = (
		float(cell.energy)
		- (locomotion_cost + morphology_cost) * metabolic_dt
	)

	var signal_factor: float = clampf(
		0.25 + float(cell.expression_quorum),
		0.18,
		2.50
	)
	var signal_amount: float = (
		quorum_signal_rate
		* signal_factor
		* clampf(float(cell.energy) / 3.0, 0.15, 1.0)
		* metabolic_dt
	)
	quorum_signal.add_index(field_index, signal_amount)
	cell.energy = maxf(0.0, float(cell.energy) - signal_amount * 0.05)

	if (
		float(cell.expression_matrix) > 0.04
		or float(cell.gene_adhesion) > 0.95
		or cell.has_plasmid(BacteriumScript.PLASMID_ADHESION)
	):
		var matrix_factor: float = (
			0.55 + 1.65 * clampf(float(cell.expression_matrix), 0.0, 2.0)
		)
		var secretion: float = (
			eps_secretion_rate
			* matrix_factor
			* maxf(0.0, float(cell.gene_adhesion) - 0.70)
			* clampf(float(cell.energy) / 3.0, 0.2, 1.0)
			* (0.55 + 1.65 * quorum_response)
			* metabolic_dt
		)
		if secretion > 0.0:
			eps.add_index(field_index, secretion)
			cell.energy = maxf(0.0, float(cell.energy) - secretion * 0.7)

	var photo_gain: float = 0.0
	if float(cell.expression_photo) > 0.04:
		var local_light: float = _light_value_for_index(field_index)
		photo_gain = (
			0.045
			* local_light
			* clampf(float(cell.expression_photo), 0.0, 2.4)
			* metabolic_dt
		)
		cell.energy = float(cell.energy) + photo_gain
		oxygen.add_index(field_index, photo_gain * 0.34)
		nutrient.add_index(field_index, photo_gain * 0.010)
		exudate.add_radial_world(cell_position, 2.2, photo_gain * 0.16)
		producer_biomass.add_index(field_index, photo_gain * 0.018)

	if (
		consumed > 0.0
		or crossfed > 0.0
		or scavenged > 0.0
		or photo_gain > 0.0
	) and not bool(cell.dividing):
		var growth_delta: float = (
			growth_per_nutrient
			* float(cell.gene_growth)
			* (
				consumed
				+ crossfed * 0.82
				+ scavenged * 0.45
				+ photo_gain * 0.52
			)
		)
		var max_length_for_cell: float = maximum_length * float(cell.gene_size)
		growth_delta = minf(
			growth_delta,
			maxf(0.0, max_length_for_cell - float(cell.length))
		)

		if growth_delta > 0.0 and float(cell.energy) > 0.35:
			cell.length = float(cell.length) + growth_delta
			cell.energy = (
				float(cell.energy)
				- growth_delta * growth_energy_cost_per_length
			)

		waste.add_index(
			field_index,
			(consumed + crossfed * 0.72 + scavenged * 0.25) * waste_fraction
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
	var limit: int = maxi(2, bacteria_population_limit)
	var required_length: float = base_division_length * float(cell.gene_size)
	var soft_start: float = minf(
		float(LIVE_POPULATION_SOFT_START),
		float(limit) * 0.55
	)
	var global_pressure: float = clampf(
		(float(bacteria.size()) - soft_start)
		/ maxf(1.0, float(limit) - soft_start),
		0.0,
		1.0
	)

	var lineage_bin: int = _lineage_bin(float(cell.lineage_hue))
	var lineage_fraction: float = (
		float(_lineage_counts[lineage_bin])
		/ float(maxi(1, bacteria.size()))
	)
	var lineage_pressure: float = clampf(
		(lineage_fraction - 0.11) / 0.39,
		0.0,
		1.0
	)
	var ecotype_fraction: float = (
		float(
			_ecotype_counts[
				_ecotype_pressure_bin(phenotype_species_id(cell, 0))
			]
		)
		/ float(maxi(1, bacteria.size()))
	)
	var ecotype_pressure: float = clampf(
		(ecotype_fraction - 0.075) / 0.30,
		0.0,
		1.0
	)
	var rare_ecotype_relief: float = 0.10 if ecotype_fraction < 0.025 else 0.0

	var required_energy: float = base_division_energy * (
		0.82
		+ 0.18 * float(cell.gene_size)
		+ global_pressure * global_pressure * 0.42
		+ lineage_pressure * lineage_pressure * 0.62
		+ ecotype_pressure * ecotype_pressure * 0.95
		- rare_ecotype_relief
	)
	return (
		bacteria.size() < limit - 1
		and not bool(cell.dividing)
		and not bool(cell.dying)
		and not bool(cell.phage_infected)
		and float(cell.length) >= required_length
		and float(cell.energy) >= required_energy
		and bool(cell.alive)
	)


func _lineage_bin(hue: float) -> int:
	return clampi(
		floori(wrapf(hue, 0.0, 1.0) * float(LINEAGE_BIN_COUNT)),
		0,
		LINEAGE_BIN_COUNT - 1
	)


func _species_bin(value: float, minimum: float, maximum: float) -> int:
	var normalized: float = clampf(
		(value - minimum) / maxf(0.0001, maximum - minimum),
		0.0,
		0.9999
	)
	return floori(normalized * 3.0)


func _species_mix(signature: int, value: int) -> int:
	return posmod(signature * 31 + value + 17, 2147483000)


func phenotype_species_id(agent: Variant, family_code: int) -> int:
	# Exact ecotypes are intentionally much finer than species. A species only
	# changes when meaningful phenotype/niche thresholds are crossed.
	if (
		family_code == 0
		and not bool(agent.phenotype_species_dirty)
		and int(agent.phenotype_species_cache) >= 0
	):
		return int(agent.phenotype_species_cache)

	var signature: int = 1009 + family_code * 100003
	match family_code:
		0:
			signature = _species_mix(signature, int(agent.guild))
			signature = _species_mix(signature, _species_bin((float(agent.gene_speed) + float(agent.gene_chemotaxis)) * 0.5, 0.55, 1.75))
			signature = _species_mix(signature, _species_bin((float(agent.gene_uptake) + float(agent.gene_growth)) * 0.5, 0.55, 1.65))
			signature = _species_mix(signature, _species_bin((float(agent.gene_adhesion) + float(agent.gene_dormancy)) * 0.5, 0.45, 1.70))
			signature = _species_mix(signature, _species_bin(float(agent.gene_size), 0.70, 1.50))
		1:
			signature = _species_mix(signature, _species_bin(float(agent.gene_speed), 0.55, 1.70))
			signature = _species_mix(signature, _species_bin(float(agent.gene_engulf), 0.55, 1.75))
			signature = _species_mix(signature, _species_bin(float(agent.gene_size), 0.70, 1.50))
		2:
			signature = _species_mix(signature, _species_bin(float(agent.gene_speed), 0.60, 1.85))
			signature = _species_mix(signature, _species_bin(float(agent.gene_capture), 0.60, 1.75))
			signature = _species_mix(signature, _species_bin(float(agent.gene_size), 0.75, 1.45))
		3:
			signature = _species_mix(signature, _species_bin(float(agent.gene_speed), 0.60, 1.80))
			signature = _species_mix(signature, _species_bin(float(agent.gene_capture), 0.55, 1.75))
			signature = _species_mix(signature, _species_bin(float(agent.gene_metabolism), 0.60, 1.50))
		4:
			signature = _species_mix(signature, _species_bin(float(agent.gene_light_use), 0.55, 1.75))
			signature = _species_mix(signature, _species_bin(float(agent.gene_exudate), 0.50, 1.85))
			signature = _species_mix(signature, _species_bin(float(agent.gene_drift), 0.50, 1.70))
		5:
			signature = _species_mix(signature, _species_bin(float(agent.gene_detritus), 0.50, 1.85))
			signature = _species_mix(signature, _species_bin(float(agent.gene_mineralize), 0.50, 1.85))
			signature = _species_mix(signature, _species_bin(float(agent.gene_growth), 0.55, 1.70))
		6:
			signature = _species_mix(signature, _species_bin(float(agent.gene_branch), 0.45, 1.85))
			signature = _species_mix(signature, _species_bin(float(agent.gene_enzyme), 0.50, 1.75))
			signature = _species_mix(signature, _species_bin(float(agent.gene_efficiency), 0.55, 1.65))

	if family_code == 0:
		agent.phenotype_species_cache = signature
		agent.phenotype_species_dirty = false
	return signature


func species_visual_hue(agent: Variant, family_code: int) -> float:
	var species_id: int = phenotype_species_id(agent, family_code)
	return float(posmod(species_id * 73 + family_code * 131, 997)) / 997.0


func bacteria_render_snapshot() -> Dictionary:
	# Rendering reads a compact immutable-at-call-time view instead of walking
	# RefCounted bacteria directly. This is an incremental bridge toward #20:
	# simulation objects remain authoritative for biology while presentation
	# consumes dense packed state.
	var positions := PackedVector2Array()
	var angles := PackedFloat32Array()
	var lengths := PackedFloat32Array()
	var radii := PackedFloat32Array()
	var gene_sizes := PackedFloat32Array()
	var burrow_depths := PackedFloat32Array()
	var species_hues := PackedFloat32Array()
	var lineage_hues := PackedFloat32Array()
	var states := PackedByteArray()

	var count: int = 0
	for cell in bacteria:
		if cell == null or bool(cell.consumed):
			continue
		count += 1
	positions.resize(count)
	angles.resize(count)
	lengths.resize(count)
	radii.resize(count)
	gene_sizes.resize(count)
	burrow_depths.resize(count)
	species_hues.resize(count)
	lineage_hues.resize(count)
	states.resize(count)

	var write_index: int = 0
	for cell in bacteria:
		if cell == null or bool(cell.consumed):
			continue
		positions[write_index] = Vector2(cell.position)
		angles[write_index] = float(cell.angle)
		lengths[write_index] = float(cell.length)
		radii[write_index] = float(cell.radius)
		gene_sizes[write_index] = float(cell.gene_size)
		burrow_depths[write_index] = float(cell.burrow_depth)
		species_hues[write_index] = species_visual_hue(cell, 0)
		lineage_hues[write_index] = float(cell.lineage_hue)
		states[write_index] = 1 if bool(cell.dying) else 0
		write_index += 1

	return {
		"positions": positions,
		"angles": angles,
		"lengths": lengths,
		"radii": radii,
		"gene_sizes": gene_sizes,
		"burrow_depths": burrow_depths,
		"species_hues": species_hues,
		"lineage_hues": lineage_hues,
		"states": states,
	}


func _ecotype_pressure_bin(ecotype_id: int) -> int:
	return posmod(ecotype_id, ECOTYPE_PRESSURE_BIN_COUNT)


func _population_metadata_stride() -> int:
	var count: int = bacteria.size()
	if count >= AGENT_ULTRA_THRESHOLD:
		return 4
	if count >= AGENT_MASS_THRESHOLD:
		return 2
	return 1


func _refresh_population_metadata() -> int:
	_lineage_counts.fill(0)
	_ecotype_counts.fill(0)
	var living_count: int = 0
	for cell in bacteria:
		if (
			cell == null
			or bool(cell.dying)
			or bool(cell.consumed)
			or int(cell.engulfed_by_id) >= 0
		):
			continue
		living_count += 1
		var bin_index: int = _lineage_bin(float(cell.lineage_hue))
		_lineage_counts[bin_index] += 1
		var species_bin: int = _ecotype_pressure_bin(
			phenotype_species_id(cell, 0)
		)
		_ecotype_counts[species_bin] += 1
	return living_count


func _divide(parent: Variant) -> Array:
	_event_inc("repro_bacteria")
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

	if bool(cell.phage_triggered_lysis):
		# Viral shunt: a larger share returns directly to dissolved resources,
		# while a compatible packet carries the local host lineage forward.
		nutrient.add_radial_world(position, 3.4, recycled * 0.48)
		exudate.add_radial_world(position, 3.0, recycled * 0.22)
		_spawn_phage_cloud(
			position,
			float(cell.lineage_hue),
			phage_burst_strength * (0.75 + recycled * 1.8),
			5.0 + float(cell.gene_size),
			1
		)

	_release_dna_fragments(cell)
	waste.add_radial_world(position, 3.0, recycled * 0.16)
	detritus.add_radial_world(position, 4.2, recycled * 0.85)
	damage_cue.add_radial_world(position, 5.0, recycled * 0.75)


func _advance_disturbance_schedule() -> void:
	while simulation_time >= next_disturbance_time:
		_trigger_disturbance(disturbance_index)
		disturbance_index += 1
		next_disturbance_time += disturbance_interval


func _trigger_disturbance(event_index: int) -> void:
	var event_type: int = posmod(event_index, 3)
	var position: Vector2 = _disturbance_position(event_index, event_type)
	last_disturbance_type = event_type
	last_disturbance_position = position
	last_disturbance_time = simulation_time

	match event_type:
		DISTURBANCE_RESOURCE_PULSE:
			_event_inc("disturbance_resource")
			# A local dissolved-resource pulse creates a bloom opportunity.
			nutrient.add_radial_world(
				position,
				disturbance_radius,
				0.92
			)
			oxygen.add_radial_world(
				position,
				disturbance_radius * 0.78,
				0.10
			)
			exudate.add_radial_world(
				position,
				disturbance_radius * 0.55,
				0.055
			)

		DISTURBANCE_WASHOUT:
			_event_inc("disturbance_washout")
			# Local shear/fresh-water turnover removes attached material rather
			# than deleting organisms. Detached biomass becomes detrital resource,
			# creating a scavenger/decomposer opportunity after the disturbance.
			producer_biomass.attenuate_radial_world(
				position,
				disturbance_radius,
				0.62
			)
			eps.attenuate_radial_world(
				position,
				disturbance_radius,
				0.76
			)
			quorum_signal.attenuate_radial_world(
				position,
				disturbance_radius,
				0.88
			)
			exudate.attenuate_radial_world(
				position,
				disturbance_radius,
				0.48
			)
			detritus.add_radial_world(
				position,
				disturbance_radius * 0.72,
				0.16
			)
			damage_cue.add_radial_world(
				position,
				disturbance_radius * 0.72,
				0.075
			)
			oxygen.add_radial_world(
				position,
				disturbance_radius * 0.86,
				0.14
			)

		DISTURBANCE_ORGANIC_FALL:
			_event_inc("disturbance_organic")
			# A bounded particulate pulse favors decomposers/scavengers and then
			# cross-feeders as mineralization/exudation proceeds.
			detritus.add_radial_world(
				position,
				disturbance_radius * 0.82,
				0.36
			)
			nutrient.add_radial_world(
				position,
				disturbance_radius * 0.56,
				0.11
			)
			exudate.add_radial_world(
				position,
				disturbance_radius * 0.46,
				0.045
			)
			damage_cue.add_radial_world(
				position,
				disturbance_radius * 0.42,
				0.022
			)


func _disturbance_position(event_index: int, event_type: int) -> Vector2:
	var sources: Array[Vector2] = (
		producer_sources
		if event_type == DISTURBANCE_WASHOUT
		else nutrient_sources
	)
	if sources.is_empty():
		return world_size * 0.5

	# No RNG consumption: adding succession must not perturb mutation/hunting
	# random streams. Seed + event index deterministically choose the patch.
	var source_index: int = posmod(
		absi(fixed_seed) + event_index * 5 + event_type * 3,
		sources.size()
	)
	var base: Vector2 = sources[source_index]
	var phase: float = (
		float(posmod(absi(fixed_seed), 997)) * 0.017
		+ float(event_index) * 2.399
		+ float(event_type) * 0.91
	)
	var offset := Vector2(cos(phase), sin(phase)) * 5.5
	var margin: float = disturbance_radius + 2.0
	var result: Vector2 = base + offset
	result.x = clampf(result.x, margin, world_size.x - margin)
	result.y = clampf(result.y, margin, world_size.y - margin)
	return result


func _spawn_phage_cloud(
	position: Vector2,
	host_hue: float,
	concentration: float,
	radius: float,
	generation: int = 0
) -> void:
	if concentration <= 0.0:
		return

	# Merge nearby compatible packets first. This keeps the representation
	# bounded while preserving local amplification around successful hosts.
	for cloud in phage_clouds:
		var compatibility: float = _phage_compatibility(
			float(cloud.host_hue),
			host_hue
		)
		if (
			compatibility >= 0.72
			and Vector2(cloud.position).distance_to(position) <= maxf(radius, float(cloud.radius))
		):
			cloud.concentration = minf(
				3.0,
				float(cloud.concentration) + concentration
			)
			cloud.radius = minf(
				phage_cloud_max_radius,
				maxf(float(cloud.radius), radius)
			)
			cloud.age = minf(float(cloud.age), 2.0)
			cloud.burst_generation = maxi(int(cloud.burst_generation), generation)
			return

	if phage_clouds.size() >= PHAGE_CLOUD_SAFETY_LIMIT:
		phage_clouds.pop_front()

	var cloud: Variant = PhageCloudScript.new(
		_next_phage_id,
		position,
		host_hue,
		concentration,
		radius,
		generation
	)
	phage_clouds.append(cloud)
	_next_phage_id += 1


func _bacteria_indices_in_radius(
	origin: Vector2,
	radius: float
) -> PackedInt32Array:
	var result := PackedInt32Array()
	var radius_sq: float = radius * radius
	var bucket_x: int = clampi(
		floori(origin.x / SPATIAL_BUCKET_SIZE),
		0,
		GRID_WIDTH - 1
	)
	var bucket_y: int = clampi(
		floori(origin.y / SPATIAL_BUCKET_SIZE),
		0,
		GRID_HEIGHT - 1
	)
	var bucket_radius: int = maxi(
		1,
		ceili(radius / SPATIAL_BUCKET_SIZE)
	)
	for y in range(
		maxi(0, bucket_y - bucket_radius),
		mini(GRID_HEIGHT - 1, bucket_y + bucket_radius) + 1
	):
		var row: int = y * GRID_WIDTH
		for x in range(
			maxi(0, bucket_x - bucket_radius),
			mini(GRID_WIDTH - 1, bucket_x + bucket_radius) + 1
		):
			var j: int = _grid_head[row + x]
			while j >= 0:
				if origin.distance_squared_to(_mech_positions[j]) <= radius_sq:
					result.append(j)
				j = _grid_next[j]
	return result


func _advance_phage_clouds(dt: float) -> void:
	if phage_clouds.is_empty():
		return

	_phage_tick += 1
	var survivors: Array = []
	for cloud in phage_clouds:
		cloud.age = float(cloud.age) + dt
		cloud.concentration = (
			float(cloud.concentration) * exp(-phage_cloud_decay * dt)
		)
		cloud.radius = minf(
			phage_cloud_max_radius,
			float(cloud.radius) + phage_cloud_diffusion * dt
		)
		var position: Vector2 = (
			Vector2(cloud.position)
			+ _water_flow(Vector2(cloud.position)) * dt * 0.92
		)
		position.x = clampf(position.x, 0.5, world_size.x - 0.5)
		position.y = clampf(position.y, 0.5, world_size.y - 0.5)
		cloud.position = position

		if (
			float(cloud.age) >= float(cloud.lifetime)
			or float(cloud.concentration) <= 0.018
		):
			continue

		var infections_this_tick: int = 0
		var nearby_indices: PackedInt32Array = _bacteria_indices_in_radius(
			position,
			float(cloud.radius)
		)
		for cell_index in nearby_indices:
			var cell: Variant = bacteria[int(cell_index)]
			if (
				bool(cell.dying)
				or bool(cell.consumed)
				or bool(cell.phage_infected)
				or int(cell.engulfed_by_id) >= 0
			):
				continue

			var compatibility: float = _phage_compatibility(
				float(cell.lineage_hue),
				float(cloud.host_hue)
			)
			if compatibility <= 0.02:
				continue

			var field_index: int = _field_index_for_world(Vector2(cell.position))
			var local_eps: float = float(eps.values[field_index])
			var matrix_factor: float = 1.0 / (
				1.0 + clampf(local_eps, 0.0, 1.5) * phage_eps_protection
			)
			var dormancy_factor: float = 0.28 if bool(cell.dormant) else 1.0
			var probability: float = 1.0 - exp(
				-phage_adsorption_rate
				* float(cloud.concentration)
				* compatibility
				* matrix_factor
				* dormancy_factor
				* dt
			)
			var roll: float = _stable_event_roll(
				int(cloud.id),
				int(cell.id),
				_phage_tick
			)
			if roll >= probability:
				continue

			_infect_cell_with_phage(cell, cloud)
			cloud.concentration = maxf(
				0.0,
				float(cloud.concentration) - 0.035
			)
			infections_this_tick += 1
			if infections_this_tick >= 3:
				break

		survivors.append(cloud)

	phage_clouds = survivors

func _infect_cell_with_phage(cell: Variant, cloud: Variant) -> void:
	if (
		bool(cell.dying)
		or bool(cell.consumed)
		or bool(cell.phage_infected)
	):
		return
	cell.phage_infected = true
	cell.phage_progress = 0.0
	cell.phage_host_hue = float(cloud.host_hue)
	cell.phage_source_id = int(cloud.id)
	cell.phage_triggered_lysis = false
	cell.dividing = false
	cell.division_progress = 0.0
	cell.competent = false
	cell.clear_transfer_state()


func _phage_compatibility(host_hue: float, cloud_hue: float) -> float:
	var delta: float = absf(
		wrapf(host_hue - cloud_hue + 0.5, 0.0, 1.0) - 0.5
	)
	return clampf(
		1.0 - delta / maxf(0.001, phage_specificity_width),
		0.0,
		1.0
	)


func _prey_handling_defense(prey: Variant) -> float:
	var position: Vector2 = Vector2(prey.position)
	var matrix_defense: float = (
		1.0
		+ clampf(float(eps.sample_world(position)), 0.0, 1.5)
		* eps_grazer_protection
	)

	# No invisible resistance score: the bacterial part is composed only from
	# existing visible/costly traits.
	var cell: Variant = find_cell_by_id(int(prey.id))
	if cell == null or cell != prey:
		return matrix_defense

	var adhesion_defense: float = maxf(
		0.0,
		float(cell.gene_adhesion) - 0.78
	) * 0.42
	var size_defense: float = maxf(
		0.0,
		float(cell.gene_size) - 0.92
	) * 0.28
	var dormancy_defense: float = 0.14 if bool(cell.dormant) else 0.0
	return matrix_defense + adhesion_defense + size_defense + dormancy_defense


func _prey_escapes_handling(
	prey: Variant,
	predator_capture: float,
	defense_factor: float,
	dt: float
) -> bool:
	var cell: Variant = find_cell_by_id(int(prey.id))
	if cell == null or cell != prey:
		return false

	var counter_adaptation: float = clampf(predator_capture, 0.45, 2.2)
	var pressure: float = maxf(
		0.0,
		defense_factor - (0.78 + counter_adaptation * 0.62)
	)
	if pressure <= 0.0:
		return false
	var escape_rate: float = clampf(pressure * 0.38, 0.0, 0.48)
	return rng.randf() < 1.0 - exp(-escape_rate * dt)


func _release_dna_fragments(cell: Variant) -> void:
	var release_count: int = 2 if float(cell.length) >= 4.0 else 1
	for fragment_index in range(release_count):
		if dna_fragments.size() >= DNA_FRAGMENT_SAFETY_LIMIT:
			dna_fragments.pop_front()

		var trait_kind: int = posmod(
			int(cell.id) + int(cell.generation) * 3 + fragment_index * 5,
			DNAFragmentScript.TRAIT_COUNT
		)
		var trait_value: float = _bacterium_trait_value(cell, trait_kind)
		var module_payload: Dictionary = {}
		if cell.genome != null and not cell.genome.modules.is_empty():
			module_payload = cell.genome.module_for_transfer(
				int(cell.id) + int(cell.generation) + fragment_index * 7
			)
		var phase: float = (
			float(posmod(int(cell.id) * 13 + fragment_index * 17, 360))
			* PI / 180.0
		)
		var fragment: Variant = DNAFragmentScript.new(
			_next_dna_id,
			Vector2(cell.position) + Vector2.RIGHT.rotated(phase) * 0.8,
			int(cell.lineage_id),
			float(cell.lineage_hue),
			trait_kind,
			trait_value,
			module_payload
		)
		fragment.lifetime = dna_fragment_lifetime
		dna_fragments.append(fragment)
		_next_dna_id += 1


func _advance_dna_fragments(dt: float) -> void:
	if dna_fragments.is_empty():
		return

	_transformation_tick += 1
	var survivors: Array = []

	for fragment in dna_fragments:
		fragment.age = float(fragment.age) + dt
		if float(fragment.age) >= float(fragment.lifetime):
			continue

		var position: Vector2 = Vector2(fragment.position)
		position += _water_flow(position) * dt * 0.58
		position.x = clampf(position.x, 0.5, world_size.x - 0.5)
		position.y = clampf(position.y, 0.5, world_size.y - 0.5)
		fragment.position = position

		var recipient: Variant = _nearest_competent_cell(
			position,
			competence_capture_radius
		)
		if recipient == null:
			survivors.append(fragment)
			continue

		var competence: float = clampf(
			float(recipient.gene_competence),
			0.30,
			1.90
		)
		var uptake_probability: float = 1.0 - exp(
			-transformation_uptake_rate * competence * dt
		)
		var uptake_roll: float = _stable_event_roll(
			int(fragment.id),
			int(recipient.id),
			_transformation_tick
		)
		if uptake_roll >= uptake_probability:
			survivors.append(fragment)
			continue

		var compatibility: float = _lineage_compatibility(
			float(recipient.lineage_hue),
			float(fragment.source_hue)
		)
		var recombine_roll: float = _stable_event_roll(
			int(fragment.id) * 17,
			int(recipient.id) * 31,
			_transformation_tick + 97
		)
		if recombine_roll < compatibility * 0.78:
			_integrate_dna_fragment(recipient, fragment)
			recipient.transformation_events = (
				int(recipient.transformation_events) + 1
			)
		else:
			# Failed/foreign DNA still has a small nutrient value.
			recipient.energy = minf(
				12.0,
				float(recipient.energy) + float(fragment.biomass) * 1.8
			)

	dna_fragments = survivors


func _nearest_competent_cell(position: Vector2, radius: float) -> Variant:
	return _nearest_bacterium_spatial(
		position,
		radius,
		true
	)


func _integrate_dna_fragment(cell: Variant, fragment: Variant) -> void:
	var strength: float = transformation_recombination_strength
	match int(fragment.trait_kind):
		DNAFragmentScript.TRAIT_SPEED:
			cell.gene_speed = lerpf(
				float(cell.gene_speed), float(fragment.trait_value), strength
			)
		DNAFragmentScript.TRAIT_CHEMOTAXIS:
			cell.gene_chemotaxis = lerpf(
				float(cell.gene_chemotaxis), float(fragment.trait_value), strength
			)
		DNAFragmentScript.TRAIT_UPTAKE:
			cell.gene_uptake = lerpf(
				float(cell.gene_uptake), float(fragment.trait_value), strength
			)
		DNAFragmentScript.TRAIT_GROWTH:
			cell.gene_growth = lerpf(
				float(cell.gene_growth), float(fragment.trait_value), strength
			)
		DNAFragmentScript.TRAIT_SIZE:
			cell.gene_size = lerpf(
				float(cell.gene_size), float(fragment.trait_value), strength
			)
			cell.radius = clampf(
				0.34 + 0.16 * float(cell.gene_size),
				0.42,
				0.63
			)
		DNAFragmentScript.TRAIT_TUMBLE:
			cell.gene_tumble = lerpf(
				float(cell.gene_tumble), float(fragment.trait_value), strength
			)
		DNAFragmentScript.TRAIT_ADHESION:
			cell.gene_adhesion = lerpf(
				float(cell.gene_adhesion), float(fragment.trait_value), strength
			)
		DNAFragmentScript.TRAIT_DORMANCY:
			cell.gene_dormancy = lerpf(
				float(cell.gene_dormancy), float(fragment.trait_value), strength
			)

	if fragment.has_module_payload():
		cell.integrate_genome_module(fragment.module_payload, rng)

	# Scalar transformation can cross phenotype/motion thresholds.
	cell.phenotype_species_dirty = true
	cell.refresh_motion_speed_cache()


func _bacterium_trait_value(cell: Variant, trait_kind: int) -> float:
	match trait_kind:
		DNAFragmentScript.TRAIT_SPEED:
			return float(cell.gene_speed)
		DNAFragmentScript.TRAIT_CHEMOTAXIS:
			return float(cell.gene_chemotaxis)
		DNAFragmentScript.TRAIT_UPTAKE:
			return float(cell.gene_uptake)
		DNAFragmentScript.TRAIT_GROWTH:
			return float(cell.gene_growth)
		DNAFragmentScript.TRAIT_SIZE:
			return float(cell.gene_size)
		DNAFragmentScript.TRAIT_TUMBLE:
			return float(cell.gene_tumble)
		DNAFragmentScript.TRAIT_ADHESION:
			return float(cell.gene_adhesion)
		DNAFragmentScript.TRAIT_DORMANCY:
			return float(cell.gene_dormancy)
	return 1.0


func _lineage_compatibility(recipient_hue: float, donor_hue: float) -> float:
	var delta: float = absf(
		wrapf(recipient_hue - donor_hue + 0.5, 0.0, 1.0) - 0.5
	)
	return clampf(1.0 - delta * 1.35, 0.28, 1.0)


func _stable_event_roll(a: int, b: int, tick: int) -> float:
	var value: int = a * 73856093
	value ^= b * 19349663
	value ^= tick * 83492791
	value = value & 0x7fffffff
	return float(value % 1000003) / 1000003.0


func _feed_environment(dt: float) -> void:
	var amount_per_source: float = source_rate * dt
	for source in nutrient_sources:
		nutrient.add_radial_world(source, source_radius, amount_per_source)

	# Producer mats are the first vegetation-like biome component: they use
	# light to release oxygen and leak a small amount of dissolved organic
	# material back into the microbial loop.
	for source in producer_sources:
		var local_light: float = float(_sample_light(source))
		var mat: float = float(producer_biomass.sample_nearest_world(source))
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
		# Logistic mat growth requires an existing local seed. Without the
		# biomass factor, every empty field cell spontaneously became a producer
		# patch and the whole dish eventually turned into uniform green wallpaper.
		var growth: float = (
			producer_growth_rate
			* biomass
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

	# Small initial particulate patches give decomposers a real substrate before
	# the first mortality event; they are resources, not permanent source nodes.
	for i in range(2):
		var detrital_source: Vector2 = nutrient_sources[(i * 3 + 1) % nutrient_sources.size()]
		detritus.add_radial_world(detrital_source, 8.0, 0.22)


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


func sample_light(position: Vector2) -> float:
	return _sample_light(position)


func _sample_light(position: Vector2) -> float:
	var index: int = _field_index_for_world(position)
	return _apply_producer_shading(
		float(_ambient_light_cache[index]),
		float(producer_biomass.values[index])
	)


func _ambient_light(position: Vector2) -> float:
	var normalized_y: float = clampf(position.y / world_size.y, 0.0, 1.0)
	var vertical: float = lerpf(1.0, 0.38, normalized_y)
	var daylight: float = (
		0.5
		+ 0.5 * cos(
			TAU * simulation_time / maxf(1.0, diel_cycle_seconds)
		)
	)
	daylight = lerpf(night_light_floor, 1.0, daylight)
	var ripple: float = (
		0.08
		* sin(position.x * 0.055 + simulation_time * 0.07)
		* cos(position.y * 0.045 - simulation_time * 0.05)
	)
	return clampf(vertical * daylight + ripple, 0.04, 1.0)


func _apply_producer_shading(light_value: float, biomass: float) -> float:
	# Qualitative self-shading: dense producer mats attenuate the light seen by
	# producers living in the same patch. A rational attenuation keeps the CPU
	# reference cheap and leaves a direct GPU-friendly equivalent for #57.
	var transmittance: float = 1.0 / (
		1.0 + producer_self_shading_strength * clampf(biomass, 0.0, 1.0)
	)
	return clampf(light_value * transmittance, 0.025, 1.0)


func _light_value_for_index(index: int) -> float:
	return _apply_producer_shading(
		float(_ambient_light_cache[index]),
		float(producer_biomass.values[index])
	)


func sample_water_flow(position: Vector2) -> Vector2:
	return _water_flow(position)


func _refresh_environment_caches() -> void:
	var daylight: float = (
		0.5
		+ 0.5 * cos(
			TAU * simulation_time / maxf(1.0, diel_cycle_seconds)
		)
	)
	daylight = lerpf(night_light_floor, 1.0, daylight)

	for x in range(FIELD_WIDTH):
		var world_x: float = (float(x) + 0.5) * FIELD_CELL_SIZE
		_flow_y_cols[x] = cos(
			world_x * 0.038 - simulation_time * 0.075
		) * water_flow_strength
		_light_x_wave[x] = sin(
			world_x * 0.055 + simulation_time * 0.07
		)

	for y in range(FIELD_HEIGHT):
		var world_y: float = (float(y) + 0.5) * FIELD_CELL_SIZE
		_flow_x_rows[y] = sin(
			world_y * 0.045 + simulation_time * 0.11
		) * water_flow_strength
		_light_y_wave[y] = cos(
			world_y * 0.045 - simulation_time * 0.05
		)
		var row: int = y * FIELD_WIDTH
		var base_light: float = float(_vertical_light_rows[y]) * daylight
		var y_wave: float = float(_light_y_wave[y])
		for x in range(FIELD_WIDTH):
			var index: int = row + x
			_ambient_light_cache[index] = clampf(
				base_light
					+ 0.08 * float(_light_x_wave[x]) * y_wave,
				0.04,
				1.0
			)
			_flow_field_cache[index] = Vector2(
				float(_flow_x_rows[y]),
				float(_flow_y_cols[x])
			)

func _field_index_for_world(position: Vector2) -> int:
	var x: int = clampi(
		floori(position.x / FIELD_CELL_SIZE),
		0,
		FIELD_WIDTH - 1
	)
	var y: int = clampi(
		floori(position.y / FIELD_CELL_SIZE),
		0,
		FIELD_HEIGHT - 1
	)
	return y * FIELD_WIDTH + x


func _water_flow_for_field_index(field_index: int) -> Vector2:
	return _flow_field_cache[
		clampi(field_index, 0, _flow_field_cache.size() - 1)
	]


func _water_flow(position: Vector2) -> Vector2:
	return _water_flow_for_field_index(_field_index_for_world(position))

func _damage_cue_direction(position: Vector2) -> Vector2:
	var gradient: Vector2 = Vector2(damage_cue.gradient_world(position))
	if gradient.length_squared() <= 0.0000001:
		return Vector2.ZERO
	return gradient.normalized()


func _rebuild_bacteria_id_map() -> void:
	_bacteria_by_id.clear()
	for cell in bacteria:
		_bacteria_by_id[int(cell.id)] = cell


func _rebuild_edible_id_map() -> void:
	_edible_by_id.clear()
	for organism in ciliates:
		_edible_by_id[int(organism.id)] = organism
	for organism in flagellates:
		_edible_by_id[int(organism.id)] = organism
	for organism in microalgae:
		_edible_by_id[int(organism.id)] = organism
	for organism in decomposers:
		_edible_by_id[int(organism.id)] = organism


func _rebuild_id_maps() -> void:
	_rebuild_bacteria_id_map()
	_rebuild_edible_id_map()


func _refugia_organism_score(organism: Variant) -> float:
	return float(organism.energy) + float(organism.generation) * 0.040


func _refresh_guild_refugia(group: Array, kind: int) -> void:
	var bank: Array = _refugia_guild_banks[kind]
	var family_code: int = kind + 1
	for organism in group:
		if organism == null or bool(organism.dying):
			continue
		if "consumed" in organism and bool(organism.consumed):
			continue
		if "engulfed_by_id" in organism and int(organism.engulfed_by_id) >= 0:
			continue

		var species_id: int = phenotype_species_id(organism, family_code)
		var matched_index: int = -1
		for i in range(bank.size()):
			if phenotype_species_id(bank[i], family_code) == species_id:
				matched_index = i
				break
		if matched_index >= 0:
			if _refugia_organism_score(organism) > _refugia_organism_score(bank[matched_index]):
				bank[matched_index] = organism
			continue

		if bank.size() < REFUGIA_GUILD_BANK_LIMIT:
			bank.append(organism)
			continue

		# A genuinely new, later-evolved species may enter the finite seed bank
		# by displacing the weakest archived phenotype.
		var weakest_index: int = 0
		var weakest_score: float = _refugia_organism_score(bank[0])
		for i in range(1, bank.size()):
			var score: float = _refugia_organism_score(bank[i])
			if score < weakest_score:
				weakest_score = score
				weakest_index = i
		if _refugia_organism_score(organism) > weakest_score:
			bank[weakest_index] = organism


func _next_guild_refugia_templates(kind: int, requested: int) -> Array:
	var result: Array = []
	var bank: Array = _refugia_guild_banks[kind]
	if bank.is_empty() or requested <= 0:
		return result
	var take: int = mini(requested, bank.size())
	var cursor: int = int(_refugia_guild_cursors[kind])
	for offset in range(take):
		result.append(bank[posmod(cursor + offset, bank.size())])
	_refugia_guild_cursors[kind] = cursor + take
	return result

func _refugia_cell_score(cell: Variant) -> float:
	return (
		float(cell.energy)
		+ 0.18 * float(cell.gene_size)
		+ 0.08 * float(cell.gene_dormancy)
	)


func _refresh_bacterial_refugia() -> void:
	for cell in bacteria:
		if (
			cell == null
			or bool(cell.dying)
			or bool(cell.consumed)
			or int(cell.engulfed_by_id) >= 0
			or String(cell.genome_event) == "refugia_wake"
		):
			continue
		var ecotype: int = int(cell.ecotype_id)
		var matched_index: int = -1
		for i in range(_refugia_bacteria.size()):
			if int(_refugia_bacteria[i].ecotype_id) == ecotype:
				matched_index = i
				break
		if matched_index >= 0:
			if _refugia_cell_score(cell) > _refugia_cell_score(_refugia_bacteria[matched_index]):
				_refugia_bacteria[matched_index] = cell
			continue
		if _refugia_bacteria.size() < REFUGIA_BACTERIA_BANK_LIMIT:
			_refugia_bacteria.append(cell)
			continue
		var weakest_index: int = 0
		var weakest_score: float = _refugia_cell_score(_refugia_bacteria[0])
		for i in range(1, _refugia_bacteria.size()):
			var score: float = _refugia_cell_score(_refugia_bacteria[i])
			if score < weakest_score:
				weakest_score = score
				weakest_index = i
		if _refugia_cell_score(cell) > weakest_score:
			_refugia_bacteria[weakest_index] = cell


func _refresh_refugia_memory() -> void:
	_refresh_bacterial_refugia()
	_refresh_guild_refugia(protozoa, 0)
	_refresh_guild_refugia(ciliates, 1)
	_refresh_guild_refugia(flagellates, 2)
	_refresh_guild_refugia(microalgae, 3)
	_refresh_guild_refugia(decomposers, 4)
	_refresh_guild_refugia(hyphae, 5)


func _refugia_position(parent: Variant, margin: float) -> Vector2:
	var position: Vector2 = (
		Vector2(parent.position)
		+ Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
		* rng.randf_range(4.0, 11.0)
	)
	position.x = clampf(position.x, margin, world_size.x - margin)
	position.y = clampf(position.y, margin, world_size.y - margin)
	return position


func _restore_refugium(kind: int, parent: Variant) -> bool:
	if parent == null:
		return false
	var child: Variant = null
	var position: Vector2
	match kind:
		0:
			position = _refugia_position(parent, 8.0)
			child = ProtozoanScript.new(_allocate_id(), position, rng.randf_range(-PI, PI), rng.randf_range(0.0, TAU))
			child.inherit_and_mutate(parent, rng)
			child.energy = 8.0
			protozoa.append(child)
		1:
			position = _refugia_position(parent, 7.0)
			child = CiliateScript.new(_allocate_id(), position, rng.randf_range(-PI, PI), rng.randf_range(0.0, TAU))
			child.inherit_and_mutate(parent, rng)
			child.energy = 6.5
			ciliates.append(child)
		2:
			position = _refugia_position(parent, 5.0)
			child = FlagellateScript.new(_allocate_id(), position, rng.randf_range(-PI, PI), rng.randf_range(0.0, TAU))
			child.inherit_and_mutate(parent, rng)
			child.energy = 4.1
			flagellates.append(child)
		3:
			position = _refugia_position(parent, 5.0)
			child = MicroalgaScript.new(_allocate_id(), position, rng.randf_range(-PI, PI), rng.randf_range(0.0, TAU))
			child.inherit_and_mutate(parent, rng)
			child.energy = 3.2
			microalgae.append(child)
		4:
			position = _refugia_position(parent, 5.0)
			child = DecomposerYeastScript.new(_allocate_id(), position, rng.randf_range(-PI, PI), rng.randf_range(0.0, TAU))
			child.inherit_and_mutate(parent, rng)
			child.energy = 3.0
			decomposers.append(child)
		5:
			position = _refugia_position(parent, 4.0)
			child = HyphalColonyScript.new(_allocate_id(), position, rng.randf_range(0.0, TAU))
			child.inherit_and_mutate(parent, rng)
			child.energy = 4.8
			hyphae.append(child)
		6:
			position = _refugia_position(parent, 4.0)
			child = BacteriumScript.new(
				_allocate_id(),
				position,
				rng.randf_range(-PI, PI),
				int(parent.generation),
				int(parent.id)
			)
			child.inherit_and_mutate(parent, rng)
			child.energy = 3.2
			child.length = maxf(
				minimum_length * float(child.gene_size),
				2.6 * float(child.gene_size)
			)
			child.sensed_memory = nutrient.sample_world(position)
			child.genome_event = "refugia_wake"
			bacteria.append(child)

	if child == null:
		return false

	# Germination/wake-up is not a reproductive generation. The inherited
	# phenotype may vary slightly, but generation counts advance only through
	# actual division/sporulation/budding.
	child.generation = int(parent.generation)
	refugia_recoveries_total += 1
	match kind:
		0: _event_inc("refugia_protozoa")
		1: _event_inc("refugia_ciliates")
		2: _event_inc("refugia_flagellates")
		3: _event_inc("refugia_algae")
		4: _event_inc("refugia_decomposers")
		5: _event_inc("refugia_hyphae")
		6:
			_event_inc("refugia_bacteria")
			_rebuild_bacteria_id_map()
	if "cooldown" in child:
		child.cooldown = 2.5
	return true


func _refugia_can_wake(kind: int) -> bool:
	var apex_pressure: int = protozoa.size() + ciliates.size()
	var all_predators: int = apex_pressure + flagellates.size()
	match kind:
		0:
			# Large grazers return only when the prey web can support more than
			# one individual; the hard safety ceiling is not the ecological target.
			return protozoa.is_empty() and _protozoan_carrying_capacity() >= 2
		1:
			return ciliates.is_empty() and _ciliate_carrying_capacity() >= 2
		2:
			return flagellates.is_empty() and _flagellate_carrying_capacity() >= 2
		3:
			# Producer cysts germinate when a real oxic producer niche exists.
			return (
				microalgae.is_empty()
				and producer_biomass.max_value() > 0.025
				and oxygen.max_value() > 0.10
			)
		4:
			# Decomposer spores respond to carrion/substrate rather than waiting
			# for every grazer to disappear.
			return (
				decomposers.is_empty()
				and detritus.max_value() > 0.040
			)
		5:
			return (
				hyphae.is_empty()
				and detritus.max_value() > 0.060
			)
		6:
			return bacteria.is_empty() and all_predators <= 4
	return false


func _try_wake_refugium(kind: int, parent: Variant) -> bool:
	if parent == null or not _refugia_can_wake(kind):
		return false
	if simulation_time < float(_refugia_next_wake[kind]):
		return false
	if not _restore_refugium(kind, parent):
		return false
	_refugia_next_wake[kind] = (
		simulation_time
		+ REFUGIA_WAKE_COOLDOWN * rng.randf_range(0.85, 1.20)
	)
	return true


func _try_wake_guild_bank(kind: int, requested: int) -> void:
	if not _refugia_can_wake(kind):
		return
	if simulation_time < float(_refugia_next_wake[kind]):
		return
	var templates: Array = _next_guild_refugia_templates(kind, requested)
	if templates.is_empty():
		return

	var woke_any: bool = false
	for parent in templates:
		if _restore_refugium(kind, parent):
			woke_any = true
	if woke_any:
		_refugia_next_wake[kind] = (
			simulation_time
			+ REFUGIA_WAKE_COOLDOWN * rng.randf_range(0.85, 1.20)
		)


func _try_wake_bacterial_bank(requested: int) -> void:
	if _refugia_bacteria.is_empty() or not _refugia_can_wake(6):
		return
	if simulation_time < float(_refugia_next_wake[6]):
		return

	var take: int = mini(requested, _refugia_bacteria.size())
	var woke_any: bool = false
	for offset in range(take):
		var parent: Variant = _refugia_bacteria[
			posmod(_refugia_bacteria_cursor + offset, _refugia_bacteria.size())
		]
		if _restore_refugium(6, parent):
			woke_any = true
	_refugia_bacteria_cursor += take
	if woke_any:
		_refugia_next_wake[6] = (
			simulation_time
			+ REFUGIA_WAKE_COOLDOWN * rng.randf_range(0.85, 1.20)
		)

func _maintain_ecological_refugia(dt: float) -> void:
	_refresh_refugia_memory()
	_refugia_accumulator += dt
	if _refugia_accumulator < REFUGIA_RECOVERY_INTERVAL:
		return
	_refugia_accumulator = fmod(_refugia_accumulator, REFUGIA_RECOVERY_INTERVAL)

	# Refugia preserve lineages through true active-population extinction.
	# They do not hold populations at an artificial floor.
	if bacteria.size() < REFUGIA_BACTERIA_MIN:
		_try_wake_bacterial_bank(2)
	if protozoa.size() < REFUGIA_PROTOZOA_MIN:
		_try_wake_guild_bank(0, 1)
	if ciliates.size() < REFUGIA_CILIATE_MIN:
		_try_wake_guild_bank(1, 1)
	if flagellates.size() < REFUGIA_FLAGELLATE_MIN:
		_try_wake_guild_bank(2, 1)
	if microalgae.size() < REFUGIA_MICROALGA_MIN:
		_try_wake_guild_bank(3, REFUGIA_BASAL_DIVERSITY_WAKE)
	if decomposers.size() < REFUGIA_DECOMPOSER_MIN:
		_try_wake_guild_bank(4, REFUGIA_BASAL_DIVERSITY_WAKE)
	if hyphae.size() < REFUGIA_HYPHA_MIN:
		_try_wake_guild_bank(5, REFUGIA_BASAL_DIVERSITY_WAKE)


func _apply_founder_niche(agent: Variant, family_code: int, index: int) -> void:
	# Seed several genuinely different strategies per guild. These are starting
	# conditions only: mutation and selection can merge, erase or split them.
	match family_code:
		0:
			match posmod(index, 6):
				0:
					agent.gene_speed *= 1.22
					agent.gene_chemotaxis *= 1.18
					agent.gene_growth *= 0.88
				1:
					agent.gene_adhesion *= 1.34
					agent.gene_dormancy *= 1.18
					agent.gene_speed *= 0.82
				2:
					agent.gene_uptake *= 1.28
					agent.gene_growth *= 0.92
					agent.gene_dormancy *= 1.12
				3:
					agent.gene_growth *= 1.26
					agent.gene_uptake *= 1.14
					agent.gene_dormancy *= 0.78
				4:
					agent.gene_dormancy *= 1.38
					agent.gene_growth *= 0.78
					agent.gene_competence *= 1.20
				5:
					agent.gene_size *= 1.22
					agent.gene_adhesion *= 1.22
					agent.gene_speed *= 0.86
		1:
			match posmod(index, 3):
				0:
					agent.gene_speed *= 1.24
					agent.gene_perception *= 1.16
					agent.gene_size *= 0.90
				1:
					agent.gene_engulf *= 1.28
					agent.gene_size *= 1.18
					agent.gene_speed *= 0.82
				2:
					agent.gene_perception *= 1.30
					agent.gene_metabolism *= 0.82
			agent.radius = 3.2 * float(agent.gene_size)
		2:
			if posmod(index, 2) == 0:
				agent.gene_speed *= 1.24
				agent.gene_perception *= 1.20
				agent.gene_capture *= 0.90
			else:
				agent.gene_capture *= 1.26
				agent.gene_size *= 1.14
				agent.gene_speed *= 0.88
			agent.radius = 2.4 * float(agent.gene_size)
		3:
			match posmod(index, 3):
				0:
					agent.gene_speed *= 1.24
					agent.gene_capture *= 0.90
				1:
					agent.gene_capture *= 1.24
					agent.gene_size *= 1.12
				2:
					agent.gene_metabolism *= 0.78
					agent.gene_perception *= 1.22
			agent.radius = 1.35 * float(agent.gene_size)
		4:
			match posmod(index, 4):
				0:
					agent.gene_light_use *= 1.28
					agent.gene_drift *= 0.80
				1:
					agent.gene_growth *= 1.24
					agent.gene_exudate *= 0.82
				2:
					agent.gene_exudate *= 1.34
					agent.gene_growth *= 0.88
				3:
					agent.gene_drift *= 1.30
					agent.gene_light_use *= 0.92
			agent.radius = 1.35 * float(agent.gene_size)
		5:
			match posmod(index, 3):
				0:
					agent.gene_detritus *= 1.30
					agent.gene_mineralize *= 0.86
				1:
					agent.gene_mineralize *= 1.30
					agent.gene_growth *= 0.88
				2:
					agent.gene_growth *= 1.22
					agent.gene_metabolism *= 1.08
			agent.radius = 1.55 * float(agent.gene_size)
		6:
			match posmod(index, 3):
				0:
					agent.gene_growth *= 1.24
					agent.gene_branch *= 0.86
				1:
					agent.gene_branch *= 1.30
					agent.gene_efficiency *= 0.90
				2:
					agent.gene_enzyme *= 1.30
					agent.gene_efficiency *= 1.16

	if family_code == 0:
		agent.refresh_motion_speed_cache()


func _allocate_id() -> int:
	var result: int = _next_id
	_next_id += 1
	return result


func _resolve_all_contacts() -> void:
	_rebuild_spatial_grid()

	if bacteria.size() > EXACT_MECHANICS_LIMIT:
		mechanics_mode_last = 1
		_resolve_density_contacts()
		for dense_cell in bacteria:
			_constrain_to_world(dense_cell)
		return

	mechanics_mode_last = 0
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


func _density_neighbor_visit_cap() -> int:
	return (
		DENSITY_NEIGHBOR_VISIT_CAP_ULTRA
		if bacteria.size() >= AGENT_ULTRA_THRESHOLD
		else DENSITY_NEIGHBOR_VISIT_CAP
	)


func _resolve_density_contacts() -> void:
	var count: int = bacteria.size()
	var visit_cap: int = _density_neighbor_visit_cap()
	_density_corrections.resize(count)
	_density_nearest.resize(count)
	_density_corrections.fill(Vector2.ZERO)
	_density_nearest.fill(-1)

	for i in range(count):
		if int(_mech_active[i]) == 0:
			continue

		var position: Vector2 = _mech_positions[i]
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
		var push := Vector2.ZERO
		var visited: int = 0
		var nearest_distance_sq: float = INF
		var radius_a: float = float(_mech_radii[i])

		for y in range(
			maxi(0, bucket_y - 1),
			mini(GRID_HEIGHT - 1, bucket_y + 1) + 1
		):
			var row: int = y * GRID_WIDTH
			for x in range(
				maxi(0, bucket_x - 1),
				mini(GRID_WIDTH - 1, bucket_x + 1) + 1
			):
				var j: int = _grid_head[row + x]
				while j >= 0:
					if j != i and int(_mech_active[j]) != 0:
						visited += 1
						pair_candidates_last += 1
						var delta: Vector2 = (
							position - _mech_positions[j]
						)
						var distance_sq: float = delta.length_squared()
						if distance_sq < nearest_distance_sq:
							nearest_distance_sq = distance_sq
							_density_nearest[i] = j

						var target: float = (
							radius_a
							+ float(_mech_radii[j])
							+ 0.34
						)
						if distance_sq < target * target:
							pair_narrow_checks_last += 1
							var distance: float = sqrt(
								maxf(distance_sq, 0.000001)
							)
							var normal: Vector2 = (
								delta / distance
								if distance > 0.001
								else _direction_for_angle(
									float(int(bacteria[i].id) % 360)
								)
							)
							push += normal * (target - distance) * 0.34
							pair_interactions_last += 1
							pair_contacts_last += 1
					if visited >= visit_cap:
						break
					j = _grid_next[j]
				if visited >= visit_cap:
					break
			if visited >= visit_cap:
				break

		_density_corrections[i] = push.limit_length(0.55)

	for i in range(count):
		var correction: Vector2 = _density_corrections[i]
		if correction.length_squared() > 0.0:
			bacteria[i].position = _mech_positions[i] + correction

		var neighbor_index: int = int(_density_nearest[i])
		if neighbor_index < 0 or neighbor_index <= i:
			continue
		var a: Variant = bacteria[i]
		var b: Variant = bacteria[neighbor_index]
		var center_distance: float = Vector2(a.position).distance_to(
			Vector2(b.position)
		)
		var contact_distance: float = (
			float(_mech_radii[i])
			+ float(_mech_radii[neighbor_index])
			+ 0.22
		)
		if center_distance <= contact_distance:
			_maybe_start_conjugation(
				a,
				b,
				center_distance,
				float(_mech_radii[i])
				+ float(_mech_radii[neighbor_index])
			)


func _rebuild_spatial_grid() -> void:
	_grid_head.fill(-1)
	var count: int = bacteria.size()
	_grid_next.resize(count)
	_grid_next.fill(-1)
	_mech_positions.resize(count)
	_mech_radii.resize(count)
	_mech_active.resize(count)
	_max_half_body_length = 0.0

	for i in range(count):
		var cell: Variant = bacteria[i]
		var position: Vector2 = Vector2(cell.position)
		_mech_positions[i] = position
		_mech_radii[i] = float(cell.radius)
		var active: bool = (
			not bool(cell.dying)
			and not bool(cell.consumed)
			and int(cell.engulfed_by_id) < 0
		)
		_mech_active[i] = 1 if active else 0
		if not active:
			continue

		_max_half_body_length = maxf(
			_max_half_body_length,
			float(cell.length) * 0.5
		)
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

	var axis_a: Vector2 = _direction_for_angle(float(a.angle))
	var axis_b: Vector2 = _direction_for_angle(float(b.angle))
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

func _reset_ecology_events() -> void:
	ecology_events = {
		"pred_proto_bacteria": 0,
		"pred_proto_ciliate": 0,
		"pred_proto_flagellate": 0,
		"pred_proto_algae": 0,
		"pred_proto_decomposer": 0,
		"pred_ciliate_bacteria": 0,
		"pred_ciliate_flagellate": 0,
		"pred_ciliate_algae": 0,
		"pred_ciliate_decomposer": 0,
		"pred_flagellate_bacteria": 0,
		"escape_proto": 0,
		"escape_ciliate": 0,
		"escape_flagellate": 0,
		"repro_bacteria": 0,
		"repro_protozoa": 0,
		"repro_ciliates": 0,
		"repro_flagellates": 0,
		"repro_algae": 0,
		"repro_decomposers": 0,
		"repro_hyphae": 0,
		"refugia_bacteria": 0,
		"refugia_protozoa": 0,
		"refugia_ciliates": 0,
		"refugia_flagellates": 0,
		"refugia_algae": 0,
		"refugia_decomposers": 0,
		"refugia_hyphae": 0,
		"disturbance_resource": 0,
		"disturbance_washout": 0,
		"disturbance_organic": 0,
	}


func _event_inc(name: String, amount: int = 1) -> void:
	ecology_events[name] = int(ecology_events.get(name, 0)) + amount


func ecology_event_metrics() -> Dictionary:
	return ecology_events.duplicate(true)


func _prey_event_kind(prey: Variant) -> String:
	if prey == null:
		return "unknown"
	var prey_script: Variant = prey.get_script()
	if prey_script == BacteriumScript:
		return "bacteria"
	if prey_script == CiliateScript:
		return "ciliate"
	if prey_script == FlagellateScript:
		return "flagellate"
	if prey_script == MicroalgaScript:
		return "algae"
	if prey_script == DecomposerYeastScript:
		return "decomposer"
	return "unknown"


func _record_predation(predator: String, prey: Variant) -> void:
	var prey_kind: String = _prey_event_kind(prey)
	var key: String = "pred_%s_%s" % [predator, prey_kind]
	if ecology_events.has(key):
		_event_inc(key)


func evolution_metrics() -> Dictionary:
	var ecotypes: Dictionary = {}
	var species: Dictionary = {}
	var species_by_family: Array[Dictionary] = [{}, {}, {}, {}, {}, {}, {}]
	var lineage_bins: Dictionary = {}
	var maximum_generation: int = 0
	var structural_total: int = 0
	var hgt_total: int = 0
	var transformation_total: int = 0
	var capability_mix_total: int = 0

	for cell in bacteria:
		if cell == null or bool(cell.consumed):
			continue
		ecotypes[int(cell.ecotype_id)] = true
		var bacterial_species: int = phenotype_species_id(cell, 0)
		species[bacterial_species] = true
		species_by_family[0][bacterial_species] = true
		lineage_bins[_lineage_bin(float(cell.lineage_hue))] = true
		maximum_generation = maxi(maximum_generation, int(cell.generation))
		structural_total += int(cell.structural_mutations)
		hgt_total += int(cell.hgt_events)
		transformation_total += int(cell.transformation_events)
		capability_mix_total += int(cell.capability_mix_events)

	var family_groups: Array = [protozoa, ciliates, flagellates, microalgae, decomposers, hyphae]
	for group_index in range(family_groups.size()):
		var group: Array = family_groups[group_index]
		var family_code: int = group_index + 1
		for organism in group:
			if organism == null:
				continue
			if "consumed" in organism and bool(organism.consumed):
				continue
			var organism_species: int = phenotype_species_id(organism, family_code)
			species[organism_species] = true
			species_by_family[family_code][organism_species] = true
			maximum_generation = maxi(maximum_generation, int(organism.generation))
			if "lineage_hue" in organism:
				lineage_bins[_lineage_bin(float(organism.lineage_hue))] = true
			if "capability_mix_events" in organism:
				capability_mix_total += int(organism.capability_mix_events)

	return {
		"ecotypes": ecotypes.size(),
		"species": species.size(),
		"species_bacteria": species_by_family[0].size(),
		"species_protozoa": species_by_family[1].size(),
		"species_ciliates": species_by_family[2].size(),
		"species_flagellates": species_by_family[3].size(),
		"species_algae": species_by_family[4].size(),
		"species_decomposers": species_by_family[5].size(),
		"species_hyphae": species_by_family[6].size(),
		"lineage_bins": lineage_bins.size(),
		"max_generation": maximum_generation,
		"structural_mutations": structural_total,
		"hgt_events": hgt_total,
		"transformations": transformation_total,
		"capability_mix_events": capability_mix_total,
		"refugia_recoveries": refugia_recoveries_total,
	}




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
	for flagellate in flagellates:
		if int(flagellate.feeding_target_id) >= 0:
			count += 1
	return count


func find_cell_by_id(cell_id: int) -> Variant:
	if _bacteria_by_id.has(cell_id):
		return _bacteria_by_id[cell_id]
	for cell in bacteria:
		if int(cell.id) == cell_id:
			_bacteria_by_id[cell_id] = cell
			return cell
	return null


func find_edible_by_id(organism_id: int) -> Variant:
	var cell: Variant = find_cell_by_id(organism_id)
	if cell != null:
		return cell
	if _edible_by_id.has(organism_id):
		return _edible_by_id[organism_id]
	for group in [ciliates, flagellates, microalgae, decomposers]:
		for organism in group:
			if int(organism.id) == organism_id:
				_edible_by_id[organism_id] = organism
				return organism
	return null


func state_signature() -> String:
	var parts := PackedStringArray()
	parts.append("t:%.5f" % simulation_time)
	parts.append("n:%d" % bacteria.size())
	parts.append("nut:%.5f" % nutrient.total())
	parts.append("waste:%.5f" % waste.total())
	parts.append("o2:%.5f" % oxygen.total())
	parts.append("det:%.5f" % detritus.total())
	parts.append("eps:%.5f" % eps.total())
	parts.append("cue:%.5f" % damage_cue.total())
	parts.append("prod:%.5f" % producer_biomass.total())
	parts.append("exu:%.5f" % exudate.total())
	parts.append("sig:%.5f" % quorum_signal.total())
	parts.append("enz:%.5f" % fungal_enzyme.total())
	parts.append("dna:%d" % dna_fragments.size())
	parts.append("phg:%d" % phage_clouds.size())
	parts.append(
		"dist:%d:%.3f:%d:%.3f:%.3f"
		% [
			disturbance_index,
			next_disturbance_time,
			last_disturbance_type,
			last_disturbance_position.x,
			last_disturbance_position.y,
		]
	)
	parts.append("p:%d" % protozoa.size())
	parts.append("c:%d" % ciliates.size())
	parts.append("f:%d" % flagellates.size())
	parts.append("a:%d" % microalgae.size())
	parts.append("y:%d" % decomposers.size())
	parts.append("h:%d" % hyphae.size())

	for cell in bacteria:
		parts.append(
			"%d:%d:gld%d:%.5f:%.5f:%.5f:%.5f:%.5f:%.4f:%.4f:%.4f:%.4f:%.4f:do%d:dt%.3f:%d:%.3f:%d:%.3f:pm%d:tr%d:tp%.3f:h%d:tf%d"
			% [
				int(cell.id),
				int(cell.generation),
				int(cell.guild),
				float(cell.position.x),
				float(cell.position.y),
				float(cell.angle),
				float(cell.length),
				float(cell.energy),
				float(cell.gene_speed),
				float(cell.gene_uptake),
				float(cell.gene_chemotaxis),
				float(cell.gene_dormancy),
				float(cell.gene_competence),
				1 if bool(cell.dormant) else 0,
				float(cell.dormant_time),
				1 if bool(cell.dividing) else 0,
				float(cell.division_progress),
				1 if bool(cell.dying) else 0,
				float(cell.lysis_progress),
				int(cell.plasmid_mask),
				int(cell.transfer_role),
				float(cell.transfer_progress),
				int(cell.hgt_events),
				int(cell.transformation_events),
			]
		)
		parts.append(
			"vi%d:vp%.3f:vl%d"
			% [
				1 if bool(cell.phage_infected) else 0,
				float(cell.phage_progress),
				1 if bool(cell.phage_triggered_lysis) else 0,
			]
		)
		parts.append(
			"eco%d:sm%d:gr%d:gm%s"
			% [
				int(cell.ecotype_id),
				int(cell.structural_mutations),
				int(cell.genome_recombination_events),
				String(cell.genome.compact_signature()) if cell.genome != null else "none",
			]
		)

	for proto in protozoa:
		parts.append(
			"p%d:g%d:%.5f:%.5f:%.5f:%.5f:%.4f:%.4f:%d:%.3f:d%d:lp%.3f"
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
				1 if bool(proto.dying) else 0,
				float(proto.lysis_progress),
			]
		)

	for ciliate in ciliates:
		parts.append(
			"c%d:g%d:%.5f:%.5f:%.5f:%.5f:%.4f:%.4f:%d:%.3f:d%d:lp%.3f:e%d:ep%.3f:x%d"
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
				1 if bool(ciliate.dying) else 0,
				float(ciliate.lysis_progress),
				int(ciliate.engulfed_by_id),
				float(ciliate.engulf_progress),
				1 if bool(ciliate.consumed) else 0,
			]
		)

	for flagellate in flagellates:
		parts.append(
			"f%d:g%d:%.5f:%.5f:%.5f:%.5f:%.4f:%.4f:%d:%.3f:d%d:lp%.3f:e%d:ep%.3f:x%d"
			% [
				int(flagellate.id),
				int(flagellate.generation),
				float(flagellate.position.x),
				float(flagellate.position.y),
				float(flagellate.angle),
				float(flagellate.energy),
				float(flagellate.gene_speed),
				float(flagellate.gene_capture),
				int(flagellate.feeding_target_id),
				float(flagellate.feeding_progress),
				1 if bool(flagellate.dying) else 0,
				float(flagellate.lysis_progress),
				int(flagellate.engulfed_by_id),
				float(flagellate.engulf_progress),
				1 if bool(flagellate.consumed) else 0,
			]
		)

	for alga in microalgae:
		parts.append(
			"a%d:g%d:%.5f:%.5f:%.5f:%.5f:r%d:rp%.3f:d%d:lp%.3f:e%d:ep%.3f:x%d"
			% [
				int(alga.id),
				int(alga.generation),
				float(alga.position.x),
				float(alga.position.y),
				float(alga.energy),
				float(alga.gene_light_use),
				1 if bool(alga.reproducing) else 0,
				float(alga.reproduction_progress),
				1 if bool(alga.dying) else 0,
				float(alga.lysis_progress),
				int(alga.engulfed_by_id),
				float(alga.engulf_progress),
				1 if bool(alga.consumed) else 0,
			]
		)

	for yeast in decomposers:
		parts.append(
			"y%d:g%d:%.5f:%.5f:%.5f:%.5f:b%d:bp%.3f:d%d:lp%.3f:e%d:ep%.3f:x%d"
			% [
				int(yeast.id),
				int(yeast.generation),
				float(yeast.position.x),
				float(yeast.position.y),
				float(yeast.energy),
				float(yeast.gene_detritus),
				1 if bool(yeast.budding) else 0,
				float(yeast.budding_progress),
				1 if bool(yeast.dying) else 0,
				float(yeast.lysis_progress),
				int(yeast.engulfed_by_id),
				float(yeast.engulf_progress),
				1 if bool(yeast.consumed) else 0,
			]
		)

	for colony in hyphae:
		parts.append(
			"h%d:g%d:%.4f:%.4f:n%d:t%d:d%d:lp%.3f"
			% [
				int(colony.id),
				int(colony.generation),
				float(colony.energy),
				float(colony.gene_enzyme),
				colony.nodes.size(),
				colony.tips.size(),
				1 if bool(colony.dying) else 0,
				float(colony.lysis_progress),
			]
		)
		for node_index in range(colony.nodes.size()):
			var node: Vector2 = colony.nodes[node_index]
			parts.append(
				"hn%d:%d:%.4f:%.4f:p%d"
				% [
					int(colony.id),
					node_index,
					node.x,
					node.y,
					int(colony.parents[node_index]),
				]
			)

	for cloud in phage_clouds:
		parts.append(
			"v%d:%.4f:%.4f:%.4f:%.3f:%.3f:g%d"
			% [
				int(cloud.id),
				float(cloud.position.x),
				float(cloud.position.y),
				float(cloud.host_hue),
				float(cloud.concentration),
				float(cloud.radius),
				int(cloud.burst_generation),
			]
		)

	for fragment in dna_fragments:
		parts.append(
			"dna%d:l%d:k%d:%.5f:%.5f:%.4f:%.3f"
			% [
				int(fragment.id),
				int(fragment.source_lineage_id),
				int(fragment.trait_kind),
				float(fragment.position.x),
				float(fragment.position.y),
				float(fragment.trait_value),
				float(fragment.age),
			]
		)

	return "|".join(parts)
