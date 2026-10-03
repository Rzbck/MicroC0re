class_name Protozoan
extends RefCounted

const PhysicalCapabilityGenomeScript = preload("res://src/simulation/physical_capability_genome.gd")

var id: int
var parent_id: int = -1
var lineage_id: int
var generation: int = 0

var position: Vector2
var angle: float
var radius: float = 3.2
var energy: float = 8.0
var age: float = 0.0
var alive: bool = true
var dying: bool = false
var lysis_progress: float = 0.0

# Hunting / engulfment state.
var target_id: int = -1
var feeding_target_id: int = -1
var feeding_progress: float = 0.0
var cooldown: float = 0.0

# Visual deformation state. Renderer reads this but does not control it.
var deform_phase: float = 0.0
var deform_amount: float = 0.0
var lineage_hue: float = 0.50

# Heritable predator phenotype.
var gene_speed: float = 1.0
var gene_perception: float = 1.0
var gene_engulf: float = 1.0
var gene_size: float = 1.0
var gene_metabolism: float = 1.0
var mutation_rate: float = 0.06


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
	deform_phase = p_phase


func is_feeding() -> bool:
	return feeding_target_id >= 0


func begin_engulf(target_cell_id: int) -> void:
	feeding_target_id = target_cell_id
	target_id = target_cell_id
	feeding_progress = 0.0


func finish_engulf() -> void:
	feeding_target_id = -1
	target_id = -1
	feeding_progress = 0.0
	cooldown = 0.65


func configure_founder(p_rng: RandomNumberGenerator) -> void:
	gene_speed = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.65, 1.45)
	gene_perception = clampf(1.0 + p_rng.randfn(0.0, 0.10), 0.65, 1.55)
	gene_engulf = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.70, 1.45)
	gene_size = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.78, 1.35)
	gene_metabolism = clampf(1.0 + p_rng.randfn(0.0, 0.06), 0.72, 1.35)
	mutation_rate = clampf(0.06 + p_rng.randfn(0.0, 0.01), 0.02, 0.14)
	radius = 3.2 * gene_size

	physical_genome = PhysicalCapabilityGenomeScript.new()
	physical_genome.configure_founder(p_rng, PhysicalCapabilityGenomeScript.PROFILE_PREDATOR)


func inherit_and_mutate(parent: Variant, p_rng: RandomNumberGenerator) -> void:
	parent_id = int(parent.id)
	lineage_id = int(parent.lineage_id)
	generation = int(parent.generation) + 1

	mutation_rate = _mutate_float(
		float(parent.mutation_rate), 0.008, 0.02, 0.14,
		float(parent.mutation_rate), p_rng
	)
	gene_speed = _mutate_float(
		float(parent.gene_speed), 0.055, 0.55, 1.65, mutation_rate, p_rng
	)
	gene_perception = _mutate_float(
		float(parent.gene_perception), 0.065, 0.50, 1.80, mutation_rate, p_rng
	)
	gene_engulf = _mutate_float(
		float(parent.gene_engulf), 0.055, 0.55, 1.70, mutation_rate, p_rng
	)
	gene_size = _mutate_float(
		float(parent.gene_size), 0.045, 0.72, 1.45, mutation_rate, p_rng
	)
	gene_metabolism = _mutate_float(
		float(parent.gene_metabolism), 0.050, 0.60, 1.55, mutation_rate, p_rng
	)
	lineage_hue = wrapf(
		float(parent.lineage_hue) + p_rng.randfn(0.0, 0.012 + mutation_rate * 0.03),
		0.0,
		1.0
	)
	deform_phase = p_rng.randf_range(0.0, TAU)
	radius = 3.2 * gene_size

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
