extends RefCounted

# Code-authored low-resolution sprite atlas.
# Every organism is rendered from cached pixel textures; no procedural lines,
# circles, flagella polylines, or smooth capsule geometry are drawn per frame.

const SPRITE_WIDTH := 32
const SPRITE_HEIGHT := 20
const FRAME_COUNT := 4
const SIZE_CLASSES := 3
const APPENDAGE_CLASSES := 3

const STATE_NORMAL := 0
const STATE_DIVIDING := 1
const STATE_LYSIS := 2
const STATE_COUNT := 3

var _textures: Array = []


func _init() -> void:
	_build_atlas()


func get_texture(
	size_class: int,
	appendage_class: int,
	frame: int,
	state: int
) -> Texture2D:
	var safe_state: int = clampi(state, 0, STATE_COUNT - 1)
	var safe_size: int = clampi(size_class, 0, SIZE_CLASSES - 1)
	var safe_appendages: int = clampi(appendage_class, 0, APPENDAGE_CLASSES - 1)
	var safe_frame: int = posmod(frame, FRAME_COUNT)
	return _textures[safe_state][safe_size][safe_appendages][safe_frame]


func _build_atlas() -> void:
	_textures.clear()

	for state in range(STATE_COUNT):
		var state_textures: Array = []

		for size_class in range(SIZE_CLASSES):
			var size_textures: Array = []

			for appendage_class in range(APPENDAGE_CLASSES):
				var frames: Array = []

				for frame in range(FRAME_COUNT):
					var image := Image.create(
						SPRITE_WIDTH,
						SPRITE_HEIGHT,
						false,
						Image.FORMAT_RGBA8
					)
					image.fill(Color(0.0, 0.0, 0.0, 0.0))
					_draw_microbe(
						image,
						size_class,
						appendage_class,
						frame,
						state
					)

					var texture := ImageTexture.create_from_image(image)
					frames.append(texture)

				size_textures.append(frames)

			state_textures.append(size_textures)

		_textures.append(state_textures)


func _draw_microbe(
	image: Image,
	size_class: int,
	appendage_class: int,
	frame: int,
	state: int
) -> void:
	var center_x: int = 18
	var center_y: int = 10
	var body_length: int = int([9, 12, 15][size_class])
	var left: int = center_x - floori(float(body_length) / 2.0)
	var right: int = center_x + floori(float(body_length) / 2.0)

	var outline := Color(0.15, 0.17, 0.19, 1.0)
	var body := Color(0.88, 0.90, 0.91, 1.0)
	var light := Color(1.0, 1.0, 1.0, 1.0)
	var mid := Color(0.58, 0.62, 0.64, 1.0)
	var dark := Color(0.31, 0.35, 0.37, 1.0)
	var appendage := Color(0.48, 0.54, 0.56, 1.0)

	# Flagella and pili live behind the cell body.
	_draw_flagella(
		image,
		left - 1,
		center_y,
		appendage_class,
		frame,
		appendage
	)
	_draw_pili(
		image,
		left,
		right,
		center_y,
		appendage_class,
		frame,
		appendage
	)

	if state == STATE_DIVIDING:
		_draw_dividing_body(
			image,
			left,
			right,
			center_y,
			outline,
			body,
			light,
			mid,
			dark
		)
	elif state == STATE_LYSIS:
		_draw_lysing_body(
			image,
			left,
			right,
			center_y,
			frame,
			outline,
			body,
			light,
			mid
		)
	else:
		_draw_body(
			image,
			left,
			right,
			center_y,
			outline,
			body,
			light,
			mid,
			dark
		)


func _draw_body(
	image: Image,
	left: int,
	right: int,
	center_y: int,
	outline: Color,
	body: Color,
	light: Color,
	mid: Color,
	dark: Color
) -> void:
	# Deliberate chunky capsule silhouette.
	_hline(image, left + 1, right - 1, center_y - 3, outline)
	_hline(image, left, right, center_y - 2, outline)
	_hline(image, left - 1, right + 1, center_y - 1, outline)
	_hline(image, left - 1, right + 1, center_y, outline)
	_hline(image, left - 1, right + 1, center_y + 1, outline)
	_hline(image, left, right, center_y + 2, outline)
	_hline(image, left + 1, right - 1, center_y + 3, outline)

	_hline(image, left + 1, right - 1, center_y - 2, body)
	_hline(image, left, right, center_y - 1, body)
	_hline(image, left, right, center_y, body)
	_hline(image, left, right, center_y + 1, mid)
	_hline(image, left + 1, right - 1, center_y + 2, dark)

	# Intentional highlight cluster.
	_hline(image, left + 2, right - 3, center_y - 1, light)
	_set_px(image, left + 1, center_y, mid)

	# Nucleoid-like broken cluster: not a membrane-bound organelle.
	var span: int = maxi(2, right - left - 5)
	for offset in range(0, span, 3):
		_set_px(image, left + 3 + offset, center_y, dark)
		if offset % 2 == 0:
			_set_px(image, left + 4 + offset, center_y + 1, dark)


