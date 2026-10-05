extends RefCounted

const WIDTH := 14
const HEIGHT := 9
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
			image.fill(Color(0, 0, 0, 0))
			_draw_frame(image, frame, state)
			frames.append(ImageTexture.create_from_image(image))
		_textures.append(frames)


func _draw_frame(image: Image, frame: int, state: int) -> void:
	var outline := Color(0.16, 0.13, 0.08, 1.0)
	var body := Color(0.84, 0.72, 0.28, 1.0)
	var mid := Color(0.64, 0.48, 0.18, 1.0)
	var light := Color(1.0, 0.91, 0.48, 1.0)
	var core := Color(0.36, 0.25, 0.10, 1.0)
	var flagellum := Color(0.92, 0.79, 0.36, 1.0)

	var cx := 7
	var cy := 4
	for y in range(1, 8):
		for x in range(4, 11):
			var dx := float(x - cx)
			var dy := float(y - cy)
			var n := (dx * dx) / 10.5 + (dy * dy) / 5.2
			if n > 1.12:
				continue
			if n > 0.78:
				image.set_pixel(x, y, outline)
			elif n > 0.38:
				image.set_pixel(x, y, body)
			else:
				image.set_pixel(x, y, mid)

	_set_px(image, 7, 3, light)
	_set_px(image, 6, 4, core)
	if state == STATE_FEED:
		_set_px(image, 10, 4, core)
		_set_px(image, 11, 4, outline)

	# One frame-authored trailing flagellum: same source-pixel scale as every
	# other organism, but a distinct propulsion silhouette.
	var wave: Array[int] = [0, 1, 1, 0, -1, -1]
	var tail_y: int = cy + wave[frame]
	for d in range(4):
		var x: int = 3 - d
		var y: int = tail_y + (wave[posmod(frame + d, FRAMES)] / 2)
		_set_px(image, x, y, flagellum)


func _set_px(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
		image.set_pixel(x, y, color)
