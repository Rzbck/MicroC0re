extends RefCounted

const SIZE := 7
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
	return _textures[clampi(kind, 0, KINDS - 1)][posmod(frame, FRAMES)]


func _build() -> void:
	_textures.clear()
	for kind in range(KINDS):
		var frames: Array = []
		for frame in range(FRAMES):
			var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
			image.fill(Color(0, 0, 0, 0))
			_draw(image, kind, frame)
			frames.append(ImageTexture.create_from_image(image))
		_textures.append(frames)


func _draw(image: Image, kind: int, frame: int) -> void:
	match kind:
		EFFECT_DIVISION:
			var gap: int = 1 if frame < 2 else 2
			_px(image, 3 - gap, 3, Color(0.78, 1.0, 0.54, 0.94))
			_px(image, 3 + gap, 3, Color(0.78, 1.0, 0.54, 0.94))
			_px(image, 3, 2, Color(0.40, 0.70, 0.32, 0.72))
			_px(image, 3, 4, Color(0.40, 0.70, 0.32, 0.72))
		EFFECT_ADHESION:
			var points := [Vector2i(1,2),Vector2i(2,1),Vector2i(4,1),Vector2i(5,2),Vector2i(5,4),Vector2i(4,5),Vector2i(2,5),Vector2i(1,4)]
			for i in range(points.size()):
				var p: Vector2i = points[i]
				_px(image,p.x,p.y,Color(0.38,0.92,0.72,0.80) if i == frame*2 else Color(0.18,0.68,0.56,0.55))
		EFFECT_REPRODUCTION:
			var points := [Vector2i(3,1),Vector2i(5,3),Vector2i(3,5),Vector2i(1,3)]
			for i in range(points.size()):
				var p: Vector2i = points[i]
				_px(image,p.x,p.y,Color(0.96,0.86,0.38,0.88) if i == frame else Color(0.72,0.90,0.38,0.62))
		EFFECT_FEEDING:
			var ring := [Vector2i(2,1),Vector2i(4,1),Vector2i(5,3),Vector2i(4,5),Vector2i(2,5),Vector2i(1,3)]
			for i in range(ring.size()):
				var p: Vector2i = ring[i]
				_px(image,p.x,p.y,Color(1.0,0.70,0.30,0.92) if i == posmod(frame+1,ring.size()) else Color(0.82,0.38,0.22,0.60))
			_px(image,3,3,Color(1.0,0.70,0.30,0.92))
		EFFECT_LYSIS:
			var spread: int = 1 + floori(float(frame) / 2.0)
			_px(image,3,3,Color(0.60,0.11,0.08,0.58))
			_px(image,3-spread,2,Color(1.0,0.34,0.14,0.90))
			_px(image,3+spread,4,Color(1.0,0.34,0.14,0.90))
			_px(image,2,3+spread,Color(0.60,0.11,0.08,0.58))
			_px(image,4,3-spread,Color(0.60,0.11,0.08,0.58))
		EFFECT_STRESS:
			var inward: int = frame % 2
			var c := Color(0.80,0.38,0.21,0.54)
			_px(image,1+inward,3,c); _px(image,5-inward,3,c); _px(image,3,1+inward,c); _px(image,3,5-inward,c)
		EFFECT_PURSUIT:
			_px(image,5,3,Color(0.62,0.90,0.88,0.78)); _px(image,4,2,Color(0.62,0.90,0.88,0.78)); _px(image,4,4,Color(0.62,0.90,0.88,0.78))
			for i in range(3):
				_px(image,3-i,3+posmod(i+frame,2),Color(0.34,0.66,0.72,0.42))
		EFFECT_DIGESTION:
			var points := [Vector2i(2,2),Vector2i(4,2),Vector2i(4,4),Vector2i(2,4)]
			for i in range(points.size()):
				var p: Vector2i = points[i]
				_px(image,p.x,p.y,Color(0.96,0.66,0.28,0.82) if i == frame else Color(0.70,0.42,0.22,0.48))
			_px(image,3,3,Color(0.86,0.28,0.15,0.58))


func _px(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < SIZE and y >= 0 and y < SIZE:
		image.set_pixel(x, y, color)
