class_name GameCursor
extends RefCounted
## Curseurs contextuels, dessinés par code (32 × 32, contour sombre) :
## tir sur un ennemi, attaque au corps à corps ou lancer, escalade d'une
## caisse ou d'un toit, prise d'une caisse, ordres au VIP, grappin, lieu
## inaccessible.
## `apply` remplace le curseur flèche du système (`Kind.DEFAULT` le rétablit).

enum Kind { DEFAULT, ATTACK, MELEE, THROW, GRENADE, CLIMB, CRATE, ORDERS, FORBIDDEN, GRAPPLE }

const SIZE := 32
const CENTER := Vector2(16, 16)
const OUTLINE := Color(0.02, 0.03, 0.04, 0.9)

const COLORS := {
	Kind.ATTACK: Color(1.0, 0.28, 0.22),
	Kind.MELEE: Color(0.8, 0.45, 1.0),
	Kind.THROW: Color(0.8, 0.45, 1.0),
	Kind.GRENADE: Color(1.0, 0.7, 0.2),
	Kind.CLIMB: Color(0.4, 0.95, 0.5),
	Kind.CRATE: Color(1.0, 0.85, 0.3),
	Kind.ORDERS: Color(0.45, 0.8, 1.0),
	Kind.FORBIDDEN: Color(1.0, 0.25, 0.2),
	Kind.GRAPPLE: Color(0.4, 0.95, 0.5),
}

static var _textures: Dictionary = {}
static var _current: Kind = Kind.DEFAULT


## Curseur affiché.
static func current() -> Kind:
	return _current


## Affiche le curseur `kind` (sans effet s'il l'est déjà).
static func apply(kind: Kind) -> void:
	if kind == _current:
		return
	_current = kind
	if kind == Kind.DEFAULT:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		return
	Input.set_custom_mouse_cursor(texture(kind), Input.CURSOR_ARROW, hotspot(kind))


## Point actif : le centre, sauf pour la flèche d'escalade (sa pointe).
static func hotspot(kind: Kind) -> Vector2:
	return Vector2(16, 3) if kind == Kind.CLIMB else CENTER


## Image du curseur `kind` (calculée une fois).
static func texture(kind: Kind) -> Texture2D:
	if not _textures.has(kind):
		_textures[kind] = ImageTexture.create_from_image(_draw(kind))
	return _textures[kind]


## Formes du curseur : segments [a, b] et cercles [centre, rayon].
static func _shapes(kind: Kind) -> Dictionary:
	var segments: Array = []
	var rings: Array = []
	var dots: Array = []
	match kind:
		Kind.ATTACK:
			rings.append([CENTER, 9.0])
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				segments.append([CENTER + d * 5.0, CENTER + d * 14.0])
			dots.append([CENTER, 1.5])
		Kind.MELEE:
			# Poignard : lame en diagonale, garde, poignée.
			segments.append([Vector2(11, 21), Vector2(26, 6)])
			segments.append([Vector2(7, 17), Vector2(15, 25)])
			segments.append([Vector2(11, 21), Vector2(5, 27)])
		Kind.THROW:
			# Poignard lancé, traits de vitesse derrière lui.
			segments.append([Vector2(15, 17), Vector2(27, 5)])
			segments.append([Vector2(12, 14), Vector2(18, 20)])
			segments.append([Vector2(15, 17), Vector2(11, 21)])
			segments.append([Vector2(3, 21), Vector2(8, 16)])
			segments.append([Vector2(7, 28), Vector2(13, 22)])
		Kind.GRENADE:
			rings.append([CENTER, 12.0])
			rings.append([CENTER, 6.0])
			dots.append([CENTER, 2.0])
		Kind.CLIMB:
			for y: float in [3.0, 12.0]:
				segments.append([Vector2(16, y), Vector2(7, y + 9.0)])
				segments.append([Vector2(16, y), Vector2(25, y + 9.0)])
			segments.append([Vector2(16, 6), Vector2(16, 29)])
		Kind.CRATE:
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var tip := CENTER + d * 13.0
				segments.append([CENTER + d * 3.0, tip])
				var side := Vector2(-d.y, d.x)
				segments.append([tip, tip - d * 5.0 + side * 4.0])
				segments.append([tip, tip - d * 5.0 - side * 4.0])
		Kind.ORDERS:
			rings.append([CENTER, 12.0])
			for x: float in [-6.0, 0.0, 6.0]:
				dots.append([CENTER + Vector2(x, 0), 1.2])
		Kind.GRAPPLE:
			# Grappin : hampe, anneau en haut, trois griffes recourbées en bas.
			rings.append([Vector2(16, 5), 3.0])
			segments.append([Vector2(16, 8), Vector2(16, 24)])
			segments.append([Vector2(16, 24), Vector2(8, 18)])
			segments.append([Vector2(16, 24), Vector2(24, 18)])
			segments.append([Vector2(16, 24), Vector2(16, 29)])
			segments.append([Vector2(8, 18), Vector2(8, 14)])
			segments.append([Vector2(24, 18), Vector2(24, 14)])
		Kind.FORBIDDEN:
			rings.append([CENTER, 11.0])
			segments.append([CENTER + Vector2(-7.5, 7.5), CENTER + Vector2(7.5, -7.5)])
	return {"segments": segments, "rings": rings, "dots": dots}


static func _draw(kind: Kind) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var shapes := _shapes(kind)
	var color: Color = COLORS.get(kind, Color.WHITE)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + 0.5, y + 0.5)
			var distance := _distance(p, shapes)
			# Trait coloré de 2,4 px, bordé d'un contour sombre de 1,3 px.
			var inner := clampf(1.2 - distance + 0.5, 0.0, 1.0)
			var outer := clampf(2.5 - distance + 0.5, 0.0, 1.0)
			if outer <= 0.0:
				continue
			var pixel := OUTLINE.lerp(color, inner)
			pixel.a = maxf(outer * OUTLINE.a, inner)
			image.set_pixel(x, y, pixel)
	return image


## Distance de `p` au trait le plus proche.
static func _distance(p: Vector2, shapes: Dictionary) -> float:
	var best := INF
	for segment: Array in shapes["segments"]:
		best = minf(best, _segment_distance(p, segment[0], segment[1]))
	for ring: Array in shapes["rings"]:
		best = minf(best, absf(p.distance_to(ring[0]) - ring[1]))
	for dot: Array in shapes["dots"]:
		best = minf(best, maxf(p.distance_to(dot[0]) - dot[1], 0.0))
	return best


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)
