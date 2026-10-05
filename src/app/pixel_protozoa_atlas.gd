extends RefCounted

const WIDTH := 24
const HEIGHT := 24
const FRAMES := 6
const STATES := 2

const STATE_SWIM := 0
const STATE_ENGULF := 1

var _textures: Array = []


func _init() -> void:
	_build()


func get_texture(frame: int, state: int) -> Texture2D:
	return _textures[clampi(state, 0, STATES - 1)][posmod(frame, FRAMES)]


func _build() -> void:
	_textures.clear()

	for state in range(STATES):
		var frames: Array = []
		for frame in range(FRAMES):
			var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
			image.fill(Color(0.0, 0.0, 0.0, 0.0))
			_draw_frame(image, frame, state)
			frames.append(ImageTexture.create_from_image(image))
		_textures.append(frames)


func _draw_frame(image: Image, frame: int, state: int) -> void:
	var outline := Color(0.12, 0.16, 0.20, 1.0)
	var body := Color(0.82, 0.89, 0.91, 1.0)
	var mid := Color(0.54, 0.65, 0.67, 1.0)
	var core := Color(0.25, 0.34, 0.39, 1.0)
	var glow := Color(0.94, 0.98, 0.91, 1.0)

	var cx: int = 12
	var cy: int = 12
	var left_push: int = int([0, 1, 2, 1, 0, -1][frame])
	var right_push: int = int([2, 1, 0, -1, 0, 1][frame])
	var top_push: int = int([0, -1, 0, 1, 2, 1][frame])
	var bottom_push: int = int([1, 2, 1, 0, -1, 0][frame])

	if state == STATE_ENGULF:
		right_push += 2 + (frame % 2)
		top_push += 1

	for y in range(HEIGHT):
		for x in range(WIDTH):
			var dx: float = float(x - cx)
			var dy: float = float(y - cy)

			var rx: float = 5.8
			var ry: float = 4.8

			if dx < 0.0:
				rx += float(left_push)
			else:
				rx += float(right_push)

			if dy < 0.0:
				ry += float(top_push) * 0.65
			else:
				ry += float(bottom_push) * 0.65

			var normalized: float = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry)
			if normalized > 1.16:
				continue

			if normalized > 0.82:
				image.set_pixel(x, y, outline)
			elif normalized > 0.48:
				image.set_pixel(x, y, body)
			else:
				image.set_pixel(x, y, mid)

	# Pseudopod clusters. They move around the silhouette instead of smooth
	# vector deformation, preserving deliberate pixel-art motion.
	var arms: Array[Vector2i] = [
		Vector2i(cx + 6 + right_push, cy - 1),
		Vector2i(cx - 5 - left_push, cy + 2),
		Vector2i(cx + 1, cy - 5 - top_push),
		Vector2i(cx - 2, cy + 5 + bottom_push),
	]
	for i in range(arms.size()):
		var p: Vector2i = arms[i]
		_set_px(image, p.x, p.y, outline)
		_set_px(image, p.x + (1 if i % 2 == 0 else -1), p.y, body)
		if i < 2:
			_set_px(image, p.x, p.y + (1 if frame % 2 == 0 else -1), mid)

	# Internal granules / vacuole-like inclusions for a eukaryotic protist.
	_set_px(image, cx - 2, cy - 1, core)
	_set_px(image, cx - 1, cy - 1, core)
	_set_px(image, cx - 2, cy, core)
	_set_px(image, cx + 2, cy + 1, glow)
	_set_px(image, cx + 3, cy + 1, glow)

	if state == STATE_ENGULF:
		# A dark food-vacuole opening that closes across frames.
		var mouth_x: int = cx + 4 + (frame % 2)
		_set_px(image, mouth_x, cy, outline)
		_set_px(image, mouth_x, cy + 1, outline)
		_set_px(image, mouth_x - 1, cy, core)


func _set_px(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return
	image.set_pixel(x, y, color)
