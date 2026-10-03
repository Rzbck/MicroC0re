extends Node2D

const WaterShader = preload("res://src/app/shaders/water_background.gdshader")
const BiomeShader = preload("res://src/app/shaders/biome_material.gdshader")

var _world_size := Vector2.ZERO
var _mask_a_image: Image
var _mask_b_image: Image
var _mask_a_texture: ImageTexture
var _mask_b_texture: ImageTexture
var _uv_driver_texture: ImageTexture
var _water_material: ShaderMaterial
var _biome_material: ShaderMaterial


func initialize(sim: Variant) -> void:
	_world_size = Vector2(sim.world_size)
	var width: int = int(sim.nutrient.width)
	var height: int = int(sim.nutrient.height)
	_mask_a_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	_mask_b_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	_mask_a_image.fill(Color(0, 0, 0, 0))
	_mask_b_image.fill(Color(0, 0, 0, 0))
	_mask_a_texture = ImageTexture.create_from_image(_mask_a_image)
	_mask_b_texture = ImageTexture.create_from_image(_mask_b_image)

	# Polygon2D only builds/passes its UV array when it owns a valid texture.
	# The biome shaders do not sample TEXTURE, but this 1x1 opaque texture is
	# required so UV spans 0..1 instead of collapsing to the default corner.
	var uv_driver_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	uv_driver_image.fill(Color.WHITE)
	_uv_driver_texture = ImageTexture.create_from_image(uv_driver_image)

	_water_material = ShaderMaterial.new()
	_water_material.shader = WaterShader
	_water_material.set_shader_parameter("world_size", _world_size)
	_water_material.set_shader_parameter("pixel_world", 0.25)

	_biome_material = ShaderMaterial.new()
	_biome_material.shader = BiomeShader
	_biome_material.set_shader_parameter("world_size", _world_size)
	_biome_material.set_shader_parameter("pixel_world", 0.25)
	_biome_material.set_shader_parameter("mask_a", _mask_a_texture)
	_biome_material.set_shader_parameter("mask_b", _mask_b_texture)

	var water := _make_world_quad(_water_material)
	water.name = "WaterShaderLayer"
	water.z_as_relative = false
	water.z_index = -2
	add_child(water)
	var biome := _make_world_quad(_biome_material)
	biome.name = "BiomeMaterialLayer"
	biome.z_as_relative = false
	biome.z_index = -1
	add_child(biome)
	refresh_from_sim(sim)


func refresh_from_sim(sim: Variant) -> void:
	if _mask_a_image == null:
		return
	for y in range(_mask_a_image.get_height()):
		for x in range(_mask_a_image.get_width()):
			var producer := clampf(float(sim.producer_biomass.get_cell(x, y)) * 1.85, 0.0, 1.0)
			var detritus := clampf(float(sim.detritus.get_cell(x, y)) * 5.4, 0.0, 1.0)
			var eps := clampf(float(sim.eps.get_cell(x, y)) * 5.0, 0.0, 1.0)
			var damage := clampf(float(sim.damage_cue.get_cell(x, y)) * 8.5, 0.0, 1.0)
			# Oxygen has a 0.42 baseline in the simulation. Only oxygen enrichment
			# should become artwork; otherwise the whole dish becomes cyan noise.
			var oxygen := clampf(
				(float(sim.oxygen.get_cell(x, y)) - 0.46) * 2.4,
				0.0,
				1.0
			)
			var nutrient := clampf(
				(float(sim.nutrient.get_cell(x, y)) - 0.04) * 1.35,
				0.0,
				1.0
			)
			var waste := clampf(float(sim.waste.get_cell(x, y)) * 1.55, 0.0, 1.0)
			var exudate_value := clampf(
				float(sim.exudate.get_cell(x, y)) * 4.0,
				0.0,
				1.0
			)
			_mask_a_image.set_pixel(x, y, Color(producer, detritus, eps, damage))
			_mask_b_image.set_pixel(x, y, Color(oxygen, nutrient, waste, exudate_value))
	_mask_a_texture.update(_mask_a_image)
	_mask_b_texture.update(_mask_b_image)
	var scene_light := clampf(float(sim.sample_light(_world_size * 0.5)), 0.0, 1.0)
	_water_material.set_shader_parameter("scene_light", scene_light)
	_biome_material.set_shader_parameter("scene_light", scene_light)


func _make_world_quad(material_value: Material) -> Polygon2D:
	var quad := Polygon2D.new()
	quad.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(_world_size.x, 0.0),
		_world_size,
		Vector2(0.0, _world_size.y),
	])
	quad.uv = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0),
		Vector2(1, 1), Vector2(0, 1),
	])
	quad.color = Color.WHITE
	quad.texture = _uv_driver_texture
	quad.material = material_value
	quad.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return quad
