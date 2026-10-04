extends Node2D

const PetriSimulationScript = preload("res://src/simulation/petri_simulation.gd")
const LivingTerrainScript = preload("res://src/simulation/living_terrain.gd")
const PhysicalCapabilityGenomeScript = preload("res://src/simulation/physical_capability_genome.gd")

const PixelAtlasScript = preload("res://src/app/pixel_microbe_atlas.gd")
const PixelProtozoaAtlasScript = preload("res://src/app/pixel_protozoa_atlas.gd")
const PixelCiliateAtlasScript = preload("res://src/app/pixel_ciliate_atlas.gd")
const PixelFlagellateAtlasScript = preload("res://src/app/pixel_flagellate_atlas.gd")
const PixelEcologyAtlasScript = preload("res://src/app/pixel_ecology_atlas.gd")
const PixelHyphaAtlasScript = preload("res://src/app/pixel_hypha_atlas.gd")
const SessionTelemetryScript = preload("res://src/app/session_telemetry.gd")

const FIXED_DT := 1.0 / 60.0
const MAX_STEPS_PER_FRAME := 16
const TILE_HALF_W := 5.0
const TILE_HALF_H := 2.5
const HEIGHT_PIXELS := 9.0
const CAMERA_ZOOM_STEP := 1.12
const MIN_USER_ZOOM := 0.58
const MAX_USER_ZOOM := 5.0
const TERRAIN_VISUAL_REFRESH := 1.0
const MENU_WIDTH := 220.0
const INSPECTOR_WIDTH := 276.0
const SIMULATION_FRAME_BUDGET_MS := 16.0
const FAR_AGENT_LOD_ZOOM := 6.20
const FAR_AGENT_REFRESH := 1.0 / 15.0

const LINEAGE_PALETTE := [
	Color(0.42, 0.70, 0.46, 1.0),
	Color(0.61, 0.70, 0.36, 1.0),
	Color(0.78, 0.62, 0.32, 1.0),
	Color(0.76, 0.44, 0.31, 1.0),
	Color(0.70, 0.39, 0.55, 1.0),
	Color(0.54, 0.43, 0.70, 1.0),
	Color(0.36, 0.53, 0.72, 1.0),
	Color(0.34, 0.66, 0.70, 1.0),
]

var sim: Variant
var terrain: Variant
var current_seed: int = 1337
var accumulator: float = 0.0
var visual_time: float = 0.0
var simulation_speed: float = 1.0
var actual_sim_speed: float = 0.0
var _speed_wall_accumulator: float = 0.0
var _speed_sim_time_start: float = 0.0
var paused: bool = false

var atlas: Variant
var protozoa_atlas: Variant
var ciliate_atlas: Variant
var flagellate_atlas: Variant
var ecology_atlas: Variant
var hypha_atlas: Variant

var rotation_quarter: int = 0
var fit_zoom: float = 1.0
var user_zoom: float = 1.0
var view_pan := Vector2.ZERO
var panning: bool = false
var rotating: bool = false
var rotate_drag_accumulator: float = 0.0
var rotate_drag_start := Vector2.ZERO
var help_visible: bool = false
var menu_visible: bool = false
var metrics_visible: bool = false

var selected_kind: String = ""
var selected_agent: Variant = null
var follow_selected: bool = false

var terrain_cache_accumulator: float = 0.0
var terrain_color_cache := PackedColorArray()
var terrain_mark_cache := PackedInt32Array()
var last_draw_ms: float = 0.0
var last_sim_step_ms: float = 0.0
var last_core_sim_ms: float = 0.0
var last_terrain_sim_ms: float = 0.0
var last_terrain_build_ms: float = 0.0
var last_visible_tiles: int = 0
var last_terrain_triangles: int = 0
var telemetry: Variant = null

var terrain_batch_layer: Node2D
var terrain_mark_layer: Node2D
var far_agent_layer: Node2D
var far_agent_accumulator: float = 0.0
var last_far_agent_count: int = 0


func _ready() -> void:
	Engine.max_fps = 144
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(
		Color(0.025, 0.055, 0.060, 1.0)
	)

	terrain_batch_layer = Node2D.new()
	terrain_batch_layer.name = "TerrainBatch"
	terrain_batch_layer.z_index = -20
	terrain_batch_layer.z_as_relative = false
	add_child(terrain_batch_layer)

	terrain_mark_layer = Node2D.new()
	terrain_mark_layer.name = "TerrainMarks"
	terrain_mark_layer.z_index = -19
	terrain_mark_layer.z_as_relative = false
	add_child(terrain_mark_layer)

	far_agent_layer = Node2D.new()
	far_agent_layer.name = "FarAgentBatch"
	far_agent_layer.z_index = -10
	far_agent_layer.z_as_relative = false
	add_child(far_agent_layer)

	atlas = PixelAtlasScript.new()
	protozoa_atlas = PixelProtozoaAtlasScript.new()
	ciliate_atlas = PixelCiliateAtlasScript.new()
	flagellate_atlas = PixelFlagellateAtlasScript.new()
	ecology_atlas = PixelEcologyAtlasScript.new()
	hypha_atlas = PixelHyphaAtlasScript.new()

	_start_seed(current_seed)
	telemetry = SessionTelemetryScript.new()
	telemetry.begin(current_seed)
	_refresh_terrain_visual_cache()
	_rebuild_terrain_batch()
	_rebuild_far_agent_batch()
	_update_terrain_layer_transform()
	get_viewport().size_changed.connect(_on_viewport_resized)
	call_deferred("_fit_view")
	queue_redraw()


func _start_seed(seed_value: int) -> void:
	current_seed = seed_value
	sim = PetriSimulationScript.new(current_seed)
	sim.seed_demo(72)
	terrain = LivingTerrainScript.new(current_seed, Vector2(sim.world_size))
	accumulator = 0.0
	visual_time = 0.0
	actual_sim_speed = 0.0
	_speed_wall_accumulator = 0.0
	_speed_sim_time_start = float(sim.simulation_time)
	view_pan = Vector2.ZERO
	user_zoom = 1.0
	_update_terrain_layer_transform()
	selected_kind = ""
	selected_agent = null
	follow_selected = false
	terrain_cache_accumulator = TERRAIN_VISUAL_REFRESH
	if telemetry != null:
		telemetry.set_seed(current_seed)


