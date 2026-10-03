class_name DecomposerYeast
extends RefCounted

const PhysicalCapabilityGenomeScript = preload("res://src/simulation/physical_capability_genome.gd")

var id: int
var parent_id: int = -1
var lineage_id: int
var generation: int = 0

var position: Vector2
var angle: float
var radius: float = 1.55
var energy: float = 2.8
var age: float = 0.0
var alive: bool = true
var dying: bool = false
var lysis_progress: float = 0.0

var budding: bool = false
var budding_progress: float = 0.0
var cooldown: float = 0.0

var engulfed_by_id: int = -1
var engulf_progress: float = 0.0
var consumed: bool = false

var gene_detritus: float = 1.0
var gene_mineralize: float = 1.0
var gene_growth: float = 1.0
var gene_size: float = 1.0
var gene_metabolism: float = 1.0
var mutation_rate: float = 0.045
var lineage_hue: float = 0.09
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
	visual_phase = p_phase


func configure_founder(p_rng: RandomNumberGenerator) -> void:
	gene_detritus = clampf(1.0 + p_rng.randfn(0.0, 0.09), 0.65, 1.55)
	gene_mineralize = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.60, 1.60)
	gene_growth = clampf(1.0 + p_rng.randfn(0.0, 0.06), 0.70, 1.45)
	gene_size = clampf(1.0 + p_rng.randfn(0.0, 0.06), 0.78, 1.35)
	gene_metabolism = clampf(1.0 + p_rng.randfn(0.0, 0.05), 0.75, 1.35)
	mutation_rate = clampf(0.045 + p_rng.randfn(0.0, 0.008), 0.015, 0.12)
	lineage_hue = wrapf(0.08 + p_rng.randfn(0.0, 0.030), 0.0, 1.0)
	visual_phase = p_rng.randf_range(0.0, TAU)
	radius = 1.55 * gene_size

	physical_genome = PhysicalCapabilityGenomeScript.new()
	physical_genome.configure_founder(p_rng, PhysicalCapabilityGenomeScript.PROFILE_DECOMPOSER)


func inherit_and_mutate(parent: Variant, p_rng: RandomNumberGenerator) -> void:
	parent_id = int(parent.id)
	lineage_id = int(parent.lineage_id)
	generation = int(parent.generation) + 1
	mutation_rate = _mutate(
		float(parent.mutation_rate), 0.006, 0.015, 0.12,
		float(parent.mutation_rate), p_rng
	)
	gene_detritus = _mutate(
		float(parent.gene_detritus), 0.055, 0.50, 1.80, mutation_rate, p_rng
	)
	gene_mineralize = _mutate(
		float(parent.gene_mineralize), 0.050, 0.50, 1.80, mutation_rate, p_rng
	)
	gene_growth = _mutate(
		float(parent.gene_growth), 0.045, 0.55, 1.65, mutation_rate, p_rng
	)
	gene_size = _mutate(
		float(parent.gene_size), 0.040, 0.70, 1.50, mutation_rate, p_rng
	)
	gene_metabolism = _mutate(
		float(parent.gene_metabolism), 0.040, 0.65, 1.45, mutation_rate, p_rng
	)
	lineage_hue = wrapf(
		float(parent.lineage_hue) + p_rng.randfn(0.0, 0.010),
		0.0,
		1.0
	)
	visual_phase = p_rng.randf_range(0.0, TAU)
	radius = 1.55 * gene_size

	physical_genome = PhysicalCapabilityGenomeScript.new()
	if parent.physical_genome != null:
		physical_genome.inherit_and_mutate(
			parent.physical_genome,
			p_rng,
			mutation_rate
		)
	else:
		physical_genome.configure_founder(p_rng, PhysicalCapabilityGenomeScript.PROFILE_DECOMPOSER)
	carried_soil = 0.0
	burrow_depth = 0.0
	terrain_action_clock = 0.0
	terrain_action = "none"


func begin_budding() -> void:
	if dying or budding or consumed or engulfed_by_id >= 0:
		return
	budding = true
	budding_progress = 0.0


func begin_lysis() -> void:
	if dying:
		return
	dying = true
	alive = false
	budding = false
	budding_progress = 0.0
	lysis_progress = 0.0


func biomass_size() -> float:
	return maxf(0.1, radius * 2.0)


func _mutate(
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
