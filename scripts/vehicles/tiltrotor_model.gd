class_name TiltrotorModel
extends Node3D
## Convertible quadrirotor (fictif), construit en code comme les soldats :
## long fuselage à facettes au nez en bec, deux paires d'ailes courtes, quatre
## nacelles hautes et chanfreinées portant chacune un rotor, tourelle sous le
## menton, canon latéral, crochets d'élingage et train d'atterrissage.
##
## Repère : l'avant vers -Z, posé au sol (y = 0) ; environ 17 m de long et
## 17 m d'envergure rotors compris (avant mise à l'échelle par `Tiltrotor`).
## Soute ouverte à l'arrière : la queue relevée laisse passer une rampe
## abaissée jusqu'au sol ; plancher, bancs et cloison du cockpit à l'intérieur
## (`Interior`, qui reste opaque quand la coque devient translucide). Les facettes sont en ombrage plat ; les
## rotors tournent à `rotor_speed` tours par seconde (disque flou au-delà de
## `BLUR_SPEED`).

enum Livery { OLIVE, GREY, WINTER }

## Nacelles : centre au sol (x, z) ; les rotors tournent en sens contraires
## d'un côté à l'autre.
const NACELLES: Array[Vector2] = [Vector2(-4.8, -3.0), Vector2(4.8, -3.0), Vector2(-5.2, 4.4), Vector2(5.2, 4.4)]
const NACELLE_BOTTOM := 1.2
const NACELLE_TOP := 5.4
const NACELLE_HALF := Vector2(0.72, 0.95)
const ROTOR_RADIUS := 3.3
const BLUR_SPEED := 2.5
## Ailes : position (z) et hauteur.
const WINGS: Array[float] = [-3.0, 4.4]
const WING_HEIGHT := 3.0
## Sections du fuselage, de la pointe à la queue : z, demi-largeur, bas,
## haut, chanfrein haut, chanfrein bas.
const HULL: Array[Array] = [
	[-8.3, 0.12, 2.0, 2.2, 0.05, 0.05],
	[-7.2, 0.6, 1.7, 2.6, 0.2, 0.2],
	[-5.9, 1.0, 1.35, 2.85, 0.45, 0.35],
	[-4.6, 1.45, 1.1, 3.35, 0.6, 0.45],
	[-3.0, 1.65, 1.0, 3.6, 0.6, 0.5],
	[2.5, 1.7, 1.0, 3.55, 0.6, 0.5],
	[5.0, 1.65, 1.05, 3.5, 0.55, 0.3],
	[7.0, 1.45, 2.65, 3.45, 0.35, 0.2],
	[8.3, 1.0, 3.0, 3.35, 0.15, 0.1],
]
## Soute : plancher (hauteur), de la cloison du cockpit à la rampe (z),
## demi-largeur intérieure ; rampe abaissée jusqu'au sol en `RAMP_END`.
const FLOOR := 1.15
const CABIN_FRONT := -3.2
const CABIN_BACK := 5.0
const CABIN_HALF_WIDTH := 1.5
const CABIN_CEILING := 3.4
## Hauteur des parois intérieures (sous les chanfreins hauts de la coque).
const CABIN_WALL_TOP := 2.9
const RAMP_END := 8.8
const RAMP_HALF_WIDTH := 1.3
## Angle de la rampe autour de sa charnière (rotation sur X) : abaissée
## jusqu'au sol, ou relevée sous la queue.
const RAMP_OPEN_ANGLE := 0.2939
## Relevée, elle va de la charnière au bout de la queue (le bout se replie :
## longueur ramenée à `RAMP_CLOSED_LENGTH`).
const RAMP_CLOSED_ANGLE := -0.5109
const RAMP_CLOSED_LENGTH := 0.953
## Facettes de dessous de la queue, ouvertes sur la soute : (section,
## segment) des chanfreins bas et du fond.
const TAIL_OPENING: Array[Vector2i] = [Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4), Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4)]
## Transparence de la coque quand un opérateur est à bord.
const CUTAWAY := 0.85
## Facettes vitrées : (section de départ, segment de l'anneau).
const GLASS: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 6), Vector2i(3, 0), Vector2i(3, 6)]