func _process(delta: float) -> void:
	visual_time += delta
	_handle_keyboard_pan(delta)
	last_sim_step_ms = 0.0

	if not paused:
		# Requested speed is accumulated as simulation time. We keep a CPU frame
		# budget for input/render responsiveness, but no longer discard nearly
		# all extra time at x2/x4/x8.
		accumulator += minf(delta, 0.05) * simulation_speed
		var steps: int = 0
		var frame_sim_start: int = Time.get_ticks_usec()
		var core_sum_ms: float = 0.0
		var terrain_sum_ms: float = 0.0
		var dynamic_budget_ms: float = minf(
			34.0,
			SIMULATION_FRAME_BUDGET_MS
			+ maxf(0.0, simulation_speed - 1.0) * 4.5
		)
		var dynamic_step_limit: int = clampi(
			ceili(simulation_speed * 2.0),
			2,
			MAX_STEPS_PER_FRAME
		)
		while accumulator >= FIXED_DT and steps < dynamic_step_limit:
			var core_start: int = Time.get_ticks_usec()
			sim.step(FIXED_DT)
			core_sum_ms += float(
				Time.get_ticks_usec() - core_start
			) / 1000.0

			var terrain_start: int = Time.get_ticks_usec()
			terrain.advance_from_sim(sim, FIXED_DT)
			terrain_sum_ms += float(
				Time.get_ticks_usec() - terrain_start
			) / 1000.0

			accumulator -= FIXED_DT
			steps += 1
			if (
				float(Time.get_ticks_usec() - frame_sim_start) / 1000.0
				>= dynamic_budget_ms
			):
				break

		if steps > 0:
			last_core_sim_ms = core_sum_ms / float(steps)
			last_terrain_sim_ms = terrain_sum_ms / float(steps)
			last_sim_step_ms = last_core_sim_ms + last_terrain_sim_ms
		else:
			last_core_sim_ms = 0.0
			last_terrain_sim_ms = 0.0

		var max_backlog: float = FIXED_DT * maxf(
			6.0,
			simulation_speed * 10.0
		)
		accumulator = minf(accumulator, max_backlog)

	_speed_wall_accumulator += delta
	if _speed_wall_accumulator >= 0.5:
		var sim_delta: float = (
			float(sim.simulation_time) - _speed_sim_time_start
		)
		actual_sim_speed = sim_delta / maxf(
			0.001,
			_speed_wall_accumulator
		)
		_speed_wall_accumulator = 0.0
		_speed_sim_time_start = float(sim.simulation_time)

	terrain_cache_accumulator += delta
	if terrain_cache_accumulator >= TERRAIN_VISUAL_REFRESH:
		terrain_cache_accumulator = fmod(
			terrain_cache_accumulator,
			TERRAIN_VISUAL_REFRESH
		)
		_refresh_terrain_visual_cache()
		_rebuild_terrain_batch()

	far_agent_accumulator += delta
	if (
		far_agent_accumulator >= FAR_AGENT_REFRESH
		or not _using_far_agent_lod()
	):
		far_agent_accumulator = 0.0
		_rebuild_far_agent_batch()

	if follow_selected:
		_update_selected_follow()

	_update_terrain_layer_transform()

	if telemetry != null:
		telemetry.record_frame(
			delta,
			last_sim_step_ms,
			last_core_sim_ms,
			last_terrain_sim_ms,
			last_draw_ms,
			last_terrain_build_ms,
			sim,
			terrain,
			_camera_zoom(),
			rotation_quarter,
			last_visible_tiles,
			last_terrain_triangles,
			last_far_agent_count,
			simulation_speed,
			actual_sim_speed
		)

	queue_redraw()


func _draw() -> void:
	if sim == null or terrain == null:
		return

	var draw_start_usec: int = Time.get_ticks_usec()
	_draw_capability_fragments()
	_draw_agents()
	_draw_selection()
	_draw_ui()

	if help_visible:
		_draw_help()

	last_draw_ms = float(
		Time.get_ticks_usec() - draw_start_usec
	) / 1000.0


func _update_terrain_layer_transform() -> void:
	if (
		terrain_batch_layer == null
		or terrain_mark_layer == null
		or far_agent_layer == null
	):
		return
	var origin: Vector2 = get_viewport_rect().size * 0.5 + view_pan
	var zoom_value: float = _camera_zoom()
	var transform := Transform2D.IDENTITY
	transform.x = Vector2(zoom_value, 0.0)
	transform.y = Vector2(0.0, zoom_value)
	transform.origin = _round_vec(origin)
	terrain_batch_layer.transform = transform
	terrain_mark_layer.transform = transform
	far_agent_layer.transform = transform


func _rebuild_terrain_batch() -> void:
	if (
		terrain == null
		or terrain_batch_layer == null
		or terrain_mark_layer == null
	):
		return

	var started: int = Time.get_ticks_usec()
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var mark_points := PackedVector2Array()
	var mark_colors := PackedColorArray()
	var mark_indices := PackedInt32Array()

	var dims: Vector2i = _rotated_dimensions()
	var max_diag: int = dims.x + dims.y - 2
	var tile_count: int = 0

	for diag in range(max_diag + 1):
		var rx_min: int = maxi(0, diag - (dims.y - 1))
		var rx_max: int = mini(dims.x - 1, diag)
		for rx in range(rx_min, rx_max + 1):
			var ry: int = diag - rx
			var source: Vector2i = _rotated_to_source(rx, ry)
			var height_value: float = terrain.height_at_grid(
				source.x,
				source.y
			)
			var center: Vector2 = _project_rotated_grid_unscaled(
				Vector2(float(rx), float(ry)),
				height_value
			)

			var top := _round_vec(
				center + Vector2(0.0, -TILE_HALF_H)
			)
			var right := _round_vec(
				center + Vector2(TILE_HALF_W, 0.0)
			)
			var bottom := _round_vec(
				center + Vector2(0.0, TILE_HALF_H)
			)
			var left := _round_vec(
				center + Vector2(-TILE_HALF_W, 0.0)
			)

			var cache_index: int = (
				source.y * terrain.width + source.x
			)
			var top_color: Color = (
				terrain_color_cache[cache_index]
				if (
					cache_index >= 0
					and cache_index < terrain_color_cache.size()
				)
				else _terrain_top_color(source, height_value)
			)
			var delta: float = terrain.height_delta_at_grid(
				source.x,
				source.y
			)
			if delta > 0.035:
				top_color = top_color.lerp(
					Color(0.62, 0.46, 0.24),
					clampf(delta * 1.4, 0.10, 0.48)
				)
			elif delta < -0.035:
				top_color = top_color.lerp(
					Color(0.22, 0.15, 0.10),
					clampf(-delta * 1.8, 0.12, 0.58)
				)

			if rx + 1 < dims.x:
				var n1: Vector2i = _rotated_to_source(
					rx + 1,
					ry
				)
				var nh1: float = terrain.height_at_grid(
					n1.x,
					n1.y
				)
				if height_value > nh1 + 0.015:
					var drop1: float = maxf(
						1.0,
						roundf(
							(height_value - nh1)
							* HEIGHT_PIXELS
						)
					)
					_batch_quad(
						points,
						colors,
						indices,
						right,
						bottom,
						bottom + Vector2(0.0, drop1),
						right + Vector2(0.0, drop1),
						_side_color(top_color, 0.72)
					)

			if ry + 1 < dims.y:
				var n2: Vector2i = _rotated_to_source(
					rx,
					ry + 1
				)
				var nh2: float = terrain.height_at_grid(
					n2.x,
					n2.y
				)
				if height_value > nh2 + 0.015:
					var drop2: float = maxf(
						1.0,
						roundf(
							(height_value - nh2)
							* HEIGHT_PIXELS
						)
					)
					_batch_quad(
						points,
						colors,
						indices,
						bottom,
						left,
						left + Vector2(0.0, drop2),
						bottom + Vector2(0.0, drop2),
						_side_color(top_color, 0.58)
					)

			_batch_quad(
				points,
				colors,
				indices,
				top,
				right,
				bottom,
				left,
				top_color
			)
			tile_count += 1

			var mark: int = (
				terrain_mark_cache[cache_index]
				if (
					cache_index >= 0
					and cache_index < terrain_mark_cache.size()
				)
				else 0
			)
			if mark > 0:
				var mark_color := Color(0.25, 0.50, 0.22, 0.82)
				var mark_center := center + Vector2(0.0, -0.5)
				if mark == 3:
					mark_color = Color(0.72, 0.24, 0.10, 0.86)
					mark_center += Vector2(0.0, -0.5)
				elif mark == 2:
					mark_color = Color(0.40, 0.25, 0.12, 0.90)
					mark_center += Vector2(0.0, 0.5)
				_batch_quad(
					mark_points,
					mark_colors,
					mark_indices,
					_round_vec(mark_center + Vector2(-1.0, -0.5)),
					_round_vec(mark_center + Vector2(1.0, -0.5)),
					_round_vec(mark_center + Vector2(1.0, 0.5)),
					_round_vec(mark_center + Vector2(-1.0, 0.5)),
					mark_color
				)

	var terrain_rid: RID = terrain_batch_layer.get_canvas_item()
	var mark_rid: RID = terrain_mark_layer.get_canvas_item()
	RenderingServer.canvas_item_clear(terrain_rid)
	RenderingServer.canvas_item_clear(mark_rid)

	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(
			terrain_rid,
			indices,
			points,
			colors
		)
	if not mark_indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(
			mark_rid,
			mark_indices,
			mark_points,
			mark_colors
		)

	last_visible_tiles = tile_count
	last_terrain_triangles = indices.size() / 3
	last_terrain_build_ms = (
		float(Time.get_ticks_usec() - started) / 1000.0
	)


