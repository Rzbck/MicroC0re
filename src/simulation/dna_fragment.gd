class_name DNAFragment
extends RefCounted

const TRAIT_SPEED := 0
const TRAIT_CHEMOTAXIS := 1
const TRAIT_UPTAKE := 2
const TRAIT_GROWTH := 3
const TRAIT_SIZE := 4
const TRAIT_TUMBLE := 5
const TRAIT_ADHESION := 6
const TRAIT_DORMANCY := 7
const TRAIT_COUNT := 8

var id: int
var position: Vector2
var source_lineage_id: int
var source_hue: float
var trait_kind: int
var trait_value: float
var module_payload: Dictionary = {}
var age: float = 0.0
var lifetime: float = 18.0
var biomass: float = 0.035


func _init(
	p_id: int,
	p_position: Vector2,
	p_source_lineage_id: int,
	p_source_hue: float,
	p_trait_kind: int,
	p_trait_value: float,
	p_module_payload: Variant = null
) -> void:
	id = p_id
	position = p_position
	source_lineage_id = p_source_lineage_id
	source_hue = wrapf(p_source_hue, 0.0, 1.0)
	trait_kind = clampi(p_trait_kind, 0, TRAIT_COUNT - 1)
	trait_value = p_trait_value
	if p_module_payload is Dictionary:
		module_payload = (p_module_payload as Dictionary).duplicate(true)


func has_module_payload() -> bool:
	return not module_payload.is_empty()
