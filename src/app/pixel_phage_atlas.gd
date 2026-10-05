extends RefCounted

const WIDTH := 11
const HEIGHT := 11
const VARIANTS := 4

var _textures: Array[Texture2D] = []


func _init() -> void:
	for variant in range(VARIANTS):
		var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		_draw_packet(image, variant)
		_textures.append(ImageTexture.create_from_image(image))


func get_texture(packet_id: int) -> Texture2D:
	return _textures[posmod(packet_id, VARIANTS)]


func _draw_packet(image: Image, variant: int) -> void:
	var dark := Color(0.25, 0.14, 0.36, 0.88)
	var body := Color(0.70, 0.38, 0.94, 0.96)
	var hot := Color(0.96, 0.66, 1.0, 1.0)
	var mist := Color(0.50, 0.30, 0.78, 0.52)

	var cx: int = 5
	var cy: int = 4
	_set_px(image, cx, cy - 2, dark)
	_set_px(image, cx - 1, cy - 1, body)
	_set_px(image, cx, cy - 1, hot)
	_set_px(image, cx + 1, cy - 1, body)
	_set_px(image, cx - 1, cy, body)
	_set_px(image, cx, cy, body)
	_set_px(image, cx + 1, cy, body)
	_set_px(image, cx, cy + 1, dark)
	_set_px(image, cx, cy + 2, body)
	_set_px(image, cx, cy + 3, dark)
	_set_px(image, cx - 1, cy + 4, dark)
	_set_px(image, cx + 1, cy + 4, dark)

	var offsets: Array[Vector2i] = [
		Vector2i(1, 2),
		Vector2i(9, 3),
		Vector2i(2, 8),
		Vector2i(8, 8),
	]
	for i in range(4):
		var p: Vector2i = offsets[posmod(i + variant, offsets.size())]
		_set_px(image, p.x, p.y, mist)


func _set_px(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
		image.set_pixel(x, y, color)
