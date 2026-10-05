class_name BacteriaHotStore
extends RefCounted

const STATE_DYING := 1
const STATE_CONSUMED := 2
const STATE_ENGULFED := 4
const STATE_ALIVE := 8

var ids: PackedInt32Array = PackedInt32Array()
var positions: PackedVector2Array = PackedVector2Array()
var angles: PackedFloat32Array = PackedFloat32Array()
var energies: PackedFloat32Array = PackedFloat32Array()
var ages: PackedFloat32Array = PackedFloat32Array()
var lengths: PackedFloat32Array = PackedFloat32Array()
var radii: PackedFloat32Array = PackedFloat32Array()
var gene_sizes: PackedFloat32Array = PackedFloat32Array()
var burrow_depths: PackedFloat32Array = PackedFloat32Array()
var species_hues: PackedFloat32Array = PackedFloat32Array()
var lineage_hues: PackedFloat32Array = PackedFloat32Array()
var states: PackedByteArray = PackedByteArray()


func size() -> int:
	return ids.size()


func clear() -> void:
	resize(0)


func resize(count: int) -> void:
	var safe_count: int = maxi(0, count)
	ids.resize(safe_count)
	positions.resize(safe_count)
	angles.resize(safe_count)
	energies.resize(safe_count)
	ages.resize(safe_count)
	lengths.resize(safe_count)
	radii.resize(safe_count)
	gene_sizes.resize(safe_count)
	burrow_depths.resize(safe_count)
	species_hues.resize(safe_count)
	lineage_hues.resize(safe_count)
	states.resize(safe_count)


func write_cell(index: int, cell: Variant, species_hue: float) -> void:
	ids[index] = int(cell.id)
	positions[index] = Vector2(cell.position)
	angles[index] = float(cell.angle)
	energies[index] = float(cell.energy)
	ages[index] = float(cell.age)
	lengths[index] = float(cell.length)
	radii[index] = float(cell.radius)
	gene_sizes[index] = float(cell.gene_size)
	burrow_depths[index] = float(cell.burrow_depth)
	species_hues[index] = species_hue
	lineage_hues[index] = float(cell.lineage_hue)

	var state: int = 0
	if bool(cell.dying):
		state |= STATE_DYING
	if bool(cell.consumed):
		state |= STATE_CONSUMED
	if int(cell.engulfed_by_id) >= 0:
		state |= STATE_ENGULFED
	if bool(cell.alive):
		state |= STATE_ALIVE
	states[index] = state


func render_snapshot() -> Dictionary:
	# Packed arrays are copy-on-write. Consumers must treat this dictionary as
	# read-only; no per-frame object walk or value-by-value copy is required.
	return {
		"ids": ids,
		"positions": positions,
		"angles": angles,
		"energies": energies,
		"ages": ages,
		"lengths": lengths,
		"radii": radii,
		"gene_sizes": gene_sizes,
		"burrow_depths": burrow_depths,
		"species_hues": species_hues,
		"lineage_hues": lineage_hues,
		"states": states,
	}
