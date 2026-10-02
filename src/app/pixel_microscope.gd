extends Node2D

const PetriSimulationScript = preload("res://src/simulation/petri_simulation.gd")
const PixelAtlasScript = preload("res://src/app/pixel_microbe_atlas.gd")
const PixelBackgroundScript = preload("res://src/app/pixel_background.gd")
const FarMultiMeshRendererScript = preload("res://src/app/far_multimesh_renderer.gd")
const PixelProtozoaAtlasScript = preload("res://src/app/pixel_protozoa_atlas.gd")
const PixelCiliateAtlasScript = preload("res://src/app/pixel_ciliate_atlas.gd")
const MicroscopeUIScript = preload("res://src/app/microscope_ui.gd")

const FIXED_DT := 1.0 / 60.0
const MAX_STEPS_PER_FRAME := 12
const FIELD_REFRESH_INTERVAL := 1.0 / 20.0
const INSPECTOR_REFRESH_INTERVAL := 0.15
const MAX_ZOOM := 48.0
const SPRITE_WORLD_PIXEL := 0.25
const ANGLE_STEPS := 32.0

const LINEAGE_PALETTE := [
	Color(0.38, 0.82, 0.42, 1.0),
	Color(0.66, 0.84, 0.32, 1.0),
	Color(0.92, 0.72, 0.30, 1.0),
	Color(0.93, 0.47, 0.30, 1.0),
	Color(0.86, 0.34, 0.58, 1.0),
	Color(0.62, 0.38, 0.86, 1.0),
	Color(0.34, 0.52, 0.88, 1.0),
	Color(0.28, 0.74, 0.84, 1.0),
]

var sim: Variant
var atlas: Variant
var protozoa_atlas: Variant
var ciliate_atlas: Variant
var far_renderer: Node2D
var ui: Variant
var current_seed: int = 1337

var accumulator: float = 0.0
var simulation_speed: float = 1.0
var paused: bool = false
var visual_time: float = 0.0

var camera: Camera2D
var dragging_camera: bool = false

var field_image: Image
var field_texture: ImageTexture
var field_refresh_accumulator: float = 0.0

var inspector_refresh_accumulator: float = 0.0
var selected_id: int = -1
var selected_kind: String = ""
var menu_pause_previous: bool = false

var sim_ms: float = 0.0
var field_ms: float = 0.0
var draw_ms: float = 0.0
var visible_cells: int = 0
var far_cells: int = 0
var sprite_cells: int = 0
var gpu_name: String = ""
var renderer_name: String = ""


func _ready() -> void:
	Engine.max_fps = 144
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.set_default_clear_color(Color(0.006, 0.010, 0.012, 1.0))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gpu_name = RenderingServer.get_video_adapter_name()
	renderer_name = RenderingServer.get_current_rendering_method()

	atlas = PixelAtlasScript.new()
	protozoa_atlas = PixelProtozoaAtlasScript.new()
	ciliate_atlas = PixelCiliateAtlasScript.new()
	_setup_infinite_background()
	_setup_gpu_renderers()
	_start_simulation(current_seed)
	_setup_camera()
	_setup_field_texture()
	_setup_ui()
	_refresh_field_texture()
	call_deferred("_fit_camera")
	queue_redraw()


func _setup_infinite_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -20
	layer.name = "InfiniteBackground"
	add_child(layer)

	var base := ColorRect.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.004, 0.008, 0.010, 1.0)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(base)

	var tiles := TextureRect.new()
	tiles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tiles.texture = PixelBackgroundScript.new().build_texture()
	tiles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tiles.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tiles.stretch_mode = TextureRect.STRETCH_TILE
	tiles.modulate = Color(1.0, 1.0, 1.0, 0.78)
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tiles)


func _setup_gpu_renderers() -> void:
	far_renderer = FarMultiMeshRendererScript.new()
	far_renderer.name = "GPUInstancing"
	add_child(far_renderer)
	far_renderer.initialize(1200)


func _start_simulation(seed_value: int) -> void:
	current_seed = seed_value
	sim = PetriSimulationScript.new(current_seed)
	sim.seed_demo(72)
	accumulator = 0.0
	selected_id = -1
	selected_kind = ""
	if ui != null:
		ui.hide_inspector()


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "MicroscopeCamera"
	camera.enabled = true
	camera.position = Vector2(sim.world_size) * 0.5
	camera.zoom = Vector2(2.5, 2.5)
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


