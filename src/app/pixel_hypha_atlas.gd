extends RefCounted

const WIDTH := 7
const HEIGHT := 5
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
	# Hyphae should read as fungal filaments, not orange cables. One source-pixel
	# body thickness is intentional; tip/junction clusters provide readability.
	var dark := Color(0.20, 0.16, 0.11, 1.0)
	var body := Color(0.62, 0.55, 0.37, 1.0)
	var light := Color(0.84, 0.78, 0.55, 1.0)
	var enzyme := Color(0.45, 0.62, 0.39, 0.90)

	match kind:
		KIND_SEGMENT:
			for x in range(1, 6):
				_set_px(image, x, 2, body)
			_set_px(image, 1, 2, dark)
			_set_px(image, 5, 2, dark)
			if variant == 1:
				_set_px(image, 3, 1, light)
			elif variant == 2:
				_set_px(image, 4, 3, light)
		KIND_TIP:
			for x in range(1, 5):
				_set_px(image, x, 2, body)
			_set_px(image, 1, 2, dark)
			_set_px(image, 4, 2, light)
			_set_px(image, 5, 2, enzyme)
			if variant == 1:
				_set_px(image, 4, 1, light)
			elif variant == 2:
				_set_px(image, 4, 3, light)
		KIND_JUNCTION:
			for x in range(1, 6):
				_set_px(image, x, 2, body)
			_set_px(image, 3, 1, body)
			_set_px(image, 3, 3, body)
			_set_px(image, 3, 2, light)
			_set_px(image, 3 + (variant - 1), 1, enzyme)


func _set_px(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
		image.set_pixel(x, y, color)