const COLORS := {
	Livery.OLIVE: Color(0.46, 0.47, 0.39),
	Livery.GREY: Color(0.56, 0.57, 0.55),
	Livery.WINTER: Color(0.75, 0.76, 0.78),
}

@export var livery: Livery = Livery.OLIVE
@export var tail_number: String = "07"
## Tours par seconde (0 : rotors arrêtés).
@export var rotor_speed: float = 0.0
@export_range(2, 6) var blade_count: int = 3

var rotors: Array[Node3D] = []
## Matériau de la coque (assombri quand l'appareil brûle).
var hull_material: StandardMaterial3D

var _materials: Dictionary = {}
var _tools: Dictionary = {}
var _blur_discs: Array[MeshInstance3D] = []
var _body: MeshInstance3D
## Charnière de la rampe (sa rotation sur X l'abaisse ou la relève).
var ramp_pivot: Node3D
var _ramp_tween: Tween
var _cut: float = 0.0
var _cut_goal: float = 0.0


func _ready() -> void:
	_make_materials()
	_build()


func _process(delta: float) -> void:
	if not is_equal_approx(_cut, _cut_goal):
		_cut = move_toward(_cut, _cut_goal, delta * 3.0)
		if _body:
			_body.transparency = _cut
	if rotor_speed == 0.0:
		return
	for i in rotors.size():
		var direction := 1.0 if NACELLES[i].x > 0.0 else -1.0
		rotors[i].rotate_y(direction * rotor_speed * TAU * delta)
	for disc in _blur_discs:
		disc.visible = absf(rotor_speed) >= BLUR_SPEED


## Opérateur à bord : la coque devient translucide (fondu) pour montrer la
## soute.
func set_cutaway(cut: bool) -> void:
	_cut_goal = CUTAWAY if cut else 0.0
	# Sans quoi l'ombre de la coque noie la soute.
	if _body:
		_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if cut else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Vrai si la coque est (en partie) translucide.
func is_cut() -> bool:
	return _cut_goal > 0.0


## Appareil détruit : coque calcinée, pales tordues.
func set_wrecked() -> void:
	rotor_speed = 0.0
	hull_material.albedo_texture = null
	hull_material.albedo_color = Color(0.13, 0.12, 0.11)
	hull_material.metallic = 0.0
	hull_material.roughness = 1.0
	for disc in _blur_discs:
		disc.visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for rotor in rotors:
		for blade in rotor.get_children():
			if blade.name.begins_with("Blade"):
				(blade as Node3D).rotation.x += rng.randf_range(-0.5, -0.15)
				(blade as Node3D).rotation.z += rng.randf_range(-0.25, 0.25)


func _make_materials() -> void:
	hull_material = StandardMaterial3D.new()
	hull_material.albedo_color = COLORS[livery]
	hull_material.roughness = 0.75
	hull_material.metallic = 0.25
	# Vue de la soute par l'arrière : l'intérieur de la coque se voit aussi.
	hull_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if livery == Livery.WINTER:
		hull_material.albedo_color = Color.WHITE
		hull_material.albedo_texture = _winter_camo()
		hull_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		hull_material.uv1_triplanar = true
		hull_material.uv1_scale = Vector3.ONE * 0.3
	_materials[&"hull"] = hull_material
	_materials[&"dark"] = _plain(Color(0.12, 0.13, 0.13), 0.6, 0.3)
	_materials[&"panel"] = _plain(COLORS[livery].darkened(0.25), 0.8, 0.2)
	var glass := _plain(Color(0.06, 0.08, 0.1), 0.12, 0.6)
	_materials[&"glass"] = glass
	_materials[&"yellow"] = _plain(Color(0.85, 0.62, 0.1), 0.5, 0.4)
	_materials[&"tyre"] = _plain(Color(0.07, 0.07, 0.07), 0.95, 0.0)
	_materials[&"floor"] = _plain(Color(0.2, 0.21, 0.2), 0.9, 0.3)
	_materials[&"seat"] = _plain(Color(0.28, 0.3, 0.24), 0.95, 0.0)
	_materials[&"red"] = _glow(Color(1.0, 0.12, 0.08))
	_materials[&"green"] = _glow(Color(0.15, 1.0, 0.3))
	_materials[&"white"] = _glow(Color(1.0, 0.95, 0.85))


