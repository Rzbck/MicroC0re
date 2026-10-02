extends Node2D

const PetriSimulationScript = preload("res://src/simulation/petri_simulation.gd")

const FIXED_DT := 1.0 / 60.0
const MAX_STEPS_PER_FRAME := 8

var sim: Variant
var accumulator: float = 0.0


func _ready() -> void:
	sim = PetriSimulationScript.new(1337)
	sim.seed_demo(24)
	scale = Vector2(4.0, 4.0)
	queue_redraw()


func _process(delta: float) -> void:
	accumulator += minf(delta, 0.25)
	var steps: int = 0

	while accumulator >= FIXED_DT and steps < MAX_STEPS_PER_FRAME:
		sim.step(FIXED_DT)
		accumulator -= FIXED_DT
		steps += 1

	queue_redraw()


func _draw() -> void:
	if sim == null:
		return

	draw_rect(
		Rect2(Vector2.ZERO, sim.world_size),
		Color(0.015, 0.02, 0.025, 1.0)
	)

	_draw_nutrient_field()
	_draw_bacteria()


func _draw_nutrient_field() -> void:
	var field: Variant = sim.nutrient
	var size: float = float(field.cell_size)

	for y in range(field.height):
		for x in range(field.width):
			var value: float = clampf(float(field.get_cell(x, y)), 0.0, 1.0)
			if value < 0.01:
				continue
			var color: Color = Color(
				0.02 + value * 0.05,
				0.04 + value * 0.22,
				0.05 + value * 0.16,
				1.0
			)
			draw_rect(
				Rect2(Vector2(x * size, y * size), Vector2(size, size)),
				color
			)


func _draw_bacteria() -> void:
	for cell in sim.bacteria:
		var hue: float = fmod(float(cell.generation) * 0.083 + 0.12, 1.0)
		var color: Color = Color.from_hsv(hue, 0.60, 0.95)
		var a: Vector2 = Vector2(cell.segment_start())
		var b: Vector2 = Vector2(cell.segment_end())

		draw_line(a, b, color, cell.radius * 2.0, false)
		draw_circle(a, cell.radius, color)
		draw_circle(b, cell.radius, color)

		var nose: Vector2 = Vector2(cell.position) + Vector2(cell.axis()) * (float(cell.length) * 0.5)
		draw_circle(nose, 0.12, Color(1.0, 1.0, 1.0, 0.9))