func _batch_quad(
	points: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector2,
	b: Vector2,
	c: Vector2,
	d: Vector2,
	color: Color
) -> void:
	var base: int = points.size()
	points.append(a)
	points.append(b)
	points.append(c)
	points.append(d)
	colors.append(color)
	colors.append(color)
	colors.append(color)
	colors.append(color)
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 3)


func _project_rotated_grid_unscaled(
	grid: Vector2,
	height_value: float
) -> Vector2:
	var dims: Vector2i = _rotated_dimensions()
	var cx: float = float(dims.x - 1) * 0.5
	var cy: float = float(dims.y - 1) * 0.5
	var dx: float = grid.x - cx
	var dy: float = grid.y - cy
	return Vector2(
		(dx - dy) * TILE_HALF_W,
		(dx + dy) * TILE_HALF_H
		- (height_value - 0.60) * HEIGHT_PIXELS
	)


func _draw_isometric_terrain() -> void:
	var dims: Vector2i = _rotated_dimensions()
	var max_diag: int = dims.x + dims.y - 2

	for diag in range(max_diag + 1):
		var rx_min: int = maxi(0, diag - (dims.y - 1))
		var rx_max: int = mini(dims.x - 1, diag)
		for rx in range(rx_min, rx_max + 1):
			var ry: int = diag - rx
			var source: Vector2i = _rotated_to_source(rx, ry)
			var h: float = terrain.height_at_grid(source.x, source.y)
			_draw_terrain_tile(rx, ry, source, h, dims)


func _draw_terrain_tile(
	rx: int,
	ry: int,
	source: Vector2i,
	height_value: float,
	dims: Vector2i
) -> void:
	var center: Vector2 = _project_rotated_grid(
		Vector2(float(rx), float(ry)),
		height_value
	)
	var viewport_size: Vector2 = get_viewport_rect().size
	if (
		center.x < -28.0
		or center.y < -28.0
		or center.x > viewport_size.x + 28.0
		or center.y > viewport_size.y + 64.0
	):
		return
	last_visible_tiles += 1
	var half_w: float = maxf(2.0, roundf(TILE_HALF_W * _camera_zoom()))
	var half_h: float = maxf(1.0, roundf(TILE_HALF_H * _camera_zoom()))

	var top := center + Vector2(0.0, -half_h)
	var right := center + Vector2(half_w, 0.0)
	var bottom := center + Vector2(0.0, half_h)
	var left := center + Vector2(-half_w, 0.0)

	var cache_index: int = source.y * terrain.width + source.x
	var top_color: Color = (
		terrain_color_cache[cache_index]
		if cache_index >= 0 and cache_index < terrain_color_cache.size()
		else _terrain_top_color(source, height_value)
	)
	var delta: float = terrain.height_delta_at_grid(source.x, source.y)
	if delta > 0.035:
		top_color = top_color.lerp(
			Color(0.62, 0.46, 0.24),
			clampf(delta * 1.4, 0.10, 0.48)
		)
	elif delta < -0.035:
		top_color = top_color.lerp(
			Color(0.22, 0.15, 0.10),
			clampf(-delta * 1.8, 0.12, 0.58)
		)

	# The two screen-facing sides expose real relief. This is where pits and
	# agent-built mounds become legible in the pixel-art view.
	if rx + 1 < dims.x:
		var n1: Vector2i = _rotated_to_source(rx + 1, ry)
		var nh1: float = terrain.height_at_grid(n1.x, n1.y)
		if height_value > nh1 + 0.015:
			var drop1: float = maxf(
				1.0,
				roundf(
					(height_value - nh1)
					* HEIGHT_PIXELS
					* _camera_zoom()
				)
			)
			draw_colored_polygon(
				PackedVector2Array([
					right,
					bottom,
					bottom + Vector2(0.0, drop1),
					right + Vector2(0.0, drop1),
				]),
				_side_color(top_color, 0.72)
			)

	if ry + 1 < dims.y:
		var n2: Vector2i = _rotated_to_source(rx, ry + 1)
		var nh2: float = terrain.height_at_grid(n2.x, n2.y)
		if height_value > nh2 + 0.015:
			var drop2: float = maxf(
				1.0,
				roundf(
					(height_value - nh2)
					* HEIGHT_PIXELS
					* _camera_zoom()
				)
			)
			draw_colored_polygon(
				PackedVector2Array([
					bottom,
					left,
					left + Vector2(0.0, drop2),
					bottom + Vector2(0.0, drop2),
				]),
				_side_color(top_color, 0.58)
			)

	draw_colored_polygon(
		PackedVector2Array([top, right, bottom, left]),
		top_color
	)

	# Environmental field sampling is cached at 4 Hz instead of repeated for
	# every tile on every rendered frame.
	var mark: int = (
		terrain_mark_cache[cache_index]
		if cache_index >= 0 and cache_index < terrain_mark_cache.size()
		else 0
	)
	var px: float = maxf(1.0, roundf(_camera_zoom()))
	if mark == 3:
		draw_rect(
			Rect2(
				_round_vec(center + Vector2(-px, -px)),
				Vector2(px * 2.0, px)
			),
			Color(0.72, 0.24, 0.10, 0.86),
			true
		)
	elif mark == 2:
		draw_rect(
			Rect2(
				_round_vec(center + Vector2(-px, 0.0)),
				Vector2(px * 2.0, px)
			),
			Color(0.40, 0.25, 0.12, 0.90),
			true
		)
	elif mark == 1:
		draw_rect(
			Rect2(
				_round_vec(center + Vector2(-px, -px)),
				Vector2(px * 2.0, px)
			),
			Color(0.25, 0.50, 0.22, 0.82),
			true
		)


func _terrain_top_color(
	source: Vector2i,
	height_value: float
) -> Color:
	var world: Vector2 = terrain.world_position_for_grid(
		source.x,
		source.y
	)
	var producer: float = float(sim.producer_biomass.sample_world(world))
	var detritus_value: float = float(sim.detritus.sample_world(world))
	var eps_value: float = float(sim.eps.sample_world(world))
	var nutrient: float = float(sim.nutrient.sample_world(world))

	if height_value < LivingTerrainScript.WATER_LEVEL:
		var water := Color(0.075, 0.22, 0.24)
		water = water.lerp(
			Color(0.10, 0.30, 0.22),
			clampf(producer * 1.4, 0.0, 0.46)
		)
		return water

	var base := Color(0.34, 0.28, 0.18)
	base = base.lerp(
		Color(0.25, 0.39, 0.20),
		clampf(producer * 1.8, 0.0, 0.62)
	)
	base = base.lerp(
		Color(0.27, 0.20, 0.12),
		clampf(detritus_value * 2.2, 0.0, 0.48)
	)
	base = base.lerp(
		Color(0.22, 0.34, 0.30),
		clampf(eps_value * 1.7, 0.0, 0.32)
	)
	base = base.lerp(
		Color(0.39, 0.35, 0.19),
		clampf(nutrient * 0.55, 0.0, 0.16)
	)
	return base


