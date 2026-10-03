extends Node2D

const WaterShader = preload("res://src/app/shaders/water_background.gdshader")
const BiomeShader = preload("res://src/app/shaders/biome_material.gdshader")

var _world_size := Vector2.ZERO
var _mask_a_image: Image
var _mask_b_image: Image
var _mask_a_texture: ImageTexture
var _mask_b_texture: ImageTexture
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
	water.z_index = -30
	add_child(water)
	var biome := _make_world_quad(_biome_material)
	biome.name = "BiomeMaterialLayer"
	biome.z_index = -29
	add_child(biome)
	refresh_from_sim(sim)


func refresh_from_sim(sim: Variant) -> void:
	if _mask_a_image == null:
		return
	for y in range(_mask_a_image.get_height()):
		for x in range(_mask_a_image.get_width()):
			var producer := clampf(float(sim.producer_biomass.get_cell(x, y)) * 1.35, 0.0, 1.0)
			var detritus := clampf(float(sim.detritus.get_cell(x, y)) * 4.2, 0.0, 1.0)
			var eps := clampf(float(sim.eps.get_cell(x, y)) * 4.0, 0.0, 1.0)
			var damage := clampf(float(sim.damage_cue.get_cell(x, y)) * 7.5, 0.0, 1.0)
			var oxygen := clampf(float(sim.oxygen.get_cell(x, y)) * 1.15, 0.0, 1.0)
			var nutrient := clampf(float(sim.nutrient.get_cell(x, y)) * 1.10, 0.0, 1.0)
			var waste := clampf(float(sim.waste.get_cell(x, y)) * 1.55, 0.0, 1.0)
			_mask_a_image.set_pixel(x, y, Color(producer, detritus, eps, damage))
			_mask_b_image.set_pixel(x, y, Color(oxygen, nutrient, waste, 0.0))
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
	quad.material = material_value
	quad.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return quad
