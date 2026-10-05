class_name Bacterium
extends RefCounted

const PhysicalCapabilityGenomeScript = preload("res://src/simulation/physical_capability_genome.gd")

const EvolvableGenomeScript = preload("res://src/simulation/evolvable_genome.gd")

const PLASMID_CONJUGATION := 1
const PLASMID_SCAVENGE := 2
const PLASMID_ADHESION := 4
const PLASMID_STRESS := 8

const TRANSFER_NONE := 0
const TRANSFER_DONOR := 1
const TRANSFER_RECIPIENT := 2

const GUILD_HETEROTROPH := 0
const GUILD_SCAVENGER := 1
const GUILD_BIOFILM := 2
const GUILD_PHOTOTROPH := 3

var id: int
var parent_id: int
var lineage_id: int
var generation: int

var position: Vector2
var angle: float
var length: float = 2.4
var radius: float = 0.50

var energy: float = 3.0
var age: float = 0.0
var alive: bool = true
var guild: int = GUILD_HETEROTROPH

# Life-cycle presentation states. Division remains resource-triggered; these
# values only make the resulting process observable instead of instantaneous.
var dividing: bool = false
var division_progress: float = 0.0
var dying: bool = false
var lysis_progress: float = 0.0
var adhesion_timer: float = 0.0

# Reversible phenotype state: starving cells may enter a low-metabolism
# dormant/persister-like state without changing genotype.
var dormant: bool = false
var dormant_time: float = 0.0
var competent: bool = false

# Bounded bacteriophage infection state. Viral particles are represented by
# cloud packets in the simulation, while the host keeps only its latent state.
var phage_infected: bool = false
var phage_progress: float = 0.0
var phage_host_hue: float = 0.0
var phage_source_id: int = -1
var phage_triggered_lysis: bool = false

# Engulfment is used by the amoeboid/protist class. The bacterium remains
# visible while it is being pulled inside the predator; completion removes it
# without pretending that ordinary bacteria "fuse" together.
var engulfed_by_id: int = -1
var engulf_progress: float = 0.0
var consumed: bool = false

# Temporal memory used by run-and-tumble chemotaxis.
var sensed_memory: float = 0.0

# Heritable phenotype. Values near 1.0 are the founder baseline.
var gene_speed: float = 1.0
var gene_chemotaxis: float = 1.0
var gene_uptake: float = 1.0
var gene_growth: float = 1.0
var gene_size: float = 1.0
var gene_tumble: float = 1.0
var gene_adhesion: float = 1.0
var gene_dormancy: float = 1.0
var gene_competence: float = 1.0
var mutation_rate: float = 0.08

# Variable-length ecological genome. The scalar genes above remain quantitative
# morphology/motility alleles; this program can duplicate/delete/rewire
# ecological modules and is the first open-ended genotype layer.
var genome: Variant = null
var ecotype_id: int = 0
var ecotype_label: String = "generalist"

# Coarse phenotype-species identity is cold derived state. It is cached so hot
# population/render loops do not repeatedly reread and quantize many genes.
var phenotype_species_cache: int = -1
var phenotype_species_dirty: bool = true

# Derived hot-motion coefficient. Recomputed only when heritable morphology or
# regulated ecological expression changes.
var motion_speed_base: float = 1.0
var genome_event: String = "founder"
var structural_mutations: int = 0
var genome_recombination_events: int = 0

# Current environmentally regulated expression; kept for rendering/inspection
# and avoids reevaluating the program outside the simulation step.
var expression_nutrient: float = 1.0
var expression_exudate: float = 0.5
var expression_detritus: float = 0.0
var expression_photo: float = 0.0
var expression_matrix: float = 0.0
var expression_quorum: float = 0.2

# Heritable visual / mechanical appendages.
var flagella_count: int = 2
var flagella_length: float = 1.0
var pili_count: int = 4
var lineage_hue: float = 0.12

