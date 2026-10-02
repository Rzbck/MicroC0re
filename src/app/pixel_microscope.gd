extends Node2D

const PetriSimulationScript = preload("res://src/simulation/petri_simulation.gd")
const PixelAtlasScript = preload("res://src/app/pixel_microbe_atlas.gd")
const PixelBackgroundScript = preload("res://src/app/pixel_background.gd")

const FIXED_DT := 1.0 / 60.0
const MAX_STEPS_PER_FRAME := 12
const FIELD_REFRESH_INTERVAL := 1.0 / 20.0
const HUD_REFRESH_INTERVAL := 0.20
const MIN_ZOOM := 0.03
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

var hud_label: Label
var hud_refresh_accumulator: float = 0.0
var selected_id: int = -1

var sim_ms: float = 0.0
var field_ms: float = 0.0
var draw_ms: float = 0.0
var visible_cells: int = 0
var far_cells: int = 0
var sprite_cells: int = 0


func _ready() -> void:
	Engine.max_fps = 144
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.set_default_clear_color(Color(0.006, 0.010, 0.012, 1.0))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	atlas = PixelAtlasScript.new()
	_setup_infinite_background()
	_start_simulation(current_seed)
	_setup_camera()
	_setup_field_texture()
	_setup_hud()
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


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.name = "HUD"
	add_child(layer)

	var panel := ColorRect.new()
	panel.position = Vector2(6.0, 6.0)
	panel.size = Vector2(316.0, 74.0)
	panel.color = Color(0.005, 0.010, 0.012, 0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)

	hud_label = Label.new()
	hud_label.position = Vector2(10.0, 9.0)
	hud_label.size = Vector2(306.0, 68.0)
	hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_label.add_theme_font_size_override("font_size", 8)
	hud_label.add_theme_color_override("font_color", Color(0.84, 0.94, 0.88))
	layer.add_child(hud_label)


func _process(delta: float) -> void:
	visual_time += delta
	_handle_keyboard_pan(delta)

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

	hud_refresh_accumulator += delta
	if hud_refresh_accumulator >= HUD_REFRESH_INTERVAL:
		hud_refresh_accumulator = 0.0
		_update_hud()

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
	draw_rect(world_rect, Color(0.18, 0.30, 0.27, 0.55), false, 0.28, false)

	draw_ms = _smooth_metric(
		draw_ms,
		float(Time.get_ticks_usec() - draw_start) / 1000.0
	)


func _draw_bacteria() -> void:
	var visible_rect: Rect2 = _visible_world_rect().grow(8.0)
	var zoom_value: float = camera.zoom.x
	var far_lod: bool = zoom_value < 1.10
	var mid_lod: bool = zoom_value < 2.40
	var frame: int = posmod(int(floor(visual_time * 8.0)), 4)

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
			far_cells += 1
			var world_pixel: float = maxf(0.30, 1.15 / zoom_value)
			draw_rect(
				Rect2(
					position - Vector2(world_pixel, world_pixel) * 0.5,
					Vector2(world_pixel, world_pixel)
				),
				color,
				true
			)
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

		draw_set_transform(position, pixel_angle, Vector2.ONE)
		draw_texture_rect(
			texture,
			Rect2(-texture_size * 0.5, texture_size),
			false,
			color
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		if int(cell.id) == selected_id:
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

			var n: float = sqrt(nutrient_value)
			var w: float = sqrt(waste_value)
			field_image.set_pixel(
				x,
				y,
				Color(
					0.005 + n * 0.020 + w * 0.15,
					0.010 + n * 0.26 + w * 0.025,
					0.014 + n * 0.16 + w * 0.18,
					1.0
				)
			)

	field_texture.update(field_image)


func _update_hud() -> void:
	if hud_label == null or sim == null:
		return

	var state_text: String = "PAUSE" if paused else "RUN"
	hud_label.text = (
		"MICROC0RE  %s  FPS %d  zoom %.2f  sim %.1fx"
		% [
			state_text,
			Engine.get_frames_per_second(),
			camera.zoom.x,
			simulation_speed,
		]
	)
	hud_label.text += (
		"\ncells %d  visible %d  gen %d  divide %d  adhere %d  lysis %d"
		% [
			sim.bacteria.size(),
			visible_cells,
			int(sim.max_generation()),
			int(sim.count_dividing()),
			int(sim.count_adhering()),
			int(sim.count_lysing()),
		]
	)
	hud_label.text += (
		"\nms sim %.2f  field %.2f  draw %.2f  far %d  sprites %d"
		% [sim_ms, field_ms, draw_ms, far_cells, sprite_cells]
	)
	hud_label.text += (
		"\npairs %d -> %d -> %d -> %d"
		% [
			int(sim.pair_candidates_last),
			int(sim.pair_narrow_checks_last),
			int(sim.pair_interactions_last),
			int(sim.pair_contacts_last),
		]
	)
	hud_label.text += (
		"\nwheel zoom | RMB/MMB pan | WASD | click inspect | F fit | R reset | N seed"
	)

	if selected_id >= 0:
		var selected: Variant = sim.find_cell_by_id(selected_id)
		if selected == null:
			selected_id = -1
		else:
			hud_label.text += (
				"\n#%d g%d E%.2f speed%.2f chemo%.2f uptake%.2f adh%.2f"
				% [
					int(selected.id),
					int(selected.generation),
					float(selected.energy),
					float(selected.gene_speed),
					float(selected.gene_chemotaxis),
					float(selected.gene_uptake),
					float(selected.gene_adhesion),
				]
			)


func _unhandled_input(event: InputEvent) -> void:
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
			_select_nearest_cell(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and dragging_camera:
		var motion := event as InputEventMouseMotion
		camera.position -= motion.relative / camera.zoom.x
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


func _select_nearest_cell(world_position: Vector2) -> void:
	var best_id: int = -1
	var best_distance: float = INF
	var selection_radius: float = maxf(0.8, 8.0 / camera.zoom.x)

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
	var pan_speed: float = 170.0 / maxf(camera.zoom.x, 0.08)
	camera.position += direction * pan_speed * delta


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
	) * 0.88
	fit_zoom = clampf(fit_zoom, MIN_ZOOM, MAX_ZOOM)

	camera.position = world * 0.5
	camera.zoom = Vector2(fit_zoom, fit_zoom)


func _smooth_metric(current: float, sample: float) -> float:
	if current <= 0.0:
		return sample
	return lerpf(current, sample, 0.18)
