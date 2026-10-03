class_name Flagellate
extends RefCounted

var id: int
var parent_id: int = -1
var lineage_id: int
var generation: int = 0

var position: Vector2
var angle: float
var radius: float = 1.35
var energy: float = 4.4
var age: float = 0.0
var alive: bool = true
var dying: bool = false
var lysis_progress: float = 0.0

var target_id: int = -1
var feeding_target_id: int = -1
var feeding_progress: float = 0.0
var cooldown: float = 0.0
var swim_phase: float = 0.0

var engulfed_by_id: int = -1
var engulf_progress: float = 0.0
var consumed: bool = false

var gene_speed: float = 1.0
var gene_perception: float = 1.0
var gene_capture: float = 1.0
var gene_size: float = 1.0
var gene_metabolism: float = 1.0
var mutation_rate: float = 0.050
var lineage_hue: float = 0.15


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
	gene_speed = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.72, 1.50)
	gene_perception = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.68, 1.55)
	gene_capture = clampf(1.0 + p_rng.randfn(0.0, 0.07), 0.70, 1.50)
	gene_size = clampf(1.0 + p_rng.randfn(0.0, 0.05), 0.82, 1.25)
	gene_metabolism = clampf(1.0 + p_rng.randfn(0.0, 0.05), 0.75, 1.35)
	mutation_rate = clampf(0.050 + p_rng.randfn(0.0, 0.008), 0.018, 0.12)
	lineage_hue = wrapf(0.14 + p_rng.randfn(0.0, 0.030), 0.0, 1.0)
	radius = 1.35 * gene_size


func inherit_and_mutate(parent: Variant, p_rng: RandomNumberGenerator) -> void:
	parent_id = int(parent.id)
	lineage_id = int(parent.lineage_id)
	generation = int(parent.generation) + 1
	mutation_rate = _mutate(
		float(parent.mutation_rate), 0.006, 0.018, 0.12,
		float(parent.mutation_rate), p_rng
	)
	gene_speed = _mutate(
		float(parent.gene_speed), 0.050, 0.60, 1.75, mutation_rate, p_rng
	)
	gene_perception = _mutate(
		float(parent.gene_perception), 0.055, 0.55, 1.75, mutation_rate, p_rng
	)
	gene_capture = _mutate(
		float(parent.gene_capture), 0.050, 0.58, 1.70, mutation_rate, p_rng
	)
	gene_size = _mutate(
		float(parent.gene_size), 0.035, 0.76, 1.35, mutation_rate, p_rng
	)
	gene_metabolism = _mutate(
		float(parent.gene_metabolism), 0.040, 0.65, 1.45, mutation_rate, p_rng
	)
	lineage_hue = wrapf(
		float(parent.lineage_hue) + p_rng.randfn(0.0, 0.010),
		0.0,
		1.0
	)
	swim_phase = p_rng.randf_range(0.0, TAU)
	radius = 1.35 * gene_size


func begin_feed(target_cell_id: int) -> void:
	feeding_target_id = target_cell_id
	target_id = target_cell_id
	feeding_progress = 0.0


func finish_feed() -> void:
	feeding_target_id = -1
	target_id = -1
	feeding_progress = 0.0
	cooldown = 0.46


func begin_lysis() -> void:
	if dying:
		return
	dying = true
	alive = false
	lysis_progress = 0.0


func biomass_size() -> float:
	return maxf(0.1, radius * 1.85)


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