func _setup_ui() -> void:
	ui = MicroscopeUIScript.new()
	ui.name = "MicroscopeUI"
	add_child(ui)

	ui.resume_requested.connect(_resume_from_menu)
	ui.fit_requested.connect(_menu_fit)
	ui.reset_requested.connect(_menu_reset)
	ui.new_seed_requested.connect(_menu_new_seed)
	ui.quit_requested.connect(_menu_quit)


func _process(delta: float) -> void:
	visual_time += delta
	if ui == null or not ui.is_menu_open():
		_handle_keyboard_pan(delta)
	_clamp_camera_to_world()

	var sim_start: int = Time.get_ticks_usec()
	if not paused:
		accumulator += minf(delta * simulation_speed, 0.20)
		var steps: int = 0
		while accumulator >= FIXED_DT and steps < MAX_STEPS_PER_FRAME:
			sim.step(FIXED_DT)
			accumulator -= FIXED_DT
			steps += 1
	sim_ms = _smooth_metric(
		sim_ms,
		float(Time.get_ticks_usec() - sim_start) / 1000.0
	)

	field_refresh_accumulator += delta
	if field_refresh_accumulator >= FIELD_REFRESH_INTERVAL:
		field_refresh_accumulator = fmod(
			field_refresh_accumulator,
			FIELD_REFRESH_INTERVAL
		)
		var field_start: int = Time.get_ticks_usec()
		_refresh_field_texture()
		field_ms = _smooth_metric(
			field_ms,
			float(Time.get_ticks_usec() - field_start) / 1000.0
		)

	inspector_refresh_accumulator += delta
	if inspector_refresh_accumulator >= INSPECTOR_REFRESH_INTERVAL:
		inspector_refresh_accumulator = 0.0
		_refresh_selected_inspector()

	queue_redraw()


func _draw() -> void:
	if sim == null or camera == null:
		return

	var draw_start: int = Time.get_ticks_usec()
	visible_cells = 0
	far_cells = 0
	sprite_cells = 0

	var world_rect := Rect2(Vector2.ZERO, Vector2(sim.world_size))
	draw_rect(world_rect, Color(0.005, 0.012, 0.014, 1.0), true)

	if field_texture != null:
		draw_texture_rect(field_texture, world_rect, false)

	_draw_bacteria()
	_draw_gene_transfers()
	_draw_protozoa()
	_draw_ciliates()
	draw_rect(world_rect, Color(0.18, 0.30, 0.27, 0.55), false, 0.28, false)

	draw_ms = _smooth_metric(
		draw_ms,
		float(Time.get_ticks_usec() - draw_start) / 1000.0
	)


