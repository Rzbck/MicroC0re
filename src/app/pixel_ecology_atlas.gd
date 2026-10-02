extends RefCounted

const WIDTH := 24
const HEIGHT := 20
const FRAMES := 4
const KINDS := 2
const STATES := 3

const KIND_ALGA := 0
const KIND_YEAST := 1

const STATE_NORMAL := 0
const STATE_REPRODUCING := 1
const STATE_LYSIS := 2

var _textures: Array = []


func _init() -> void:
	_build()


func get_texture(kind: int, state: int, frame: int) -> Texture2D:
	return _textures[
		clampi(kind, 0, KINDS - 1)
	][
		clampi(state, 0, STATES - 1)
	][
		posmod(frame, FRAMES)
	]


func _build() -> void:
	_textures.clear()

	for kind in range(KINDS):
		var kind_textures: Array = []

		for state in range(STATES):
			var frames: Array = []

			for frame in range(FRAMES):
				var image := Image.create(
					WIDTH,
					HEIGHT,
					false,
					Image.FORMAT_RGBA8
				)
				image.fill(Color(0.0, 0.0, 0.0, 0.0))

				if kind == KIND_ALGA:
					_draw_alga(image, state, frame)
				else:
					_draw_yeast(image, state, frame)

				frames.append(ImageTexture.create_from_image(image))

			kind_textures.append(frames)

		_textures.append(kind_textures)


func _draw_alga(image: Image, state: int, frame: int) -> void:
	var outline := Color(0.10, 0.24, 0.17, 1.0)
	var body := Color(0.38, 0.88, 0.38, 1.0)
	var light := Color(0.70, 1.0, 0.52, 1.0)
	var chloroplast := Color(0.16, 0.52, 0.28, 1.0)
	var core := Color(0.25, 0.68, 0.48, 1.0)

	var cx: int = 12
	var cy: int = 10
	var pulse: int = [0, 1, 0, -1][frame]

	# Faceted single-cell microalga: deliberate pixels, not a smooth circle.
	_hline(image, cx - 2, cx + 2, cy - 5, outline)
	_hline(image, cx - 4, cx + 4, cy - 4, outline)
	_hline(image, cx - 5, cx + 5, cy - 2, outline)
	_hline(image, cx - 6, cx + 6, cy, outline)
	_hline(image, cx - 5, cx + 5, cy + 2, outline)
	_hline(image, cx - 4, cx + 4, cy + 4, outline)
	_hline(image, cx - 2, cx + 2, cy + 5, outline)

	for y in range(cy - 4, cy + 5):
		var half: int = 4
		if abs(y - cy) <= 2:
			half = 5
		_hline(image, cx - half, cx + half, y, body)

	_hline(image, cx - 2, cx + 2, cy - 3, light)
	_set_px(image, cx - 3, cy - 2, light)
	_set_px(image, cx - 2, cy + 1, chloroplast)
	_set_px(image, cx + 2, cy - 1, chloroplast)
	_set_px(image, cx + 3, cy + 2, chloroplast)
	_set_px(image, cx, cy + 2, core)

	# Tiny frame-authored flagellar pair / drift cue.
	_set_px(image, cx + 6, cy - 1, core)
	_set_px(image, cx + 7, cy - 2 + pulse, core)
	_set_px(image, cx + 8, cy - 1 + pulse, core)
	_set_px(image, cx + 6, cy + 1, core)
	_set_px(image, cx + 7, cy + 2 - pulse, core)
	_set_px(image, cx + 8, cy + 1 - pulse, core)

	if state == STATE_REPRODUCING:
		for y in range(cy - 4, cy + 5):
			_set_px(image, cx, y, outline)
		_set_px(image, cx - 1, cy, light)
		_set_px(image, cx + 1, cy, light)
	elif state == STATE_LYSIS:
		_overlay_lysis(image, frame, cx, cy, outline, light)


func _draw_yeast(image: Image, state: int, frame: int) -> void:
	var outline := Color(0.24, 0.16, 0.10, 1.0)
	var body := Color(0.94, 0.68, 0.34, 1.0)
	var light := Color(1.0, 0.88, 0.58, 1.0)
	var dark := Color(0.55, 0.31, 0.17, 1.0)
	var vacuole := Color(0.78, 0.48, 0.26, 1.0)

	var cx: int = 11
	var cy: int = 10
	var wobble: int = [0, 0, 1, -1][frame]

	_draw_yeast_cell(
		image,
		cx,
		cy,
		5,
		outline,
		body,
		light,
		dark,
		vacuole
	)

	if state == STATE_REPRODUCING:
		var bud_size: int = 2 + floori(float(frame) / 2.0)
		_draw_yeast_cell(
			image,
			cx + 6,
			cy - 3 + wobble,
			bud_size,
			outline,
			body,
			light,
			dark,
			vacuole
		)
	elif state == STATE_NORMAL:
		_set_px(image, cx + 5, cy - 2 + wobble, outline)
		_set_px(image, cx + 6, cy - 2 + wobble, body)
	elif state == STATE_LYSIS:
		_overlay_lysis(image, frame, cx, cy, outline, light)


func _draw_yeast_cell(
	image: Image,
	cx: int,
	cy: int,
	radius: int,
	outline: Color,
	body: Color,
	light: Color,
	dark: Color,
	vacuole: Color
) -> void:
	var r2: int = radius * radius
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			var dx: int = x - cx
			var dy: int = y - cy
			var d2: int = dx * dx + dy * dy
			if d2 > r2:
				continue
			var edge: bool = d2 >= maxi(0, r2 - radius * 2)
			_set_px(image, x, y, outline if edge else body)

	_set_px(image, cx - 2, cy - 2, light)
	_set_px(image, cx - 1, cy - 2, light)
	_set_px(image, cx + 1, cy + 1, vacuole)
	_set_px(image, cx + 2, cy + 1, vacuole)
	_set_px(image, cx - 1, cy + 2, dark)


func _overlay_lysis(
	image: Image,
	frame: int,
	cx: int,
	cy: int,
	outline: Color,
	light: Color
) -> void:
	for y in range(cy - 6, cy + 7):
		for x in range(cx - 7, cx + 8):
			var key: int = posmod(x * 7 + y * 5 + frame * 9, 19)
			if key < 1 + frame:
				_set_px(image, x, y, Color(0.0, 0.0, 0.0, 0.0))

	_set_px(image, cx + 7 + frame, cy - 2, light)
	_set_px(image, cx - 6 - frame, cy + 3, outline)


func _hline(
	image: Image,
	x0: int,
	x1: int,
	y: int,
	color: Color
) -> void:
	for x in range(x0, x1 + 1):
		_set_px(image, x, y, color)


func _set_px(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return
	image.set_pixel(x, y, color)
