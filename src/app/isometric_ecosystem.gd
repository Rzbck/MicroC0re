extends Node3D

const PetriSimulationScript = preload("res://src/simulation/petri_simulation.gd")
const LivingTerrainScript = preload("res://src/simulation/living_terrain.gd")
const PhysicalCapabilityGenomeScript = preload("res://src/simulation/physical_capability_genome.gd")

const FIXED_DT := 1.0 / 60.0
const MAX_STEPS_PER_FRAME := 4
const TERRAIN_REFRESH_INTERVAL := 0.12
const AGENT_REFRESH_INTERVAL := 1.0 / 30.0
const MIN_CAMERA_SIZE := 18.0
const MAX_CAMERA_SIZE := 240.0
const ORBIT_SENSITIVITY := 0.008
const PAN_SPEED := 0.65

var sim: Variant
var terrain: Variant
var current_seed: int = 1337
var accumulator: float = 0.0
var terrain_refresh: float = 0.0
var agent_refresh: float = 0.0
var simulation_speed: float = 1.0
var paused: bool = false

var pivot: Node3D
var tilt: Node3D
var camera: Camera3D
var terrain_mesh: MeshInstance3D
var water_mesh: MeshInstance3D
var terrain_material: StandardMaterial3D
var renderers: Dictionary = {}
var dig_renderer: MultiMeshInstance3D
var egg_renderer: MultiMeshInstance3D
var armor_renderer: MultiMeshInstance3D
var hud: Label

var orbiting: bool = false
var panning: bool = false
var last_terrain_revision: int = -1


func _ready() -> void:
	Engine.max_fps = 144
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	_start_seed(current_seed)
	_setup_environment()
	_setup_camera()
	_setup_terrain()
	_setup_agent_renderers()
	_setup_hud()
	_fit_camera()
	_rebuild_terrain_mesh()
	_update_agent_renderers()


func _start_seed(seed_value: int) -> void:
	current_seed = seed_value
	sim = PetriSimulationScript.new(current_seed)
	sim.seed_demo(72)
	terrain = LivingTerrainScript.new(current_seed, Vector2(sim.world_size))
	accumulator = 0.0
	terrain_refresh = 0.0
	agent_refresh = 0.0
	last_terrain_revision = -1


func _setup_environment() -> void:
	RenderingServer.set_default_clear_color(Color(0.018, 0.027, 0.030, 1.0))
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.027, 0.030)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.48, 0.46)
	environment.ambient_light_energy = 0.90
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color(0.92, 0.88, 0.74)
	sun.shadow_enabled = true
	add_child(sun)


func _setup_camera() -> void:
	pivot = Node3D.new()
	pivot.name = "OrbitPivot"
	add_child(pivot)

	tilt = Node3D.new()
	tilt.name = "OrbitTilt"
	tilt.rotation.x = deg_to_rad(-48.0)
	pivot.add_child(tilt)

	camera = Camera3D.new()
	camera.name = "IsometricCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 600.0
	camera.position = Vector3(0.0, 0.0, 155.0)
	camera.size = 120.0
	camera.current = true
	tilt.add_child(camera)


func _setup_terrain() -> void:
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.name = "LivingTerrain"
	add_child(terrain_mesh)

	terrain_material = StandardMaterial3D.new()
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 0.96
	terrain_material.metallic = 0.0

	water_mesh = MeshInstance3D.new()
	water_mesh.name = "WaterPlane"
	var water_plane := PlaneMesh.new()
	water_plane.size = Vector2(sim.world_size)
	water_mesh.mesh = water_plane
	water_mesh.position = Vector3(
		0.0,
		LivingTerrainScript.WATER_LEVEL,
		0.0
	)
	var water_material := StandardMaterial3D.new()
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.albedo_color = Color(0.08, 0.28, 0.32, 0.36)
	water_material.roughness = 0.28
	water_plane.material = water_material
	add_child(water_mesh)


