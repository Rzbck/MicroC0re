extends Node2D

const PetriSimulationScript = preload("res://src/simulation/petri_simulation.gd")

const FIXED_DT := 1.0 / 120.0
const MAX_STEPS_PER_FRAME := 24
const FIELD_REFRESH_INTERVAL := 1.0 / 20.0
const HUD_REFRESH_INTERVAL := 0.20
const MIN_ZOOM := 1.0
const MAX_ZOOM := 28.0

var sim: Variant
var current_seed: int = 1337
var accumulator: float = 0.0
var simulation_speed: float = 1.0
var paused: bool = false

var camera: Camera2D
var field_image: Image
var field_texture: ImageTexture
var field_refresh_accumulator: float = 0.0

var hud_label: Label
var hud_refresh_accumulator: float = 0.0
var selected_id: int = -1

var dragging_camera: bool = false
var visual_time: float = 0.0
var last_step_count: int = 0


func _ready() -> void:
	Engine.max_fps = 144
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_start_simulation(current_seed)
	_setup_camera()
	_setup_field_texture()
	_setup_hud()

	_refresh_field_texture()
	_update_hud()
	call_deferred("_fit_camera")
	queue_redraw()


func _start_simulation(seed_value: int) -> void:
	current_seed = seed_value
	sim = PetriSimulationScript.new(current_seed)
	sim.seed_demo(36)
	accumulator = 0.0
	selected_id = -1


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "MicroscopeCamera"
	camera.enabled = true
	camera.position = Vector2(sim.world_size) * 0.5
	camera.zoom = Vector2(5.0, 5.0)
	add_child(camera)


func _setup_field_texture() -> void:
	var field: Variant = sim.nutrient
	field_image = Image.create(
		int(field.width),
		int(field.height),
		false,
		Image.FORMAT_RGBA8
	)
	field_texture = ImageTexture.create_from_image(field_image)


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	var panel := ColorRect.new()
	panel.position = Vector2(14.0, 14.0)
	panel.size = Vector2(430.0, 152.0)
	panel.color = Color(0.015, 0.020, 0.025, 0.86)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)

	hud_label = Label.new()
	hud_label.position = Vector2(26.0, 22.0)
	hud_label.size = Vector2(410.0, 138.0)
	hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_label.add_theme_font_size_override("font_size", 15)
	hud_label.add_theme_color_override("font_color", Color(0.88, 0.94, 0.92))
	hud_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	hud_label.add_theme_constant_override("shadow_offset_x", 1)
	hud_label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(hud_label)


func _process(delta: float) -> void:
	visual_time += delta
	_handle_keyboard_pan(delta)

	last_step_count = 0
	if not paused:
		accumulator += minf(delta * simulation_speed, 0.20)
		while accumulator >= FIXED_DT and last_step_count < MAX_STEPS_PER_FRAME:
			sim.step(FIXED_DT)
			accumulator -= FIXED_DT
			last_step_count += 1

	field_refresh_accumulator += delta
	if field_refresh_accumulator >= FIELD_REFRESH_INTERVAL:
		field_refresh_accumulator = fmod(field_refresh_accumulator, FIELD_REFRESH_INTERVAL)
		_refresh_field_texture()

	hud_refresh_accumulator += delta
	if hud_refresh_accumulator >= HUD_REFRESH_INTERVAL:
		hud_refresh_accumulator = 0.0
		_update_hud()

	queue_redraw()


func _draw() -> void:
	if sim == null:
		return

	var world_rect := Rect2(Vector2.ZERO, Vector2(sim.world_size))
	draw_rect(world_rect, Color(0.006, 0.010, 0.012, 1.0), true)

	if field_texture != null:
		draw_texture_rect(field_texture, world_rect, false)

	_draw_source_markers()
	_draw_bacteria()
	draw_rect(world_rect, Color(0.18, 0.28, 0.26, 0.70), false, 0.32, false)