func _draw_bacteria() -> void:
	var visible_rect: Rect2 = _visible_world_rect().grow(8.0)
	var zoom_value: float = camera.zoom.x
	var overview_zoom: float = _minimum_camera_zoom()
	var far_lod: bool = zoom_value < overview_zoom * 1.16
	var mid_lod: bool = zoom_value < overview_zoom * 2.10
	var frame: int = posmod(int(floor(visual_time * 8.0)), 4)

	if far_lod:
		var count: int = int(far_renderer.update_from_cells(
			sim.bacteria,
			visible_rect,
			zoom_value,
			LINEAGE_PALETTE
		))
		visible_cells = count
		far_cells = count
		sprite_cells = 0
		return

	far_renderer.clear()

	for cell in sim.bacteria:
		var position: Vector2 = Vector2(cell.position)
		if not visible_rect.has_point(position):
			continue

		visible_cells += 1
		var color: Color = _lineage_color(float(cell.lineage_hue))

		if bool(cell.dying):
			color.a = clampf(1.0 - float(cell.lysis_progress) * 0.72, 0.20, 1.0)
		elif float(cell.adhesion_timer) > 0.0:
			color = color.lightened(0.12)

		if far_lod:
			continue

		sprite_cells += 1
		var size_class: int = _size_class(cell)
		var appendage_class: int = 0 if mid_lod else _appendage_class(cell)
		var state: int = 0
		if bool(cell.dying):
			state = 2
		elif bool(cell.dividing):
			state = 1

		var cell_frame: int = 0 if mid_lod else posmod(
			frame + int(floor(float(cell.visual_phase))),
			4
		)
		var texture: Texture2D = atlas.get_texture(
			size_class,
			appendage_class,
			cell_frame,
			state
		)

		var angle_step: float = TAU / ANGLE_STEPS
		var pixel_angle: float = roundf(float(cell.angle) / angle_step) * angle_step
		var texture_size: Vector2 = texture.get_size() * SPRITE_WORLD_PIXEL
		if float(cell.engulf_progress) > 0.0:
			var engulf_scale: float = 1.0 - 0.68 * clampf(
				float(cell.engulf_progress),
				0.0,
				1.0
			)
			texture_size *= engulf_scale
			color.a *= 1.0 - 0.72 * float(cell.engulf_progress)

		draw_set_transform(position, pixel_angle, Vector2.ONE)
		draw_texture_rect(
			texture,
			Rect2(-texture_size * 0.5, texture_size),
			false,
			color
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		if selected_kind == "bacterium" and int(cell.id) == selected_id:
			var marker_size: float = maxf(2.2, float(cell.length) * 0.72)
			draw_rect(
				Rect2(
					position - Vector2(marker_size, marker_size) * 0.5,
					Vector2(marker_size, marker_size)
				),
				Color(0.94, 1.0, 0.72, 0.90),
				false,
				maxf(0.12, 0.85 / zoom_value),
				false
			)


func _draw_gene_transfers() -> void:
	if sim == null or camera == null or camera.zoom.x < 1.8:
		return

	var pixel_size: float = maxf(0.16, 0.85 / camera.zoom.x)
	for donor in sim.bacteria:
		if int(donor.transfer_role) != 1:
			continue

		var recipient: Variant = sim.find_cell_by_id(int(donor.transfer_partner_id))
		if recipient == null:
			continue

		var a: Vector2 = Vector2(donor.position)
		var b: Vector2 = Vector2(recipient.position)
		var progress: float = clampf(float(donor.transfer_progress), 0.0, 1.0)
		var active_steps: int = maxi(2, floori(7.0 * progress))

		for i in range(8):
			var t: float = float(i + 1) / 9.0
			var p: Vector2 = a.lerp(b, t)
			var color := Color(0.34, 0.96, 0.86, 0.34)
			if i < active_steps:
				color = Color(0.68, 1.0, 0.82, 0.95)
			draw_rect(
				Rect2(
					p - Vector2(pixel_size, pixel_size) * 0.5,
					Vector2(pixel_size, pixel_size)
				),
				color,
				true
			)


func _draw_protozoa() -> void:
	if sim == null or protozoa_atlas == null:
		return

	var visible_rect: Rect2 = _visible_world_rect().grow(12.0)
	var zoom_value: float = camera.zoom.x

	for proto in sim.protozoa:
		var position: Vector2 = Vector2(proto.position)
		if not visible_rect.has_point(position):
			continue

		if zoom_value < _minimum_camera_zoom() * 1.16:
			var marker_size: float = maxf(0.55, 1.65 / zoom_value)
			draw_rect(
				Rect2(
					position - Vector2(marker_size, marker_size) * 0.5,
					Vector2(marker_size, marker_size)
				),
				Color(0.34, 0.82, 0.78, 0.95),
				true
			)
			continue

		var state: int = 1 if int(proto.feeding_target_id) >= 0 else 0
		var frame: int = posmod(
			int(floor(visual_time * (6.0 + float(proto.deform_amount) * 4.0)))
				+ int(proto.id),
			6
		)
		var texture: Texture2D = protozoa_atlas.get_texture(frame, state)
		var base_scale: float = 0.36 + float(proto.radius) * 0.012
		var pulse_x: float = 1.0 + sin(float(proto.deform_phase)) * 0.10
		var pulse_y: float = 1.0 - sin(float(proto.deform_phase)) * 0.08
		var feeding_bulge: float = 1.0 + float(proto.deform_amount) * 0.18
		var texture_size: Vector2 = texture.get_size() * base_scale
		texture_size.x *= pulse_x * feeding_bulge
		texture_size.y *= pulse_y * feeding_bulge

		var color := Color(0.38, 0.88, 0.78, 1.0)
		if state == 1:
			color = Color(0.55, 0.96, 0.73, 1.0)

		var angle_step: float = TAU / 16.0
		var pixel_angle: float = roundf(float(proto.angle) / angle_step) * angle_step

		draw_set_transform(position, pixel_angle, Vector2.ONE)
		draw_texture_rect(
			texture,
			Rect2(-texture_size * 0.5, texture_size),
			false,
			color
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		if selected_kind == "amoeba" and int(proto.id) == selected_id:
			var marker_size: float = maxf(4.0, float(proto.radius) * 2.6)
			draw_rect(
				Rect2(
					position - Vector2(marker_size, marker_size) * 0.5,
					Vector2(marker_size, marker_size)
				),
				Color(0.94, 1.0, 0.72, 0.90),
				false,
				maxf(0.12, 0.85 / zoom_value),
				false
			)


func _draw_ciliates() -> void:
	if sim == null or ciliate_atlas == null:
		return

	var visible_rect: Rect2 = _visible_world_rect().grow(10.0)
	var zoom_value: float = camera.zoom.x

	for ciliate in sim.ciliates:
		var position: Vector2 = Vector2(ciliate.position)
		if not visible_rect.has_point(position):
			continue

		if zoom_value < _minimum_camera_zoom() * 1.16:
			var marker_size: float = maxf(0.48, 1.35 / zoom_value)
			draw_rect(
				Rect2(
					position - Vector2(marker_size, marker_size) * 0.5,
					Vector2(marker_size, marker_size)
				),
				Color(0.60, 0.66, 0.98, 0.96),
				true
			)
			continue

		var state: int = 1 if int(ciliate.feeding_target_id) >= 0 else 0
		var frame: int = posmod(
			int(floor(visual_time * (10.0 + float(ciliate.gene_speed) * 2.0)))
				+ int(ciliate.id),
			6
		)
		var texture: Texture2D = ciliate_atlas.get_texture(frame, state)
		var base_scale: float = 0.33 + float(ciliate.radius) * 0.014
		var texture_size: Vector2 = texture.get_size() * base_scale
		var pulse: float = 1.0 + sin(float(ciliate.swim_phase)) * 0.055
		texture_size.x *= pulse
		texture_size.y *= 2.0 - pulse

		var color := Color(0.68, 0.72, 1.0, 1.0)
		if state == 1:
			color = Color(0.86, 0.72, 1.0, 1.0)

		var angle_step: float = TAU / 24.0
		var pixel_angle: float = roundf(float(ciliate.angle) / angle_step) * angle_step

		draw_set_transform(position, pixel_angle, Vector2.ONE)
		draw_texture_rect(
			texture,
			Rect2(-texture_size * 0.5, texture_size),
			false,
			color
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		if selected_kind == "ciliate" and int(ciliate.id) == selected_id:
			var marker_size: float = maxf(3.4, float(ciliate.radius) * 2.5)
			draw_rect(
				Rect2(
					position - Vector2(marker_size, marker_size) * 0.5,
					Vector2(marker_size, marker_size)
				),
				Color(0.94, 1.0, 0.72, 0.90),
				false,
				maxf(0.12, 0.85 / zoom_value),
				false
			)


func _lineage_color(hue: float) -> Color:
	var normalized: float = wrapf(hue, 0.0, 1.0)
	var index: int = clampi(
		floori(normalized * float(LINEAGE_PALETTE.size())),
		0,
		LINEAGE_PALETTE.size() - 1
	)
	return LINEAGE_PALETTE[index]


func _size_class(cell: Variant) -> int:
	var length_value: float = float(cell.length)
	if length_value < 3.0:
		return 0
	if length_value < 4.5:
		return 1
	return 2


func _appendage_class(cell: Variant) -> int:
	var score: float = (
		float(cell.flagella_count)
		+ float(cell.pili_count) * 0.22
		+ float(cell.flagella_length) * 0.55
	)
	if score < 3.1:
		return 0
	if score < 4.8:
		return 1
	return 2


func _visible_world_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_extents: Vector2 = viewport_size * 0.5 / camera.zoom.x
	return Rect2(camera.position - half_extents, half_extents * 2.0)


func _refresh_field_texture() -> void:
	if sim == null or field_image == null or field_texture == null:
		return

	var nutrient_field: Variant = sim.nutrient
	var waste_field: Variant = sim.waste
	var oxygen_field: Variant = sim.oxygen
	var detritus_field: Variant = sim.detritus
	var eps_field: Variant = sim.eps
	var cue_field: Variant = sim.damage_cue
	var producer_field: Variant = sim.producer_biomass
	var width: int = int(nutrient_field.width)
	var height: int = int(nutrient_field.height)

	for y in range(height):
		for x in range(width):
			var nutrient_value: float = clampf(
				float(nutrient_field.get_cell(x, y)) * 1.65,
				0.0,
				1.0
			)
			var waste_value: float = clampf(
				float(waste_field.get_cell(x, y)) * 2.2,
				0.0,
				1.0
			)
			var oxygen_value: float = clampf(
				float(oxygen_field.get_cell(x, y)) * 1.35,
				0.0,
				1.0
			)
			var detritus_value: float = clampf(
				float(detritus_field.get_cell(x, y)) * 4.2,
				0.0,
				1.0
			)
			var eps_value: float = clampf(
				float(eps_field.get_cell(x, y)) * 5.0,
				0.0,
				1.0
			)
			var cue_value: float = clampf(
				float(cue_field.get_cell(x, y)) * 7.0,
				0.0,
				1.0
			)
			var producer_value: float = clampf(
				float(producer_field.get_cell(x, y)) * 1.35,
				0.0,
				1.0
			)

			var n: float = sqrt(nutrient_value)
			var w: float = sqrt(waste_value)
			var o: float = sqrt(oxygen_value)
			var d: float = sqrt(detritus_value)
			var e: float = sqrt(eps_value)
			var cue: float = sqrt(cue_value)
			var p: float = sqrt(producer_value)

			field_image.set_pixel(
				x,
				y,
				Color(
					clampf(
						0.004 + n * 0.012 + w * 0.11 + d * 0.15 + cue * 0.24,
						0.0,
						1.0
					),
					clampf(
						0.009 + n * 0.15 + o * 0.055 + p * 0.22 + e * 0.11,
						0.0,
						1.0
					),
					clampf(
						0.014 + n * 0.08 + o * 0.12 + w * 0.10 + e * 0.15,
						0.0,
						1.0
					),
					1.0
				)
			)

	field_texture.update(field_image)


func _refresh_selected_inspector() -> void:
	if ui == null or not ui.is_inspector_open() or selected_id < 0:
		return

	var organism: Variant = _selected_organism()
	if organism == null:
		_clear_selection()
		return

	ui.update_inspector(
		_inspector_title(organism),
		_inspector_body(organism)
	)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if (
			key_event.pressed
			and not key_event.echo
			and key_event.keycode == KEY_ESCAPE
		):
			if ui != null and ui.is_inspector_open():
				_clear_selection()
			elif ui != null and ui.is_menu_open():
				_resume_from_menu()
			else:
				_open_menu()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if ui != null and ui.is_menu_open():
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton

		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_zoom_at_screen_position(mouse_button.position, 1.22)
			get_viewport().set_input_as_handled()
			return

		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_at_screen_position(mouse_button.position, 1.0 / 1.22)
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
			_select_nearest_organism(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and dragging_camera:
		var motion := event as InputEventMouseMotion
		camera.position -= motion.relative / camera.zoom.x
		_clamp_camera_to_world()
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
				_reset_same_seed()
			KEY_N:
				_new_seed()
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

		get_viewport().set_input_as_handled()


func _zoom_at_screen_position(screen_position: Vector2, factor: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var viewport_center: Vector2 = viewport_size * 0.5
	var old_zoom: float = camera.zoom.x
	var minimum_zoom: float = _minimum_camera_zoom()
	var new_zoom: float = clampf(old_zoom * factor, minimum_zoom, MAX_ZOOM)
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
	_clamp_camera_to_world()


func _select_nearest_organism(world_position: Vector2) -> void:
	var best_id: int = -1
	var best_kind: String = ""
	var best_distance: float = INF
	var base_radius: float = maxf(1.0, 7.0 / camera.zoom.x)

	for cell in sim.bacteria:
		if bool(cell.consumed):
			continue
		var distance: float = Vector2(cell.position).distance_to(world_position)
		var radius: float = maxf(base_radius, float(cell.length) * 0.75)
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best_id = int(cell.id)
			best_kind = "bacterium"

	for proto in sim.protozoa:
		var distance: float = Vector2(proto.position).distance_to(world_position)
		var radius: float = maxf(base_radius * 1.2, float(proto.radius) * 1.5)
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best_id = int(proto.id)
			best_kind = "amoeba"

	for ciliate in sim.ciliates:
		var distance: float = Vector2(ciliate.position).distance_to(world_position)
		var radius: float = maxf(base_radius * 1.1, float(ciliate.radius) * 1.6)
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best_id = int(ciliate.id)
			best_kind = "ciliate"

	if best_id < 0:
		_clear_selection()
		return

	selected_id = best_id
	selected_kind = best_kind
	var organism: Variant = _selected_organism()
	if organism != null and ui != null:
		ui.show_inspector(
			_inspector_title(organism),
			_inspector_body(organism)
		)


func _selected_organism() -> Variant:
	if selected_id < 0:
		return null

	if selected_kind == "bacterium":
		return sim.find_cell_by_id(selected_id)

	if selected_kind == "amoeba":
		for proto in sim.protozoa:
			if int(proto.id) == selected_id:
				return proto

	if selected_kind == "ciliate":
		for ciliate in sim.ciliates:
			if int(ciliate.id) == selected_id:
				return ciliate

	return null


func _clear_selection() -> void:
	selected_id = -1
	selected_kind = ""
	if ui != null:
		ui.hide_inspector()


func _inspector_title(organism: Variant) -> String:
	match selected_kind:
		"bacterium":
			return "BAC  #%d" % int(organism.id)
		"amoeba":
			return "AMOEBA  #%d" % int(organism.id)
		"ciliate":
			return "CILIATE  #%d" % int(organism.id)
		_:
			return "ORGANISM"


func _inspector_body(organism: Variant) -> String:
	if selected_kind == "bacterium":
		var state: String = "motile"
		if bool(organism.dying):
			state = "lysis"
		elif bool(organism.dividing):
			state = "fission"
		elif int(organism.engulfed_by_id) >= 0:
			state = "engulfed"
		elif int(organism.transfer_role) == 1:
			state = "HGT donor"
		elif int(organism.transfer_role) == 2:
			state = "HGT receiver"
		elif float(organism.adhesion_timer) > 0.0:
			state = "adhering"

		var text: String = (
			"%s | E %.2f | L %.2f\n"
			+ "g%d  parent %d  lineage %d  age %.1fs\n"
			+ "speed %.2f  chemo %.2f  uptake %.2f\n"
			+ "growth %.2f  size %.2f  tumble %.2f\n"
			+ "adh %.2f  mut %.3f\n"
			+ "flag %d  pili %d\n"
			+ "DNA %s\nHGT %d  transfer %.0f%%"
		) % [
			state,
			float(organism.energy),
			float(organism.length),
			int(organism.generation),
			int(organism.parent_id),
			int(organism.lineage_id),
			float(organism.age),
			float(organism.gene_speed),
			float(organism.gene_chemotaxis),
			float(organism.gene_uptake),
			float(organism.gene_growth),
			float(organism.gene_size),
			float(organism.gene_tumble),
			float(organism.gene_adhesion),
			float(organism.mutation_rate),
			int(organism.flagella_count),
			int(organism.pili_count),
			String(organism.plasmid_names()),
			int(organism.hgt_events),
			float(organism.transfer_progress) * 100.0,
		]
		return text + _local_biome_text(Vector2(organism.position))

	if selected_kind == "amoeba":
		var state: String = (
			"feeding #%d" % int(organism.feeding_target_id)
			if int(organism.feeding_target_id) >= 0
			else "hunting"
		)
		if bool(organism.dying):
			state = "dying %.0f%%" % (float(organism.lysis_progress) * 100.0)

		var text: String = (
			"%s | E %.2f | R %.2f\n"
			+ "g%d  parent %d  lineage %d  age %.1fs\n"
			+ "feed %.0f%%  speed %.2f  sense %.2f\n"
			+ "engulf %.2f  size %.2f  metab %.2f\n"
			+ "mutation %.3f"
		) % [
			state,
			float(organism.energy),
			float(organism.radius),
			int(organism.generation),
			int(organism.parent_id),
			int(organism.lineage_id),
			float(organism.age),
			float(organism.feeding_progress) * 100.0,
			float(organism.gene_speed),
			float(organism.gene_perception),
			float(organism.gene_engulf),
			float(organism.gene_size),
			float(organism.gene_metabolism),
			float(organism.mutation_rate),
		]
		return text + _local_biome_text(Vector2(organism.position))

	if selected_kind == "ciliate":
		var state: String = (
			"feeding #%d" % int(organism.feeding_target_id)
			if int(organism.feeding_target_id) >= 0
			else "grazing"
		)
		if bool(organism.dying):
			state = "dying %.0f%%" % (float(organism.lysis_progress) * 100.0)

		var text: String = (
			"%s | E %.2f | R %.2f\n"
			+ "g%d  parent %d  lineage %d  age %.1fs\n"
			+ "feed %.0f%%  speed %.2f  sense %.2f\n"
			+ "capture %.2f  size %.2f  metab %.2f\n"
			+ "mutation %.3f"
		) % [
			state,
			float(organism.energy),
			float(organism.radius),
			int(organism.generation),
			int(organism.parent_id),
			int(organism.lineage_id),
			float(organism.age),
			float(organism.feeding_progress) * 100.0,
			float(organism.gene_speed),
			float(organism.gene_perception),
			float(organism.gene_capture),
			float(organism.gene_size),
			float(organism.gene_metabolism),
			float(organism.mutation_rate),
		]
		return text + _local_biome_text(Vector2(organism.position))

	return ""

func _local_biome_text(position: Vector2) -> String:
	if sim == null:
		return ""
	return (
		"\n\nLOCAL BIOME\n"
		+ "nutrient  %.3f\noxygen    %.3f\ndetritus  %.3f\n"
		+ "EPS       %.3f\ndamage    %.3f\nproducer  %.3f"
	) % [
		float(sim.nutrient.sample_world(position)),
		float(sim.oxygen.sample_world(position)),
		float(sim.detritus.sample_world(position)),
		float(sim.eps.sample_world(position)),
		float(sim.damage_cue.sample_world(position)),
		float(sim.producer_biomass.sample_world(position)),
	]


func _open_menu() -> void:
	if ui == null:
		return
	menu_pause_previous = paused
	paused = true
	dragging_camera = false
	ui.show_menu()


func _resume_from_menu() -> void:
	if ui == null:
		return
	ui.hide_menu()
	paused = menu_pause_previous


func _menu_fit() -> void:
	_fit_camera()
	_resume_from_menu()


func _menu_reset() -> void:
	_reset_same_seed()
	_resume_from_menu()


func _menu_new_seed() -> void:
	_new_seed()
	_resume_from_menu()


func _menu_quit() -> void:
	get_tree().quit()


func _reset_same_seed() -> void:
	_start_simulation(current_seed)
	_setup_field_texture()
	_refresh_field_texture()
	_fit_camera()


func _new_seed() -> void:
	_start_simulation(current_seed + 1)
	_setup_field_texture()
	_refresh_field_texture()
	_fit_camera()


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
	var pan_speed: float = 170.0 / maxf(camera.zoom.x, 0.08)
	camera.position += direction * pan_speed * delta
	_clamp_camera_to_world()


func _minimum_camera_zoom() -> float:
	if camera == null or sim == null:
		return 1.0

	var viewport_size: Vector2 = get_viewport_rect().size
	var world: Vector2 = Vector2(sim.world_size)
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return 1.0

	# "Cover", not "contain": the simulated world always fills the screen.
	# The user can only stay at this overview or zoom further in.
	return clampf(
		maxf(
			viewport_size.x / world.x,
			viewport_size.y / world.y
		),
		0.01,
		MAX_ZOOM
	)


func _clamp_camera_to_world() -> void:
	if camera == null or sim == null:
		return

	var minimum_zoom: float = _minimum_camera_zoom()
	if camera.zoom.x < minimum_zoom:
		camera.zoom = Vector2(minimum_zoom, minimum_zoom)

	var half_extents: Vector2 = get_viewport_rect().size * 0.5 / camera.zoom.x
	var world: Vector2 = Vector2(sim.world_size)
	var min_position: Vector2 = half_extents
	var max_position: Vector2 = world - half_extents

	camera.position.x = (
		world.x * 0.5
		if min_position.x > max_position.x
		else clampf(camera.position.x, min_position.x, max_position.x)
	)
	camera.position.y = (
		world.y * 0.5
		if min_position.y > max_position.y
		else clampf(camera.position.y, min_position.y, max_position.y)
	)


func _fit_camera() -> void:
	if camera == null or sim == null:
		return

	var fit_zoom: float = _minimum_camera_zoom()
	camera.position = Vector2(sim.world_size) * 0.5
	camera.zoom = Vector2(fit_zoom, fit_zoom)
	_clamp_camera_to_world()


func _smooth_metric(current: float, sample: float) -> float:
	if current <= 0.0:
		return sample
	return lerpf(current, sample, 0.18)