func _setup_agent_renderers() -> void:
	renderers["bacteria"] = _make_renderer(
		"Bacteria3D",
		_box_mesh(Vector3(1.5, 0.7, 0.72)),
		512
	)
	renderers["protozoa"] = _make_renderer(
		"Protozoa3D",
		_sphere_mesh(1.0),
		32
	)
	renderers["ciliates"] = _make_renderer(
		"Ciliates3D",
		_capsule_mesh(0.55, 1.8),
		32
	)
	renderers["flagellates"] = _make_renderer(
		"Flagellates3D",
		_box_mesh(Vector3(1.25, 0.55, 0.50)),
		48
	)
	renderers["microalgae"] = _make_renderer(
		"Microalgae3D",
		_sphere_mesh(0.72),
		96
	)
	renderers["decomposers"] = _make_renderer(
		"Decomposers3D",
		_sphere_mesh(0.78),
		72
	)
	renderers["hyphae"] = _make_renderer(
		"Hyphae3D",
		_box_mesh(Vector3(1.8, 0.28, 0.34)),
		16
	)

	dig_renderer = _make_renderer(
		"DigMorphology",
		_box_mesh(Vector3(0.90, 0.30, 0.55)),
		768
	)
	egg_renderer = _make_renderer(
		"OvipositorMorphology",
		_sphere_mesh(0.34),
		768
	)
	armor_renderer = _make_renderer(
		"ArmorMorphology",
		_sphere_mesh(0.68),
		768
	)


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(18.0, 16.0)
	hud.add_theme_font_size_override("font_size", 16)
	hud.add_theme_color_override(
		"font_color",
		Color(0.86, 0.92, 0.88)
	)
	hud.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.80)
	)
	hud.add_theme_constant_override("shadow_offset_x", 1)
	hud.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(hud)
	_update_hud()


func _process(delta: float) -> void:
	_handle_keyboard(delta)

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

	terrain_refresh += delta
	if terrain_refresh >= TERRAIN_REFRESH_INTERVAL:
		terrain_refresh = fmod(
			terrain_refresh,
			TERRAIN_REFRESH_INTERVAL
		)
		if int(terrain.revision) != last_terrain_revision:
			_rebuild_terrain_mesh()

	agent_refresh += delta
	if agent_refresh >= AGENT_REFRESH_INTERVAL:
		agent_refresh = fmod(
			agent_refresh,
			AGENT_REFRESH_INTERVAL
		)
		_update_agent_renderers()
		_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if (
			button.button_index == MOUSE_BUTTON_WHEEL_UP
			and button.pressed
		):
			camera.size = clampf(
				camera.size * 0.90,
				MIN_CAMERA_SIZE,
				MAX_CAMERA_SIZE
			)
			get_viewport().set_input_as_handled()
			return
		if (
			button.button_index == MOUSE_BUTTON_WHEEL_DOWN
			and button.pressed
		):
			camera.size = clampf(
				camera.size / 0.90,
				MIN_CAMERA_SIZE,
				MAX_CAMERA_SIZE
			)
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = button.pressed
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			panning = button.pressed
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if orbiting:
			pivot.rotation.y -= (
				motion.screen_relative.x * ORBIT_SENSITIVITY
			)
			tilt.rotation.x = clampf(
				tilt.rotation.x
				- motion.screen_relative.y * ORBIT_SENSITIVITY,
				deg_to_rad(-72.0),
				deg_to_rad(-26.0)
			)
			get_viewport().set_input_as_handled()
			return
		if panning:
			var scale: float = camera.size / 720.0
			var right := Vector3(
				cos(pivot.rotation.y),
				0.0,
				-sin(pivot.rotation.y)
			)
			var forward := Vector3(
				sin(pivot.rotation.y),
				0.0,
				cos(pivot.rotation.y)
			)
			pivot.position += (
				right * -motion.screen_relative.x
				+ forward * motion.screen_relative.y
			) * scale
			_clamp_pivot()
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
				_fit_camera()
			KEY_R:
				_start_seed(current_seed)
				_rebuild_terrain_mesh()
			KEY_N:
				_start_seed(current_seed + 1)
				_rebuild_terrain_mesh()
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
		_update_hud()
		get_viewport().set_input_as_handled()


