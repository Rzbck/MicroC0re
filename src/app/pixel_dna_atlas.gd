extends RefCounted

const WIDTH := 7
const HEIGHT := 5
const VARIANTS := 4

var _textures: Array[Texture2D] = []


func _init() -> void:
	for variant in range(VARIANTS):
		var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		_draw_fragment(image, variant)
		_textures.append(ImageTexture.create_from_image(image))


func get_texture(fragment_id: int) -> Texture2D:
	return _textures[posmod(fragment_id, VARIANTS)]


func _draw_fragment(image: Image, variant: int) -> void:
	var dark := Color(0.17, 0.38, 0.48, 0.72)
	var body := Color(0.34, 0.76, 0.86, 0.88)
	var hot := Color(0.68, 0.96, 0.94, 0.96)
	var patterns := [
		[Vector2i(1,3),Vector2i(2,2),Vector2i(3,2),Vector2i(4,1),Vector2i(5,1)],
		[Vector2i(1,1),Vector2i(2,2),Vector2i(3,2),Vector2i(4,3),Vector2i(5,3)],
		[Vector2i(1,2),Vector2i(2,1),Vector2i(3,2),Vector2i(4,3),Vector2i(5,2)],
		[Vector2i(1,3),Vector2i(2,3),Vector2i(3,2),Vector2i(4,1),Vector2i(5,2)],
	]
	var points: Array = patterns[variant]
	for i in range(points.size()):
		var p: Vector2i = points[i]
		image.set_pixel(p.x, p.y, hot if i == 2 else body)
		if i == 0 or i == points.size() - 1:
			image.set_pixel(p.x, clampi(p.y + (1 if i == 0 else -1), 0, HEIGHT - 1), dark)
