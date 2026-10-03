extends Node2D

const PetriSimulationScript = preload("res://src/simulation/petri_simulation.gd")
const BacteriumScript = preload("res://src/simulation/bacterium.gd")
const PixelAtlasScript = preload("res://src/app/pixel_microbe_atlas.gd")
const PixelBackgroundScript = preload("res://src/app/pixel_background.gd")
const FarMultiMeshRendererScript = preload("res://src/app/far_multimesh_renderer.gd")
const PixelProtozoaAtlasScript = preload("res://src/app/pixel_protozoa_atlas.gd")
const PixelCiliateAtlasScript = preload("res://src/app/pixel_ciliate_atlas.gd")
const PixelFlagellateAtlasScript = preload("res://src/app/pixel_flagellate_atlas.gd")
const PixelEcologyAtlasScript = preload("res://src/app/pixel_ecology_atlas.gd")
const BiomeMaterialRendererScript = preload("res://src/app/biome_material_renderer.gd")
const PixelEffectAtlasScript = preload("res://src/app/pixel_effect_atlas.gd")
const PixelDNAAtlasScript = preload("res://src/app/pixel_dna_atlas.gd")
const PixelHyphaAtlasScript = preload("res://src/app/pixel_hypha_atlas.gd")
const PixelPhageAtlasScript = preload("res://src/app/pixel_phage_atlas.gd")
const MicroscopeUIScript = preload("res://src/app/microscope_ui.gd")

const FIXED_DT := 1.0 / 60.0
const MAX_STEPS_PER_FRAME := 4
const SIMULATION_FRAME_BUDGET_USEC := 9000
const FIELD_REFRESH_INTERVAL := 0.5
const INSPECTOR_REFRESH_INTERVAL := 0.15
const MAX_ZOOM := 48.0
const SPRITE_WORLD_PIXEL := 0.25
const ANGLE_STEPS := 8.0
# Full source sprites only become eligible once one 0.25-world-unit art pixel
# is close to one internal viewport pixel. The transition is object-dithered:
# each organism is EITHER its overview silhouette OR its sprite, never two
# translucent representations on top of each other.
const SPRITE_LOD_START_ZOOM := 3.20
const SPRITE_LOD_END_ZOOM := 4.00
const DETAIL_LOD_ZOOM := 7.00
const WHEEL_ZOOM_FACTOR := 1.10
const FOCUS_CAMERA_RESPONSE := 9.0
const FOCUS_ZOOM_RESPONSE := 7.0
const FOCUS_MIN_MULTIPLIER := 2.65

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
var flagellate_atlas: Variant
var ecology_atlas: Variant
var biome_renderer: Node2D
var effect_atlas: Variant
var dna_atlas: Variant
var hypha_atlas: Variant
var phage_atlas: Variant
var far_renderer: Node2D
var ui: Variant
var current_seed: int = 1337

var accumulator: float = 0.0
var simulation_speed: float = 1.0
var paused: bool = false
var visual_time: float = 0.0

var camera: Camera2D
var dragging_camera: bool = false

var field_refresh_accumulator: float = 0.0

var inspector_refresh_accumulator: float = 0.0
var selected_id: int = -1
var selected_kind: String = ""
var follow_selected: bool = false
var focus_zoom_target: float = -1.0
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
	flagellate_atlas = PixelFlagellateAtlasScript.new()
	ecology_atlas = PixelEcologyAtlasScript.new()
	effect_atlas = PixelEffectAtlasScript.new()
	dna_atlas = PixelDNAAtlasScript.new()
	hypha_atlas = PixelHyphaAtlasScript.new()
	phage_atlas = PixelPhageAtlasScript.new()
	_setup_infinite_background()
	_setup_gpu_renderers()
	_start_simulation(current_seed)
	_setup_camera()
	_setup_biome_renderer()
	_setup_ui()
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
	follow_selected = false
	focus_zoom_target = -1.0
	if ui != null:
		ui.hide_inspector()


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "MicroscopeCamera"
	camera.enabled = true
	camera.position = Vector2(sim.world_size) * 0.5
	camera.zoom = Vector2(2.5, 2.5)
	add_child(camera)


func _setup_biome_renderer() -> void:
	biome_renderer = BiomeMaterialRendererScript.new()
	biome_renderer.name = "BiomeMaterialRenderer"
	add_child(biome_renderer)
	biome_renderer.initialize(sim)


func _setup_ui() -> void:
	ui = MicroscopeUIScript.new()
	ui.name = "MicroscopeUI"
	add_child(ui)

	ui.resume_requested.connect(_resume_from_menu)
	ui.fit_requested.connect(_menu_fit)
	ui.reset_requested.connect(_menu_reset)
	ui.new_seed_requested.connect(_menu_new_seed)
	ui.quit_requested.connect(_menu_quit)
	ui.inspector_close_requested.connect(_clear_selection)


func _process(delta: float) -> void:
	visual_time += delta
	if ui == null or not ui.is_menu_open():
		_handle_keyboard_pan(delta)
		_update_selection_camera(delta)
	_clamp_camera_to_world()

	var sim_start: int = Time.get_ticks_usec()
	if not paused:
		# Fixed-step biology remains deterministic, but the visible app must not
		# enter a catch-up death spiral when a tick becomes slower than realtime.
		# Once the per-frame simulation budget is spent, stale wall-clock backlog
		# is dropped instead of executing many expensive ticks in one render frame.
		accumulator += minf(delta * simulation_speed, 0.05)
		var steps: int = 0
		while accumulator >= FIXED_DT and steps < MAX_STEPS_PER_FRAME:
			sim.step(FIXED_DT)
			accumulator -= FIXED_DT
			steps += 1
			if Time.get_ticks_usec() - sim_start >= SIMULATION_FRAME_BUDGET_USEC:
				break
		if accumulator >= FIXED_DT:
			accumulator = fmod(accumulator, FIXED_DT)
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
		if biome_renderer != null:
			biome_renderer.refresh_from_sim(sim)
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
	# The water/biome shader renderer owns the dish background. Do not paint an
	# opaque world rectangle here: it would sit above the negative-z shader
	# layers and hide the entire biome, which was visible in the 2026-10-03
	# maintainer recording as a completely black dish.
	_draw_phage_clouds()
	_draw_bacteria()
	_draw_protozoa()
	_draw_ciliates()
	_draw_flagellates()
	_draw_microalgae()
	_draw_decomposers()
	_draw_hyphae()
	_draw_extracellular_dna()
	_draw_life_state_cues()
	_draw_active_feeding_links()
	_draw_gene_transfers()
	_draw_selection_focus()
	draw_rect(world_rect, Color(0.18, 0.30, 0.27, 0.55), false, 0.28, false)

	draw_ms = _smooth_metric(
		draw_ms,
		float(Time.get_ticks_usec() - draw_start) / 1000.0
	)


