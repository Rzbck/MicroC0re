class_name Microalga
extends RefCounted

const PhysicalCapabilityGenomeScript = preload("res://src/simulation/physical_capability_genome.gd")

var id: int
var parent_id: int = -1
var lineage_id: int
var generation: int = 0

var position: Vector2
var angle: float
var radius: float = 1.35
var energy: float = 3.2
var age: float = 0.0
var alive: bool = true
var dying: bool = false
var lysis_progress: float = 0.0

var reproducing: bool = false
var reproduction_progress: float = 0.0
var cooldown: float = 0.0

var engulfed_by_id: int = -1
var engulf_progress: float = 0.0
var consumed: bool = false

var gene_light_use: float = 1.0
var gene_growth: float = 1.0
var gene_size: float = 1.0
var gene_exudate: float = 1.0
var gene_drift: float = 1.0
var mutation_rate: float = 0.045
var lineage_hue: float = 0.31
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
	p_phase: float = 0.0
) -> void:
	id = p_id
	lineage_id = p_id
	position = p_position
	angle = p_angle
	visual_phase = p_phase


func configure_founder(p_rng: RandomNumberGenerator) -> void:
	gene_light_use = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.70, 1.45)
	gene_growth = clampf(1.0 + p_rng.randfn(0.0, 0.06), 0.70, 1.40)
	gene_size = clampf(1.0 + p_rng.randfn(0.0, 0.06), 0.78, 1.35)
	gene_exudate = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.65, 1.55)
	gene_drift = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.60, 1.45)
	mutation_rate = clampf(0.065 + p_rng.randfn(0.0, 0.011), 0.020, 0.16)
	lineage_hue = wrapf(0.28 + p_rng.randfn(0.0, 0.035), 0.0, 1.0)
	visual_phase = p_rng.randf_range(0.0, TAU)
	radius = 1.35 * gene_size

	physical_genome = PhysicalCapabilityGenomeScript.new()
	physical_genome.configure_founder(p_rng, PhysicalCapabilityGenomeScript.PROFILE_PRODUCER)


func inherit_and_mutate(parent: Variant, p_rng: RandomNumberGenerator) -> void:
	parent_id = int(parent.id)
	lineage_id = int(parent.lineage_id)
	generation = int(parent.generation) + 1
	mutation_rate = _mutate(
		float(parent.mutation_rate), 0.009, 0.020, 0.16,
		float(parent.mutation_rate), p_rng
	)
	gene_light_use = _mutate(
		float(parent.gene_light_use), 0.050, 0.55, 1.70, mutation_rate, p_rng
	)
	gene_growth = _mutate(
		float(parent.gene_growth), 0.045, 0.55, 1.60, mutation_rate, p_rng
	)
	gene_size = _mutate(
		float(parent.gene_size), 0.040, 0.70, 1.50, mutation_rate, p_rng
	)
	gene_exudate = _mutate(
		float(parent.gene_exudate), 0.050, 0.50, 1.80, mutation_rate, p_rng
	)
	gene_drift = _mutate(
		float(parent.gene_drift), 0.045, 0.50, 1.65, mutation_rate, p_rng
	)
	lineage_hue = wrapf(
		float(parent.lineage_hue) + p_rng.randfn(0.0, 0.016 + mutation_rate * 0.035),
		0.0,
		1.0
	)
	visual_phase = p_rng.randf_range(0.0, TAU)
	radius = 1.35 * gene_size

	physical_genome = PhysicalCapabilityGenomeScript.new()
	if parent.physical_genome != null:
		physical_genome.inherit_and_mutate(
			parent.physical_genome,
			p_rng,
			mutation_rate
		)
	else:
		physical_genome.configure_founder(p_rng, PhysicalCapabilityGenomeScript.PROFILE_PRODUCER)
	carried_soil = 0.0
	burrow_depth = 0.0
	terrain_action_clock = 0.0
	terrain_action = "none"


func begin_reproduction() -> void:
	if dying or reproducing or consumed or engulfed_by_id >= 0:
		return
	reproducing = true
	reproduction_progress = 0.0


func begin_lysis() -> void:
	if dying:
		return
	dying = true
	alive = false
	reproducing = false
	reproduction_progress = 0.0
	lysis_progress = 0.0


func biomass_size() -> float:
	return maxf(0.1, radius * 1.8)


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