# Mobile genetic elements. These are qualitative plasmid modules used to
# model horizontal gene transfer by direct-contact conjugation.
var plasmid_mask: int = 0
var transfer_role: int = TRANSFER_NONE
var transfer_partner_id: int = -1
var transfer_progress: float = 0.0
var hgt_events: int = 0
var transformation_events: int = 0

# Deterministic visual animation phase. Rendering may read this value but
# simulation behavior never depends on it.
var visual_phase: float = 0.0


var physical_genome: Variant = null
var carried_soil: float = 0.0
var burrow_depth: float = 0.0
var terrain_action_clock: float = 0.0
var terrain_action: String = "none"
var physical_dig: float = 0.0
var physical_deposit: float = 0.0
var physical_burrow: float = 0.0
var physical_climb: float = 0.0
var physical_oviposit: float = 0.0
var physical_armor: float = 0.0
var capability_mix_events: int = 0

func _init(
	p_id: int,
	p_position: Vector2,
	p_angle: float,
	p_generation: int = 0,
	p_parent_id: int = -1
) -> void:
	id = p_id
	position = p_position
	angle = p_angle
	generation = p_generation
	parent_id = p_parent_id
	lineage_id = p_id


func configure_founder(p_rng: RandomNumberGenerator) -> void:
	gene_speed = clampf(1.0 + p_rng.randfn(0.0, 0.07), 0.70, 1.35)
	gene_chemotaxis = clampf(1.0 + p_rng.randfn(0.0, 0.09), 0.55, 1.55)
	gene_uptake = clampf(1.0 + p_rng.randfn(0.0, 0.07), 0.65, 1.45)
	gene_growth = clampf(1.0 + p_rng.randfn(0.0, 0.06), 0.70, 1.35)
	gene_size = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.72, 1.35)
	gene_tumble = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.60, 1.45)
	gene_adhesion = clampf(1.0 + p_rng.randfn(0.0, 0.12), 0.45, 1.70)
	gene_dormancy = clampf(1.0 + p_rng.randfn(0.0, 0.10), 0.55, 1.60)
	gene_competence = clampf(1.0 + p_rng.randfn(0.0, 0.12), 0.40, 1.70)
	mutation_rate = clampf(0.11 + p_rng.randfn(0.0, 0.016), 0.030, 0.22)

	flagella_count = clampi(2 + p_rng.randi_range(-1, 1), 1, 4)
	flagella_length = clampf(1.0 + p_rng.randfn(0.0, 0.10), 0.65, 1.55)
	pili_count = clampi(4 + p_rng.randi_range(-2, 2), 1, 8)

	# A minority of founders carry conjugative plasmids. Payload modules are
	# sparse so useful traits can spread horizontally during the run.
	if p_rng.randf() < 0.18:
		plasmid_mask |= PLASMID_CONJUGATION
		var cargo_roll: int = p_rng.randi_range(0, 2)
		if cargo_roll == 0:
			plasmid_mask |= PLASMID_SCAVENGE
		elif cargo_roll == 1:
			plasmid_mask |= PLASMID_ADHESION
		else:
			plasmid_mask |= PLASMID_STRESS
		pili_count = maxi(pili_count, 4)

	lineage_hue = p_rng.randf()
	visual_phase = p_rng.randf_range(0.0, TAU)

	genome = EvolvableGenomeScript.new()
	genome.configure_founder(p_rng)
	guild = int(genome.baseline_guild())
	ecotype_id = int(genome.ecotype_hash())
	ecotype_label = "founder"
	genome_event = String(genome.last_event)
	structural_mutations = 0
	genome_recombination_events = 0
	phenotype_species_dirty = true

	_apply_size_phenotype()
	refresh_motion_speed_cache()

	physical_genome = PhysicalCapabilityGenomeScript.new()
	physical_genome.configure_founder(p_rng, PhysicalCapabilityGenomeScript.PROFILE_MICROBE)