func _draw_phage_clouds() -> void:
	if sim == null or phage_atlas == null or camera == null:
		return
	var zoom_value: float = camera.zoom.x
	if zoom_value < SPRITE_LOD_START_ZOOM:
		return
	var visible_rect: Rect2 = _visible_world_rect().grow(12.0)

	for cloud in sim.phage_clouds:
		var center: Vector2 = Vector2(cloud.position)
		if not visible_rect.has_point(center):
			continue
		var alpha: float = clampf(
			0.22 + float(cloud.concentration) * 0.32,
			0.18,
			0.82
		)
		var spread: float = minf(float(cloud.radius) * 0.42, 4.0)
		for packet_index in range(3):
			var phase: float = (
				float(cloud.visual_phase)
				+ float(packet_index) * TAU / 3.0
				+ visual_time * (0.12 + float(packet_index) * 0.025)
			)
			var position: Vector2 = center + Vector2.RIGHT.rotated(phase) * (
				spread * (0.30 + float(packet_index) * 0.22)
			)
			var texture: Texture2D = phage_atlas.get_texture(
				int(cloud.id) + packet_index
			)
			var size: Vector2 = texture.get_size() * SPRITE_WORLD_PIXEL
			draw_texture_rect(
				texture,
				Rect2(position - size * 0.5, size),
				false,
				Color(0.88, 0.54, 1.0, alpha)
			)


