class_name Ciliate
extends RefCounted

const PhysicalCapabilityGenomeScript = preload("res://src/simulation/physical_capability_genome.gd")

var id: int
var parent_id: int = -1
var lineage_id: int
var generation: int = 0

var position: Vector2
var angle: float
var radius: float = 2.4
var energy: float = 7.0
var age: float = 0.0
var alive: bool = true
var dying: bool = false
var lysis_progress: float = 0.0

var target_id: int = -1
var feeding_target_id: int = -1
var feeding_progress: float = 0.0
var cooldown: float = 0.0
var swim_phase: float = 0.0

# Larger amoeboid predators may capture ciliates. The ciliate remains visible
# during the staged engulfment rather than disappearing on contact.
var engulfed_by_id: int = -1
var engulf_progress: float = 0.0
var consumed: bool = false

# Heritable phenotype.
var gene_speed: float = 1.0
var gene_perception: float = 1.0
var gene_capture: float = 1.0
var gene_size: float = 1.0
var gene_metabolism: float = 1.0
var mutation_rate: float = 0.055
var lineage_hue: float = 0.68


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
	p_phase: float = 0.0
) -> void:
	id = p_id
	lineage_id = p_id
	position = p_position
	angle = p_angle
	swim_phase = p_phase


func configure_founder(p_rng: RandomNumberGenerator) -> void:
	gene_speed = clampf(1.0 + p_rng.randfn(0.0, 0.09), 0.70, 1.55)
	gene_perception = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.70, 1.55)
	gene_capture = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.70, 1.50)
	gene_size = clampf(1.0 + p_rng.randfn(0.0, 0.06), 0.82, 1.30)
	gene_metabolism = clampf(1.0 + p_rng.randfn(0.0, 0.05), 0.75, 1.35)
	mutation_rate = clampf(0.055 + p_rng.randfn(0.0, 0.009), 0.02, 0.12)
	lineage_hue = wrapf(0.66 + p_rng.randfn(0.0, 0.025), 0.0, 1.0)
	radius = 2.4 * gene_size

	physical_genome = PhysicalCapabilityGenomeScript.new()
	physical_genome.configure_founder(p_rng, PhysicalCapabilityGenomeScript.PROFILE_PREDATOR)


func inherit_and_mutate(parent: Variant, p_rng: RandomNumberGenerator) -> void:
	parent_id = int(parent.id)
	lineage_id = int(parent.lineage_id)
	generation = int(parent.generation) + 1

	mutation_rate = _mutate_float(
		float(parent.mutation_rate), 0.007, 0.02, 0.12,
		float(parent.mutation_rate), p_rng
	)
	gene_speed = _mutate_float(
		float(parent.gene_speed), 0.055, 0.60, 1.80, mutation_rate, p_rng
	)
	gene_perception = _mutate_float(
		float(parent.gene_perception), 0.055, 0.60, 1.75, mutation_rate, p_rng
	)
	gene_capture = _mutate_float(
		float(parent.gene_capture), 0.050, 0.60, 1.70, mutation_rate, p_rng
	)
	gene_size = _mutate_float(
		float(parent.gene_size), 0.040, 0.78, 1.40, mutation_rate, p_rng
	)
	gene_metabolism = _mutate_float(
		float(parent.gene_metabolism), 0.045, 0.65, 1.50, mutation_rate, p_rng
	)
	lineage_hue = wrapf(
		float(parent.lineage_hue) + p_rng.randfn(0.0, 0.010 + mutation_rate * 0.025),
		0.0,
		1.0
	)
	swim_phase = p_rng.randf_range(0.0, TAU)
	radius = 2.4 * gene_size

	physical_genome = PhysicalCapabilityGenomeScript.new()
	if parent.physical_genome != null:
		physical_genome.inherit_and_mutate(
			parent.physical_genome,
			p_rng,
			mutation_rate
		)
	else:
		physical_genome.configure_founder(p_rng, PhysicalCapabilityGenomeScript.PROFILE_PREDATOR)
	carried_soil = 0.0
	burrow_depth = 0.0
	terrain_action_clock = 0.0
	terrain_action = "none"


func begin_feed(target_cell_id: int) -> void:
	feeding_target_id = target_cell_id
	target_id = target_cell_id
	feeding_progress = 0.0


func finish_feed() -> void:
	feeding_target_id = -1
	target_id = -1
	feeding_progress = 0.0
	cooldown = 0.38


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


func begin_lysis() -> void:
	if dying:
		return
	dying = true
	alive = false
	lysis_progress = 0.0


func biomass_size() -> float:
	return maxf(0.1, radius * 2.2)