func inherit_and_mutate(parent: Variant, p_rng: RandomNumberGenerator) -> void:
	lineage_id = int(parent.lineage_id)
	generation = int(parent.generation) + 1
	guild = int(parent.guild)
	plasmid_mask = int(parent.plasmid_mask)
	transfer_role = TRANSFER_NONE
	transfer_partner_id = -1
	transfer_progress = 0.0
	hgt_events = 0
	transformation_events = 0
	competent = false
	phage_infected = false
	phage_progress = 0.0
	phage_host_hue = 0.0
	phage_source_id = -1
	phage_triggered_lysis = false
	genome_recombination_events = int(parent.genome_recombination_events)

	var inherited_rate: float = float(parent.mutation_rate)
	mutation_rate = clampf(
		_mutate_float(inherited_rate, 0.014, 0.025, 0.24, inherited_rate, p_rng),
		0.02,
		0.18
	)

	gene_speed = _mutate_float(
		float(parent.gene_speed), 0.055, 0.55, 1.70, mutation_rate, p_rng
	)
	gene_chemotaxis = _mutate_float(
		float(parent.gene_chemotaxis), 0.070, 0.35, 2.00, mutation_rate, p_rng
	)
	gene_uptake = _mutate_float(
		float(parent.gene_uptake), 0.055, 0.50, 1.80, mutation_rate, p_rng
	)
	gene_growth = _mutate_float(
		float(parent.gene_growth), 0.050, 0.55, 1.65, mutation_rate, p_rng
	)
	gene_size = _mutate_float(
		float(parent.gene_size), 0.045, 0.65, 1.55, mutation_rate, p_rng
	)
	gene_tumble = _mutate_float(
		float(parent.gene_tumble), 0.060, 0.40, 1.80, mutation_rate, p_rng
	)
	gene_adhesion = _mutate_float(
		float(parent.gene_adhesion), 0.070, 0.30, 2.00, mutation_rate, p_rng
	)
	gene_dormancy = _mutate_float(
		float(parent.gene_dormancy), 0.060, 0.45, 1.80, mutation_rate, p_rng
	)
	gene_competence = _mutate_float(
		float(parent.gene_competence), 0.065, 0.30, 1.90, mutation_rate, p_rng
	)
	flagella_length = _mutate_float(
		float(parent.flagella_length), 0.060, 0.55, 1.80, mutation_rate, p_rng
	)

	flagella_count = _mutate_count(
		int(parent.flagella_count), 1, 6, mutation_rate * 1.35, p_rng
	)
	pili_count = _mutate_count(
		int(parent.pili_count), 0, 10, mutation_rate * 1.15, p_rng
	)

	lineage_hue = wrapf(
		float(parent.lineage_hue) + p_rng.randfn(0.0, 0.014 + mutation_rate * 0.045),
		0.0,
		1.0
	)
	visual_phase = p_rng.randf_range(0.0, TAU)

	genome = EvolvableGenomeScript.new()
	if parent.genome != null:
		genome.inherit_and_mutate(parent.genome, p_rng, mutation_rate)
	else:
		genome.configure_founder(p_rng)
	structural_mutations = (
		int(parent.structural_mutations)
		+ int(genome.last_structural_changes)
	)
	genome_event = String(genome.last_event)
	ecotype_id = int(genome.ecotype_hash())
	guild = int(genome.baseline_guild())
	phenotype_species_dirty = true

	_apply_size_phenotype()
	refresh_motion_speed_cache()

	physical_genome = PhysicalCapabilityGenomeScript.new()
	if parent.physical_genome != null:
		physical_genome.inherit_and_mutate(
			parent.physical_genome,
			p_rng,
			mutation_rate
		)
	else:
		physical_genome.configure_founder(p_rng, PhysicalCapabilityGenomeScript.PROFILE_MICROBE)
	carried_soil = 0.0
	burrow_depth = 0.0
	terrain_action_clock = 0.0
	terrain_action = "none"


