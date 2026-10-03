extends RefCounted

const TILE_SIZE := 4
const LEVELS := 4
const VARIANTS := 4
const FRAMES := 4
const KINDS := 7

const KIND_WATER := 0
const KIND_PRODUCER := 1
const KIND_DETRITUS := 2
const KIND_EPS := 3
const KIND_DAMAGE := 4
const KIND_OXYGEN := 5
const KIND_NUTRIENT := 6

var _tiles: Array = []


func _init() -> void:
	_build()


func get_tile_image(kind: int, level: int, variant: int, frame: int) -> Image:
	return _tiles[
		clampi(kind, 0, KINDS - 1)
	][
		clampi(level, 0, LEVELS - 1)
	][
		posmod(variant, VARIANTS)
	][
		posmod(frame, FRAMES)
	]


func classify(
	nutrient: float,
	oxygen: float,
	detritus: float,
	eps: float,
	damage: float,
	producer: float,
	waste: float
) -> PackedInt32Array:
	var scores := PackedFloat32Array([
		0.18,
		producer * 1.36,
		maxf(detritus, waste * 0.72) * 1.34,
		eps * 1.28,
		damage * 1.78 + detritus * 0.18,
		maxf(0.0, oxygen - 0.18) * 0.95,
		maxf(0.0, nutrient - 0.12) * 0.88,
	])

	var primary: int = KIND_WATER
	var secondary: int = KIND_WATER
	var primary_score: float = scores[0]
	var secondary_score: float = -1.0

	for kind in range(1, KINDS):
		var score: float = scores[kind]
		if score > primary_score:
			secondary = primary
			secondary_score = primary_score
			primary = kind
			primary_score = score
		elif score > secondary_score:
			secondary = kind
			secondary_score = score

	var primary_level: int = _score_level(primary_score)
	var secondary_level: int = _score_level(secondary_score)
	return PackedInt32Array([
		primary,
		primary_level,
		secondary,
		secondary_level,
	])


func accent_color(kind: int, level: int) -> Color:
	var t: float = float(clampi(level, 0, LEVELS - 1)) / 3.0
	match kind:
		KIND_PRODUCER:
			return Color(0.34, 0.76 + t * 0.20, 0.26, 0.84)
		KIND_DETRITUS:
			return Color(0.58 + t * 0.18, 0.34 + t * 0.08, 0.18, 0.82)
		KIND_EPS:
			return Color(0.20, 0.66 + t * 0.18, 0.60 + t * 0.12, 0.76)
		KIND_DAMAGE:
			return Color(0.92 + t * 0.08, 0.26 + t * 0.18, 0.14, 0.88)
		KIND_OXYGEN:
			return Color(0.30, 0.78 + t * 0.18, 0.94 + t * 0.06, 0.76)
		KIND_NUTRIENT:
			return Color(0.54 + t * 0.16, 0.68 + t * 0.16, 0.24, 0.70)
		_:
			return Color(0.18, 0.42, 0.44, 0.45)


func accent_offset(variant: int, frame: int) -> Vector2i:
	var x: int = posmod(variant + frame * 2, TILE_SIZE)
	var y: int = posmod(variant * 3 + frame, TILE_SIZE)
	return Vector2i(x, y)


func _score_level(score: float) -> int:
	if score < 0.28:
		return 0
	if score < 0.58:
		return 1
	if score < 0.92:
		return 2
	return 3


func _build() -> void:
	_tiles.clear()
	for kind in range(KINDS):
		var levels: Array = []
		for level in range(LEVELS):
			var variants: Array = []
			for variant in range(VARIANTS):
				var frames: Array = []
				for frame in range(FRAMES):
					var image := Image.create(
						TILE_SIZE,
						TILE_SIZE,
						false,
						Image.FORMAT_RGBA8
					)
					_draw_tile(image, kind, level, variant, frame)
					frames.append(image)
				variants.append(frames)
			levels.append(variants)
		_tiles.append(levels)


func _draw_tile(
	image: Image,
	kind: int,
	level: int,
	variant: int,
	frame: int
) -> void:
	_fill_water(image, variant, frame)
	match kind:
		KIND_PRODUCER:
			_draw_producer(image, level, variant, frame)
		KIND_DETRITUS:
			_draw_detritus(image, level, variant, frame)
		KIND_EPS:
			_draw_eps(image, level, variant, frame)
		KIND_DAMAGE:
			_draw_damage(image, level, variant, frame)
		KIND_OXYGEN:
			_draw_oxygen(image, level, variant, frame)
		KIND_NUTRIENT:
			_draw_nutrient(image, level, variant, frame)
		_:
			pass


func _fill_water(image: Image, variant: int, frame: int) -> void:
	var deep := Color(0.010, 0.060, 0.070, 1.0)
	var mid := Color(0.016, 0.090, 0.095, 1.0)
	var glint := Color(0.040, 0.145, 0.145, 1.0)
	image.fill(deep)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			if posmod(x * 7 + y * 11 + variant * 5, 13) == 0:
				image.set_pixel(x, y, mid)
	var gx: int = posmod(variant + frame, TILE_SIZE)
	var gy: int = posmod(variant * 2 + frame * 3, TILE_SIZE)
	image.set_pixel(gx, gy, glint)