func _draw_bacteria() -> void:
	var visible_rect: Rect2 = _visible_world_rect().grow(8.0)
	var zoom_value: float = camera.zoom.x
	var sprite_ratio: float = _sprite_lod_ratio(zoom_value)
	var mid_lod: bool = zoom_value < DETAIL_LOD_ZOOM
	var frame: int = posmod(int(floor(visual_time * 8.0)), 4)

	var far_count: int = 0
	if sprite_ratio < 0.999:
		far_count = int(far_renderer.update_from_cells(
			sim.bacteria,
			visible_rect,
			zoom_value,
			LINEAGE_PALETTE,
			sprite_ratio
		))
	else:
		far_renderer.clear()
	far_cells = far_count

	for cell in sim.bacteria:
		var position: Vector2 = Vector2(cell.position)
		if not visible_rect.has_point(position):
			continue
		if not _lod_uses_sprite(int(cell.id), sprite_ratio):
			continue

		visible_cells += 1
		var color: Color = _lineage_color(float(cell.lineage_hue))
		color = color.lerp(_guild_color(int(cell.guild)), 0.28)

		if bool(cell.dying):
			if bool(cell.phage_triggered_lysis):
				color = color.lerp(Color(0.92, 0.32, 0.96, color.a), 0.52)
			color.a = clampf(1.0 - float(cell.lysis_progress) * 0.72, 0.20, 1.0)
		elif bool(cell.phage_infected):
			color = color.lerp(Color(0.78, 0.36, 0.96, color.a), 0.55)
		elif bool(cell.dormant):
			color = color.lerp(Color(0.32, 0.46, 0.48, color.a), 0.72)
			color.a *= 0.78
		elif bool(cell.competent):
			color = color.lerp(Color(0.48, 0.92, 0.96, color.a), 0.28)
		elif float(cell.adhesion_timer) > 0.0:
			color = color.lightened(0.12)
		else:
			var starvation: float = clampf(1.0 - float(cell.energy) / 0.95, 0.0, 1.0)
			if starvation > 0.0:
				color = color.lerp(Color(0.60, 0.32, 0.24, color.a), starvation * 0.68)

		sprite_cells += 1
		var size_class: int = _size_class(cell)
		var appendage_class: int = 0 if mid_lod else _appendage_class(cell)
		var state: int = 0
		if bool(cell.dying):
			state = 2
		elif bool(cell.dividing):
			state = 1

		var cell_frame: int = (
			0
			if bool(cell.dormant)
			else posmod(frame + int(floor(float(cell.visual_phase))), 4)
		)
		var texture: Texture2D = atlas.get_texture(
			clampi(int(cell.guild), 0, 3),
			size_class,
			appendage_class,
			cell_frame,
			state
		)

		var angle_step: float = TAU / ANGLE_STEPS
		var pixel_angle: float = roundf(float(cell.angle) / angle_step) * angle_step
		var texture_size: Vector2 = texture.get_size() * SPRITE_WORLD_PIXEL
		if float(cell.engulf_progress) > 0.0:
			color.a *= 1.0 - 0.72 * float(cell.engulf_progress)

		draw_set_transform(position, pixel_angle, Vector2.ONE)
		draw_texture_rect(
			texture,
			Rect2(-texture_size * 0.5, texture_size),
			false,
			color
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_gene_transfers() -> void:
	if sim == null or camera == null or camera.zoom.x < 1.8:
		return

	var pixel_size: float = SPRITE_WORLD_PIXEL
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
	var sprite_ratio: float = _sprite_lod_ratio(zoom_value)

	for proto in sim.protozoa:
		var position: Vector2 = Vector2(proto.position)
		if not visible_rect.has_point(position):
			continue
		if not _lod_uses_sprite(int(proto.id), sprite_ratio):
			_draw_overview_marker(
				position,
				4.0,
				3.0,
				Color(0.34, 0.82, 0.78, 0.96),
				1.0
			)
			continue

		var state: int = 1 if int(proto.feeding_target_id) >= 0 else 0
		var frame: int = (
			clampi(floori(float(proto.feeding_progress) * 5.999), 0, 5)
			if state == 1
			else posmod(
				int(floor(visual_time * 6.0)) + int(proto.id),
				6
			)
		)
		var texture: Texture2D = protozoa_atlas.get_texture(frame, state)
		var texture_size: Vector2 = texture.get_size() * SPRITE_WORLD_PIXEL
		var color := Color(0.38, 0.88, 0.78, 1.0)
		if state == 1:
			color = Color(0.55, 0.96, 0.73, 1.0)
		elif not bool(proto.dying):
			var starvation: float = clampf(1.0 - float(proto.energy) / 2.2, 0.0, 1.0)
			if starvation > 0.0:
				color = color.lerp(Color(0.45, 0.46, 0.43, 1.0), starvation * 0.58)
		if bool(proto.dying):
			var death_progress: float = clampf(float(proto.lysis_progress), 0.0, 1.0)
			color = Color(0.92, 0.48, 0.34, clampf(1.0 - death_progress * 0.82, 0.16, 1.0))

		var angle_step: float = TAU / ANGLE_STEPS
		var pixel_angle: float = roundf(float(proto.angle) / angle_step) * angle_step
		draw_set_transform(position, pixel_angle, Vector2.ONE)
		draw_texture_rect(texture, Rect2(-texture_size * 0.5, texture_size), false, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if bool(proto.dying):
			_draw_lysis_fragments(position, int(proto.id), float(proto.lysis_progress), color, zoom_value)

func _draw_ciliates() -> void:
	if sim == null or ciliate_atlas == null:
		return

	var visible_rect: Rect2 = _visible_world_rect().grow(10.0)
	var zoom_value: float = camera.zoom.x
	var sprite_ratio: float = _sprite_lod_ratio(zoom_value)

	for ciliate in sim.ciliates:
		var position: Vector2 = Vector2(ciliate.position)
		if not visible_rect.has_point(position):
			continue
		if not _lod_uses_sprite(int(ciliate.id), sprite_ratio):
			_draw_overview_marker(
				position,
				4.2,
				2.0,
				Color(0.60, 0.66, 0.98, 0.96),
				1.0
			)
			continue

		var state: int = 1 if int(ciliate.feeding_target_id) >= 0 else 0
		var frame: int = (
			clampi(floori(float(ciliate.feeding_progress) * 5.999), 0, 5)
			if state == 1
			else posmod(
				int(floor(visual_time * 9.0)) + int(ciliate.id),
				6
			)
		)
		var texture: Texture2D = ciliate_atlas.get_texture(frame, state)
		var texture_size: Vector2 = texture.get_size() * SPRITE_WORLD_PIXEL
		var color := Color(0.68, 0.72, 1.0, 1.0)
		if state == 1:
			color = Color(0.86, 0.72, 1.0, 1.0)
		elif not bool(ciliate.dying):
			var starvation: float = clampf(1.0 - float(ciliate.energy) / 1.8, 0.0, 1.0)
			if starvation > 0.0:
				color = color.lerp(Color(0.48, 0.47, 0.50, 1.0), starvation * 0.55)
		if float(ciliate.engulf_progress) > 0.0:
			color.a *= 1.0 - 0.70 * clampf(float(ciliate.engulf_progress), 0.0, 1.0)
		if bool(ciliate.dying):
			var death_progress: float = clampf(float(ciliate.lysis_progress), 0.0, 1.0)
			color = Color(0.96, 0.52, 0.38, clampf(1.0 - death_progress * 0.84, 0.14, 1.0))

		var angle_step: float = TAU / ANGLE_STEPS
		var pixel_angle: float = roundf(float(ciliate.angle) / angle_step) * angle_step
		draw_set_transform(position, pixel_angle, Vector2.ONE)
		draw_texture_rect(texture, Rect2(-texture_size * 0.5, texture_size), false, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if bool(ciliate.dying):
			_draw_lysis_fragments(position, int(ciliate.id), float(ciliate.lysis_progress), color, zoom_value)

func _draw_flagellates() -> void:
	if sim == null or flagellate_atlas == null:
		return

	var visible_rect: Rect2 = _visible_world_rect().grow(8.0)
	var zoom_value: float = camera.zoom.x
	var sprite_ratio: float = _sprite_lod_ratio(zoom_value)

	for flagellate in sim.flagellates:
		var position: Vector2 = Vector2(flagellate.position)
		if not visible_rect.has_point(position):
			continue
		if not _lod_uses_sprite(int(flagellate.id), sprite_ratio):
			_draw_overview_marker(
				position,
				3.0,
				1.5,
				Color(0.96, 0.78, 0.30, 0.96),
				1.0
			)
			continue

		var state: int = 1 if int(flagellate.feeding_target_id) >= 0 else 0
		var frame: int = (
			clampi(floori(float(flagellate.feeding_progress) * 5.999), 0, 5)
			if state == 1
			else posmod(
				int(floor(visual_time * 8.0)) + int(flagellate.id),
				6
			)
		)
		var texture: Texture2D = flagellate_atlas.get_texture(frame, state)
		var texture_size: Vector2 = texture.get_size() * SPRITE_WORLD_PIXEL
		var color := Color(1.0, 0.84, 0.38, 1.0)
		if float(flagellate.energy) < 1.4 and not bool(flagellate.dying):
			var starvation: float = clampf(1.0 - float(flagellate.energy) / 1.4, 0.0, 1.0)
			color = color.lerp(Color(0.52, 0.43, 0.28, 1.0), starvation * 0.70)
		if float(flagellate.engulf_progress) > 0.0:
			color.a *= 1.0 - clampf(float(flagellate.engulf_progress), 0.0, 1.0) * 0.72
		if bool(flagellate.dying):
			var death: float = clampf(float(flagellate.lysis_progress), 0.0, 1.0)
			color = Color(0.94, 0.46, 0.20, clampf(1.0 - death * 0.84, 0.14, 1.0))

		var angle_step: float = TAU / ANGLE_STEPS
		var pixel_angle: float = roundf(float(flagellate.angle) / angle_step) * angle_step
		draw_set_transform(position, pixel_angle, Vector2.ONE)
		draw_texture_rect(texture, Rect2(-texture_size * 0.5, texture_size), false, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if bool(flagellate.dying):
			_draw_lysis_fragments(position, int(flagellate.id), float(flagellate.lysis_progress), color, zoom_value)

func _draw_microalgae() -> void:
	if sim == null or ecology_atlas == null:
		return

	var visible_rect: Rect2 = _visible_world_rect().grow(8.0)
	var zoom_value: float = camera.zoom.x
	var sprite_ratio: float = _sprite_lod_ratio(zoom_value)

	for alga in sim.microalgae:
		var position: Vector2 = Vector2(alga.position)
		if not visible_rect.has_point(position):
			continue
		if not _lod_uses_sprite(int(alga.id), sprite_ratio):
			_draw_overview_marker(
				position,
				3.0,
				3.0,
				Color(0.42, 1.0, 0.38, 0.95),
				1.0
			)
			continue

		var state: int = 0
		if bool(alga.dying):
			state = 2
		elif bool(alga.reproducing):
			state = 1

		var frame: int = (
			clampi(floori(float(alga.reproduction_progress) * 3.999), 0, 3)
			if bool(alga.reproducing)
			else (
				clampi(floori(float(alga.lysis_progress) * 3.999), 0, 3)
				if bool(alga.dying)
				else posmod(int(floor(visual_time * 4.0 + float(alga.visual_phase))), 4)
			)
		)
		var texture: Texture2D = ecology_atlas.get_texture(0, state, frame)
		var texture_size: Vector2 = texture.get_size() * SPRITE_WORLD_PIXEL
		var local_light: float = float(sim.sample_light(position))
		var color := Color(
			0.34 + local_light * 0.18,
			0.62 + local_light * 0.38,
			0.28 + local_light * 0.18,
			1.0
		)
		if not bool(alga.dying):
			var starvation: float = clampf(1.0 - float(alga.energy) / 1.25, 0.0, 1.0)
			if starvation > 0.0:
				color = color.lerp(Color(0.62, 0.48, 0.20, 1.0), starvation * 0.72)
		if float(alga.engulf_progress) > 0.0:
			color.a *= 1.0 - clampf(float(alga.engulf_progress), 0.0, 1.0) * 0.74
		if bool(alga.dying):
			var death: float = clampf(float(alga.lysis_progress), 0.0, 1.0)
			color = Color(0.82, 0.80, 0.28, clampf(1.0 - death * 0.82, 0.15, 1.0))

		var angle_step: float = TAU / ANGLE_STEPS
		var pixel_angle: float = roundf(float(alga.angle) / angle_step) * angle_step
		draw_set_transform(position, pixel_angle, Vector2.ONE)
		draw_texture_rect(texture, Rect2(-texture_size * 0.5, texture_size), false, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		if bool(alga.dying):
			_draw_lysis_fragments(position, int(alga.id), float(alga.lysis_progress), color, zoom_value)

func _draw_decomposers() -> void:
	if sim == null or ecology_atlas == null:
		return

	var visible_rect: Rect2 = _visible_world_rect().grow(8.0)
	var zoom_value: float = camera.zoom.x
	var sprite_ratio: float = _sprite_lod_ratio(zoom_value)

	for yeast in sim.decomposers:
		var position: Vector2 = Vector2(yeast.position)
		if not visible_rect.has_point(position):
			continue
		if not _lod_uses_sprite(int(yeast.id), sprite_ratio):
			_draw_overview_marker(
				position,
				3.0,
				2.5,
				Color(0.96, 0.64, 0.27, 0.96),
				1.0
			)
			continue

		var state: int = 0
		if bool(yeast.dying):
			state = 2
		elif bool(yeast.budding):
			state = 1

		var frame: int = (
			clampi(floori(float(yeast.budding_progress) * 3.999), 0, 3)
			if bool(yeast.budding)
			else (
				clampi(floori(float(yeast.lysis_progress) * 3.999), 0, 3)
				if bool(yeast.dying)
				else posmod(int(floor(visual_time * 4.5 + float(yeast.visual_phase))), 4)
			)
		)
		var texture: Texture2D = ecology_atlas.get_texture(1, state, frame)
		var texture_size: Vector2 = texture.get_size() * SPRITE_WORLD_PIXEL
		var color := Color(1.0, 0.70, 0.34, 1.0)
		if not bool(yeast.dying):
			var starvation: float = clampf(1.0 - float(yeast.energy) / 1.20, 0.0, 1.0)
			if starvation > 0.0:
				color = color.lerp(Color(0.58, 0.30, 0.22, 1.0), starvation * 0.70)
		if float(yeast.engulf_progress) > 0.0:
			color.a *= 1.0 - clampf(float(yeast.engulf_progress), 0.0, 1.0) * 0.74
		if bool(yeast.dying):
			var death: float = clampf(float(yeast.lysis_progress), 0.0, 1.0)
			color = Color(0.90, 0.43, 0.25, clampf(1.0 - death * 0.82, 0.15, 1.0))

		var angle_step: float = TAU / ANGLE_STEPS
		var pixel_angle: float = roundf(float(yeast.angle) / angle_step) * angle_step
		draw_set_transform(position, pixel_angle, Vector2.ONE)
		draw_texture_rect(texture, Rect2(-texture_size * 0.5, texture_size), false, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		if bool(yeast.dying):
			_draw_lysis_fragments(position, int(yeast.id), float(yeast.lysis_progress), color, zoom_value)

func _draw_hyphae() -> void:
	if sim == null or hypha_atlas == null or camera == null:
		return
	var visible_rect: Rect2 = _visible_world_rect().grow(5.0)
	var sprite_ratio: float = _sprite_lod_ratio(camera.zoom.x)

	for colony in sim.hyphae:
		if colony.nodes.is_empty():
			continue
		if not visible_rect.has_point(Vector2(colony.position)):
			var any_visible: bool = false
			for node in colony.nodes:
				if visible_rect.has_point(Vector2(node)):
					any_visible = true
					break
			if not any_visible:
				continue

		if not _lod_uses_sprite(int(colony.id), sprite_ratio):
			_draw_overview_marker(
				Vector2(colony.position),
				4.0 + minf(4.0, sqrt(float(colony.nodes.size()))),
				2.0,
				Color(0.86, 0.72, 0.42, 0.88),
				1.0
			)
			continue

		var child_counts: Array[int] = []
		child_counts.resize(colony.nodes.size())
		child_counts.fill(0)
		for node_index in range(1, colony.nodes.size()):
			var parent_index: int = int(colony.parents[node_index])
			if parent_index >= 0 and parent_index < child_counts.size():
				child_counts[parent_index] += 1

		var colony_color := Color(0.92, 0.78, 0.48, 1.0)
		if bool(colony.dying):
			var death: float = clampf(float(colony.lysis_progress), 0.0, 1.0)
			colony_color = Color(0.72, 0.36, 0.20, 1.0 - death * 0.78)

		for node_index in range(1, colony.nodes.size()):
			var parent_index: int = int(colony.parents[node_index])
			if parent_index < 0 or parent_index >= colony.nodes.size():
				continue
			var a: Vector2 = colony.nodes[parent_index]
			var b: Vector2 = colony.nodes[node_index]
			var delta: Vector2 = b - a
			if delta.length_squared() <= 0.000001:
				continue
			var texture: Texture2D = hypha_atlas.get_texture(
				PixelHyphaAtlasScript.KIND_SEGMENT,
				node_index
			)
			var size: Vector2 = texture.get_size() * SPRITE_WORLD_PIXEL
			var angle_step: float = TAU / ANGLE_STEPS
			var angle: float = roundf(delta.angle() / angle_step) * angle_step
			draw_set_transform(a.lerp(b, 0.5), angle, Vector2.ONE)
			draw_texture_rect(texture, Rect2(-size * 0.5, size), false, colony_color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		for node_index in range(colony.nodes.size()):
			var is_tip: bool = colony.tips.has(node_index)
			var is_junction: bool = child_counts[node_index] > 1
			if not is_tip and not is_junction:
				continue
			var kind: int = (
				PixelHyphaAtlasScript.KIND_TIP
				if is_tip
				else PixelHyphaAtlasScript.KIND_JUNCTION
			)
			var texture: Texture2D = hypha_atlas.get_texture(kind, node_index)
			var size: Vector2 = texture.get_size() * SPRITE_WORLD_PIXEL
			draw_texture_rect(
				texture,
				Rect2(Vector2(colony.nodes[node_index]) - size * 0.5, size),
				false,
				colony_color
			)

func _draw_extracellular_dna() -> void:
	if sim == null or dna_atlas == null or camera == null:
		return
	if camera.zoom.x < SPRITE_LOD_START_ZOOM:
		return
	var visible_rect: Rect2 = _visible_world_rect().grow(2.0)
	for fragment in sim.dna_fragments:
		var position: Vector2 = Vector2(fragment.position)
		if not visible_rect.has_point(position):
			continue
		var texture: Texture2D = dna_atlas.get_texture(int(fragment.id))
		var size: Vector2 = texture.get_size() * SPRITE_WORLD_PIXEL
		var age_alpha: float = clampf(
			1.0 - float(fragment.age) / maxf(0.001, float(fragment.lifetime)),
			0.10,
			1.0
		)
		var color := Color(0.74, 0.96, 1.0, 0.34 + age_alpha * 0.46)
		draw_texture_rect(
			texture,
			Rect2(position - size * 0.5, size),
			false,
			color
		)


func _draw_life_state_cues() -> void:
	if sim == null or camera == null or effect_atlas == null:
		return
	var visible_rect: Rect2 = _visible_world_rect().grow(6.0)
	var zoom_value: float = camera.zoom.x
	if zoom_value < SPRITE_LOD_START_ZOOM:
		return
	var frame: int = posmod(floori(visual_time * 7.0), 4)

	for cell in sim.bacteria:
		var p: Vector2 = Vector2(cell.position)
		if not visible_rect.has_point(p):
			continue
		if bool(cell.phage_infected) and not bool(cell.dying):
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_STRESS,
				frame,
				1.02 + float(cell.phage_progress) * 0.18
			)
		elif bool(cell.dividing):
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_DIVISION,
				frame,
				1.05
			)
		elif float(cell.adhesion_timer) > 0.0:
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_ADHESION,
				frame,
				1.00
			)
		elif float(cell.energy) < 0.72:
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_STRESS,
				frame,
				0.86
			)

	for alga in sim.microalgae:
		var p: Vector2 = Vector2(alga.position)
		if not visible_rect.has_point(p):
			continue
		if bool(alga.reproducing):
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_REPRODUCTION,
				frame,
				1.05
			)
		elif not bool(alga.dying) and float(alga.energy) < 0.82:
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_STRESS,
				frame,
				0.84
			)

	for yeast in sim.decomposers:
		var p: Vector2 = Vector2(yeast.position)
		if not visible_rect.has_point(p):
			continue
		if bool(yeast.budding):
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_REPRODUCTION,
				frame,
				1.02
			)
		elif not bool(yeast.dying) and float(yeast.energy) < 0.78:
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_STRESS,
				frame,
				0.82
			)


	for proto in sim.protozoa:
		var p: Vector2 = Vector2(proto.position)
		if not visible_rect.has_point(p) or bool(proto.dying):
			continue
		if int(proto.feeding_target_id) >= 0:
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_PURSUIT,
				frame,
				1.08
			)
		elif float(proto.cooldown) > 0.0:
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_DIGESTION,
				frame,
				1.04
			)

	for ciliate in sim.ciliates:
		var p: Vector2 = Vector2(ciliate.position)
		if not visible_rect.has_point(p) or bool(ciliate.dying):
			continue
		if int(ciliate.feeding_target_id) >= 0:
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_PURSUIT,
				frame,
				0.96
			)
		elif float(ciliate.cooldown) > 0.0:
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_DIGESTION,
				frame,
				0.92
			)


	for flagellate in sim.flagellates:
		var p: Vector2 = Vector2(flagellate.position)
		if not visible_rect.has_point(p) or bool(flagellate.dying):
			continue
		if int(flagellate.feeding_target_id) >= 0:
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_PURSUIT,
				frame,
				0.72
			)
		elif float(flagellate.cooldown) > 0.0:
			_draw_effect_asset(
				p,
				PixelEffectAtlasScript.EFFECT_DIGESTION,
				frame,
				0.68
			)