func _draw_dividing_body(
	image: Image,
	left: int,
	right: int,
	center_y: int,
	outline: Color,
	body: Color,
	light: Color,
	mid: Color,
	dark: Color
) -> void:
	_draw_body(
		image,
		left,
		right,
		center_y,
		outline,
		body,
		light,
		mid,
		dark
	)

	var center_x: int = floori(float(left + right) / 2.0)

	# Visible septum / constriction.
	for y in range(center_y - 2, center_y + 3):
		_set_px(image, center_x, y, outline)

	_set_px(image, center_x - 1, center_y - 2, dark)
	_set_px(image, center_x + 1, center_y + 2, dark)
	_set_px(image, center_x - 1, center_y, light)
	_set_px(image, center_x + 1, center_y, light)


func _draw_lysing_body(
	image: Image,
	left: int,
	right: int,
	center_y: int,
	frame: int,
	outline: Color,
	body: Color,
	light: Color,
	mid: Color
) -> void:
	_draw_body(
		image,
		left,
		right,
		center_y,
		outline,
		body,
		light,
		mid,
		outline
	)

	# Staged pixel breakup. Holes increase with the animation frame.
	for y in range(center_y - 2, center_y + 3):
		for x in range(left, right + 1):
			var key: int = posmod(x * 3 + y * 5 + frame * 7, 11)
			var threshold: int = 1 + frame
			if key < threshold:
				_set_px(image, x, y, Color(0.0, 0.0, 0.0, 0.0))

	# A few detached fragments.
	_set_px(image, right + 3 + frame, center_y - 2, mid)
	_set_px(image, right + 1 + frame, center_y + 3, light)
	_set_px(image, left - 2 - frame, center_y + 2, outline)


func _draw_flagella(
	image: Image,
	start_x: int,
	center_y: int,
	appendage_class: int,
	frame: int,
	color: Color
) -> void:
	var count: int = appendage_class + 1
	var phase_table: Array = [
		[0, -1, -1, 0, 1, 1, 0, -1, -1],
		[0, 1, 1, 0, -1, -1, 0, 1, 1],
		[0, -1, 0, 1, 1, 0, -1, -1, 0],
		[0, 1, 0, -1, -1, 0, 1, 1, 0],
	]
	var wave: Array = phase_table[frame]

	for tail in range(count):
		var y_bias: int = tail - floori(float(count - 1) / 2.0)
		for step in range(9):
			var x: int = start_x - step
			var y: int = center_y + int(wave[step]) + y_bias * 2
			_set_px(image, x, y, color)

			# Small connected clusters avoid single-pixel visual noise.
			if step in [2, 5, 8]:
				_set_px(image, x, y + (1 if tail % 2 == 0 else -1), color)


func _draw_pili(
	image: Image,
	left: int,
	right: int,
	center_y: int,
	appendage_class: int,
	frame: int,
	color: Color
) -> void:
	var anchors: Array = [
		left + 1,
		floori(float(left + right) / 2.0),
		right - 1,
	]

	var count: int = appendage_class + 1
	for i in range(count):
		var x: int = int(anchors[i])
		var shift: int = 1 if posmod(frame + i, 2) == 0 else 0
		_set_px(image, x, center_y - 4 - shift, color)
		_set_px(image, x + 1, center_y - 5 - shift, color)
		_set_px(image, x, center_y + 4 + shift, color)
		_set_px(image, x - 1, center_y + 5 + shift, color)


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
	if x < 0 or x >= SPRITE_WIDTH or y < 0 or y >= SPRITE_HEIGHT:
		return
	image.set_pixel(x, y, color)