func _handle_keyboard(delta: float) -> void:
	var move := Vector2.ZERO
	if (
		Input.is_key_pressed(KEY_A)
		or Input.is_key_pressed(KEY_LEFT)
	):
		move.x -= 1.0
	if (
		Input.is_key_pressed(KEY_D)
		or Input.is_key_pressed(KEY_RIGHT)
	):
		move.x += 1.0
	if (
		Input.is_key_pressed(KEY_W)
		or Input.is_key_pressed(KEY_UP)
	):
		move.y -= 1.0
	if (
		Input.is_key_pressed(KEY_S)
		or Input.is_key_pressed(KEY_DOWN)
	):
		move.y += 1.0

	if move.length_squared() > 0.0:
		move = move.normalized()
		var right := Vector3(
			cos(pivot.rotation.y),
			0.0,
			-sin(pivot.rotation.y)
		)
		var forward := Vector3(
			sin(pivot.rotation.y),
			0.0,
			cos(pivot.rotation.y)
		)
		pivot.position += (
			right * move.x + forward * move.y
		) * PAN_SPEED * camera.size * delta
		_clamp_pivot()

	if Input.is_key_pressed(KEY_Q):
		pivot.rotation.y += 0.95 * delta
	if Input.is_key_pressed(KEY_E):
		pivot.rotation.y -= 0.95 * delta


func _rebuild_terrain_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(terrain.height - 1):
		for x in range(terrain.width - 1):
			var p00 := _terrain_vertex(x, y)
			var p10 := _terrain_vertex(x + 1, y)
			var p01 := _terrain_vertex(x, y + 1)
			var p11 := _terrain_vertex(x + 1, y + 1)

			_add_terrain_vertex(st, p00)
			_add_terrain_vertex(st, p01)
			_add_terrain_vertex(st, p10)

			_add_terrain_vertex(st, p10)
			_add_terrain_vertex(st, p01)
			_add_terrain_vertex(st, p11)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, terrain_material)
	terrain_mesh.mesh = mesh
	last_terrain_revision = int(terrain.revision)


func _terrain_vertex(x: int, y: int) -> Vector3:
	var world: Vector2 = terrain.world_position_for_grid(x, y)
	return Vector3(
		world.x - float(sim.world_size.x) * 0.5,
		terrain.height_at_grid(x, y),
		world.y - float(sim.world_size.y) * 0.5
	)


func _add_terrain_vertex(st: SurfaceTool, vertex: Vector3) -> void:
	var world := Vector2(
		vertex.x + float(sim.world_size.x) * 0.5,
		vertex.z + float(sim.world_size.y) * 0.5
	)
	st.set_color(_terrain_color(world, vertex.y))
	st.add_vertex(vertex)


func _terrain_color(world: Vector2, h: float) -> Color:
	var producer: float = float(
		sim.producer_biomass.sample_world(world)
	)
	var detritus_value: float = float(
		sim.detritus.sample_world(world)
	)
	var eps_value: float = float(sim.eps.sample_world(world))
	if h < LivingTerrainScript.WATER_LEVEL - 0.08:
		return Color(0.14, 0.20, 0.17).lerp(
			Color(0.18, 0.28, 0.20),
			clampf(producer * 0.9, 0.0, 0.55)
		)

	var base := Color(0.36, 0.29, 0.18)
	base = base.lerp(
		Color(0.29, 0.39, 0.19),
		clampf(producer * 1.6, 0.0, 0.72)
	)
	base = base.lerp(
		Color(0.30, 0.22, 0.14),
		clampf(detritus_value * 2.5, 0.0, 0.55)
	)
	base = base.lerp(
		Color(0.24, 0.36, 0.31),
		clampf(eps_value * 1.8, 0.0, 0.35)
	)
	if h > 2.0:
		base = base.lerp(
			Color(0.42, 0.34, 0.22),
			clampf((h - 2.0) / 5.0, 0.0, 0.55)
		)
	return base


func _update_agent_renderers() -> void:
	_update_group(
		"bacteria",
		sim.bacteria,
		Vector3(1.0, 1.0, 1.0),
		0
	)
	_update_group(
		"protozoa",
		sim.protozoa,
		Vector3(1.7, 1.2, 1.7),
		1
	)
	_update_group(
		"ciliates",
		sim.ciliates,
		Vector3(1.5, 1.0, 1.0),
		2
	)
	_update_group(
		"flagellates",
		sim.flagellates,
		Vector3(1.0, 0.8, 0.8),
		3
	)
	_update_group(
		"microalgae",
		sim.microalgae,
		Vector3(1.1, 1.1, 1.1),
		4
	)
	_update_group(
		"decomposers",
		sim.decomposers,
		Vector3(1.15, 1.0, 1.15),
		5
	)
	_update_group(
		"hyphae",
		sim.hyphae,
		Vector3(1.2, 0.55, 0.75),
		6
	)
	_update_capability_morphology()