func _draw_effect_asset(
	position: Vector2,
	kind: int,
	frame: int,
	_scale: float
) -> void:
	if effect_atlas == null or camera == null:
		return
	var texture: Texture2D = effect_atlas.get_texture(kind, frame)
	var size: Vector2 = texture.get_size() * SPRITE_WORLD_PIXEL
	draw_texture_rect(
		texture,
		Rect2(position - size * 0.5, size),
		false
	)


func _draw_reproduction_orbit(
	position: Vector2,
	progress: float,
	px: float,
	color: Color
) -> void:
	var radius: float = 1.4 + clampf(progress, 0.0, 1.0) * 1.8
	for i in range(4):
		var phase: float = float(i) * TAU / 4.0 + visual_time * 1.4
		var q: Vector2 = position + Vector2.RIGHT.rotated(phase) * radius
		draw_rect(
			Rect2(q - Vector2.ONE * px * 0.45, Vector2.ONE * px * 0.90),
			color,
			true
		)


func _draw_selection_focus() -> void:
	if selected_id < 0 or camera == null:
		return
	var organism: Variant = _selected_organism()
	if organism == null:
		return

	var p: Vector2 = Vector2(organism.position)
	var px: float = maxf(0.10, 0.88 / camera.zoom.x)
	var biological_size: float = 3.0
	if selected_kind == "bacterium":
		biological_size = maxf(2.4, float(organism.length) * 0.72)
	else:
		biological_size = maxf(3.0, float(organism.radius) * 2.15)
	var r: float = biological_size * 0.72 + px * 2.0
	var arm: float = px * 2.4
	var pulse: float = 0.78 + 0.22 * sin(visual_time * 4.0)
	var c := Color(0.88, 1.0, 0.70, 0.64 * pulse)

	# Four pixel-art microscope brackets: no giant debug rectangle.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := p + Vector2(r * sx, r * sy)
			draw_rect(
				Rect2(corner + Vector2(-arm if sx > 0.0 else 0.0, -px * 0.5), Vector2(arm, px)),
				c,
				true
			)
			draw_rect(
				Rect2(corner + Vector2(-px * 0.5, -arm if sy > 0.0 else 0.0), Vector2(px, arm)),
				c,
				true
			)

	# A short trailing focus wake makes motion easy to perceive while tracking.
	var axis: Vector2 = Vector2.RIGHT.rotated(float(organism.angle))
	for i in range(3):
		var distance: float = r + px * (2.0 + float(i) * 2.0)
		var q: Vector2 = p - axis * distance
		var wake := Color(0.64, 0.92, 0.88, 0.28 - float(i) * 0.07)
		draw_rect(
			Rect2(q - Vector2.ONE * px * 0.38, Vector2.ONE * px * 0.76),
			wake,
			true
		)


