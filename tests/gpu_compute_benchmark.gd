extends SceneTree

const WIDTH := 96
const HEIGHT := 64
const FIELD_SIZE := WIDTH * HEIGHT
const ITERATIONS := 1200


func _init() -> void:
	print("MicroC0re GPU compute benchmark")
	print("renderer=", RenderingServer.get_current_rendering_method())
	print("gpu=", RenderingServer.get_video_adapter_name())
	print("api=", RenderingServer.get_video_adapter_api_version())

	var rd: RenderingDevice = RenderingServer.create_local_rendering_device()
	if rd == null:
		push_error("RenderingDevice unavailable. Run with Forward+ or Mobile, not headless/Compatibility.")
		quit(1)
		return

	var shader_code: String = FileAccess.get_file_as_string(
		"res://src/gpu/field_diffusion.glsl"
	)
	if shader_code.is_empty():
		push_error("Failed to read compute shader source.")
		quit(1)
		return

	# #[compute] is an import hint for RDShaderFile. We compile source directly
	# here so this benchmark works from a fresh git clone without editor import.
	# Git on Windows may hand us CRLF and/or a UTF-8 BOM, so remove the marker
	# line structurally instead of relying on one exact newline sequence.
	shader_code = shader_code.replace("\r\n", "\n")
	shader_code = shader_code.trim_prefix("\ufeff")

	var cleaned_lines := PackedStringArray()
	for source_line in shader_code.split("\n"):
		var trimmed: String = source_line.strip_edges()
		if trimmed == "#[compute]":
			continue
		cleaned_lines.append(source_line)
	shader_code = "\n".join(cleaned_lines)

	if shader_code.begins_with("#[compute]"):
		push_error("Compute marker stripping failed.")
		quit(1)
		return

	var shader_source := RDShaderSource.new()
	shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	shader_source.source_compute = shader_code

	var shader_spirv: RDShaderSPIRV = rd.shader_compile_spirv_from_source(
		shader_source,
		true
	)
	if shader_spirv.compile_error_compute != "":
		push_error("Compute shader compilation failed:")
		push_error(shader_spirv.compile_error_compute)
		quit(1)
		return

	var shader: RID = rd.shader_create_from_spirv(
		shader_spirv,
		"MicroC0re field diffusion benchmark"
	)
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

	initial[floori(float(HEIGHT) / 2.0) * WIDTH + floori(float(WIDTH) / 2.0)] = 1.0
	initial[floori(float(HEIGHT) / 3.0) * WIDTH + floori(float(WIDTH) / 4.0)] = 0.65
	initial[floori(float(HEIGHT) * 2.0 / 3.0) * WIDTH + floori(float(WIDTH) * 3.0 / 4.0)] = 0.85

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