func _draw_source_markers() -> void:
	var zoom_value: float = camera.zoom.x
	if zoom_value < 2.0:
		return

	for source in sim.nutrient_sources:
		var center: Vector2 = Vector2(source)
		draw_arc(
			center,
			1.7,
			0.0,
			TAU,
			12,
			Color(0.16, 0.48, 0.31, 0.20),
			0.18,
			false
		)


func _draw_bacteria() -> void:
	var detail_zoom: float = camera.zoom.x

	for cell in sim.bacteria:
		_draw_single_bacterium(cell, detail_zoom)


func _draw_single_bacterium(cell: Variant, detail_zoom: float) -> void:
	var position: Vector2 = Vector2(cell.position)
	var axis: Vector2 = Vector2(cell.axis())
	var normal: Vector2 = axis.orthogonal()
	var radius: float = float(cell.radius)
	var half_line: float = float(cell.centerline_half_length())
	var a: Vector2 = position - axis * half_line
	var b: Vector2 = position + axis * half_line

	var body_color: Color = Color(cell.phenotype_color())
	var membrane_color: Color = body_color.darkened(0.58)
	var cytoplasm_color: Color = body_color.darkened(0.12)
	var core_color: Color = body_color.lightened(0.34)

	# Flagella are drawn behind the membrane.
	if detail_zoom >= 2.2:
		_draw_flagella(cell, position, axis, normal, half_line, membrane_color)

	# Selection halo.
	if int(cell.id) == selected_id:
		draw_arc(
			position,
			maxf(float(cell.length) * 0.64, radius * 2.7),
			0.0,
			TAU,
			24,
			Color(0.96, 0.98, 0.72, 0.92),
			0.22,
			false
		)

	# Dark cell wall / membrane.
	var outer_width: float = radius * 2.55
	draw_line(a, b, membrane_color, outer_width, false)
	draw_circle(a, outer_width * 0.5, membrane_color, true, -1.0, false)
	draw_circle(b, outer_width * 0.5, membrane_color, true, -1.0, false)

	# Inner cytoplasm.
	var inner_width: float = radius * 1.78
	draw_line(a, b, cytoplasm_color, inner_width, false)
	draw_circle(a, inner_width * 0.5, cytoplasm_color, true, -1.0, false)
	draw_circle(b, inner_width * 0.5, cytoplasm_color, true, -1.0, false)

	# A thin longitudinal highlight makes orientation and deformation readable.
	var highlight_offset: Vector2 = normal * radius * 0.20
	draw_line(
		a + highlight_offset,
		b + highlight_offset,
		body_color.lightened(0.20),
		maxf(0.08, radius * 0.18),
		false
	)

	# Nucleoid-like internal marks: deliberately not membrane-bound organelles.
	if detail_zoom >= 3.4:
		for i in range(3):
			var t: float = (float(i) - 1.0) * 0.42
			var wobble: float = sin(
				float(cell.visual_phase) + float(i) * 2.1 + visual_time * 0.7
			) * radius * 0.16
			var core_position: Vector2 = (
				position
				+ axis * (half_line * t)
				+ normal * wobble
			)
			draw_circle(
				core_position,
				maxf(0.09, radius * 0.16),
				core_color,
				true,
				-1.0,
				false
			)

		_draw_pili(cell, position, axis, normal, half_line, radius, membrane_color)


func _draw_flagella(
	cell: Variant,
	position: Vector2,
	axis: Vector2,
	normal: Vector2,
	half_line: float,
	color: Color
) -> void:
	var count: int = int(cell.flagella_count)
	if count <= 0:
		return

	var rear: Vector2 = position - axis * (half_line + float(cell.radius) * 0.82)
	var base_length: float = (
		2.4
		+ 1.55 * float(cell.flagella_length)
		+ 0.16 * float(cell.length)
	)

	for flagellum_index in range(count):
		var points := PackedVector2Array()
		var side_offset: float = (
			(float(flagellum_index) - float(count - 1) * 0.5)
			* float(cell.radius)
			* 0.42
		)

		for segment in range(9):
			var u: float = float(segment) / 8.0
			var distance: float = base_length * u
			var phase: float = (
				visual_time * 10.0
				+ float(cell.visual_phase)
				+ float(flagellum_index) * 1.73
				- u * 8.5
			)
			var wave: float = sin(phase) * (0.10 + 0.34 * u)
			var point: Vector2 = (
				rear
				- axis * distance
				+ normal * (side_offset * (1.0 - u) + wave)
			)
			points.append(point)

		draw_polyline(
			points,
			Color(color.r, color.g, color.b, 0.78),
			0.13,
			false
		)


