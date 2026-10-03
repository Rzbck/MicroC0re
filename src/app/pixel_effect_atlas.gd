extends RefCounted

const SIZE := 11
const FRAMES := 4
const KINDS := 8

const EFFECT_DIVISION := 0
const EFFECT_ADHESION := 1
const EFFECT_REPRODUCTION := 2
const EFFECT_FEEDING := 3
const EFFECT_LYSIS := 4
const EFFECT_STRESS := 5
const EFFECT_PURSUIT := 6
const EFFECT_DIGESTION := 7

var _textures: Array = []


func _init() -> void:
	_build()


func get_texture(kind: int, frame: int) -> Texture2D:
	return _textures[
		clampi(kind, 0, KINDS - 1)
	][
		posmod(frame, FRAMES)
	]


func _build() -> void:
	_textures.clear()
	for kind in range(KINDS):
		var frames: Array = []
		for frame in range(FRAMES):
			var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
			image.fill(Color(0.0, 0.0, 0.0, 0.0))
			match kind:
				EFFECT_DIVISION:
					_draw_division(image, frame)
				EFFECT_ADHESION:
					_draw_adhesion(image, frame)
				EFFECT_REPRODUCTION:
					_draw_reproduction(image, frame)
				EFFECT_FEEDING:
					_draw_feeding(image, frame)
				EFFECT_LYSIS:
					_draw_lysis(image, frame)
				EFFECT_STRESS:
					_draw_stress(image, frame)
				EFFECT_PURSUIT:
					_draw_pursuit(image, frame)
				EFFECT_DIGESTION:
					_draw_digestion(image, frame)
			frames.append(ImageTexture.create_from_image(image))
		_textures.append(frames)


func _draw_division(image: Image, frame: int) -> void:
	var dim := Color(0.38, 0.66, 0.30, 0.75)
	var bright := Color(0.78, 1.0, 0.54, 0.95)
	var gap: int = 1 + frame / 2
	_set_px(image, 5 - gap, 5, bright)
	_set_px(image, 5 + gap, 5, bright)
	_set_px(image, 5 - gap - 1, 5, dim)
	_set_px(image, 5 + gap + 1, 5, dim)
	_set_px(image, 5, 4, dim)
	_set_px(image, 5, 6, dim)


func _draw_adhesion(image: Image, frame: int) -> void:
	var body := Color(0.22, 0.70, 0.56, 0.60)
	var hot := Color(0.42, 0.98, 0.76, 0.86)
	for i in range(8):
		var x: int = posmod(i * 3 + frame, SIZE - 2) + 1
		var y: int = posmod(i * 5 + frame * 2, SIZE - 2) + 1
		_set_px(image, x, y, hot if i % 3 == 0 else body)
		if i % 2 == 0:
			_set_px(image, clampi(x + 1, 0, SIZE - 1), y, body)


func _draw_reproduction(image: Image, frame: int) -> void:
	var body := Color(0.78, 0.92, 0.42, 0.72)
	var hot := Color(1.0, 0.88, 0.42, 0.92)
	var offsets := [
		Vector2i(-3, 0),
		Vector2i(0, -3),
		Vector2i(3, 0),
		Vector2i(0, 3),
	]
	for i in range(offsets.size()):
		var o: Vector2i = offsets[posmod(i + frame, offsets.size())]
		_set_px(image, 5 + o.x, 5 + o.y, hot if i == 0 else body)
	_set_px(image, 5, 5, body)


func _draw_feeding(image: Image, frame: int) -> void:
	var body := Color(0.88, 0.42, 0.26, 0.66)
	var hot := Color(1.0, 0.76, 0.36, 0.96)
	var ring := [
		Vector2i(-2, -2), Vector2i(0, -3), Vector2i(2, -2),
		Vector2i(3, 0), Vector2i(2, 2), Vector2i(0, 3),
		Vector2i(-2, 2), Vector2i(-3, 0),
	]
	for i in range(ring.size()):
		var o: Vector2i = ring[i]
		_set_px(image, 5 + o.x, 5 + o.y, hot if i == frame * 2 else body)
	_set_px(image, 5, 5, hot)


func _draw_lysis(image: Image, frame: int) -> void:
	var stain := Color(0.56, 0.12, 0.09, 0.56)
	var hot := Color(1.0, 0.38, 0.16, 0.95)
	for i in range(10):
		var distance: int = 1 + frame + i % 3
		var x: int = clampi(5 + ((i * 7) % 5 - 2) * distance / 2, 0, SIZE - 1)
		var y: int = clampi(5 + ((i * 11) % 5 - 2) * distance / 2, 0, SIZE - 1)
		_set_px(image, x, y, hot if i % 3 == 0 else stain)
	_set_px(image, 5, 5, Color(0.92, 0.20, 0.12, 0.72))


func _draw_stress(image: Image, frame: int) -> void:
	var dim := Color(0.72, 0.34, 0.22, 0.44)
	var hot := Color(0.96, 0.54, 0.26, 0.74)
	var inward: int = frame % 2
	_set_px(image, 2 + inward, 5, hot)
	_set_px(image, 8 - inward, 5, hot)
	_set_px(image, 5, 2 + inward, dim)
	_set_px(image, 5, 8 - inward, dim)


func _draw_pursuit(image: Image, frame: int) -> void:
	var dim := Color(0.36, 0.72, 0.78, 0.48)
	var hot := Color(0.66, 0.96, 0.92, 0.88)
	var head_x: int = 7 + frame % 2
	_set_px(image, head_x, 5, hot)
	_set_px(image, head_x - 1, 4, hot)
	_set_px(image, head_x - 1, 6, hot)
	for i in range(4):
		_set_px(image, 5 - i, 5, dim)
		if i % 2 == frame % 2:
			_set_px(image, 5 - i, 6, Color(0.28, 0.58, 0.64, 0.34))


func _draw_digestion(image: Image, frame: int) -> void:
	var body := Color(0.74, 0.46, 0.24, 0.54)
	var hot := Color(1.0, 0.70, 0.30, 0.88)
	var inner := Color(0.90, 0.34, 0.18, 0.62)
	var ring := [
		Vector2i(-2, -1), Vector2i(-1, -2), Vector2i(1, -2),
		Vector2i(2, -1), Vector2i(2, 1), Vector2i(1, 2),
		Vector2i(-1, 2), Vector2i(-2, 1),
	]
	for i in range(ring.size()):
		var o: Vector2i = ring[i]
		var index: int = posmod(i + frame * 2, ring.size())
		_set_px(
			image,
			5 + o.x,
			5 + o.y,
			hot if index == 0 or index == 4 else body
		)
	_set_px(image, 5, 5, inner)
	_set_px(image, 5 + (frame % 2), 4, hot)


func _set_px(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or x >= SIZE or y < 0 or y >= SIZE:
		return
	image.set_pixel(x, y, color)
