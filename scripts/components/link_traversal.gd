class_name LinkTraversal
extends RefCounted
## Franchissement scripté d'un `TraversalLink` par une unité (opérateur,
## ennemi, VIP) : son `NavigationAgent3D` signale l'entrée du lien
## (`link_reached`), l'unité appelle `begin`, puis `update` à chaque image
## physique tant qu'il renvoie vrai, sans se déplacer elle-même. Le corps
## suit les phases ci-dessous ; le modèle joue l'animation correspondante.
## - Muret : escalade jusqu'au dessus, puis descente de l'autre côté (mêmes
##   courbes que les caisses).
## - Échelle, montée : pas jusqu'au pied, barreaux, puis rétablissement sur
##   le toit (escalade d'un rebord). Descente : l'inverse, face à l'échelle.
## - Corde (grappin) : le relief se gravit face par face, chaque ressaut bas
##   escaladé comme une caisse, chaque paroi haute à la corde.

## Vitesse sur les barreaux (m/s) et longueur d'un cycle de l'animation
## (deux barreaux).
const LADDER_SPEED := 0.9
const LADDER_CYCLE := 0.6
## Distance du corps à la face du mur, sur l'échelle.
const LADDER_STANCE := 0.4
## Dénivelé franchi par le rétablissement en haut de l'échelle (animation
## d'escalade d'une caisse).
const MOUNT_HEIGHT := 1.2
## Durée des pas entre le pied de l'échelle et les barreaux.
const STEP_TIME := 0.35
## Ressaut escaladé d'un coup (comme une caisse) jusqu'à cette hauteur ;
## au-delà, il faut des barreaux ou une corde.
const SHORT_CLIMB := 1.4
## Escalade d'un ressaut : départ avant la face, arrivée après son bord.
const CLIMB_DISTANCE := 0.55
const LAND_DISTANCE := 0.6
## Vitesse de marche entre deux faces (m/s).
const WALK_SPEED := 1.3
## Durées par défaut, si l'unité n'a pas de réglages d'escalade (`UnitStats`).
const CLIMB_TIME := 1.4
const DESCEND_TIME := 1.0

enum Phase { WALK, CLIMB_UP, LOWER, CLIMB_DOWN, RUNGS }

## Franchissement en cours.
var active: bool = false
## Lien franchi (null hors franchissement).
var link: TraversalLink
## Point d'arrivée.
var exit: Vector3

var _body: CharacterBody3D
var _model: SoldierModel
var _phases: Array[Dictionary] = []
var _index: int = 0
var _time: float = 0.0


func _init(body: CharacterBody3D, model: SoldierModel) -> void:
	_body = body
	_model = model


## Commence à franchir `traversal` depuis son extrémité la plus proche de
## `entry` jusqu'à l'autre (`exit_point` n'en donne que l'ordre). Renvoie faux si un franchissement est déjà en
## cours.
func begin(traversal: TraversalLink, entry: Vector3, exit_point: Vector3) -> bool:
	if active or traversal == null:
		return false
	# La navigation donne des points de son maillage, un peu au-dessus du
	# sol : on prend les vraies extrémités du lien, au sol.
	var near_start := entry.distance_squared_to(traversal.global_start()) <= entry.distance_squared_to(traversal.global_end())
	entry = traversal.global_start() if near_start else traversal.global_end()
	exit_point = traversal.global_end() if near_start else traversal.global_start()
	link = traversal
	exit = exit_point
	var start := _body.global_position
	start.y = entry.y
	var direction := exit_point - entry
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return false
	direction = direction.normalized()
	_phases.clear()
	var climb := _stat(&"climb_time", CLIMB_TIME)
	var descend := _stat(&"descend_time", DESCEND_TIME)
	if traversal.kind == TraversalLink.Kind.VAULT:
		var top := (entry + exit_point) * 0.5
		top.y = entry.y + traversal.height
		_add(Phase.CLIMB_UP, start, top, climb)
		_add(Phase.CLIMB_DOWN, top, exit_point, descend)
	else:
		# Échelle (une seule face, le mur) ou corde (les faces du relief).
		var faces: Array[Vector4] = traversal.faces.duplicate()
		var going_up := exit_point.y > entry.y
		var foot := entry if going_up else exit_point
		var summit := exit_point if going_up else entry
		var up := direction if going_up else -direction
		if traversal.kind == TraversalLink.Kind.LADDER:
			var wall := foot + up * traversal.face_distance
			faces = [Vector4(wall.x, wall.z, foot.y, summit.y)]
		if going_up:
			_climb_faces(start, summit, faces, up, climb)
		else:
			_descend_faces(start, foot, faces, up, climb, descend)
		direction = up if going_up else -up
	_body.rotation.y = atan2(-direction.x, -direction.z)
	if _phases.is_empty():
		return false
	_body.velocity = Vector3.ZERO
	_body.set(&"posture", SoldierModel.Posture.STANDING)
	_model.posture = SoldierModel.Posture.STANDING
	_model.weapon_slung = true
	_index = 0
	_time = 0.0
	active = true
	return true


## Avance le franchissement d'une image. Renvoie vrai tant qu'il est en cours
## (l'unité ne doit alors pas se déplacer elle-même).
func update(delta: float) -> bool:
	if not active:
		return false
	_model.weapon_slung = true
	var phase := _phases[_index]
	if _time == 0.0:
		var facing: Vector3 = phase["facing"]
		if facing != Vector3.ZERO:
			_body.rotation.y = atan2(-facing.x, -facing.z)
	_time += delta
	var t := clampf(_time / maxf(phase["duration"], 0.001), 0.0, 1.0)
	_apply(phase, t)
	if t >= 1.0:
		_index += 1
		_time = 0.0
		if _index >= _phases.size():
			_finish()
	return true