func _draw_pili(
	cell: Variant,
	position: Vector2,
	axis: Vector2,
	normal: Vector2,
	half_line: float,
	radius: float,
	color: Color
) -> void:
	var count: int = int(cell.pili_count)
	if count <= 0:
		return

	for pilus_index in range(count):
		var side: float = -1.0 if pilus_index % 2 == 0 else 1.0
		var pair_index: int = pilus_index / 2
		var pair_count: int = maxi(1, (count + 1) / 2)
		var along: float = (
			(float(pair_index) + 0.5) / float(pair_count) * 2.0 - 1.0
		)
		var anchor: Vector2 = (
			position
			+ axis * half_line * along
			+ normal * radius * side
		)
		var tilt: float = sin(
			float(cell.visual_phase) + float(pilus_index) * 1.31
		) * 0.30
		var outward: Vector2 = (
			normal * side + axis * tilt
		).normalized()
		var tip: Vector2 = anchor + outward * (0.52 + 0.12 * float(pilus_index % 3))

		draw_line(
			anchor,
			tip,
			Color(color.r, color.g, color.b, 0.82),
			0.10,
			false
		)


func _refresh_field_texture() -> void:
	if sim == null or field_image == null or field_texture == null:
		return

	var nutrient_field: Variant = sim.nutrient
	var waste_field: Variant = sim.waste
	var width: int = int(nutrient_field.width)
	var height: int = int(nutrient_field.height)

	for y in range(height):
		for x in range(width):
			var nutrient_value: float = clampf(
				float(nutrient_field.get_cell(x, y)) * 1.9,
				0.0,
				1.0
			)
			var waste_value: float = clampf(
				float(waste_field.get_cell(x, y)) * 2.4,
				0.0,
				1.0
			)

			var nutrient_glow: float = sqrt(nutrient_value)
			var waste_glow: float = sqrt(waste_value)

			var pixel_color := Color(
				0.006 + nutrient_glow * 0.025 + waste_glow * 0.20,
				0.012 + nutrient_glow * 0.30 + waste_glow * 0.035,
				0.016 + nutrient_glow * 0.20 + waste_glow * 0.23,
				1.0
			)
			field_image.set_pixel(x, y, pixel_color)

	field_texture.update(field_image)