func _side_color(color: Color, factor: float) -> Color:
	return Color(
		color.r * factor,
		color.g * factor,
		color.b * factor,
		1.0
	)


func _using_far_agent_lod() -> bool:
	return _camera_zoom() < FAR_AGENT_LOD_ZOOM


func _rebuild_far_agent_batch() -> void:
	if far_agent_layer == null:
		return
	var rid: RID = far_agent_layer.get_canvas_item()
	RenderingServer.canvas_item_clear(rid)
	last_far_agent_count = 0
	far_agent_layer.visible = _using_far_agent_lod()
	if not far_agent_layer.visible or terrain == null:
		return

	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	_batch_far_group(points, colors, indices, sim.bacteria, 0)
	_batch_far_group(points, colors, indices, sim.protozoa, 1)
	_batch_far_group(points, colors, indices, sim.ciliates, 2)
	_batch_far_group(points, colors, indices, sim.flagellates, 3)
	_batch_far_group(points, colors, indices, sim.microalgae, 4)
	_batch_far_group(points, colors, indices, sim.decomposers, 5)

	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(
			rid,
			indices,
			points,
			colors
		)


func _batch_far_group(
	points: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	group: Array,
	kind: int
) -> void:
	for agent in group:
		if agent == null:
			continue
		if "consumed" in agent and bool(agent.consumed):
			continue

		var p: Vector2 = Vector2(agent.position)
		var height_value: float = (
			terrain.sample_height(p)
			- float(agent.burrow_depth) * 0.24
		)
		var center: Vector2 = _round_vec(
			_project_world_unscaled(p, height_value)
		)
		var half_size := Vector2(0.70, 0.42)
		var color := Color(0.65, 0.72, 0.62)
		match kind:
			0:
				color = _lineage_color(float(agent.lineage_hue))
				if bool(agent.dying):
					color = color.lerp(
						Color(0.72, 0.30, 0.18),
						0.62
					)
			1:
				half_size = Vector2(1.45, 1.05)
				color = Color(0.62, 0.82, 0.76)
			2:
				half_size = Vector2(1.20, 0.72)
				color = Color(0.69, 0.69, 0.88)
			3:
				half_size = Vector2(0.90, 0.52)
				color = Color(0.82, 0.72, 0.44)
			4:
				half_size = Vector2(0.82, 0.70)
				color = Color(0.38, 0.68, 0.34)
			5:
				half_size = Vector2(0.88, 0.72)
				color = Color(0.72, 0.57, 0.35)

		_batch_quad(
			points,
			colors,
			indices,
			center + Vector2(-half_size.x, -half_size.y),
			center + Vector2(half_size.x, -half_size.y),
			center + Vector2(half_size.x, half_size.y),
			center + Vector2(-half_size.x, half_size.y),
			color
		)
		last_far_agent_count += 1


func _project_world_unscaled(
	world_position: Vector2,
	height_value: float
) -> Vector2:
	var gx: float = world_position.x / LivingTerrainScript.CELL_SIZE
	var gy: float = world_position.y / LivingTerrainScript.CELL_SIZE
	var rotated: Vector2 = _source_to_rotated_float(gx, gy)
	return _project_rotated_grid_unscaled(rotated, height_value)


func _draw_agents() -> void:
	if _using_far_agent_lod():
		return
	var entries: Array = []
	_append_agent_entries(entries, "bacterium", sim.bacteria)
	_append_agent_entries(entries, "amoeba", sim.protozoa)
	_append_agent_entries(entries, "ciliate", sim.ciliates)
	_append_agent_entries(entries, "flagellate", sim.flagellates)
	_append_agent_entries(entries, "alga", sim.microalgae)
	_append_agent_entries(entries, "yeast", sim.decomposers)
	_append_agent_entries(entries, "hypha", sim.hyphae)

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["screen_y"]) < float(b["screen_y"])
	)

	for entry in entries:
		var kind: String = String(entry["kind"])
		var agent: Variant = entry["agent"]
		if kind == "hypha":
			_draw_hypha(agent)
		else:
			_draw_agent_sprite(kind, agent)


func _append_agent_entries(
	entries: Array,
	kind: String,
	group: Array
) -> void:
	for agent in group:
		if agent == null:
			continue
		if "consumed" in agent and bool(agent.consumed):
			continue
		var p: Vector2 = Vector2(agent.position)
		var h: float = terrain.sample_height(p)
		var depth: float = (
			float(agent.burrow_depth)
			if "burrow_depth" in agent
			else 0.0
		)
		var screen: Vector2 = _project_world(
			p,
			h - depth * 0.24
		)
		entries.append({
			"kind": kind,
			"agent": agent,
			"screen_y": screen.y,
		})


func _draw_agent_sprite(kind: String, agent: Variant) -> void:
	var texture: Texture2D = _agent_texture(kind, agent)
	if texture == null:
		return

	var p: Vector2 = Vector2(agent.position)
	var h: float = terrain.sample_height(p)
	var depth: float = float(agent.burrow_depth)
	var screen: Vector2 = _round_vec(
		_project_world(p, h - depth * 0.24)
	)

	var base_scale: float = clampf(
		0.56 * _camera_zoom(),
		0.62,
		2.60
	)
	var size: Vector2 = texture.get_size() * base_scale
	size.x = maxf(1.0, roundf(size.x))
	size.y = maxf(1.0, roundf(size.y))

	# Contact shadow anchors the sprite to the isometric terrain.
	var shadow_w: float = maxf(2.0, roundf(size.x * 0.30))
	var shadow_h: float = maxf(1.0, roundf(_camera_zoom()))
	draw_rect(
		Rect2(
			_round_vec(screen + Vector2(-shadow_w * 0.5, size.y * 0.30)),
			Vector2(shadow_w, shadow_h)
		),
		Color(0.03, 0.04, 0.035, 0.45),
		true
	)

	var tint: Color = _agent_tint(kind, agent)
	if depth > 0.10:
		tint = tint.darkened(clampf(depth * 0.10, 0.0, 0.28))
		tint.a *= clampf(1.0 - depth * 0.12, 0.48, 1.0)

	draw_texture_rect(
		texture,
		Rect2(
			_round_vec(screen - size * 0.5),
			size
		),
		false,
		tint
	)

	_draw_capability_marks(agent, screen, size)