func _update_group(
	key: String,
	group: Array,
	base_scale: Vector3,
	kind: int
) -> void:
	var renderer: MultiMeshInstance3D = renderers[key]
	var mm: MultiMesh = renderer.multimesh
	var count: int = mini(group.size(), mm.instance_count)
	mm.visible_instance_count = count

	for i in range(count):
		var agent = group[i]
		var p: Vector2 = Vector2(agent.position)
		var ground: float = terrain.sample_height(p)
		var depth: float = clampf(
			float(agent.burrow_depth),
			0.0,
			3.0
		)
		var armor: float = clampf(
			float(agent.physical_armor),
			0.0,
			2.0
		)
		var size_factor: float = 1.0
		if kind == 0:
			size_factor = clampf(
				float(agent.gene_size),
				0.65,
				1.65
			)
		elif kind in [1, 2, 3, 4, 5]:
			size_factor = clampf(
				float(agent.gene_size),
				0.65,
				1.65
			)
		elif kind == 6:
			size_factor = clampf(
				sqrt(float(agent.nodes.size())) * 0.55,
				0.8,
				2.0
			)

		var scale := base_scale * size_factor
		scale.y *= 1.0 + armor * 0.18
		scale.z *= 1.0 + armor * 0.10
		if kind == 0:
			scale.x *= clampf(
				float(agent.length) / 3.0,
				0.70,
				2.2
			)

		var basis := Basis(
			Vector3.UP,
			-float(agent.angle)
		).scaled(scale)
		var origin := Vector3(
			p.x - float(sim.world_size.x) * 0.5,
			ground + 0.34 * scale.y - depth * 0.72,
			p.y - float(sim.world_size.y) * 0.5
		)
		mm.set_instance_transform(
			i,
			Transform3D(basis, origin)
		)
		var hue: float = float(agent.lineage_hue)
		var color := Color.from_hsv(
			wrapf(hue, 0.0, 1.0),
			0.38,
			0.78
		)
		if depth > 0.25:
			color = color.darkened(
				clampf(depth * 0.12, 0.0, 0.32)
			)
		mm.set_instance_color(i, color)