## Interrompt le franchissement (mort de l'unité) : le modèle quitte la
## pose d'escalade, le corps reste où il est.
func cancel() -> void:
	if active:
		_finish()


func _finish() -> void:
	active = false
	link = null
	_model.climb_progress = -1.0
	_model.ladder_phase = -1.0
	_model.move_ratio = 0.0


func _add(kind: Phase, from: Vector3, to: Vector3, duration: float, facing: Vector3 = Vector3.ZERO) -> void:
	_phases.append({"kind": kind, "from": from, "to": to, "duration": duration, "facing": facing})


## Marche de `from` à `to` (rien si les points sont confondus).
func _walk(from: Vector3, to: Vector3, facing: Vector3) -> void:
	var distance := from.distance_to(to)
	if distance > 0.05:
		_add(Phase.WALK, from, to, maxf(distance / WALK_SPEED, STEP_TIME * 0.5), facing)


## Montée de `from` à `summit` par les faces `faces` (du bas vers le haut,
## x et z de la face, sol bas, sol haut), dans la direction `up` : un ressaut
## bas s'escalade comme une caisse ; une paroi haute se gravit (barreaux ou
## corde) jusqu'à un rétablissement sur le rebord.
func _climb_faces(from: Vector3, summit: Vector3, faces: Array[Vector4], up: Vector3, climb: float) -> void:
	var position := from
	for face in faces:
		var at := Vector3(face.x, 0.0, face.y)
		var land := at + up * LAND_DISTANCE
		land.y = face.w
		if face.w - face.z <= SHORT_CLIMB:
			var base := at - up * CLIMB_DISTANCE
			base.y = face.z
			_walk(position, base, up)
			_add(Phase.CLIMB_UP, base, land, climb, up)
		else:
			var rung := at - up * LADDER_STANCE
			rung.y = face.z
			var hang := Vector3(rung.x, face.w - MOUNT_HEIGHT, rung.z)
			_walk(position, rung, up)
			_add(Phase.RUNGS, rung, hang, (hang.y - rung.y) / LADDER_SPEED, up)
			_add(Phase.CLIMB_UP, hang, land, climb, up)
		position = land
	_walk(position, summit, up)


## Descente de `from` à `foot`, l'inverse de `_climb_faces` : un ressaut bas
## se descend face au vide ; une paroi haute, face à elle, en s'accrochant
## au rebord puis aux barreaux (ou à la corde).
func _descend_faces(from: Vector3, foot: Vector3, faces: Array[Vector4], up: Vector3, climb: float, descend: float) -> void:
	var position := from
	var down := -up
	for i in range(faces.size() - 1, -1, -1):
		var face := faces[i]
		var at := Vector3(face.x, 0.0, face.y)
		var edge := at + up * LAND_DISTANCE
		edge.y = face.w
		_walk(position, edge, down)
		if face.w - face.z <= SHORT_CLIMB:
			var landing := at - up * CLIMB_DISTANCE
			landing.y = face.z
			_add(Phase.CLIMB_DOWN, edge, landing, descend, down)
			position = landing
		else:
			var rung := at - up * LADDER_STANCE
			rung.y = face.z
			var hang := Vector3(rung.x, face.w - MOUNT_HEIGHT, rung.z)
			_add(Phase.LOWER, edge, hang, climb, up)
			_add(Phase.RUNGS, hang, rung, (hang.y - rung.y) / LADDER_SPEED, up)
			position = rung
	_walk(position, foot, down)


func _apply(phase: Dictionary, t: float) -> void:
	var from: Vector3 = phase["from"]
	var to: Vector3 = phase["to"]
	_model.climb_progress = -1.0
	_model.ladder_phase = -1.0
	_model.move_ratio = 0.0
	match phase["kind"]:
		Phase.WALK:
			_body.global_position = from.lerp(to, t)
			_model.move_ratio = 0.5
		Phase.RUNGS:
			_body.global_position = from.lerp(to, t)
			_model.ladder_phase = absf(_body.global_position.y - minf(from.y, to.y)) / LADDER_CYCLE
		Phase.CLIMB_UP:
			_model.climb_descending = false
			_model.climb_jump = false
			_model.climb_progress = t
			_body.global_position = _curve(from, to, Commando.CLIMB_UP_FORWARD, Commando.CLIMB_UP_HEIGHT, t)
		Phase.LOWER:
			# Le rétablissement à l'envers : de `from` (en haut) à `to` (accroché).
			_model.climb_descending = false
			_model.climb_jump = false
			_model.climb_progress = 1.0 - t
			_body.global_position = _curve(to, from, Commando.CLIMB_UP_FORWARD, Commando.CLIMB_UP_HEIGHT, 1.0 - t)
		Phase.CLIMB_DOWN:
			_model.climb_descending = true
			_model.climb_jump = false
			_model.climb_progress = t
			_body.global_position = _curve(from, to, Commando.CLIMB_DOWN_FORWARD, Commando.CLIMB_DOWN_HEIGHT, t)


## Position sur une escalade de `from` à `to` à l'instant `t` : avancée et
## élévation suivent leurs courbes propres.
static func _curve(from: Vector3, to: Vector3, forward: Array[float], height: Array[float], t: float) -> Vector3:
	var along := SoldierModel.sample_keys(forward, t)
	var up := SoldierModel.sample_keys(height, t)
	return Vector3(lerpf(from.x, to.x, along), lerpf(from.y, to.y, up), lerpf(from.z, to.z, along))


func _stat(property: StringName, fallback: float) -> float:
	var stats := _body.get(&"stats") as UnitStats
	if stats == null:
		return fallback
	return float(stats.get(property))
