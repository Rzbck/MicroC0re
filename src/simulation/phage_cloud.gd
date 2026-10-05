class_name PhageCloud
extends RefCounted

var id: int
var position: Vector2
var host_hue: float
var concentration: float = 0.70
var radius: float = 6.0
var age: float = 0.0
var lifetime: float = 32.0
var burst_generation: int = 0
var visual_phase: float = 0.0


func _init(
	p_id: int,
	p_position: Vector2,
	p_host_hue: float,
	p_concentration: float = 0.70,
	p_radius: float = 6.0,
	p_generation: int = 0
) -> void:
	id = p_id
	position = p_position
	host_hue = wrapf(p_host_hue, 0.0, 1.0)
	concentration = maxf(0.0, p_concentration)
	radius = maxf(1.0, p_radius)
	burst_generation = maxi(0, p_generation)
	visual_phase = float(posmod(p_id * 37 + p_generation * 13, 360)) * PI / 180.0
