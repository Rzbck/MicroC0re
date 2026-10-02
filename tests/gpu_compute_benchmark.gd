extends SceneTree

const WIDTH := 96
const HEIGHT := 64
const FIELD_SIZE := WIDTH * HEIGHT
const ITERATIONS := 1200


func _init() -> void:
	print("MicroC0re GPU compute benchmark")
	print("renderer=", ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	print("gpu=", RenderingServer.get_video_adapter_name())
	print("api=", RenderingServer.get_video_adapter_api_version())

	var rd: RenderingDevice = RenderingServer.create_local_rendering_device()
	if rd == null:
		push_error("RenderingDevice unavailable. Run with Forward+ or Mobile, not headless/Compatibility.")
		quit(1)
		return

	var shader_file: RDShaderFile = load("res://src/gpu/field_diffusion.glsl") as RDShaderFile
	if shader_file == null:
		push_error("Failed to load compute shader.")
		quit(1)
		return

	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader: RID = rd.shader_create_from_spirv(shader_spirv)
	if not shader.is_valid():
		push_error("Failed to create compute shader RID.")
		quit(1)
		return

	var pipeline: RID = rd.compute_pipeline_create(shader)
	if not pipeline.is_valid():
		push_error("Failed to create compute pipeline.")
		rd.free_rid(shader)
		quit(1)
		return

	var initial := PackedFloat32Array()
	initial.resize(FIELD_SIZE)
	initial.fill(0.0)

	initial[(HEIGHT / 2) * WIDTH + WIDTH / 2] = 1.0
	initial[(HEIGHT / 3) * WIDTH + WIDTH / 4] = 0.65
	initial[(HEIGHT * 2 / 3) * WIDTH + WIDTH * 3 / 4] = 0.85

	var zero := PackedFloat32Array()
	zero.resize(FIELD_SIZE)
	zero.fill(0.0)

	var initial_bytes: PackedByteArray = initial.to_byte_array()
	var zero_bytes: PackedByteArray = zero.to_byte_array()

	var buffer_a: RID = rd.storage_buffer_create(
		initial_bytes.size(),
		initial_bytes
	)
	var buffer_b: RID = rd.storage_buffer_create(
		zero_bytes.size(),
		zero_bytes
	)

	var set_ab: RID = _make_uniform_set(rd, shader, buffer_a, buffer_b)
	var set_ba: RID = _make_uniform_set(rd, shader, buffer_b, buffer_a)

	var dispatch_x: int = ceili(float(WIDTH) / 8.0)
	var dispatch_y: int = ceili(float(HEIGHT) / 8.0)

	var start_usec: int = Time.get_ticks_usec()
	var compute_list: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)

	for iteration in range(ITERATIONS):
		var uniform_set: RID = set_ab if iteration % 2 == 0 else set_ba
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_dispatch(compute_list, dispatch_x, dispatch_y, 1)
		if iteration + 1 < ITERATIONS:
			rd.compute_list_add_barrier(compute_list)

	rd.compute_list_end()
	rd.submit()
	rd.sync()
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0

	var final_buffer: RID = buffer_a if ITERATIONS % 2 == 0 else buffer_b
	var output_bytes: PackedByteArray = rd.buffer_get_data(final_buffer)
	var output: PackedFloat32Array = output_bytes.to_float32_array()

	var minimum: float = INF
	var maximum: float = -INF
	var total: float = 0.0
	for value in output:
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
		total += value

	var cells_processed: float = float(FIELD_SIZE * ITERATIONS)
	var million_cell_updates_per_second: float = (
		cells_processed / maxf(elapsed_ms / 1000.0, 0.000001) / 1000000.0
	)

	print(
		"field=%dx%d iterations=%d | %.3f ms total | %.3f us/step | %.1f M cell-updates/s"
		% [
			WIDTH,
			HEIGHT,
			ITERATIONS,
			elapsed_ms,
			elapsed_ms * 1000.0 / float(ITERATIONS),
			million_cell_updates_per_second,
		]
	)
	print(
		"result min=%.6f max=%.6f total=%.6f"
		% [minimum, maximum, total]
	)
	print("GPU_COMPUTE_PASS")

	rd.free_rid(set_ab)
	rd.free_rid(set_ba)
	rd.free_rid(buffer_a)
	rd.free_rid(buffer_b)
	rd.free_rid(pipeline)
	rd.free_rid(shader)

	quit(0)


func _make_uniform_set(
	rd: RenderingDevice,
	shader: RID,
	read_buffer: RID,
	write_buffer: RID
) -> RID:
	var input_uniform := RDUniform.new()
	input_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	input_uniform.binding = 0
	input_uniform.add_id(read_buffer)

	var output_uniform := RDUniform.new()
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	output_uniform.binding = 1
	output_uniform.add_id(write_buffer)

	return rd.uniform_set_create(
		[input_uniform, output_uniform],
		shader,
		0
	)
