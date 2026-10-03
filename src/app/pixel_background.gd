extends RefCounted

const TILE_SIZE := 32


func build_texture() -> Texture2D:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.006, 0.010, 0.012, 1.0))

	# Deliberate sparse pixel clusters. The texture repeats in screen space so
	# zooming/panning can never reveal Godot's default clear color.
	var dim := Color(0.012, 0.026, 0.026, 1.0)
	var soft := Color(0.016, 0.038, 0.034, 1.0)
	var speck := Color(0.026, 0.060, 0.050, 1.0)

	var clusters: Array[Vector2i] = [
		Vector2i(3, 5), Vector2i(4, 5), Vector2i(4, 6),
		Vector2i(14, 2), Vector2i(15, 2),
		Vector2i(24, 8), Vector2i(25, 8), Vector2i(25, 9),
		Vector2i(8, 18), Vector2i(9, 18),
		Vector2i(20, 22), Vector2i(20, 23), Vector2i(21, 23),
		Vector2i(29, 27), Vector2i(30, 27),
	]
	for point in clusters:
		image.set_pixel(point.x, point.y, dim)

	var soft_points: Array[Vector2i] = [
		Vector2i(1, 25), Vector2i(11, 11), Vector2i(17, 16),
		Vector2i(27, 3), Vector2i(6, 29), Vector2i(30, 14),
	]
	for point in soft_points:
		image.set_pixel(point.x, point.y, soft)

	var specks: Array[Vector2i] = [
		Vector2i(12, 27), Vector2i(23, 15), Vector2i(5, 12),
	]
	for point in specks:
		image.set_pixel(point.x, point.y, speck)

	return ImageTexture.create_from_image(image)
