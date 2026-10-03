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

const FIXED_DT := 1.0 / 60.0
const MAX_STEPS_PER_FRAME := 4
const TILE_HALF_W := 5.0
const TILE_HALF_H := 2.5
const HEIGHT_PIXELS := 9.0
const CAMERA_ZOOM_STEP := 1.12
const MIN_USER_ZOOM := 0.58
const MAX_USER_ZOOM := 5.0

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
var help_visible: bool = false


func _ready() -> void:
	Engine.max_fps = 144
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	atlas = PixelAtlasScript.new()
	protozoa_atlas = PixelProtozoaAtlasScript.new()
	ciliate_atlas = PixelCiliateAtlasScript.new()
	flagellate_atlas = PixelFlagellateAtlasScript.new()
	ecology_atlas = PixelEcologyAtlasScript.new()
	hypha_atlas = PixelHyphaAtlasScript.new()

	_start_seed(current_seed)
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
	view_pan = Vector2.ZERO
	user_zoom = 1.0


func _process(delta: float) -> void:
	visual_time += delta
	_handle_keyboard_pan(delta)

	if not paused:
		accumulator += minf(delta * simulation_speed, 0.05)
		var steps: int = 0
		while accumulator >= FIXED_DT and steps < MAX_STEPS_PER_FRAME:
			sim.step(FIXED_DT)
			terrain.advance_from_sim(sim, FIXED_DT)
			accumulator -= FIXED_DT
			steps += 1
		if accumulator >= FIXED_DT:
			accumulator = fmod(accumulator, FIXED_DT)

	queue_redraw()


func _draw() -> void:
	if sim == null or terrain == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	draw_rect(
		Rect2(Vector2.ZERO, viewport_size),
		Color(0.025, 0.055, 0.060, 1.0),
		true
	)

	_draw_isometric_terrain()
	_draw_capability_fragments()
	_draw_agents()

	if help_visible:
		_draw_help()


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
	var half_w: float = maxf(2.0, roundf(TILE_HALF_W * _camera_zoom()))
	var half_h: float = maxf(1.0, roundf(TILE_HALF_H * _camera_zoom()))

	var top := center + Vector2(0.0, -half_h)
	var right := center + Vector2(half_w, 0.0)
	var bottom := center + Vector2(0.0, half_h)
	var left := center + Vector2(-half_w, 0.0)

	var top_color: Color = _terrain_top_color(source, height_value)
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

	# Coherent ecological material marks sit on the tile instead of replacing
	# the terrain with noise.
	var world: Vector2 = terrain.world_position_for_grid(
		source.x,
		source.y
	)
	var producer: float = float(sim.producer_biomass.sample_world(world))
	var detritus_value: float = float(sim.detritus.sample_world(world))
	var damage: float = float(sim.damage_cue.sample_world(world))
	var px: float = maxf(1.0, roundf(_camera_zoom()))
	if damage > 0.09:
		draw_rect(
			Rect2(
				_round_vec(center + Vector2(-px, -px)),
				Vector2(px * 2.0, px)
			),
			Color(0.72, 0.24, 0.10, 0.86),
			true
		)
	elif detritus_value > 0.10:
		draw_rect(
			Rect2(
				_round_vec(center + Vector2(-px, 0.0)),
				Vector2(px * 2.0, px)
			),
			Color(0.40, 0.25, 0.12, 0.90),
			true
		)
	elif producer > 0.16:
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


func _draw_agents() -> void:
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
	var dims: Vector2i = _rotated_dimensions()
	var cx: float = float(dims.x - 1) * 0.5
	var cy: float = float(dims.y - 1) * 0.5
	var dx: float = grid.x - cx
	var dy: float = grid.y - cy
	var unscaled := Vector2(
		(dx - dy) * TILE_HALF_W,
		(dx + dy) * TILE_HALF_H
		- (height_value - 0.60) * HEIGHT_PIXELS
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
	view_pan = Vector2.ZERO
	_recompute_fit_keep_zoom()


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
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			panning = button.pressed
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_RIGHT:
			rotating = button.pressed
			if not rotating:
				rotate_drag_accumulator = 0.0
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if panning:
			view_pan += motion.relative
			get_viewport().set_input_as_handled()
			return
		if rotating:
			rotate_drag_accumulator += motion.relative.x
			while absf(rotate_drag_accumulator) >= 54.0:
				var step: int = 1 if rotate_drag_accumulator > 0.0 else -1
				_rotate_view(step)
				rotate_drag_accumulator -= 54.0 * float(step)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.keycode:
			KEY_SPACE:
				paused = not paused
			KEY_F:
				_fit_view()
			KEY_R:
				_start_seed(current_seed)
				_fit_view()
			KEY_N:
				_start_seed(current_seed + 1)
				_fit_view()
			KEY_Q:
				_rotate_view(-1)
			KEY_E:
				_rotate_view(1)
			KEY_H:
				help_visible = not help_visible
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
	direction = direction.normalized()
	view_pan += direction * 220.0 * delta


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


func _round_vec(value: Vector2) -> Vector2:
	return Vector2(roundf(value.x), roundf(value.y))