func _agent_texture(kind: String, agent: Variant) -> Texture2D:
	match kind:
		"bacterium":
			var state: int = 0
			if bool(agent.dying):
				state = 2
			elif bool(agent.dividing):
				state = 1
			return atlas.get_texture(
				clampi(int(agent.guild), 0, 3),
				_size_class(agent),
				_appendage_class(agent),
				posmod(
					int(floor(visual_time * 7.0))
					+ int(agent.id),
					4
				),
				state
			)
		"amoeba":
			var astate: int = (
				1 if int(agent.feeding_target_id) >= 0 else 0
			)
			return protozoa_atlas.get_texture(
				posmod(
					int(floor(visual_time * 5.0))
					+ int(agent.id),
					6
				),
				astate
			)
		"ciliate":
			var cstate: int = (
				1 if int(agent.feeding_target_id) >= 0 else 0
			)
			return ciliate_atlas.get_texture(
				posmod(
					int(floor(visual_time * 7.0))
					+ int(agent.id),
					6
				),
				cstate
			)
		"flagellate":
			var fstate: int = (
				1 if int(agent.feeding_target_id) >= 0 else 0
			)
			return flagellate_atlas.get_texture(
				posmod(
					int(floor(visual_time * 7.0))
					+ int(agent.id),
					6
				),
				fstate
			)
		"alga":
			var alga_state: int = 0
			if bool(agent.dying):
				alga_state = 2
			elif bool(agent.reproducing):
				alga_state = 1
			return ecology_atlas.get_texture(
				0,
				alga_state,
				posmod(
					int(floor(visual_time * 4.0))
					+ int(agent.id),
					4
				)
			)
		"yeast":
			var yeast_state: int = 0
			if bool(agent.dying):
				yeast_state = 2
			elif bool(agent.budding):
				yeast_state = 1
			return ecology_atlas.get_texture(
				1,
				yeast_state,
				posmod(
					int(floor(visual_time * 4.0))
					+ int(agent.id),
					4
				)
			)
	return null


func _agent_tint(kind: String, agent: Variant) -> Color:
	match kind:
		"bacterium":
			var color: Color = _lineage_color(float(agent.lineage_hue))
			if bool(agent.dying):
				color = color.lerp(Color(0.74, 0.34, 0.22), 0.62)
			elif bool(agent.dormant):
				color = color.lerp(Color(0.34, 0.42, 0.40), 0.62)
			return color
		"amoeba":
			return Color(0.78, 0.90, 0.84)
		"ciliate":
			return Color(0.84, 0.84, 0.95)
		"flagellate":
			return Color(0.92, 0.84, 0.62)
		"alga":
			return Color(0.90, 0.96, 0.86)
		"yeast":
			return Color(0.94, 0.88, 0.78)
	return Color.WHITE


func _draw_hypha(colony: Variant) -> void:
	if colony.nodes.is_empty():
		return
	var width_px: float = maxf(1.0, roundf(_camera_zoom()))

	for i in range(1, colony.nodes.size()):
		var parent_index: int = int(colony.parents[i])
		if parent_index < 0 or parent_index >= colony.nodes.size():
			continue
		var a_world: Vector2 = Vector2(colony.nodes[parent_index])
		var b_world: Vector2 = Vector2(colony.nodes[i])
		var a: Vector2 = _round_vec(
			_project_world(
				a_world,
				terrain.sample_height(a_world)
				- float(colony.burrow_depth) * 0.20
			)
		)
		var b: Vector2 = _round_vec(
			_project_world(
				b_world,
				terrain.sample_height(b_world)
				- float(colony.burrow_depth) * 0.20
			)
		)
		draw_line(
			a,
			b,
			Color(0.64, 0.56, 0.38),
			width_px,
			false
		)

	for tip_index in colony.tips:
		var tip_world: Vector2 = Vector2(colony.nodes[int(tip_index)])
		var tip: Vector2 = _round_vec(
			_project_world(
				tip_world,
				terrain.sample_height(tip_world)
			)
		)
		var px: float = maxf(1.0, roundf(_camera_zoom()))
		draw_rect(
			Rect2(
				tip - Vector2.ONE * px,
				Vector2.ONE * px * 2.0
			),
			Color(0.78, 0.72, 0.50),
			true
		)


func _draw_capability_marks(
	agent: Variant,
	screen: Vector2,
	sprite_size: Vector2
) -> void:
	var px: float = maxf(1.0, roundf(_camera_zoom()))
	var heading: Vector2 = _project_heading(float(agent.angle))
	var side := Vector2(-heading.y, heading.x)

	# Soil is visible as material the organism is actually carrying.
	if float(agent.carried_soil) > 0.018:
		var carry_pos: Vector2 = _round_vec(
			screen - side * (sprite_size.x * 0.28)
			+ Vector2(0.0, sprite_size.y * 0.18)
		)
		draw_rect(
			Rect2(carry_pos, Vector2(px * 2.0, px * 2.0)),
			Color(0.52, 0.34, 0.16),
			true
		)

	# Digging ability has a small physical wedge/mandible in front.
	if float(agent.physical_dig) > 0.48:
		var dig_pos: Vector2 = _round_vec(
			screen
			+ heading * (sprite_size.x * 0.34 + px)
		)
		draw_rect(
			Rect2(
				dig_pos - Vector2.ONE * px,
				Vector2(px * 3.0, px)
			),
			Color(0.42, 0.30, 0.16),
			true
		)

	# Armor is a sparse edge, not a glowing bubble.
	if float(agent.physical_armor) > 0.56:
		var r := Rect2(
			_round_vec(screen - sprite_size * 0.37),
			_round_vec(sprite_size * 0.74)
		)
		draw_rect(
			r,
			Color(0.64, 0.68, 0.62, 0.70),
			false,
			px,
			false
		)

	# Oviposition potential changes the rear silhouette; actual egg entities
	# remain a separate lifecycle implementation.
	if float(agent.physical_oviposit) > 0.52:
		var rear: Vector2 = _round_vec(
			screen
			- heading * (sprite_size.x * 0.30 + px)
		)
		draw_rect(
			Rect2(
				rear - Vector2.ONE * px,
				Vector2(px * 2.0, px)
			),
			Color(0.74, 0.68, 0.50),
			true
		)

	if String(agent.terrain_action) == "dig":
		_draw_earth_action(agent, screen, heading, true)
	elif String(agent.terrain_action) == "deposit":
		_draw_earth_action(agent, screen, heading, false)


func _draw_earth_action(
	agent: Variant,
	screen: Vector2,
	heading: Vector2,
	digging: bool
) -> void:
	var px: float = maxf(1.0, roundf(_camera_zoom()))
	var base: Vector2 = (
		screen + heading * px * 4.0
		if digging
		else screen - heading * px * 3.0
	)
	var color := (
		Color(0.31, 0.20, 0.11)
		if digging
		else Color(0.66, 0.45, 0.20)
	)
	for i in range(3):
		var phase: float = (
			visual_time * 5.0
			+ float(int(agent.id) * 3 + i) * 1.73
		)
		var q: Vector2 = _round_vec(
			base
			+ Vector2(
				cos(phase) * px * 2.0,
				-sin(phase * 1.31) * px * 2.0
			)
		)
		draw_rect(
			Rect2(q, Vector2(px, px)),
			color,
			true
		)


func _draw_capability_fragments() -> void:
	var px: float = maxf(1.0, roundf(_camera_zoom()))
	for fragment in terrain.capability_fragments:
		var p: Vector2 = Vector2(fragment["position"])
		var screen: Vector2 = _round_vec(
			_project_world(
				p,
				terrain.sample_height(p) + 0.06
			)
		)
		var c := Color(0.46, 0.82, 0.72, 0.80)
		draw_rect(
			Rect2(
				screen - Vector2(px, 0.0),
				Vector2(px * 3.0, px)
			),
			c,
			true
		)
		draw_rect(
			Rect2(
				screen + Vector2(0.0, -px),
				Vector2(px, px * 3.0)
			),
			c,
			true
		)


