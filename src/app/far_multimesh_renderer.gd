extends Node2D

# GPU-instanced far LOD. One MultiMesh draw replaces one draw_rect call per
# organism. The full transform/color buffer is uploaded in one call.

const FLOATS_PER_INSTANCE := 12

var capacity: int = 0
var multimesh: MultiMesh
var instance_node: MultiMeshInstance2D
var buffer: PackedFloat32Array = PackedFloat32Array()


func initialize(max_instances: int) -> void:
	capacity = maxi(1, max_instances)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0

	buffer.resize(capacity * FLOATS_PER_INSTANCE)
	buffer.fill(0.0)

	var white_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white_image.set_pixel(0, 0, Color.WHITE)
	var white_texture := ImageTexture.create_from_image(white_image)

	instance_node = MultiMeshInstance2D.new()
	instance_node.name = "FarLOD_GPU"
	instance_node.multimesh = multimesh
	instance_node.texture = white_texture
	instance_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(instance_node)


func clear() -> void:
	if multimesh != null:
		multimesh.visible_instance_count = 0


func update_from_cells(
	cells: Array,
	visible_rect: Rect2,
	zoom_value: float,
	palette: Array,
	sprite_ratio: float = 0.0
) -> int:
	if multimesh == null:
		return 0

	var count: int = 0
	var safe_zoom: float = maxf(zoom_value, 0.001)

	for cell in cells:
		if count >= capacity:
			break

		var position: Vector2 = Vector2(cell.position)
		if not visible_rect.has_point(position):
			continue
		if _lod_roll(int(cell.id)) < clampf(sprite_ratio, 0.0, 1.0):
			continue

		var hue: float = wrapf(float(cell.lineage_hue), 0.0, 1.0)
		var palette_index: int = clampi(
			floori(hue * float(palette.size())),
			0,
			palette.size() - 1
		)
		var color: Color = Color(palette[palette_index])

		if bool(cell.dying):
			color.a = clampf(
				1.0 - float(cell.lysis_progress) * 0.72,
				0.20,
				1.0
			)
		elif float(cell.adhesion_timer) > 0.0:
			color = color.lightened(0.12)

		# Deliberate overview silhouette: integer screen-pixel dimensions and
		# quantized orientation. This is a separate LOD drawing, not a shrunken
		# copy of the close sprite.
		var screen_length: float = roundf(clampf(
			1.75 + float(cell.length) * 0.34,
			2.0,
			4.0
		))
		var screen_thickness: float = 1.0
		var world_length: float = maxf(0.30, screen_length / safe_zoom)
		var world_thickness: float = maxf(0.20, screen_thickness / safe_zoom)

		var base: int = count * FLOATS_PER_INSTANCE

		# Transform2D buffer row-major order:
		# x.x, y.x, pad, origin.x, x.y, y.y, pad, origin.y
		var angle_step: float = TAU / 8.0
		var angle: float = roundf(float(cell.angle) / angle_step) * angle_step
		var cosine: float = cos(angle)
		var sine: float = sin(angle)
		buffer[base + 0] = cosine * world_length
		buffer[base + 1] = -sine * world_thickness
		buffer[base + 2] = 0.0
		buffer[base + 3] = position.x
		buffer[base + 4] = sine * world_length
		buffer[base + 5] = cosine * world_thickness
		buffer[base + 6] = 0.0
		buffer[base + 7] = position.y
		buffer[base + 8] = color.r
		buffer[base + 9] = color.g
		buffer[base + 10] = color.b
		buffer[base + 11] = color.a

		count += 1

	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), buffer)
	multimesh.visible_instance_count = count
	return count


func _lod_roll(organism_id: int) -> float:
	var value: int = (
		organism_id * 1103515245
		+ 12345
	) & 0x7fffffff
	return float(value % 4093) / 4093.0
