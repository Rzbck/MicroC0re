class_name Protozoan
extends RefCounted

var id: int
var position: Vector2
var angle: float
var radius: float = 3.2
var energy: float = 8.0
var age: float = 0.0

# Hunting / engulfment state.
var target_id: int = -1
var feeding_target_id: int = -1
var feeding_progress: float = 0.0
var cooldown: float = 0.0

# Visual deformation state. Renderer reads this but does not control it.
var deform_phase: float = 0.0
var deform_amount: float = 0.0
var lineage_hue: float = 0.50


func _init(
	p_id: int,
	p_position: Vector2,
	p_angle: float,
	p_phase: float = 0.0
) -> void:
	id = p_id
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
