extends RefCounted

const WIDTH := 9
const HEIGHT := 7
const KIND_SEGMENT := 0
const KIND_TIP := 1
const KIND_JUNCTION := 2
const KINDS := 3
const VARIANTS := 3

var _textures: Array = []


func _init() -> void:
	for kind in range(KINDS):
		var variants: Array = []
		for variant in range(VARIANTS):
			var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw(image, kind, variant)
			variants.append(ImageTexture.create_from_image(image))
		_textures.append(variants)


func get_texture(kind: int, variant: int) -> Texture2D:
	return _textures[
		clampi(kind, 0, KINDS - 1)
	][
		posmod(variant, VARIANTS)
	]


func _draw(image: Image, kind: int, variant: int) -> void:
	var outline := Color(0.19, 0.14, 0.10, 1.0)
	var body := Color(0.78, 0.66, 0.40, 1.0)
	var light := Color(0.98, 0.88, 0.58, 1.0)
	var enzyme := Color(0.58, 0.84, 0.52, 0.86)

	match kind:
		KIND_SEGMENT:
			for x in range(1, 8):
				_set_px(image, x, 3, body)
				if x in [1, 7]:
					_set_px(image, x, 2, outline)
				if posmod(x + variant, 3) == 0:
					_set_px(image, x, 2, light)
		KIND_TIP:
			for x in range(1, 6):
				_set_px(image, x, 3, body)
			_set_px(image, 5, 2, outline)
			_set_px(image, 6, 3, light)
			_set_px(image, 7, 3, enzyme)
			_set_px(image, 6, 4, outline)
		KIND_JUNCTION:
			for x in range(1, 8):
				_set_px(image, x, 3, body)
			for y in range(1, 6):
				_set_px(image, 4, y, body)
			_set_px(image, 4, 3, light)
			_set_px(image, 4 + (variant - 1), 2, enzyme)


func _set_px(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
		image.set_pixel(x, y, color)
