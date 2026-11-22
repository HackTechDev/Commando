@tool
class_name Passerby
extends Node3D
## Passant (décor) : un civil qui marche le long d'un tracé, en aller-retour
## (ou en boucle), en tenant sa droite pour croiser les autres. Il s'arrête
## un instant devant quelqu'un (opérateur, garde, VIP, autre passant), puis
## repart. Comme les invités (`Guest`), il ne voit rien, ne réagit à rien et
## ne barre pas le passage : la foule anime la rue, l'effet « se fondre dans
## la foule » passe par la tenue (`LevelRoot.dress_code`).

const GROUP := &"passersby"
## Écart à droite du tracé (m) : deux passants qui se croisent ne se gênent
## pas.
const LANE := 0.8
## Distance (m) et attente maximale (s) devant quelqu'un.
const CLEARANCE := 1.1
const MAX_WAIT := 2.5
## Vitesse de rotation (rad/s) pour suivre les virages et faire demi-tour.
const TURN_SPEED := 5.0
## Vitesse de marche (m/s) correspondant à `SoldierModel.move_ratio` = 1.
const WALK_SPEED := 1.5
## Hors de l'écran, il n'est déplacé qu'une image sur `HIDDEN_EVERY` :
## déplacer un personnage recalcule la place de toutes ses pièces.
const HIDDEN_EVERY := 10

## Tracé, au sol, dans le repère du parent.
@export var points: PackedVector3Array = PackedVector3Array()
## Faux : aller-retour ; vrai : boucle (le dernier point rejoint le premier).
@export var loop: bool = false
## Distance (m) parcourue au départ le long du tracé, sens de départ.
@export var start_at: float = 0.0
@export var backward: bool = false
@export var speed: float = 1.3
@export var look_seed: int = 0
@export var dress: StringName = &"casual"

var model: SoldierModel
var _lengths: PackedFloat32Array = PackedFloat32Array()
var _total: float = 0.0
var _at: float = 0.0
var _dir: float = 1.0
var _waited: float = 0.0
## Décalage courant sur la droite du tracé : il glisse d'un côté à l'autre
## au demi-tour, au lieu de sauter.
var _offset := Vector3.ZERO
var _hidden_frames: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		# Aperçu au début du trajet, sans déplacer le nœud (enregistré).
		model = CrowdModel.new()
		model.civilian = dress == &"suit"
		model.silent = true
		model.outfit = Guest.random_look(look_seed, dress)
		add_child(model)
		model.set_armed(false)
		place_preview()
		return
	add_to_group(GROUP)
	model = CrowdModel.new()
	(model as CrowdModel).every = 2
	model.civilian = dress == &"suit"
	model.silent = true
	model.outfit = Guest.random_look(look_seed, dress)
	add_child(model)
	model.set_armed(false)
	_lengths.append(0.0)
	var count := points.size() + (1 if loop else 0)
	for i in range(1, count):
		_total += points[(i - 1) % points.size()].distance_to(points[i % points.size()])
		_lengths.append(_total)
	_at = fposmod(start_at, maxf(_total, 0.01)) if loop else clampf(start_at, 0.0, _total)
	_dir = -1.0 if backward else 1.0
	if points.size() >= 2:
		_offset = _lane()
		position = _place(_at) + _offset
		rotation.y = _heading()


## Il avance une fois par image (pas à chaque pas de physique).
## Éditeur : place le modèle au début du trajet (le nœud ne bouge pas).
func place_preview() -> void:
	if model and points.size() >= 2:
		var heading := points[1] - points[0]
		model.transform = Transform3D(Basis(Vector3.UP, atan2(-heading.x, -heading.z)), points[0] - position)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if points.size() < 2 or _total <= 0.0:
		return
	var seen := (model as CrowdModel).is_seen()
	if seen and _blocked() and _waited < MAX_WAIT:
		_waited += delta
		model.move_ratio = 0.0
		return
	if not seen or not _blocked():
		_waited = 0.0
	_at += _dir * speed * delta
	if loop:
		_at = fposmod(_at, _total)
	elif _at >= _total or _at <= 0.0:
		_at = clampf(_at, 0.0, _total)
		_dir = -_dir
	_offset = _offset.move_toward(_lane(), delta * speed)
	model.move_ratio = speed / WALK_SPEED
	_hidden_frames = 0 if seen else _hidden_frames + 1
	if seen or _hidden_frames % HIDDEN_EVERY == 0:
		position = _place(_at) + _offset
		rotation.y = rotate_toward(rotation.y, _heading(), TURN_SPEED * delta * (1.0 if seen else HIDDEN_EVERY))


## Point du tracé à la distance `at`.
func _place(at: float) -> Vector3:
	var segment := _segment(at)
	var a := points[segment % points.size()]
	var b := points[(segment + 1) % points.size()]
	var span := _lengths[segment + 1] - _lengths[segment]
	var t := 0.0 if span <= 0.0 else (at - _lengths[segment]) / span
	return a.lerp(b, t)


## Décalage visé : `LANE` sur la droite du sens de marche.
func _lane() -> Vector3:
	var segment := _segment(_at)
	var forward := (points[(segment + 1) % points.size()] - points[segment % points.size()]).normalized() * _dir
	return Vector3(-forward.z, 0.0, forward.x) * LANE


## Cap (rotation y) du sens de marche sur le segment courant.
func _heading() -> float:
	var segment := _segment(_at)
	var forward := (points[(segment + 1) % points.size()] - points[segment % points.size()]) * _dir
	return atan2(-forward.x, -forward.z)


func _segment(at: float) -> int:
	for i in range(_lengths.size() - 1):
		if at <= _lengths[i + 1]:
			return i
	return _lengths.size() - 2


## Vrai si quelqu'un se tient juste devant lui.
func _blocked() -> bool:
	var forward := -global_basis.z
	for group: StringName in [&"commandos", &"enemies", &"vips", GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			var other := node as Node3D
			if other == null or other == self:
				continue
			var offset := other.global_position - global_position
			offset.y = 0.0
			if offset.length() < CLEARANCE and offset.normalized().dot(forward) > 0.5:
				return true
	return false