func _draw_producer(image: Image, level: int, variant: int, frame: int) -> void:
	var dark := Color(0.055, 0.22, 0.11, 1.0)
	var body := Color(0.12, 0.46, 0.17, 1.0)
	var light := Color(0.26, 0.74, 0.24, 1.0)
	var hot := Color(0.46, 0.92, 0.30, 1.0)
	var count: int = 4 + level * 3
	for i in range(count):
		var x: int = posmod(i * 3 + variant + frame, TILE_SIZE)
		var y: int = posmod(i * 5 + variant * 2, TILE_SIZE)
		var color: Color = body
		if i % 4 == 0:
			color = dark
		elif i % 5 == 0 and level >= 2:
			color = hot
		elif i % 3 == 0:
			color = light
		image.set_pixel(x, y, color)
	if level >= 2:
		var cx: int = posmod(1 + variant, TILE_SIZE)
		var cy: int = posmod(2 + variant, TILE_SIZE)
		image.set_pixel(cx, cy, hot)
		image.set_pixel(posmod(cx + 1, TILE_SIZE), cy, light)


func _draw_detritus(image: Image, level: int, variant: int, frame: int) -> void:
	var dark := Color(0.20, 0.12, 0.07, 1.0)
	var body := Color(0.45, 0.27, 0.13, 1.0)
	var light := Color(0.72, 0.46, 0.20, 1.0)
	var count: int = 2 + level * 3
	for i in range(count):
		var x: int = posmod(i * 5 + variant * 3, TILE_SIZE)
		var y: int = posmod(i * 2 + frame + variant, TILE_SIZE)
		image.set_pixel(x, y, light if i % 4 == 0 else body)
		if level >= 2 and i % 3 == 0:
			image.set_pixel(posmod(x + 1, TILE_SIZE), y, dark)


func _draw_eps(image: Image, level: int, variant: int, frame: int) -> void:
	var dark := Color(0.05, 0.24, 0.22, 1.0)
	var body := Color(0.12, 0.50, 0.45, 1.0)
	var light := Color(0.24, 0.74, 0.62, 1.0)
	var row: int = posmod(variant + frame / 2, TILE_SIZE)
	var col: int = posmod(variant * 3 + 1, TILE_SIZE)
	for x in range(TILE_SIZE):
		if x % 2 == variant % 2 or level >= 2:
			image.set_pixel(x, row, body)
	for y in range(TILE_SIZE):
		if y % 2 == (variant + 1) % 2 or level >= 3:
			image.set_pixel(col, y, dark)
	image.set_pixel(col, row, light)
	if level >= 2:
		image.set_pixel(posmod(col + 1, TILE_SIZE), posmod(row + 1, TILE_SIZE), light)


func _draw_damage(image: Image, level: int, variant: int, frame: int) -> void:
	var stain := Color(0.24, 0.07, 0.08, 1.0)
	var body := Color(0.66, 0.15, 0.10, 1.0)
	var hot := Color(1.0, 0.42, 0.16, 1.0)
	var count: int = 2 + level * 3
	for i in range(count):
		var radius_step: int = i + frame
		var x: int = posmod(variant + radius_step * 3, TILE_SIZE)
		var y: int = posmod(variant * 2 + radius_step * 5, TILE_SIZE)
		image.set_pixel(x, y, hot if i % 3 == 0 else body)
		if level >= 2 and i % 2 == 0:
			image.set_pixel(posmod(x + 1, TILE_SIZE), y, stain)


func _draw_oxygen(image: Image, level: int, variant: int, frame: int) -> void:
	var body := Color(0.10, 0.34, 0.43, 1.0)
	var light := Color(0.22, 0.66, 0.78, 1.0)
	var hot := Color(0.50, 0.92, 0.96, 1.0)
	var count: int = 1 + level * 2
	for i in range(count):
		var x: int = posmod(i * 2 + variant + frame, TILE_SIZE)
		var y: int = posmod(i * 3 + variant * 2 - frame, TILE_SIZE)
		image.set_pixel(x, y, hot if i % 3 == 0 else light)
		if level >= 3 and i % 2 == 0:
			image.set_pixel(x, posmod(y + 1, TILE_SIZE), body)


func _draw_nutrient(image: Image, level: int, variant: int, frame: int) -> void:
	var body := Color(0.24, 0.36, 0.10, 1.0)
	var light := Color(0.50, 0.62, 0.17, 1.0)
	var hot := Color(0.72, 0.78, 0.28, 1.0)
	var count: int = 2 + level * 2
	for i in range(count):
		var x: int = posmod(i * 3 + variant * 2, TILE_SIZE)
		var y: int = posmod(i * 5 + frame + variant, TILE_SIZE)
		image.set_pixel(x, y, hot if level >= 3 and i % 3 == 0 else light)
		if i % 2 == 0:
			image.set_pixel(posmod(x + 1, TILE_SIZE), y, body)
