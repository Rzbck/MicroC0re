class_name HyphalColony
extends RefCounted

const PhysicalCapabilityGenomeScript = preload("res://src/simulation/physical_capability_genome.gd")

var id: int
var parent_id: int = -1
var lineage_id: int
var generation: int = 0

var position: Vector2
var angle: float = 0.0
var radius: float = 2.0
var energy: float = 4.8
var age: float = 0.0
var alive: bool = true
var dying: bool = false
var lysis_progress: float = 0.0
var cooldown: float = 0.0
var visual_phase: float = 0.0
var growth_accumulator: float = 0.0
var dormant: bool = false
var dormant_time: float = 0.0

var nodes: Array[Vector2] = []
var parents: Array[int] = []
var tips: Array[int] = []

var gene_growth: float = 1.0
var gene_branch: float = 1.0
var gene_enzyme: float = 1.0
var gene_efficiency: float = 1.0
var gene_quiescence: float = 1.0
var mutation_rate: float = 0.040
var lineage_hue: float = 0.10


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

func _init(p_id: int, root: Vector2, p_phase: float = 0.0) -> void:
	id = p_id
	lineage_id = p_id
	position = root
	visual_phase = p_phase
	nodes.append(root)
	parents.append(-1)
	tips.append(0)


func configure_founder(p_rng: RandomNumberGenerator) -> void:
	gene_growth = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.68, 1.45)
	gene_branch = clampf(1.0 + p_rng.randfn(0.0, 0.10), 0.55, 1.60)
	gene_enzyme = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.62, 1.50)
	gene_efficiency = clampf(1.0 + p_rng.randfn(0.0, 0.07), 0.70, 1.45)
	gene_quiescence = clampf(1.0 + p_rng.randfn(0.0, 0.08), 0.55, 1.80)
	mutation_rate = clampf(0.060 + p_rng.randfn(0.0, 0.009), 0.020, 0.15)
	lineage_hue = wrapf(0.10 + p_rng.randfn(0.0, 0.025), 0.0, 1.0)

	physical_genome = PhysicalCapabilityGenomeScript.new()
	physical_genome.configure_founder(p_rng, PhysicalCapabilityGenomeScript.PROFILE_FILAMENTOUS)


func inherit_and_mutate(parent: Variant, p_rng: RandomNumberGenerator) -> void:
	parent_id = int(parent.id)
	lineage_id = int(parent.lineage_id)
	generation = int(parent.generation) + 1
	mutation_rate = _mutate(
		float(parent.mutation_rate), 0.008, 0.020, 0.15,
		float(parent.mutation_rate), p_rng
	)
	gene_growth = _mutate(
		float(parent.gene_growth), 0.055, 0.55, 1.60, mutation_rate, p_rng
	)
	gene_branch = _mutate(
		float(parent.gene_branch), 0.060, 0.45, 1.80, mutation_rate, p_rng
	)
	gene_enzyme = _mutate(
		float(parent.gene_enzyme), 0.055, 0.50, 1.70, mutation_rate, p_rng
	)
	gene_efficiency = _mutate(
		float(parent.gene_efficiency), 0.050, 0.55, 1.60, mutation_rate, p_rng
	)
	gene_quiescence = _mutate(
		float(parent.gene_quiescence), 0.055, 0.55, 1.80, mutation_rate, p_rng
	)
	lineage_hue = wrapf(
		float(parent.lineage_hue) + p_rng.randfn(0.0, 0.014 + mutation_rate * 0.032),
		0.0,
		1.0
	)

	physical_genome = PhysicalCapabilityGenomeScript.new()
	if parent.physical_genome != null:
		physical_genome.inherit_and_mutate(
			parent.physical_genome,
			p_rng,
			mutation_rate
		)
	else:
		physical_genome.configure_founder(p_rng, PhysicalCapabilityGenomeScript.PROFILE_FILAMENTOUS)
	carried_soil = 0.0
	burrow_depth = 0.0
	terrain_action_clock = 0.0
	terrain_action = "none"


func enter_dormancy() -> void:
	if dying:
		return
	dormant = true
	dormant_time = 0.0
	growth_accumulator = 0.0


func wake_from_dormancy() -> void:
	dormant = false
	dormant_time = 0.0
	growth_accumulator = 0.0


func add_node(parent_index: int, node_position: Vector2) -> int:
	if parent_index < 0 or parent_index >= nodes.size():
		return -1
	var index: int = nodes.size()
	nodes.append(node_position)
	parents.append(parent_index)
	tips.erase(parent_index)
	tips.append(index)
	position = _centroid()
	var delta: Vector2 = node_position - nodes[parent_index]
	if delta.length_squared() > 0.000001:
		angle = delta.angle()
	return index


func add_branch(parent_index: int, node_position: Vector2) -> int:
	if parent_index < 0 or parent_index >= nodes.size():
		return -1
	var index: int = nodes.size()
	nodes.append(node_position)
	parents.append(parent_index)
	if not tips.has(parent_index):
		tips.append(parent_index)
	tips.append(index)
	position = _centroid()
	return index


func begin_lysis() -> void:
	if dying:
		return
	dying = true
	alive = false
	dormant = false
	dormant_time = 0.0
	lysis_progress = 0.0


func biomass_size() -> float:
	return maxf(0.2, float(nodes.size()) * 0.28)


func _centroid() -> Vector2:
	if nodes.is_empty():
		return position
	var sum := Vector2.ZERO
	for node in nodes:
		sum += node
	return sum / float(nodes.size())


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
