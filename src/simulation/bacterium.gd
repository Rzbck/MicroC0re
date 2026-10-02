class_name Bacterium
extends RefCounted

var id: int
var parent_id: int
var generation: int

var position: Vector2
var angle: float
var length: float = 2.4
var radius: float = 0.45

var energy: float = 3.0
var age: float = 0.0
var alive: bool = true

# Exponentially filtered concentration memory used for temporal chemotaxis.
var sensed_memory: float = 0.0


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


func axis() -> Vector2:
	return Vector2.RIGHT.rotated(angle)


func centerline_half_length() -> float:
	return maxf(0.0, (length - 2.0 * radius) * 0.5)


func segment_start() -> Vector2:
	return position - axis() * centerline_half_length()


func segment_end() -> Vector2:
	return position + axis() * centerline_half_length()
