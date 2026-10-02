class_name Bacterium
extends RefCounted

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

# Life-cycle presentation states. Division remains resource-triggered; these
# values only make the resulting process observable instead of instantaneous.
var dividing: bool = false
var division_progress: float = 0.0
var dying: bool = false
var lysis_progress: float = 0.0
var adhesion_timer: float = 0.0

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
var mutation_rate: float = 0.08

# Heritable visual / mechanical appendages.
var flagella_count: int = 2
var flagella_length: float = 1.0
var pili_count: int = 4
var lineage_hue: float = 0.12

# Deterministic visual animation phase. Rendering may read this value but
# simulation behavior never depends on it.
var visual_phase: float = 0.0


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
	mutation_rate = clampf(0.08 + p_rng.randfn(0.0, 0.012), 0.025, 0.16)

	flagella_count = clampi(2 + p_rng.randi_range(-1, 1), 1, 4)
	flagella_length = clampf(1.0 + p_rng.randfn(0.0, 0.10), 0.65, 1.55)
	pili_count = clampi(4 + p_rng.randi_range(-2, 2), 1, 8)
	lineage_hue = p_rng.randf()
	visual_phase = p_rng.randf_range(0.0, TAU)

	_apply_size_phenotype()


func inherit_and_mutate(parent: Variant, p_rng: RandomNumberGenerator) -> void:
	lineage_id = int(parent.lineage_id)
	generation = int(parent.generation) + 1

	var inherited_rate: float = float(parent.mutation_rate)
	mutation_rate = clampf(
		_mutate_float(inherited_rate, 0.010, 0.02, 0.18, inherited_rate, p_rng),
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
		float(parent.lineage_hue) + p_rng.randfn(0.0, 0.008 + mutation_rate * 0.025),
		0.0,
		1.0
	)
	visual_phase = p_rng.randf_range(0.0, TAU)

	_apply_size_phenotype()


func begin_division() -> void:
	if dying or dividing:
		return
	dividing = true
	division_progress = 0.0


func begin_lysis() -> void:
	if dying:
		return
	dying = true
	alive = false
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