func _sprite_lod_ratio(zoom_value: float) -> float:
	return smoothstep(
		SPRITE_LOD_START_ZOOM,
		SPRITE_LOD_END_ZOOM,
		zoom_value
	)


func _lod_roll(organism_id: int) -> float:
	var value: int = (
		organism_id * 1103515245
		+ 12345
	) & 0x7fffffff
	return float(value % 4093) / 4093.0


func _lod_uses_sprite(organism_id: int, sprite_ratio: float) -> bool:
	return _lod_roll(organism_id) < clampf(sprite_ratio, 0.0, 1.0)


func _overview_sprite_blend(zoom_value: float) -> float:
	# Kept as a semantic visibility helper for interaction overlays. Organism
	# LOD itself is binary/dithered and never alpha-crossfades two bodies.
	return _sprite_lod_ratio(zoom_value)


func _draw_overview_marker(
	position: Vector2,
	width_pixels: float,
	height_pixels: float,
	color: Color,
	alpha_scale: float
) -> void:
	var pixel_world: float = 1.0 / maxf(camera.zoom.x, 0.001)
	var marker_size := Vector2(
		maxf(0.22, width_pixels * pixel_world),
		maxf(0.18, height_pixels * pixel_world)
	)
	var marker_color: Color = color
	marker_color.a *= clampf(alpha_scale, 0.0, 1.0)
	draw_rect(
		Rect2(position - marker_size * 0.5, marker_size),
		marker_color,
		true
	)

	# One bright center cluster keeps the far silhouette biological rather than
	# reading as an isolated single debug pixel.
	if marker_color.a > 0.20:
		var core_size := Vector2.ONE * maxf(0.14, 0.72 * pixel_world)
		var core_color: Color = marker_color.lightened(0.22)
		core_color.a *= 0.70
		draw_rect(
			Rect2(position - core_size * 0.5, core_size),
			core_color,
			true
		)


