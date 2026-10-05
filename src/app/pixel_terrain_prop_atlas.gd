extends RefCounted

# Authored pixel-art props for the living terrain.
# These are deliberately larger, readable silhouettes rather than one/two-pixel
# biome markers. They remain code-authored so the simulation has no external
# asset dependency and can deterministically select variants by terrain cell.

const WIDTH := 24
const HEIGHT := 24
const VARIANTS := 4
const SEASONS := 4

const PROP_GRASS := 0
const PROP_SHRUB := 1
const PROP_TREE := 2
const PROP_ROCK := 3
const PROP_MARSH := 4
const PROP_SAND := 5
const PROP_CRAG := 6
const PROP_RIDGE := 7
const PROP_COUNT := 8

var _textures: Array = []


func _init() -> void:
	_build()


func get_texture(kind: int, variant: int, season: int) -> Texture2D:
	return _textures[
		clampi(kind, 0, PROP_COUNT - 1)
	][
		posmod(variant, VARIANTS)
	][
		posmod(season, SEASONS)
	]


func _build() -> void:
	_textures.clear()
	for kind in range(PROP_COUNT):
		var kind_textures: Array = []
		for variant in range(VARIANTS):
			var season_textures: Array = []
			for season in range(SEASONS):
				var image := Image.create(
					WIDTH,
					HEIGHT,
					false,
					Image.FORMAT_RGBA8
				)
				image.fill(Color(0.0, 0.0, 0.0, 0.0))
				_draw_prop(image, kind, variant, season)
				season_textures.append(ImageTexture.create_from_image(image))
			kind_textures.append(season_textures)
		_textures.append(kind_textures)


func _draw_prop(image: Image, kind: int, variant: int, season: int) -> void:
	match kind:
		PROP_GRASS:
			_draw_grass(image, variant, season)
		PROP_SHRUB:
			_draw_shrub(image, variant, season)
		PROP_TREE:
			_draw_tree(image, variant, season)
		PROP_ROCK:
			_draw_rock(image, variant, season)
		PROP_MARSH:
			_draw_marsh(image, variant, season)
		PROP_SAND:
			_draw_sand(image, variant)
		PROP_CRAG:
			_draw_crag(image, variant, season)
		PROP_RIDGE:
			_draw_ridge(image, variant, season)


func _leaf_palette(season: int) -> Array:
	match season:
		0:
			return [
				Color(0.12, 0.28, 0.12),
				Color(0.22, 0.48, 0.18),
				Color(0.40, 0.68, 0.26),
				Color(0.56, 0.78, 0.34),
			]
		1:
			return [
				Color(0.10, 0.26, 0.11),
				Color(0.18, 0.42, 0.16),
				Color(0.30, 0.58, 0.22),
				Color(0.44, 0.68, 0.28),
			]
		2:
			return [
				Color(0.26, 0.18, 0.08),
				Color(0.50, 0.28, 0.10),
				Color(0.72, 0.42, 0.12),
				Color(0.82, 0.58, 0.20),
			]
		_:
			return [
				Color(0.12, 0.18, 0.15),
				Color(0.22, 0.30, 0.24),
				Color(0.34, 0.42, 0.34),
				Color(0.48, 0.54, 0.45),
			]


func _draw_grass(image: Image, variant: int, season: int) -> void:
	var p: Array = _leaf_palette(season)
	var base_y: int = 20
	_rect(image, 6, 20, 18, 21, Color(0.04, 0.08, 0.055, 0.38))
	var offsets := [-5, -3, -1, 1, 3, 5]
	for i in range(offsets.size()):
		var x: int = 12 + int(offsets[i])
		var height: int = 3 + posmod(i * 3 + variant * 5, 5)
		var lean: int = -1 if posmod(i + variant, 2) == 0 else 1
		_vline(image, x, base_y - height, base_y, p[1])
		if height >= 5:
			_set_px(image, x + lean, base_y - height + 1, p[2])
			_set_px(image, x + lean * 2, base_y - height, p[3])
	_set_px(image, 10 + variant, 19, p[3])
	_set_px(image, 14 - variant / 2, 18, p[2])


func _draw_shrub(image: Image, variant: int, season: int) -> void:
	var p: Array = _leaf_palette(season)
	_rect(image, 5, 20, 19, 21, Color(0.03, 0.05, 0.035, 0.42))
	_rect(image, 11, 14, 12, 20, Color(0.28, 0.17, 0.08))
	_draw_leaf_blob(image, 8 + variant % 2, 15, 5, 4, p)
	_draw_leaf_blob(image, 15 - variant % 2, 14, 5, 5, p)
	_draw_leaf_blob(image, 12, 11 + variant % 2, 5, 5, p)
	_set_px(image, 7, 15, p[3])
	_set_px(image, 16, 12, p[3])
	_set_px(image, 11, 9 + variant % 2, p[2])


