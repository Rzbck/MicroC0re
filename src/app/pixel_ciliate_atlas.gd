extends RefCounted

const WIDTH := 26
const HEIGHT := 16
const FRAMES := 6
const STATES := 2

const STATE_SWIM := 0
const STATE_FEED := 1

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
	var outline := Color(0.13, 0.14, 0.22, 1.0)
	var body := Color(0.72, 0.77, 0.97, 1.0)
	var mid := Color(0.43, 0.51, 0.82, 1.0)
	var light := Color(0.92, 0.94, 1.0, 1.0)
	var core := Color(0.27, 0.31, 0.58, 1.0)
	var cilia := Color(0.57, 0.65, 0.97, 1.0)

	var cx: int = 13
	var cy: int = 8

	# Intentional elongated ciliate silhouette.
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var dx: float = float(x - cx)
			var dy: float = float(y - cy)
			var rx: float = 8.0
			var ry: float = 4.2
			var normalized: float = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry)

			if normalized > 1.10:
				continue
			if normalized > 0.82:
				image.set_pixel(x, y, outline)
			elif normalized > 0.48:
				image.set_pixel(x, y, body)
			else:
				image.set_pixel(x, y, mid)

	# Oral groove / feeding side.
	for i in range(4):
		_set_px(image, cx + 2 + i, cy + 1, core)
	if state == STATE_FEED:
		_set_px(image, cx + 6, cy, outline)
		_set_px(image, cx + 7, cy, outline)
		_set_px(image, cx + 6, cy + 1, core)

	# Internal vacuole / nucleus-like clusters.
	_set_px(image, cx - 3, cy - 1, core)
	_set_px(image, cx - 2, cy - 1, core)
	_set_px(image, cx - 2, cy, core)
	_set_px(image, cx + 1, cy - 1, light)

	# Cilia are frame-authored clusters, not procedural antialiased lines.
	for x in range(5, 22, 2):
		var phase: int = posmod(frame + x, 3)
		var top_len: int = 1 + (1 if phase == 0 else 0)
		var bottom_len: int = 1 + (1 if phase == 1 else 0)

		for d in range(top_len):
			_set_px(image, x, 2 - d, cilia)
		for d in range(bottom_len):
			_set_px(image, x, 13 + d, cilia)

	# Rear ciliary tuft gives a readable propulsion direction.
	var tail_wave: Array[int] = [0, 1, 1, 0, -1, -1]
	var tail_y: int = cy + tail_wave[frame]
	for d in range(4):
		_set_px(image, 3 - d, tail_y + (d % 2), cilia)


func _set_px(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return
	image.set_pixel(x, y, color)