func _draw_active_feeding_links() -> void:
	if sim == null or camera == null:
		return

	for proto in sim.protozoa:
		if int(proto.feeding_target_id) < 0:
			continue
		var prey: Variant = sim.find_edible_by_id(int(proto.feeding_target_id))
		if prey == null:
			continue
		_draw_feeding_link(
			Vector2(proto.position),
			Vector2(prey.position),
			float(proto.feeding_progress),
			Color(1.0, 0.58, 0.26, 0.94),
			int(proto.id)
		)

	for ciliate in sim.ciliates:
		if int(ciliate.feeding_target_id) < 0:
			continue
		var prey: Variant = sim.find_edible_by_id(int(ciliate.feeding_target_id))
		if prey == null:
			continue
		_draw_feeding_link(
			Vector2(ciliate.position),
			Vector2(prey.position),
			float(ciliate.feeding_progress),
			Color(0.92, 0.55, 1.0, 0.92),
			int(ciliate.id)
		)


	for flagellate in sim.flagellates:
		if int(flagellate.feeding_target_id) < 0:
			continue
		var prey: Variant = sim.find_edible_by_id(int(flagellate.feeding_target_id))
		if prey == null:
			continue
		_draw_feeding_link(
			Vector2(flagellate.position),
			Vector2(prey.position),
			float(flagellate.feeding_progress),
			Color(1.0, 0.78, 0.30, 0.90),
			int(flagellate.id)
		)


func _draw_feeding_link(
	predator_position: Vector2,
	prey_position: Vector2,
	progress: float,
	color: Color,
	organism_id: int
) -> void:
	var delta: Vector2 = predator_position - prey_position
	if delta.length_squared() <= 0.000001:
		return

	var zoom_value: float = camera.zoom.x
	var pixel_size: float = SPRITE_WORLD_PIXEL
	var normal: Vector2 = delta.normalized().orthogonal()
	var visibility: float = lerpf(
		0.50,
		1.0,
		_overview_sprite_blend(zoom_value)
	)
	var pulse_index: int = posmod(
		floori(visual_time * 13.0) + organism_id,
		7
	)

	for i in range(7):
		var t: float = float(i + 1) / 8.0
		var p: Vector2 = prey_position.lerp(predator_position, t)
		p += normal * sin(visual_time * 9.0 + float(i) * 1.7) * pixel_size * 0.55
		var bead_color: Color = color
		bead_color.a *= visibility * (0.42 + progress * 0.42)
		if i == pulse_index:
			bead_color = bead_color.lightened(0.30)
			bead_color.a = minf(1.0, bead_color.a + 0.32)
		draw_rect(
			Rect2(
				p - Vector2(pixel_size, pixel_size) * 0.5,
				Vector2(pixel_size, pixel_size)
			),
			bead_color,
			true
		)

	_draw_effect_asset(
		predator_position,
		PixelEffectAtlasScript.EFFECT_FEEDING,
		posmod(floori(visual_time * 8.0) + organism_id, 4),
		1.0 + clampf(progress, 0.0, 1.0) * 0.18
	)

	# Pixel vacuole/handling ring around the predator grows through ingestion.
	var ring_radius: float = pixel_size * (2.0 + clampf(progress, 0.0, 1.0) * 1.8)
	for i in range(6):
		var phase: float = float(i) * TAU / 6.0 + visual_time * 1.6
		var p: Vector2 = predator_position + Vector2.RIGHT.rotated(phase) * ring_radius
		var ring_color: Color = color.lightened(0.18)
		ring_color.a *= visibility * (0.30 + progress * 0.55)
		draw_rect(
			Rect2(
				p - Vector2(pixel_size, pixel_size) * 0.42,
				Vector2(pixel_size, pixel_size) * 0.84
			),
			ring_color,
			true
		)