func _draw_tree(image: Image, variant: int, season: int) -> void:
	var p: Array = _leaf_palette(season)
	_rect(image, 6, 21, 19, 22, Color(0.025, 0.04, 0.03, 0.44))
	var trunk_x: int = 11 + (variant % 2)
	_rect(image, trunk_x - 1, 11, trunk_x + 1, 21, Color(0.28, 0.16, 0.075))
	_vline(image, trunk_x, 10, 19, Color(0.48, 0.28, 0.12))
	_hline(image, trunk_x - 4, trunk_x, 15, Color(0.34, 0.20, 0.09))
	_hline(image, trunk_x, trunk_x + 4, 13, Color(0.34, 0.20, 0.09))

	if season == 3:
		# Winter exposes the branching silhouette instead of swapping to a grey blob.
		_vline(image, trunk_x - 3, 8, 15, Color(0.30, 0.24, 0.16))
		_vline(image, trunk_x + 3, 7, 13, Color(0.30, 0.24, 0.16))
		_hline(image, trunk_x - 6, trunk_x - 2, 9, Color(0.34, 0.29, 0.20))
		_hline(image, trunk_x + 2, trunk_x + 6, 8, Color(0.34, 0.29, 0.20))
		for q in [[7,7],[10,5],[14,6],[17,9],[8,12],[16,12]]:
			_rect(image, int(q[0]), int(q[1]), int(q[0])+1, int(q[1])+1, p[2])
		return

	_draw_leaf_blob(image, 8 + variant % 2, 9, 5, 5, p)
	_draw_leaf_blob(image, 15 - variant % 2, 8, 5, 5, p)
	_draw_leaf_blob(image, 12, 5 + variant % 2, 6, 5, p)
	_draw_leaf_blob(image, 12, 11, 7, 4, p)
	_set_px(image, 8, 6, p[3])
	_set_px(image, 13, 3 + variant % 2, p[3])
	_set_px(image, 17, 8, p[3])


func _draw_rock(image: Image, variant: int, season: int) -> void:
	var dark := Color(0.18, 0.22, 0.21)
	var body := Color(0.36, 0.41, 0.39)
	var mid := Color(0.48, 0.53, 0.50)
	var light := Color(0.62, 0.66, 0.61)
	if season == 3:
		light = Color(0.70, 0.74, 0.70)
	_rect(image, 6, 20, 19, 21, Color(0.025, 0.035, 0.034, 0.40))
	_hline(image, 7, 17, 18, dark)
	_hline(image, 6, 18, 17, dark)
	_hline(image, 7, 19, 16, body)
	_hline(image, 8, 18, 15, body)
	_hline(image, 9, 17, 14, body)
	_hline(image, 10, 16, 13 - variant % 2, mid)
	_hline(image, 11, 15, 12 - variant % 2, mid)
	_set_px(image, 11, 13, light)
	_set_px(image, 12, 13, light)
	_set_px(image, 16, 16, dark)
	_set_px(image, 8, 17, light)


func _draw_marsh(image: Image, variant: int, season: int) -> void:
	var p: Array = _leaf_palette(season)
	_rect(image, 4, 20, 20, 22, Color(0.06, 0.18, 0.18, 0.70))
	_hline(image, 6, 18, 19, Color(0.12, 0.34, 0.30, 0.78))
	_hline(image, 9, 15, 21, Color(0.26, 0.50, 0.45, 0.82))
	var reed_x := [6, 9, 12, 15, 18]
	for i in range(reed_x.size()):
		var x: int = int(reed_x[i]) + (1 if posmod(i + variant, 3) == 0 else 0)
		var h: int = 6 + posmod(i * 5 + variant * 3, 7)
		_vline(image, x, 20 - h, 20, p[1])
		_set_px(image, x + (1 if i % 2 == 0 else -1), 21 - h, p[2])
		if h >= 9:
			_rect(image, x - 1, 20 - h, x, 22 - h, Color(0.44, 0.27, 0.10))
	_set_px(image, 5, 19, p[3])
	_set_px(image, 19, 18, p[2])