func _project_world(
	world_position: Vector2,
	height_value: float
) -> Vector2:
	var gx: float = world_position.x / LivingTerrainScript.CELL_SIZE
	var gy: float = world_position.y / LivingTerrainScript.CELL_SIZE
	var rotated: Vector2 = _source_to_rotated_float(gx, gy)
	return _project_rotated_grid(rotated, height_value)


func _project_rotated_grid(
	grid: Vector2,
	height_value: float
) -> Vector2:
	var unscaled: Vector2 = _project_rotated_grid_unscaled(
		grid,
		height_value
	)
	return (
		get_viewport_rect().size * 0.5
		+ view_pan
		+ unscaled * _camera_zoom()
	)


func _project_heading(angle: float) -> Vector2:
	var direction := Vector2.RIGHT.rotated(angle)
	var step_world := direction * LivingTerrainScript.CELL_SIZE
	var a := _project_world(Vector2(sim.world_size) * 0.5, 0.6)
	var b := _project_world(
		Vector2(sim.world_size) * 0.5 + step_world,
		0.6
	)
	var screen_direction: Vector2 = b - a
	if screen_direction.length_squared() <= 0.0001:
		return Vector2.RIGHT
	return screen_direction.normalized()


func _source_to_rotated_float(x: float, y: float) -> Vector2:
	var w: float = float(terrain.width - 1)
	var h: float = float(terrain.height - 1)
	match rotation_quarter:
		1:
			return Vector2(h - y, x)
		2:
			return Vector2(w - x, h - y)
		3:
			return Vector2(y, w - x)
		_:
			return Vector2(x, y)


func _rotated_to_source(rx: int, ry: int) -> Vector2i:
	var w: int = terrain.width
	var h: int = terrain.height
	match rotation_quarter:
		1:
			return Vector2i(ry, h - 1 - rx)
		2:
			return Vector2i(w - 1 - rx, h - 1 - ry)
		3:
			return Vector2i(w - 1 - ry, rx)
		_:
			return Vector2i(rx, ry)


func _rotated_dimensions() -> Vector2i:
	if rotation_quarter % 2 == 0:
		return Vector2i(terrain.width, terrain.height)
	return Vector2i(terrain.height, terrain.width)


func _camera_zoom() -> float:
	return fit_zoom * user_zoom


func _fit_view() -> void:
	if terrain == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var dims: Vector2i = _rotated_dimensions()
	var base_width: float = (
		float(dims.x + dims.y) * TILE_HALF_W
	)
	var base_height: float = (
		float(dims.x + dims.y) * TILE_HALF_H
		+ 64.0
	)
	fit_zoom = clampf(
		minf(
			(viewport_size.x - 40.0) / maxf(1.0, base_width),
			(viewport_size.y - 36.0) / maxf(1.0, base_height)
		),
		0.35,
		4.0
	)
	view_pan = Vector2.ZERO
	user_zoom = 1.0


func _zoom_at(
	screen_position: Vector2,
	factor: float
) -> void:
	var old_zoom: float = _camera_zoom()
	var new_user_zoom: float = clampf(
		user_zoom * factor,
		MIN_USER_ZOOM,
		MAX_USER_ZOOM
	)
	var new_zoom: float = fit_zoom * new_user_zoom
	if is_equal_approx(old_zoom, new_zoom):
		return

	var center: Vector2 = get_viewport_rect().size * 0.5
	var unscaled: Vector2 = (
		screen_position - center - view_pan
	) / old_zoom
	view_pan = (
		screen_position
		- center
		- unscaled * new_zoom
	)
	user_zoom = new_user_zoom


func _rotate_view(step: int) -> void:
	rotation_quarter = posmod(rotation_quarter + step, 4)
	_recompute_fit_keep_zoom()
	_rebuild_terrain_batch()
	_rebuild_far_agent_batch()
	if follow_selected:
		_update_selected_follow()
	if telemetry != null:
		telemetry.mark_event("rotations")


