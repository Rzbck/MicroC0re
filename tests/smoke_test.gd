extends SceneTree

const PetriSimulationScript = preload("res://src/simulation/petri_simulation.gd")
# Compile the visible app stack during every headless smoke run so renderer
# script parse errors cannot survive until the manual GUI test.
const PixelMicroscopeScript = preload("res://src/app/pixel_microscope.gd")
const PixelAtlasScript = preload("res://src/app/pixel_microbe_atlas.gd")
const FarMultiMeshRendererScript = preload("res://src/app/far_multimesh_renderer.gd")

const STEPS := 600
const DT := 1.0 / 60.0


func _init() -> void:
	var first = PetriSimulationScript.new(424242)
	var second = PetriSimulationScript.new(424242)
	first.seed_demo(24)
	second.seed_demo(24)

	for _i in range(STEPS):
		first.step(DT)
		second.step(DT)

	var errors := PackedStringArray()

	if first.state_signature() != second.state_signature():
		errors.append("determinism: identical seeds produced different signatures")

	if first.bacteria.is_empty():
		errors.append("population: all bacteria died during the smoke window")

	if first.nutrient.min_value() < -0.000001:
		errors.append("nutrient: negative concentration detected")

	if first.waste.min_value() < -0.000001:
		errors.append("waste: negative concentration detected")

	var ids := {}
	var saw_genotype_variation: bool = false
	for cell in first.bacteria:
		if ids.has(cell.id):
			errors.append("identity: duplicate cell id %d" % cell.id)
		ids[cell.id] = true

		if not _finite_vector(cell.position):
			errors.append("state: non-finite position for cell %d" % cell.id)
		if not is_finite(cell.angle):
			errors.append("state: non-finite angle for cell %d" % cell.id)
		if not is_finite(cell.length) or cell.length <= 0.0:
			errors.append("state: invalid length for cell %d" % cell.id)
		if not is_finite(cell.energy) or cell.energy < 0.0:
			errors.append("state: invalid energy for cell %d" % cell.id)
		if (
			not is_finite(float(cell.division_progress))
			or float(cell.division_progress) < 0.0
			or float(cell.division_progress) > 1.000001
		):
			errors.append("state: invalid division progress for cell %d" % cell.id)
		if (
			not is_finite(float(cell.lysis_progress))
			or float(cell.lysis_progress) < 0.0
			or float(cell.lysis_progress) > 1.000001
		):
			errors.append("state: invalid lysis progress for cell %d" % cell.id)

		if absf(float(cell.gene_speed) - 1.0) > 0.001:
			saw_genotype_variation = true

	if not saw_genotype_variation:
		errors.append("genetics: founders did not expose any trait variation")

	if errors.is_empty():
		print(
			"MicroC0re smoke PASS | steps=%d cells=%d nutrient=%.3f waste=%.3f"
			% [
				STEPS,
				first.bacteria.size(),
				first.nutrient.total(),
				first.waste.total(),
			]
		)
		quit(0)
	else:
		for message in errors:
			push_error(message)
		quit(1)


func _finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