func _draw_sand(image: Image, variant: int) -> void:
	var shadow := Color(0.24, 0.17, 0.08, 0.30)
	var dark := Color(0.50, 0.36, 0.17)
	var body := Color(0.68, 0.52, 0.27)
	var light := Color(0.82, 0.67, 0.38)
	_hline(image, 4, 20, 21, shadow)
	_hline(image, 3, 18, 20, dark)
	_hline(image, 5, 21, 19, body)
	_hline(image, 4 + variant % 2, 18, 18, body)
	_hline(image, 7, 20 - variant % 3, 17, light)
	_hline(image, 9, 15, 16, light)
	_set_px(image, 6, 17, dark)
	_set_px(image, 18, 18, dark)
	_set_px(image, 16, 16, body)


func _draw_crag(image: Image, variant: int, season: int) -> void:
	var outline := Color(0.13, 0.16, 0.16)
	var dark := Color(0.25, 0.29, 0.28)
	var body := Color(0.38, 0.43, 0.41)
	var light := Color(0.54, 0.58, 0.54)
	if season == 3:
		light = Color(0.64, 0.68, 0.65)
	_rect(image, 3, 21, 21, 22, Color(0.02, 0.03, 0.03, 0.46))
	_hline(image, 5, 20, 20, outline)
	_hline(image, 4, 19, 19, dark)
	_hline(image, 6, 20, 18, dark)
	_hline(image, 6, 18, 17, body)
	_hline(image, 8, 19, 16, body)
	_hline(image, 7, 17, 15, dark)
	_hline(image, 9, 18, 14, body)
	_hline(image, 10, 17, 13, body)
	_hline(image, 9 + variant % 2, 15, 12, light)
	_hline(image, 11, 16, 11, body)
	_hline(image, 12, 15, 10 - variant % 2, light)
	_vline(image, 8, 16, 19, outline)
	_vline(image, 16, 12, 18, outline)
	_set_px(image, 7, 17, light)
	_set_px(image, 17, 15, dark)


func _draw_ridge(image: Image, variant: int, season: int) -> void:
	var outline := Color(0.10, 0.13, 0.14)
	var left := Color(0.28, 0.33, 0.34)
	var right := Color(0.20, 0.25, 0.27)
	var face := Color(0.40, 0.45, 0.44)
	var highlight := Color(0.58, 0.62, 0.58)
	_rect(image, 2, 21, 22, 22, Color(0.02, 0.025, 0.03, 0.48))
	var peak_x: int = 11 + (variant - 1)
	for y in range(5, 21):
		var spread: int = int((y - 4) * 0.62)
		var x0: int = maxi(2, peak_x - spread)
		var x1: int = mini(22, peak_x + spread)
		_hline(image, x0, x1, y, outline)
		if x1 - x0 >= 2:
			_hline(image, x0 + 1, peak_x, y, left)
			_hline(image, peak_x + 1, x1 - 1, y, right)
	for y in range(7, 19, 3):
		var ledge: int = 2 + posmod(y + variant, 4)
		_hline(image, peak_x - ledge, peak_x, y, face)
	_set_px(image, peak_x - 1, 6, highlight)
	_set_px(image, peak_x, 6, highlight)
	_set_px(image, peak_x - 2, 8, highlight)
	if season == 3:
		_hline(image, peak_x - 2, peak_x + 2, 7, Color(0.72, 0.76, 0.72))
		_hline(image, peak_x - 3, peak_x + 1, 8, Color(0.62, 0.68, 0.66))


func _draw_leaf_blob(
	image: Image,
	cx: int,
	cy: int,
	rx: int,
	ry: int,
	palette: Array
) -> void:
	for y in range(cy - ry, cy + ry + 1):
		var ny: float = absf(float(y - cy)) / float(maxi(1, ry))
		var half: int = maxi(1, roundi(float(rx) * (1.0 - ny * 0.56)))
		_hline(image, cx - half, cx + half, y, palette[0])
		if half >= 2:
			_hline(image, cx - half + 1, cx + half - 1, y, palette[1])
		if y <= cy and half >= 3:
			_hline(image, cx - half + 2, cx, y, palette[2])
	_set_px(image, cx - 1, cy - ry + 1, palette[3])


func _rect(image: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_set_px(image, x, y, color)


func _hline(image: Image, x0: int, x1: int, y: int, color: Color) -> void:
	for x in range(x0, x1 + 1):
		_set_px(image, x, y, color)


func _vline(image: Image, x: int, y0: int, y1: int, color: Color) -> void:
	for y in range(y0, y1 + 1):
		_set_px(image, x, y, color)


func _set_px(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return
	image.set_pixel(x, y, color)