func _recompute_fit_keep_zoom() -> void:
	var old_user_zoom: float = user_zoom
	var viewport_size: Vector2 = get_viewport_rect().size
	var dims: Vector2i = _rotated_dimensions()
	var base_width: float = float(dims.x + dims.y) * TILE_HALF_W
	var base_height: float = (
		float(dims.x + dims.y) * TILE_HALF_H + 64.0
	)
	fit_zoom = clampf(
		minf(
			(viewport_size.x - 40.0) / maxf(1.0, base_width),
			(viewport_size.y - 36.0) / maxf(1.0, base_height)
		),
		0.35,
		4.0
	)
	user_zoom = clampf(
		old_user_zoom,
		MIN_USER_ZOOM,
		MAX_USER_ZOOM
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if (
			button.button_index == MOUSE_BUTTON_WHEEL_UP
			and button.pressed
		):
			_zoom_at(
				button.position,
				1.22 if button.ctrl_pressed else CAMERA_ZOOM_STEP
			)
			follow_selected = false
			if telemetry != null:
				telemetry.mark_event("zooms")
			get_viewport().set_input_as_handled()
			return
		if (
			button.button_index == MOUSE_BUTTON_WHEEL_DOWN
			and button.pressed
		):
			_zoom_at(
				button.position,
				1.0 / (
					1.22
					if button.ctrl_pressed
					else CAMERA_ZOOM_STEP
				)
			)
			follow_selected = false
			if telemetry != null:
				telemetry.mark_event("zooms")
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			panning = button.pressed
			if panning:
				follow_selected = false
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed:
				rotating = true
				rotate_drag_start = button.position
				rotate_drag_accumulator = 0.0
			else:
				if rotating and absf(rotate_drag_accumulator) >= 28.0:
					_rotate_view(
						1 if rotate_drag_accumulator > 0.0 else -1
					)
				rotating = false
				rotate_drag_accumulator = 0.0
			get_viewport().set_input_as_handled()
			return
		if (
			button.button_index == MOUSE_BUTTON_LEFT
			and button.pressed
		):
			if _handle_ui_click(button.position):
				get_viewport().set_input_as_handled()
				return
			_select_at_screen(button.position)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if panning:
			view_pan += motion.relative
			get_viewport().set_input_as_handled()
			return
		if rotating:
			# A drag previews intent only. One quarter-turn is committed on
			# release, so fast drags cannot accidentally spin several times.
			rotate_drag_accumulator = (
				motion.position.x - rotate_drag_start.x
			)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.keycode:
			KEY_SPACE:
				paused = not paused
			KEY_ESCAPE:
				menu_visible = not menu_visible
				if menu_visible and telemetry != null:
					telemetry.mark_event("menu_opens")
			KEY_F:
				follow_selected = false
				_fit_view()
			KEY_R:
				_start_seed(current_seed)
				_refresh_terrain_visual_cache()
				_rebuild_terrain_batch()
				_rebuild_far_agent_batch()
				_fit_view()
			KEY_N:
				current_seed += 1
				_start_seed(current_seed)
				if telemetry != null:
					telemetry.mark_event("seed_changes")
				_refresh_terrain_visual_cache()
				_rebuild_terrain_batch()
				_rebuild_far_agent_batch()
				_fit_view()
			KEY_Q:
				_rotate_view(-1)
			KEY_E:
				_rotate_view(1)
			KEY_H:
				help_visible = not help_visible
			KEY_P:
				metrics_visible = not metrics_visible
			KEY_1:
				simulation_speed = 1.0
			KEY_2:
				simulation_speed = 2.0
			KEY_3:
				simulation_speed = 4.0
			KEY_4:
				simulation_speed = 8.0
			KEY_ENTER:
				if key.alt_pressed:
					_toggle_fullscreen()
				else:
					return
			_:
				return
		get_viewport().set_input_as_handled()


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
	direction = direction.normalized()
	view_pan += direction * 220.0 * delta


func _refresh_terrain_visual_cache() -> void:
	if sim == null or terrain == null:
		return
	var count: int = terrain.width * terrain.height
	terrain_color_cache.resize(count)
	terrain_mark_cache.resize(count)
	for y in range(terrain.height):
		for x in range(terrain.width):
			var index: int = y * terrain.width + x
			var source := Vector2i(x, y)
			var height_value: float = terrain.height_at_grid(x, y)
			terrain_color_cache[index] = _terrain_top_color(
				source,
				height_value
			)
			var world_position: Vector2 = (
				terrain.world_position_for_grid(x, y)
			)
			var damage: float = float(
				sim.damage_cue.sample_world(world_position)
			)
			var detritus_value: float = float(
				sim.detritus.sample_world(world_position)
			)
			var producer: float = float(
				sim.producer_biomass.sample_world(world_position)
			)
			var mark: int = 0
			if damage > 0.09:
				mark = 3
			elif detritus_value > 0.10:
				mark = 2
			elif producer > 0.16:
				mark = 1
			terrain_mark_cache[index] = mark


func _select_at_screen(screen_position: Vector2) -> void:
	if telemetry != null:
		telemetry.mark_event("selection_attempts")
	var best_agent: Variant = null
	var best_kind: String = ""
	var best_distance_sq: float = 38.0 * 38.0

	for record in _selection_groups():
		var kind: String = String(record[0])
		var group: Array = record[1]
		for agent in group:
			if agent == null:
				continue
			if "consumed" in agent and bool(agent.consumed):
				continue
			var p: Vector2 = Vector2(agent.position)
			var screen: Vector2 = _project_world(
				p,
				terrain.sample_height(p)
				- float(agent.burrow_depth) * 0.24
			)
			var distance_sq: float = screen.distance_squared_to(
				screen_position
			)
			if distance_sq < best_distance_sq:
				best_distance_sq = distance_sq
				best_agent = agent
				best_kind = kind

	if best_agent == null:
		selected_agent = null
		selected_kind = ""
		follow_selected = false
		return

	selected_agent = best_agent
	selected_kind = best_kind
	follow_selected = true
	user_zoom = maxf(user_zoom, 1.45)
	_update_selected_follow()
	if telemetry != null:
		telemetry.mark_event("selection_hits")


func _selection_groups() -> Array:
	return [
		["BACTERIUM", sim.bacteria],
		["AMOEBA", sim.protozoa],
		["CILIATE", sim.ciliates],
		["FLAGELLATE", sim.flagellates],
		["MICROALGA", sim.microalgae],
		["YEAST", sim.decomposers],
		["HYPHA", sim.hyphae],
	]


func _selected_screen_position() -> Vector2:
	if selected_agent == null:
		return Vector2.ZERO
	var p: Vector2 = Vector2(selected_agent.position)
	return _project_world(
		p,
		terrain.sample_height(p)
		- float(selected_agent.burrow_depth) * 0.24
	)


func _update_selected_follow() -> void:
	if selected_agent == null:
		follow_selected = false
		return
	var center: Vector2 = get_viewport_rect().size * 0.5
	var selected_screen: Vector2 = _selected_screen_position()
	view_pan += center - selected_screen


func _draw_selection() -> void:
	if selected_agent == null:
		return
	var screen: Vector2 = _round_vec(_selected_screen_position())
	var s: float = maxf(5.0, roundf(7.0 * _camera_zoom()))
	var c := Color(0.82, 0.94, 0.70, 0.88)
	var w: float = maxf(1.0, roundf(_camera_zoom()))
	draw_line(
		screen + Vector2(-s, -s),
		screen + Vector2(-s * 0.35, -s),
		c,
		w,
		false
	)
	draw_line(
		screen + Vector2(s, -s),
		screen + Vector2(s * 0.35, -s),
		c,
		w,
		false
	)
	draw_line(
		screen + Vector2(-s, s),
		screen + Vector2(-s * 0.35, s),
		c,
		w,
		false
	)
	draw_line(
		screen + Vector2(s, s),
		screen + Vector2(s * 0.35, s),
		c,
		w,
		false
	)


func _draw_ui() -> void:
	var button: Rect2 = _menu_button_rect()
	draw_rect(
		button,
		Color(0.025, 0.055, 0.057, 0.92),
		true
	)
	draw_rect(
		button,
		Color(0.34, 0.50, 0.45, 0.72),
		false,
		1.0
	)
	for i in range(3):
		draw_line(
			button.position + Vector2(7.0, 7.0 + float(i) * 5.0),
			button.position + Vector2(21.0, 7.0 + float(i) * 5.0),
			Color(0.78, 0.86, 0.82),
			1.0
		)

	if menu_visible:
		_draw_menu_panel()
	if selected_agent != null:
		_draw_inspector()
	if metrics_visible:
		_draw_metrics_panel()


func _menu_button_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Rect2(
		Vector2(viewport_size.x - 42.0, 12.0),
		Vector2(30.0, 26.0)
	)


func _menu_panel_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Rect2(
		Vector2(viewport_size.x - MENU_WIDTH - 12.0, 46.0),
		Vector2(MENU_WIDTH, 267.0)
	)


func _draw_menu_panel() -> void:
	var panel: Rect2 = _menu_panel_rect()
	draw_rect(panel, Color(0.012, 0.026, 0.028, 0.94), true)
	draw_rect(
		panel,
		Color(0.26, 0.45, 0.40, 0.80),
		false,
		1.0
	)
	_ui_text(
		panel.position + Vector2(12.0, 21.0),
		"MICROC0RE",
		14,
		Color(0.84, 0.92, 0.88)
	)
	var labels: Array = [
		"RESUME" if paused else "PAUSE",
		"SPEED  x%.0f  (actual x%.1f)" % [
			simulation_speed,
			actual_sim_speed,
		],
		"FIT BIOME",
		"NEW SEED",
		"PERF  " + ("ON" if metrics_visible else "OFF"),
		"HELP  " + ("ON" if help_visible else "OFF"),
		"EXIT TO DESKTOP",
	]
	for i in range(labels.size()):
		var row := Rect2(
			panel.position + Vector2(10.0, 35.0 + float(i) * 31.0),
			Vector2(panel.size.x - 20.0, 25.0)
		)
		draw_rect(row, Color(0.035, 0.072, 0.070, 0.88), true)
		_ui_text(
			row.position + Vector2(8.0, 17.0),
			String(labels[i]),
			12,
			Color(0.72, 0.82, 0.78)
		)


func _draw_inspector() -> void:
	var panel := Rect2(
		Vector2(12.0, 12.0),
		Vector2(INSPECTOR_WIDTH, 172.0)
	)
	draw_rect(panel, Color(0.010, 0.022, 0.024, 0.93), true)
	draw_rect(
		panel,
		Color(0.28, 0.50, 0.45, 0.78),
		false,
		1.0
	)
	_ui_text(
		panel.position + Vector2(11.0, 21.0),
		"%s #%d" % [selected_kind, int(selected_agent.id)],
		14,
		Color(0.84, 0.94, 0.88)
	)
	_ui_text(
		panel.position + Vector2(panel.size.x - 22.0, 21.0),
		"X",
		13,
		Color(0.78, 0.82, 0.80)
	)

	var state: String = "active"
	if "dying" in selected_agent and bool(selected_agent.dying):
		state = "dying"
	elif "dormant" in selected_agent and bool(selected_agent.dormant):
		state = "dormant"
	elif "terrain_action" in selected_agent:
		var action: String = String(selected_agent.terrain_action)
		if action != "none":
			state = action

	var y: float = 43.0
	_ui_text(
		panel.position + Vector2(11.0, y),
		"%s   E %.2f   age %.1fs" % [
			state,
			float(selected_agent.energy),
			float(selected_agent.age),
		],
		12,
		Color(0.72, 0.82, 0.78)
	)
	y += 20.0

	if selected_kind == "BACTERIUM":
		var module_count: int = (
			selected_agent.genome.modules.size()
			if selected_agent.genome != null
			else 0
		)
		_ui_text(
			panel.position + Vector2(11.0, y),
			"%s   eco %04X   modules %d" % [
				String(selected_agent.ecotype_label),
				int(selected_agent.ecotype_id) & 0xffff,
				module_count,
			],
			11,
			Color(0.69, 0.80, 0.76)
		)
		y += 19.0
	elif "generation" in selected_agent:
		_ui_text(
			panel.position + Vector2(11.0, y),
			"generation %d   lineage %.2f" % [
				int(selected_agent.generation),
				float(selected_agent.lineage_hue),
			],
			11,
			Color(0.69, 0.80, 0.76)
		)
		y += 19.0

	_ui_text(
		panel.position + Vector2(11.0, y),
		"dig %.2f  bur %.2f  climb %.2f  armor %.2f" % [
			float(selected_agent.physical_dig),
			float(selected_agent.physical_burrow),
			float(selected_agent.physical_climb),
			float(selected_agent.physical_armor),
		],
		11,
		Color(0.77, 0.73, 0.57)
	)
	y += 19.0
	_ui_text(
		panel.position + Vector2(11.0, y),
		"soil %.2f  depth %.2f  mixes %d" % [
			float(selected_agent.carried_soil),
			float(selected_agent.burrow_depth),
			int(selected_agent.capability_mix_events),
		],
		11,
		Color(0.68, 0.72, 0.62)
	)
	y += 19.0

	var p: Vector2 = Vector2(selected_agent.position)
	_ui_text(
		panel.position + Vector2(11.0, y),
		"N %.2f  O2 %.2f  det %.2f  prod %.2f" % [
			float(sim.nutrient.sample_world(p)),
			float(sim.oxygen.sample_world(p)),
			float(sim.detritus.sample_world(p)),
			float(sim.producer_biomass.sample_world(p)),
		],
		11,
		Color(0.62, 0.72, 0.70)
	)


func _draw_metrics_panel() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel := Rect2(
		Vector2(12.0, viewport_size.y - 88.0),
		Vector2(330.0, 70.0)
	)
	draw_rect(panel, Color(0.010, 0.022, 0.024, 0.88), true)
	_ui_text(
		panel.position + Vector2(10.0, 18.0),
		"FPS %.0f   speed x%.1f/x%.0f   draw %.2fms" % [
			Performance.get_monitor(Performance.TIME_FPS),
			actual_sim_speed,
			simulation_speed,
			last_draw_ms,
		],
		11,
		Color(0.78, 0.86, 0.82)
	)
	_ui_text(
		panel.position + Vector2(10.0, 37.0),
		"sim %.2fms (core %.2f / earth %.2f)  agents %d" % [
			last_sim_step_ms,
			last_core_sim_ms,
			last_terrain_sim_ms,
			_total_agent_count(),
		],
		11,
		Color(0.68, 0.78, 0.74)
	)
	_ui_text(
		panel.position + Vector2(10.0, 56.0),
		"terrain %.2fms  tris %d  far agents %d" % [
			last_terrain_build_ms,
			last_terrain_triangles,
			last_far_agent_count,
		],
		11,
		Color(0.72, 0.70, 0.58)
	)


func _handle_ui_click(position: Vector2) -> bool:
	if _menu_button_rect().has_point(position):
		menu_visible = not menu_visible
		if menu_visible and telemetry != null:
			telemetry.mark_event("menu_opens")
		return true

	if selected_agent != null:
		var close_rect := Rect2(
			Vector2(INSPECTOR_WIDTH - 18.0, 12.0),
			Vector2(30.0, 30.0)
		)
		if close_rect.has_point(position):
			selected_agent = null
			selected_kind = ""
			follow_selected = false
			return true
		var inspector_rect := Rect2(
			Vector2(12.0, 12.0),
			Vector2(INSPECTOR_WIDTH, 172.0)
		)
		if inspector_rect.has_point(position):
			return true

	if not menu_visible:
		return false
	var panel: Rect2 = _menu_panel_rect()
	if not panel.has_point(position):
		menu_visible = false
		return false

	var local_y: float = position.y - panel.position.y
	if local_y < 35.0:
		return true
	var row: int = floori((local_y - 35.0) / 31.0)
	match row:
		0:
			paused = not paused
		1:
			simulation_speed = (
				2.0 if simulation_speed == 1.0
				else 4.0 if simulation_speed == 2.0
				else 8.0 if simulation_speed == 4.0
				else 1.0
			)
		2:
			follow_selected = false
			_fit_view()
		3:
			current_seed += 1
			_start_seed(current_seed)
			if telemetry != null:
				telemetry.mark_event("seed_changes")
			_refresh_terrain_visual_cache()
			_rebuild_terrain_batch()
			_rebuild_far_agent_batch()
			_fit_view()
		4:
			metrics_visible = not metrics_visible
		5:
			help_visible = not help_visible
		6:
			if telemetry != null:
				telemetry.finalize()
			get_tree().quit()
	return true


func _total_agent_count() -> int:
	return (
		sim.bacteria.size()
		+ sim.protozoa.size()
		+ sim.ciliates.size()
		+ sim.flagellates.size()
		+ sim.microalgae.size()
		+ sim.decomposers.size()
		+ sim.hyphae.size()
	)


func _ui_text(
	position: Vector2,
	text_value: String,
	font_size: int,
	color: Color
) -> void:
	draw_string(
		ThemeDB.fallback_font,
		_round_vec(position),
		text_value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)


func _draw_help() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel := Rect2(
		Vector2(12.0, viewport_size.y - 58.0),
		Vector2(480.0, 42.0)
	)
	draw_rect(
		panel,
		Color(0.015, 0.025, 0.027, 0.82),
		true
	)
	draw_string(
		ThemeDB.fallback_font,
		panel.position + Vector2(9.0, 17.0),
		"MMB pan  RMB drag rotate  wheel zoom  WASD move  Q/E rotate  F fit",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		12,
		Color(0.80, 0.87, 0.83)
	)
	draw_string(
		ThemeDB.fallback_font,
		panel.position + Vector2(9.0, 33.0),
		"SPACE pause  1-4 speed  N seed  R reset  H hide help",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		12,
		Color(0.63, 0.72, 0.68)
	)


func _on_viewport_resized() -> void:
	_recompute_fit_keep_zoom()
	_update_terrain_layer_transform()


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		else DisplayServer.WINDOW_MODE_FULLSCREEN
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
	if float(cell.length) < 3.0:
		return 0
	if float(cell.length) < 4.5:
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


func _exit_tree() -> void:
	if telemetry != null:
		telemetry.finalize()


func _round_vec(value: Vector2) -> Vector2:
	return Vector2(roundf(value.x), roundf(value.y))