func _update_capability_morphology() -> void:
	var all_agents: Array = []
	all_agents.append_array(sim.bacteria)
	all_agents.append_array(sim.protozoa)
	all_agents.append_array(sim.ciliates)
	all_agents.append_array(sim.flagellates)
	all_agents.append_array(sim.microalgae)
	all_agents.append_array(sim.decomposers)
	all_agents.append_array(sim.hyphae)

	var dig_mm: MultiMesh = dig_renderer.multimesh
	var egg_mm: MultiMesh = egg_renderer.multimesh
	var armor_mm: MultiMesh = armor_renderer.multimesh
	var dig_count: int = 0
	var egg_count: int = 0
	var armor_count: int = 0

	for agent in all_agents:
		if agent.physical_genome == null:
			continue
		var p: Vector2 = Vector2(agent.position)
		var h: float = terrain.sample_height(p)
		var forward := Vector2.RIGHT.rotated(float(agent.angle))
		var dig: float = maxf(
			float(agent.physical_dig),
			float(agent.physical_genome.neutral_expression(
				PhysicalCapabilityGenomeScript.CAP_DIG
			))
		)
		var egg: float = maxf(
			float(agent.physical_oviposit),
			float(agent.physical_genome.neutral_expression(
				PhysicalCapabilityGenomeScript.CAP_OVIPOSIT
			))
		)
		var armor: float = maxf(
			float(agent.physical_armor),
			float(agent.physical_genome.neutral_expression(
				PhysicalCapabilityGenomeScript.CAP_ARMOR
			))
		)

		if dig > 0.48 and dig_count < dig_mm.instance_count:
			var tip := p + forward * (
				0.85 + minf(1.4, dig) * 0.35
			)
			var scale := Vector3(
				0.65 + dig * 0.28,
				0.72,
				0.72
			)
			var basis := Basis(
				Vector3.UP,
				-float(agent.angle)
			).scaled(scale)
			var origin := Vector3(
				tip.x - float(sim.world_size.x) * 0.5,
				h + 0.28 - float(agent.burrow_depth) * 0.70,
				tip.y - float(sim.world_size.y) * 0.5
			)
			dig_mm.set_instance_transform(
				dig_count,
				Transform3D(basis, origin)
			)
			dig_mm.set_instance_color(
				dig_count,
				Color(0.28, 0.20, 0.12)
			)
			dig_count += 1

		if egg > 0.42 and egg_count < egg_mm.instance_count:
			var sac := p - forward * 0.72
			var scale := Vector3.ONE * (
				0.70 + minf(1.5, egg) * 0.18
			)
			var origin := Vector3(
				sac.x - float(sim.world_size.x) * 0.5,
				h + 0.34 - float(agent.burrow_depth) * 0.70,
				sac.y - float(sim.world_size.y) * 0.5
			)
			egg_mm.set_instance_transform(
				egg_count,
				Transform3D(
					Basis.IDENTITY.scaled(scale),
					origin
				)
			)
			egg_mm.set_instance_color(
				egg_count,
				Color(0.74, 0.70, 0.55)
			)
			egg_count += 1

		if armor > 0.52 and armor_count < armor_mm.instance_count:
			var scale := Vector3.ONE * (
				0.86 + minf(1.8, armor) * 0.12
			)
			var origin := Vector3(
				p.x - float(sim.world_size.x) * 0.5,
				h + 0.36 - float(agent.burrow_depth) * 0.70,
				p.y - float(sim.world_size.y) * 0.5
			)
			armor_mm.set_instance_transform(
				armor_count,
				Transform3D(
					Basis.IDENTITY.scaled(scale),
					origin
				)
			)
			armor_mm.set_instance_color(
				armor_count,
				Color(0.24, 0.27, 0.25, 0.24)
			)
			armor_count += 1

	dig_mm.visible_instance_count = dig_count
	egg_mm.visible_instance_count = egg_count
	armor_mm.visible_instance_count = armor_count


func _make_renderer(
	name_value: String,
	mesh: Mesh,
	capacity: int
) -> MultiMeshInstance3D:
	var renderer := MultiMeshInstance3D.new()
	renderer.name = name_value
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	renderer.multimesh = mm
	add_child(renderer)
	return renderer


func _agent_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.78
	material.metallic = 0.0
	return material


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _agent_material()
	return mesh


func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _agent_material()
	return mesh


func _capsule_mesh(
	radius: float,
	height_value: float
) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height_value
	mesh.radial_segments = 8
	mesh.rings = 3
	mesh.material = _agent_material()
	return mesh


func _fit_camera() -> void:
	pivot.position = Vector3.ZERO
	pivot.rotation.y = deg_to_rad(45.0)
	tilt.rotation.x = deg_to_rad(-48.0)
	camera.size = maxf(
		float(sim.world_size.y) * 0.92,
		float(sim.world_size.x) * 0.64
	)


func _clamp_pivot() -> void:
	var half_x: float = float(sim.world_size.x) * 0.56
	var half_z: float = float(sim.world_size.y) * 0.56
	pivot.position.x = clampf(
		pivot.position.x,
		-half_x,
		half_x
	)
	pivot.position.z = clampf(
		pivot.position.z,
		-half_z,
		half_z
	)


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		else DisplayServer.WINDOW_MODE_FULLSCREEN
	)


func _update_hud() -> void:
	if hud == null:
		return
	var total_agents: int = (
		sim.bacteria.size()
		+ sim.protozoa.size()
		+ sim.ciliates.size()
		+ sim.flagellates.size()
		+ sim.microalgae.size()
		+ sim.decomposers.size()
		+ sim.hyphae.size()
	)
	hud.text = (
		"MICROC0RE  seed %d  x%.0f%s\n"
		+ "agents %d  soil moved %.2f / %.2f\n"
		+ "RMB orbit  MMB pan  wheel zoom  WASD move  Q/E rotate  F fit  N new seed"
	) % [
		current_seed,
		simulation_speed,
		"  PAUSED" if paused else "",
		total_agents,
		float(terrain.excavated_total),
		float(terrain.deposited_total),
	]