func _draw_lysis_fragments(
	position: Vector2,
	organism_id: int,
	progress: float,
	color: Color,
	zoom_value: float
) -> void:
	if progress <= 0.05:
		return
	_draw_effect_asset(
		position,
		PixelEffectAtlasScript.EFFECT_LYSIS,
		clampi(floori(clampf(progress, 0.0, 0.999) * 4.0), 0, 3),
		1.0 + progress * 0.30
	)
	var pixel_size: float = SPRITE_WORLD_PIXEL
	var radius: float = 0.7 + progress * 3.2
	for i in range(6):
		var phase: float = (
			float(i) * TAU / 6.0
			+ float(organism_id % 11) * 0.37
		)
		var offset: Vector2 = Vector2.RIGHT.rotated(phase) * radius
		var fragment_color: Color = color
		fragment_color.a *= 0.75 * (1.0 - progress * 0.55)
		draw_rect(
			Rect2(
				position + offset - Vector2(pixel_size, pixel_size) * 0.5,
				Vector2(pixel_size, pixel_size)
			),
			fragment_color,
			true
		)

	# A larger warm pixel bloom makes death readable at normal zoom and leaves
	# a visual hand-off toward the detritus/damage fields behind the organism.
	var bloom_radius: float = 1.8 + progress * 5.2
	for i in range(8):
		var phase: float = (
			float(i) * TAU / 8.0
			+ float(organism_id % 7) * 0.29
		)
		var p: Vector2 = position + Vector2.RIGHT.rotated(phase) * bloom_radius
		var bloom_color := Color(
			1.0,
			0.34 + progress * 0.12,
			0.16,
			0.42 * (1.0 - progress * 0.58)
		)
		draw_rect(
			Rect2(
				p - Vector2(pixel_size, pixel_size) * 0.55,
				Vector2(pixel_size, pixel_size) * 1.10
			),
			bloom_color,
			true
		)
func _guild_color(guild: int) -> Color:
	match guild:
		BacteriumScript.GUILD_SCAVENGER:
			return Color(0.92, 0.61, 0.24, 1.0)
		BacteriumScript.GUILD_BIOFILM:
			return Color(0.34, 0.92, 0.66, 1.0)
		BacteriumScript.GUILD_PHOTOTROPH:
			return Color(0.40, 0.95, 0.32, 1.0)
		_:
			return Color(0.70, 0.76, 0.94, 1.0)


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
			_zoom_at_screen_position(mouse_button.position, WHEEL_ZOOM_FACTOR)
			get_viewport().set_input_as_handled()
			return

		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_at_screen_position(mouse_button.position, 1.0 / WHEEL_ZOOM_FACTOR)
			get_viewport().set_input_as_handled()
			return

		if (
			mouse_button.button_index == MOUSE_BUTTON_RIGHT
			or mouse_button.button_index == MOUSE_BUTTON_MIDDLE
		):
			dragging_camera = mouse_button.pressed
			if mouse_button.pressed:
				follow_selected = false
				focus_zoom_target = -1.0
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

	if follow_selected:
		camera.zoom = Vector2(new_zoom, new_zoom)
		focus_zoom_target = -1.0
		var organism: Variant = _selected_organism()
		if organism != null:
			camera.position = Vector2(organism.position)
	else:
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

	for flagellate in sim.flagellates:
		var distance: float = Vector2(flagellate.position).distance_to(world_position)
		var radius: float = maxf(base_radius, float(flagellate.radius) * 1.7)
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best_id = int(flagellate.id)
			best_kind = "flagellate"

	for alga in sim.microalgae:
		var distance: float = Vector2(alga.position).distance_to(world_position)
		var radius: float = maxf(base_radius, float(alga.radius) * 1.7)
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best_id = int(alga.id)
			best_kind = "alga"

	for yeast in sim.decomposers:
		var distance: float = Vector2(yeast.position).distance_to(world_position)
		var radius: float = maxf(base_radius, float(yeast.radius) * 1.7)
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best_id = int(yeast.id)
			best_kind = "yeast"

	for colony in sim.hyphae:
		for node in colony.nodes:
			var distance: float = Vector2(node).distance_to(world_position)
			var radius: float = maxf(base_radius, 1.35)
			if distance <= radius and distance < best_distance:
				best_distance = distance
				best_id = int(colony.id)
				best_kind = "hypha"

	if best_id < 0:
		_clear_selection()
		return

	selected_id = best_id
	selected_kind = best_kind
	follow_selected = true
	var minimum_zoom: float = _minimum_camera_zoom()
	focus_zoom_target = clampf(
		maxf(camera.zoom.x, minimum_zoom * FOCUS_MIN_MULTIPLIER),
		minimum_zoom,
		MAX_ZOOM
	)
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

	if selected_kind == "flagellate":
		for flagellate in sim.flagellates:
			if int(flagellate.id) == selected_id:
				return flagellate

	if selected_kind == "alga":
		for alga in sim.microalgae:
			if int(alga.id) == selected_id:
				return alga

	if selected_kind == "yeast":
		for yeast in sim.decomposers:
			if int(yeast.id) == selected_id:
				return yeast

	if selected_kind == "hypha":
		for colony in sim.hyphae:
			if int(colony.id) == selected_id:
				return colony

	return null


func _clear_selection() -> void:
	selected_id = -1
	selected_kind = ""
	follow_selected = false
	focus_zoom_target = -1.0
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
		"flagellate":
			return "FLAGELLATE  #%d" % int(organism.id)
		"alga":
			return "MICROALGA  #%d" % int(organism.id)
		"yeast":
			return "DECOMPOSER  #%d" % int(organism.id)
		"hypha":
			return "HYPHA  #%d" % int(organism.id)
		_:
			return "ORGANISM"


func _inspector_body(organism: Variant) -> String:
	var state: String = _compact_state_text(organism)
	var energy: float = float(organism.energy)
	var generation: int = int(organism.generation)
	var age: float = float(organism.age)
	var lineage: int = int(organism.lineage_id)
	var trait_line: String = ""

	match selected_kind:
		"bacterium":
			trait_line = "%s adh %.1f dor %.1f cmp %.1f" % [
				String(organism.guild_name()),
				float(organism.gene_adhesion),
				float(organism.gene_dormancy),
				float(organism.gene_competence),
			]
		"amoeba":
			trait_line = "hunt %.1f  engulf %.1f" % [
				float(organism.gene_perception),
				float(organism.gene_engulf),
			]
		"ciliate":
			trait_line = "spd %.1f  capture %.1f" % [
				float(organism.gene_speed),
				float(organism.gene_capture),
			]
		"flagellate":
			trait_line = "spd %.1f  capture %.1f" % [
				float(organism.gene_speed),
				float(organism.gene_capture),
			]
		"alga":
			trait_line = "photo %.1f  growth %.1f" % [
				float(organism.gene_light_use),
				float(organism.gene_growth),
			]
		"yeast":
			trait_line = "det %.1f  mineral %.1f" % [
				float(organism.gene_detritus),
				float(organism.gene_mineralize),
			]
		"hypha":
			trait_line = "nodes %d enz %.1f br %.1f" % [
				organism.nodes.size(),
				float(organism.gene_enzyme),
				float(organism.gene_branch),
			]

	return (
		"%s   E %.2f\n"
		+ "g%d  age %.1fs  line %d\n"
		+ "%s\n"
		+ "%s"
	) % [
		state,
		energy,
		generation,
		age,
		lineage,
		trait_line,
		_compact_biome_text(Vector2(organism.position)),
	]