func _update_hud() -> void:
	if hud_label == null or sim == null:
		return

	var selected_text := ""
	if selected_id >= 0:
		var selected: Variant = sim.find_cell_by_id(selected_id)
		if selected == null:
			selected_id = -1
		else:
			selected_text = (
				"\nCELL #%d  gen %d  lineage %d  energy %.2f"
				% [
					int(selected.id),
					int(selected.generation),
					int(selected.lineage_id),
					float(selected.energy),
				]
			)
			selected_text += (
				"\n genes  speed %.2f  chemo %.2f  uptake %.2f  growth %.2f  size %.2f"
				% [
					float(selected.gene_speed),
					float(selected.gene_chemotaxis),
					float(selected.gene_uptake),
					float(selected.gene_growth),
					float(selected.gene_size),
				]
			)
			selected_text += (
				"\n appendages  flagella %d x%.2f   pili %d"
				% [
					int(selected.flagella_count),
					float(selected.flagella_length),
					int(selected.pili_count),
				]
			)

	var pause_text: String = "PAUSED" if paused else "RUNNING"
	hud_label.text = (
		"MICROC0RE  |  %s  |  FPS %d  |  sim %.1fx"
		% [pause_text, Engine.get_frames_per_second(), simulation_speed]
	)
	hud_label.text += (
		"\nseed %d  |  cells %d  |  max generation %d  |  mean energy %.2f"
		% [
			current_seed,
			sim.bacteria.size(),
			int(sim.max_generation()),
			float(sim.mean_energy()),
		]
	)
	hud_label.text += (
		"\nwheel zoom  •  RMB/MMB drag  •  WASD pan  •  click inspect  •  F fit  •  SPACE pause  •  R reset  •  N new seed"
	)
	hud_label.text += selected_text


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton

		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_zoom_at_screen_position(mouse_button.position, 1.20)
			get_viewport().set_input_as_handled()
			return

		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_at_screen_position(mouse_button.position, 1.0 / 1.20)
			get_viewport().set_input_as_handled()
			return

		if (
			mouse_button.button_index == MOUSE_BUTTON_RIGHT
			or mouse_button.button_index == MOUSE_BUTTON_MIDDLE
		):
			dragging_camera = mouse_button.pressed
			get_viewport().set_input_as_handled()
			return

		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_select_nearest_cell(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and dragging_camera:
		var motion := event as InputEventMouseMotion
		camera.position -= motion.relative / camera.zoom.x
		_clamp_camera_position()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return

		match key_event.keycode:
			KEY_SPACE:
				paused = not paused
			KEY_F:
				_fit_camera()
			KEY_R:
				_start_simulation(current_seed)
				_setup_field_texture()
				_refresh_field_texture()
				_fit_camera()
			KEY_N:
				_start_simulation(current_seed + 1)
				_setup_field_texture()
				_refresh_field_texture()
				_fit_camera()
			KEY_1:
				simulation_speed = 1.0
			KEY_2:
				simulation_speed = 2.0
			KEY_3:
				simulation_speed = 4.0
			KEY_4:
				simulation_speed = 8.0
			_:
				return

		_update_hud()
		get_viewport().set_input_as_handled()


func _zoom_at_screen_position(screen_position: Vector2, factor: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var viewport_center: Vector2 = viewport_size * 0.5
	var old_zoom: float = camera.zoom.x
	var new_zoom: float = clampf(old_zoom * factor, MIN_ZOOM, MAX_ZOOM)

	if is_equal_approx(old_zoom, new_zoom):
		return

	var world_under_cursor: Vector2 = (
		camera.position
		+ (screen_position - viewport_center) / old_zoom
	)
	camera.zoom = Vector2(new_zoom, new_zoom)
	camera.position = (
		world_under_cursor
		- (screen_position - viewport_center) / new_zoom
	)
	_clamp_camera_position()


func _select_nearest_cell(world_position: Vector2) -> void:
	var best_id: int = -1
	var best_distance: float = INF
	var selection_radius: float = maxf(0.85, 10.0 / camera.zoom.x)

	for cell in sim.bacteria:
		var distance: float = Vector2(cell.position).distance_to(world_position)
		if distance <= selection_radius and distance < best_distance:
			best_distance = distance
			best_id = int(cell.id)

	selected_id = best_id
	_update_hud()


func _handle_keyboard_pan(delta: float) -> void:
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0

	if direction.length_squared() <= 0.0:
		return

	direction = direction.normalized()
	var pan_speed: float = 280.0 / camera.zoom.x
	camera.position += direction * pan_speed * delta
	_clamp_camera_position()


func _fit_camera() -> void:
	if camera == null or sim == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return

	var world: Vector2 = Vector2(sim.world_size)
	var fit_zoom: float = minf(
		viewport_size.x / world.x,
		viewport_size.y / world.y
	) * 0.92
	fit_zoom = clampf(fit_zoom, MIN_ZOOM, MAX_ZOOM)

	camera.position = world * 0.5
	camera.zoom = Vector2(fit_zoom, fit_zoom)


func _clamp_camera_position() -> void:
	var world: Vector2 = Vector2(sim.world_size)
	var margin: Vector2 = world * 0.18
	camera.position.x = clampf(camera.position.x, -margin.x, world.x + margin.x)
	camera.position.y = clampf(camera.position.y, -margin.y, world.y + margin.y)