func _plain(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _glow(color: Color) -> StandardMaterial3D:
	var material := _plain(color, 0.4, 0.0)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.5
	return material


## Camouflage numérique hiver : carrés de gris et de blanc.
static func _winter_camo() -> ImageTexture:
	var palette: Array[Color] = [Color(0.92, 0.93, 0.95), Color(0.78, 0.8, 0.83), Color(0.6, 0.62, 0.65), Color(0.4, 0.42, 0.45)]
	var weights: Array[float] = [0.35, 0.3, 0.22, 0.13]
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for cx in 16:
		for cy in 16:
			var pick := rng.randf()
			var index := 0
			while index < weights.size() - 1 and pick > weights[index]:
				pick -= weights[index]
				index += 1
			image.fill_rect(Rect2i(cx * 4, cy * 4, 4, 4), palette[index])
	return ImageTexture.create_from_image(image)


func _build() -> void:
	_build_hull()
	_build_wings()
	for i in NACELLES.size():
		_build_nacelle(i)
	_build_weapons()
	_build_gear()
	_body = _commit("Body")
	_build_interior()
	_commit("Interior")
	_build_ramp()
	for i in NACELLES.size():
		_build_rotor(i)
	_build_lights()


# --- Maillage à facettes ------------------------------------------------------

## Anneau octogonal chanfreiné de demi-largeur `w`, de `bottom` à `top`, dans
## le plan (`u`, `v`) autour de `origin`.
static func ring(origin: Vector3, u: Vector3, v: Vector3, w: float, bottom: float, top: float, chamfer_top: float, chamfer_bottom: float) -> PackedVector3Array:
	var flat: Array[Vector2] = [
		Vector2(w * 0.55, top), Vector2(w, top - chamfer_top), Vector2(w, bottom + chamfer_bottom), Vector2(w * 0.6, bottom),
		Vector2(-w * 0.6, bottom), Vector2(-w, bottom + chamfer_bottom), Vector2(-w, top - chamfer_top), Vector2(-w * 0.55, top),
	]
	var points := PackedVector3Array()
	for p in flat:
		points.append(origin + u * p.x + v * p.y)
	return points


## Triangle à normale plate, tourné vers l'extérieur (loin de `inside`).
func _tri(key: StringName, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-10:
		return
	normal = normal.normalized()
	if normal.dot((a + b + c) / 3.0 - inside) < 0.0:
		normal = -normal
	else:
		# Face avant dans le sens des aiguilles d'une montre (Godot).
		var swap := b
		b = c
		c = swap
	if not _tools.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(_materials[key])
		_tools[key] = tool
	var surface: SurfaceTool = _tools[key]
	for point in [a, b, c]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(point.x + point.z, point.y) * 0.5)
		surface.add_vertex(point)


func _quad(key: StringName, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
	_tri(key, a, b, c, inside)
	_tri(key, a, c, d, inside)


## Relie des anneaux successifs (même nombre de points) ; bouche les deux
## bouts. `material_for(section, segment)` choisit le matériau d'une facette.
func _loft(rings: Array[PackedVector3Array], material_for: Callable = Callable()) -> void:
	for s in rings.size() - 1:
		var a := rings[s]
		var b := rings[s + 1]
		var inside := (_centroid(a) + _centroid(b)) * 0.5
		for i in a.size():
			var j := (i + 1) % a.size()
			var key: StringName = material_for.call(s, i) if material_for.is_valid() else &"hull"
			# Clé vide : facette ouverte.
			if key != &"":
				_quad(key, a[i], a[j], b[j], b[i], inside)
	var cap_key: StringName = material_for.call(0, 0) if material_for.is_valid() else &"hull"
	var middle := (_centroid(rings[0]) + _centroid(rings[rings.size() - 1])) * 0.5
	for cap: PackedVector3Array in [rings[0], rings[rings.size() - 1]]:
		var center := _centroid(cap)
		# Le bout : son « intérieur » est vers le milieu de la pièce.
		var inside := center + (middle - center).normalized() * 0.01 if middle.distance_to(center) > 0.001 else middle
		for i in cap.size():
			_tri(cap_key, center, cap[i], cap[(i + 1) % cap.size()], inside)


static func _centroid(points: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for p in points:
		sum += p
	return sum / maxf(points.size(), 1)


## Pavé (facettes plates) de centre `center` et de taille `size`.
func _box(key: StringName, center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var c: Array[Vector3] = []
	for i in 8:
		c.append(center + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for face: Array in [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]:
		_quad(key, c[face[0]], c[face[1]], c[face[2]], c[face[3]], center)


## Cylindre d'axe `axis` (facettes), de `from` à `to`.
func _cylinder(key: StringName, from: Vector3, to: Vector3, radius: float, sides: int = 10) -> void:
	var axis := (to - from).normalized()
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	var bottom := PackedVector3Array()
	var top := PackedVector3Array()
	for i in sides:
		var angle := TAU * i / sides
		var offset := (u * cos(angle) + v * sin(angle)) * radius
		bottom.append(from + offset)
		top.append(to + offset)
	var inside := (from + to) * 0.5
	for i in sides:
		var j := (i + 1) % sides
		_quad(key, bottom[i], bottom[j], top[j], top[i], inside)
		_tri(key, from, bottom[i], bottom[j], inside)
		_tri(key, to, top[i], top[j], inside)


## Réunit les facettes accumulées en un maillage (une surface par matériau).
func _commit(node_name: String, parent: Node3D = self) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for key: StringName in _tools:
		(_tools[key] as SurfaceTool).commit(mesh)
	_tools.clear()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


# --- Pièces -----------------------------------------------------------------

func _build_hull() -> void:
	var rings: Array[PackedVector3Array] = []
	for s in HULL:
		rings.append(ring(Vector3(0, 0, s[0]), Vector3.RIGHT, Vector3.UP, s[1], s[2], s[3], s[4], s[5]))
	_loft(rings, func(section: int, segment: int) -> StringName:
		if TAIL_OPENING.has(Vector2i(section, segment)):
			return &""
		return &"glass" if GLASS.has(Vector2i(section, segment)) else &"hull")
	# Dos : carénage de transmission entre les ailes.
	var spine: Array[PackedVector3Array] = []
	for s: Array in [[-3.4, 0.35, 3.5, 3.62], [-2.4, 0.75, 3.5, 4.05], [4.6, 0.75, 3.45, 4.0], [5.6, 0.3, 3.35, 3.5]]:
		spine.append(ring(Vector3(0, 0, s[0]), Vector3.RIGHT, Vector3.UP, s[1], s[2], s[3], 0.2, 0.0))
	_loft(spine)
	# Flancs bas, élargis (logements du train).
	var sponson: Array[PackedVector3Array] = []
	for s: Array in [[-2.0, 1.2, 1.15, 1.6], [-1.2, 2.05, 1.0, 2.1], [3.2, 2.05, 1.0, 2.1], [4.2, 1.7, 1.05, 1.6]]:
		sponson.append(ring(Vector3(0, 0, s[0]), Vector3.RIGHT, Vector3.UP, s[1], s[2], s[3], 0.45, 0.25))
	_loft(sponson)
	# Hublots latéraux et trappe arrière.
	for side: float in [-1.0, 1.0]:
		for z: float in [-1.4, 0.4]:
			_box(&"dark", Vector3(side * 1.71, 2.75, z), Vector3(0.04, 0.4, 0.6))
		_box(&"panel", Vector3(side * 2.06, 1.55, 1.0), Vector3(0.03, 0.55, 2.6))


## Soute : plancher, bancs le long des flancs, cloison du cockpit.
func _build_interior() -> void:
	var length := CABIN_BACK - CABIN_FRONT
	var middle := (CABIN_FRONT + CABIN_BACK) * 0.5
	_box(&"floor", Vector3(0, FLOOR - 0.04, middle), Vector3(CABIN_HALF_WIDTH * 2.0, 0.08, length))
	# Cloison du cockpit, au profil de la coque (un peu en retrait).
	var bulkhead: Array[PackedVector3Array] = []
	for dz: float in [0.0, 0.1]:
		bulkhead.append(ring(Vector3(0, 0, CABIN_FRONT + dz), Vector3.RIGHT, Vector3.UP, 1.55, FLOOR, 3.5, 0.62, 0.0))
	_loft(bulkhead, func(_s: int, _i: int) -> StringName: return &"dark")
	for side: float in [-1.0, 1.0]:
		# Paroi intérieure, banc et dossier en toile.
		_box(&"panel", Vector3(side * (CABIN_HALF_WIDTH + 0.03), (FLOOR + CABIN_WALL_TOP) * 0.5, middle), Vector3(0.06, CABIN_WALL_TOP - FLOOR, length))
		_box(&"seat", Vector3(side * (CABIN_HALF_WIDTH - 0.25), FLOOR + 0.42, middle + 0.4), Vector3(0.45, 0.08, length - 2.0))
		_box(&"seat", Vector3(side * (CABIN_HALF_WIDTH - 0.04), FLOOR + 0.8, middle + 0.4), Vector3(0.05, 0.6, length - 2.0))
		for k in 5:
			var z := CABIN_FRONT + 1.6 + k * (length - 2.4) / 4.0
			_box(&"dark", Vector3(side * (CABIN_HALF_WIDTH - 0.25), FLOOR + 0.2, z), Vector3(0.04, 0.4, 0.04))


## Rampe arrière, sur sa charnière au bord du plancher (`ramp_pivot`) : un
## plateau le long de +Z, bandes jaunes sur les bords. Abaissée jusqu'au sol
## ou relevée sous la queue (`set_ramp_closed`).
func _build_ramp() -> void:
	ramp_pivot = Node3D.new()
	ramp_pivot.name = "RampPivot"
	ramp_pivot.position = Vector3(0, FLOOR, CABIN_BACK)
	ramp_pivot.rotation.x = RAMP_OPEN_ANGLE
	add_child(ramp_pivot)
	var length := ramp_length()
	_box(&"floor", Vector3(0, -0.05, length * 0.5), Vector3(RAMP_HALF_WIDTH * 2.0, 0.1, length))
	for side: float in [-1.0, 1.0]:
		_box(&"yellow", Vector3(side * (RAMP_HALF_WIDTH - 0.1), 0.005, length * 0.5), Vector3(0.16, 0.01, length))
	_commit("Ramp", ramp_pivot)


## Longueur de la rampe (de la charnière au sol, abaissée).
static func ramp_length() -> float:
	return Vector2(FLOOR, RAMP_END - CABIN_BACK).length()


## Relève (`closed`) ou abaisse la rampe, en `duration` secondes.
func set_ramp_closed(closed: bool, duration: float = 0.0) -> void:
	var angle := RAMP_CLOSED_ANGLE if closed else RAMP_OPEN_ANGLE
	var length := RAMP_CLOSED_LENGTH if closed else 1.0
	if _ramp_tween:
		_ramp_tween.kill()
	if duration <= 0.0:
		ramp_pivot.rotation.x = angle
		ramp_pivot.scale.z = length
		return
	_ramp_tween = create_tween().set_parallel()
	_ramp_tween.tween_property(ramp_pivot, "rotation:x", angle, duration).set_trans(Tween.TRANS_SINE)
	_ramp_tween.tween_property(ramp_pivot, "scale:z", length, duration)


func _build_wings() -> void:
	for z in WINGS:
		var x := NACELLES[0].x if z < 0.0 else NACELLES[2].x
		var rings: Array[PackedVector3Array] = []
		for tip: float in [x, 0.0, -x]:
			var chord := 2.5 if is_zero_approx(tip) else 1.9
			rings.append(ring(Vector3(tip, 0, z), Vector3.BACK, Vector3.UP, chord * 0.5, WING_HEIGHT - 0.3, WING_HEIGHT + 0.3, 0.18, 0.12))
		_loft(rings)


func _build_nacelle(index: int) -> void:
	var at := NACELLES[index]
	var origin := Vector3(at.x, 0, at.y)
	var rings: Array[PackedVector3Array] = []
	# Anneaux horizontaux, du bas (effilé) au haut.
	for s: Array in [[NACELLE_BOTTOM, 0.7], [NACELLE_BOTTOM + 0.45, 1.0], [NACELLE_TOP - 0.35, 1.0], [NACELLE_TOP, 0.78]]:
		var scale: float = s[1]
		rings.append(ring(origin + Vector3.UP * s[0], Vector3.RIGHT, Vector3.BACK, NACELLE_HALF.x * scale, -NACELLE_HALF.y * scale, NACELLE_HALF.y * scale, 0.22 * scale, 0.22 * scale))
	_loft(rings)
	var outward := signf(at.x)
	# Prises d'air sombres, sur la face extérieure et à l'avant.
	_box(&"dark", origin + Vector3(outward * (NACELLE_HALF.x + 0.01), 2.1, 0.2), Vector3(0.03, 0.55, 0.5))
	_box(&"dark", origin + Vector3(outward * (NACELLE_HALF.x + 0.01), 3.4, 0.2), Vector3(0.03, 0.4, 0.5))
	_box(&"dark", origin + Vector3(0, 1.75, -NACELLE_HALF.y - 0.01), Vector3(0.45, 0.4, 0.03))
	_box(&"panel", origin + Vector3(0, NACELLE_TOP + 0.08, 0), Vector3(0.7, 0.16, 0.9))
	# Numéro de l'appareil, à l'avant et sur le flanc extérieur.
	for face: int in 2:
		var label := Label3D.new()
		label.text = tail_number
		label.font_size = 96
		label.outline_size = 0
		label.pixel_size = 0.005
		label.modulate = Color(0.12, 0.12, 0.13)
		label.double_sided = false
		label.shaded = true
		if face == 0:
			label.position = origin + Vector3(0, 3.7, -NACELLE_HALF.y - 0.02)
			label.rotation.y = PI
		else:
			label.position = origin + Vector3(outward * (NACELLE_HALF.x + 0.02), 4.25, -0.1)
			label.rotation.y = outward * PI * 0.5
		label.name = "Number%d_%d" % [index, face]
		add_child(label)


func _build_weapons() -> void:
	# Tourelle sous le menton : boule, berceau et deux canons.
	var turret := Vector3(0, 1.25, -6.1)
	_box(&"dark", turret + Vector3(0, 0.2, 0), Vector3(0.5, 0.25, 0.6))
	_cylinder(&"dark", turret + Vector3(-0.3, 0, 0), turret + Vector3(0.3, 0, 0), 0.32, 12)
	for side: float in [-0.1, 0.1]:
		_cylinder(&"dark", turret + Vector3(side, -0.05, -0.2), turret + Vector3(side, -0.05, -1.1), 0.05, 6)
	# Canon latéral, côté droit du cockpit.
	var mount := Vector3(1.35, 2.45, -4.3)
	_box(&"panel", mount, Vector3(0.35, 0.35, 0.8))
	_cylinder(&"dark", mount + Vector3(0, 0, -0.3), mount + Vector3(0, 0, -1.6), 0.07, 8)
	# Crochets d'élingage sous les ailes.
	for z in WINGS:
		var hook := Vector3(0, 1.0, z)
		_cylinder(&"dark", hook, hook + Vector3(0, -0.35, 0), 0.12, 8)
		_box(&"yellow", hook + Vector3(0, -0.45, 0), Vector3(0.28, 0.12, 0.08))


func _build_gear() -> void:
	var wheels: Array[Vector3] = [Vector3(0, 0.3, -4.9)]
	for side: float in [-1.0, 1.0]:
		wheels.append(Vector3(side * 1.55, 0.36, 0.2))
		wheels.append(Vector3(side * 1.55, 0.36, 1.7))
	for i in wheels.size():
		var wheel := wheels[i]
		var radius := wheel.y
		_cylinder(&"dark", wheel + Vector3(0, 0, 0), wheel + Vector3(0, 1.1 - wheel.y, 0), 0.07, 6)
		_cylinder(&"tyre", wheel + Vector3(-0.14, 0, 0), wheel + Vector3(0.14, 0, 0), radius, 12)


func _build_rotor(index: int) -> void:
	var at := NACELLES[index]
	var rotor := Node3D.new()
	rotor.name = "Rotor%d" % index
	rotor.position = Vector3(at.x, NACELLE_TOP + 0.16, at.y)
	add_child(rotor)
	rotors.append(rotor)
	_cylinder(&"dark", Vector3.ZERO, Vector3(0, 0.4, 0), 0.3, 12)
	_cylinder(&"panel", Vector3(0, 0.4, 0), Vector3(0, 0.62, 0), 0.18, 10)
	_commit("Hub", rotor)
	for b in blade_count:
		var blade := Node3D.new()
		blade.name = "Blade%d" % b
		blade.rotation.y = TAU * b / blade_count + index * 0.4
		blade.position.y = 0.3
		rotor.add_child(blade)
		# Pale effilée, légèrement vrillée.
		var root := PackedVector3Array([Vector3(0.25, 0.04, -0.22), Vector3(0.25, 0.04, 0.22), Vector3(0.25, -0.04, 0.22), Vector3(0.25, -0.04, -0.22)])
		var tip := PackedVector3Array([Vector3(ROTOR_RADIUS, 0.05, -0.12), Vector3(ROTOR_RADIUS, 0.02, 0.18), Vector3(ROTOR_RADIUS, -0.02, 0.18), Vector3(ROTOR_RADIUS, 0.01, -0.12)])
		var rings: Array[PackedVector3Array] = [root, tip]
		_loft(rings, func(_s: int, _i: int) -> StringName: return &"dark")
		_commit("Mesh", blade)
	var disc := MeshInstance3D.new()
	disc.name = "Blur"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = ROTOR_RADIUS
	cylinder.bottom_radius = ROTOR_RADIUS
	cylinder.height = 0.02
	cylinder.radial_segments = 32
	disc.mesh = cylinder
	var blur := StandardMaterial3D.new()
	blur.albedo_color = Color(0.1, 0.1, 0.1, 0.22)
	blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = blur
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = 0.3
	disc.visible = false
	rotor.add_child(disc)
	_blur_discs.append(disc)


## Feux de position (rouge à gauche, vert à droite), feu de nez et feux bas.
func _build_lights() -> void:
	for at in NACELLES:
		var key := &"red" if at.x < 0.0 else &"green"
		_box(key, Vector3(at.x + signf(at.x) * 0.45, NACELLE_TOP - 0.15, at.y - 0.6), Vector3(0.1, 0.1, 0.1))
		_box(&"white", Vector3(at.x, NACELLE_BOTTOM - 0.02, at.y), Vector3(0.18, 0.04, 0.18))
	_box(&"red", Vector3(0, 2.1, -8.32), Vector3(0.18, 0.08, 0.04))
	_commit("Lights")