func refresh_motion_speed_cache() -> void:
	var flagella_propulsion: float = (
		0.66
		+ 0.085 * float(flagella_count)
		+ 0.15 * float(flagella_length)
	)
	var size_drag: float = 0.84 + 0.20 * float(gene_size)
	var ecological_drag: float = clampf(
		1.0
		- float(expression_matrix) * 0.17
		- float(expression_photo) * 0.07
		- float(expression_detritus) * 0.035,
		0.52,
		1.0
	)
	motion_speed_base = (
		float(gene_speed)
		* ecological_drag
		* flagella_propulsion
		/ maxf(0.001, size_drag)
	)


func integrate_genome_module(
	module_data: Dictionary,
	p_rng: RandomNumberGenerator
) -> bool:
	if genome == null:
		genome = EvolvableGenomeScript.new()
		genome.configure_founder(p_rng)
	var changed: bool = bool(genome.integrate_module(module_data, p_rng))
	if changed:
		genome_recombination_events += 1
		structural_mutations += int(genome.last_structural_changes)
		genome_event = String(genome.last_event)
		ecotype_id = int(genome.ecotype_hash())
		phenotype_species_dirty = true
	return changed


func guild_name() -> String:
	match guild:
		GUILD_SCAVENGER:
			return "scavenger"
		GUILD_BIOFILM:
			return "biofilm"
		GUILD_PHOTOTROPH:
			return "phototroph"
		_:
			return "heterotroph"


func has_plasmid(module_bit: int) -> bool:
	return (plasmid_mask & module_bit) != 0


func plasmid_names() -> String:
	var names := PackedStringArray()
	if has_plasmid(PLASMID_CONJUGATION):
		names.append("conjugation")
	if has_plasmid(PLASMID_SCAVENGE):
		names.append("scavenge")
	if has_plasmid(PLASMID_ADHESION):
		names.append("adhesion")
	if has_plasmid(PLASMID_STRESS):
		names.append("stress")
	if names.is_empty():
		return "none"
	return ", ".join(names)


func clear_transfer_state() -> void:
	transfer_role = TRANSFER_NONE
	transfer_partner_id = -1
	transfer_progress = 0.0


func begin_division() -> void:
	if (
		dying
		or dividing
		or dormant
		or phage_infected
		or transfer_role != TRANSFER_NONE
	):
		return
	dividing = true
	division_progress = 0.0


func begin_lysis() -> void:
	if dying:
		return
	dying = true
	alive = false
	dormant = false
	dormant_time = 0.0
	competent = false
	clear_transfer_state()
	dividing = false
	division_progress = 0.0
	lysis_progress = 0.0


func _mutate_float(
	value: float,
	sigma: float,
	minimum: float,
	maximum: float,
	probability: float,
	p_rng: RandomNumberGenerator
) -> float:
	var result: float = value
	if p_rng.randf() < probability:
		result += p_rng.randfn(0.0, sigma)
	return clampf(result, minimum, maximum)


func _mutate_count(
	value: int,
	minimum: int,
	maximum: int,
	probability: float,
	p_rng: RandomNumberGenerator
) -> int:
	var result: int = value
	if p_rng.randf() < probability:
		result += -1 if p_rng.randf() < 0.5 else 1
	return clampi(result, minimum, maximum)


func _apply_size_phenotype() -> void:
	radius = clampf(0.34 + 0.16 * gene_size, 0.42, 0.63)


func biomass_size() -> float:
	return maxf(0.1, length)


func axis() -> Vector2:
	return Vector2.RIGHT.rotated(angle)


func normal() -> Vector2:
	return axis().orthogonal()


func centerline_half_length() -> float:
	return maxf(0.0, (length - 2.0 * radius) * 0.5)


func segment_start() -> Vector2:
	return position - axis() * centerline_half_length()


func segment_end() -> Vector2:
	return position + axis() * centerline_half_length()


func phenotype_color() -> Color:
	return Color.from_hsv(
		wrapf(lineage_hue, 0.0, 1.0),
		0.58,
		0.96
	)