func _compact_state_text(organism: Variant) -> String:
	match selected_kind:
		"bacterium":
			if bool(organism.dying):
				return "LYSIS %.0f%%" % (float(organism.lysis_progress) * 100.0)
			if bool(organism.dividing):
				return "FISSION %.0f%%" % (float(organism.division_progress) * 100.0)
			if bool(organism.phage_infected):
				return "PHAGE %.0f%%" % (float(organism.phage_progress) * 100.0)
			if bool(organism.dormant):
				return "DORMANT %.1fs" % float(organism.dormant_time)
			if int(organism.engulfed_by_id) >= 0:
				return "ENGULFED %.0f%%" % (float(organism.engulf_progress) * 100.0)
			if int(organism.transfer_role) != 0:
				return "HGT %.0f%%" % (float(organism.transfer_progress) * 100.0)
			if bool(organism.competent):
				return "COMPETENT  T%d" % int(organism.transformation_events)
			if float(organism.adhesion_timer) > 0.0:
				return "ADHERING"
			if float(organism.energy) < 0.95:
				return "STARVING"
			return "MOTILE"
		"amoeba":
			if bool(organism.dying):
				return "LYSIS %.0f%%" % (float(organism.lysis_progress) * 100.0)
			if int(organism.feeding_target_id) >= 0:
				return "ENGULF %.0f%%" % (float(organism.feeding_progress) * 100.0)
			if float(organism.energy) < 2.2:
				return "STARVING"
			return "HUNTING"
		"ciliate":
			if int(organism.engulfed_by_id) >= 0:
				return "PREY %.0f%%" % (float(organism.engulf_progress) * 100.0)
			if bool(organism.dying):
				return "LYSIS %.0f%%" % (float(organism.lysis_progress) * 100.0)
			if int(organism.feeding_target_id) >= 0:
				return "FEED %.0f%%" % (float(organism.feeding_progress) * 100.0)
			if float(organism.energy) < 1.8:
				return "STARVING"
			return "GRAZING"
		"flagellate":
			if int(organism.engulfed_by_id) >= 0:
				return "PREY %.0f%%" % (float(organism.engulf_progress) * 100.0)
			if bool(organism.dying):
				return "LYSIS %.0f%%" % (float(organism.lysis_progress) * 100.0)
			if int(organism.feeding_target_id) >= 0:
				return "BACTERIVORE %.0f%%" % (float(organism.feeding_progress) * 100.0)
			if float(organism.energy) < 1.4:
				return "STARVING"
			return "HUNTING"
		"alga":
			if int(organism.engulfed_by_id) >= 0:
				return "GRAZED %.0f%%" % (float(organism.engulf_progress) * 100.0)
			if bool(organism.dying):
				return "LYSIS %.0f%%" % (float(organism.lysis_progress) * 100.0)
			if bool(organism.reproducing):
				return "DIVIDE %.0f%%" % (float(organism.reproduction_progress) * 100.0)
			return "PHOTOSYNTH"
		"hypha":
			if bool(organism.dying):
				return "DECAY %.0f%%" % (float(organism.lysis_progress) * 100.0)
			if float(organism.energy) < 1.0:
				return "STARVING"
			return "BRANCHING"
		"yeast":
			if int(organism.engulfed_by_id) >= 0:
				return "GRAZED %.0f%%" % (float(organism.engulf_progress) * 100.0)
			if bool(organism.dying):
				return "LYSIS %.0f%%" % (float(organism.lysis_progress) * 100.0)
			if bool(organism.budding):
				return "BUD %.0f%%" % (float(organism.budding_progress) * 100.0)
			return "DECOMPOSE"
	return "ALIVE"


func _compact_biome_text(position: Vector2) -> String:
	return "L %.2f N %.2f O2 %.2f\nD %.2f E %.2f X %.2f" % [
		float(sim.sample_light(position)),
		float(sim.nutrient.sample_world(position)),
		float(sim.oxygen.sample_world(position)),
		float(sim.detritus.sample_world(position)),
		float(sim.eps.sample_world(position)),
		float(sim.exudate.sample_world(position)),
	]


func _update_selection_camera(delta: float) -> void:
	if not follow_selected or selected_id < 0 or camera == null:
		return
	var organism: Variant = _selected_organism()
	if organism == null:
		_clear_selection()
		return

	var alpha: float = 1.0 - exp(-FOCUS_CAMERA_RESPONSE * delta)
	camera.position = camera.position.lerp(Vector2(organism.position), alpha)

	if focus_zoom_target > 0.0:
		var zoom_alpha: float = 1.0 - exp(-FOCUS_ZOOM_RESPONSE * delta)
		var next_zoom: float = lerpf(camera.zoom.x, focus_zoom_target, zoom_alpha)
		camera.zoom = Vector2(next_zoom, next_zoom)
		if absf(next_zoom - focus_zoom_target) < 0.01:
			camera.zoom = Vector2(focus_zoom_target, focus_zoom_target)
			focus_zoom_target = -1.0


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
	if biome_renderer != null:
		biome_renderer.refresh_from_sim(sim)
	_fit_camera()


func _new_seed() -> void:
	_start_simulation(current_seed + 1)
	if biome_renderer != null:
		biome_renderer.refresh_from_sim(sim)
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

	follow_selected = false
	focus_zoom_target = -1.0
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

	follow_selected = false
	focus_zoom_target = -1.0
	var fit_zoom: float = _minimum_camera_zoom()
	camera.position = Vector2(sim.world_size) * 0.5
	camera.zoom = Vector2(fit_zoom, fit_zoom)
	_clamp_camera_to_world()


func _smooth_metric(current: float, sample: float) -> float:
	if current <= 0.0:
		return sample
	return lerpf(current, sample, 0.18)
