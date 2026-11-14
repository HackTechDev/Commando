class_name PathWalker
extends RefCounted
## Aide au suivi de chemin des unités (opérateurs et ennemis) sur un terrain
## inégal :
## - `next_point` : point suivant du `NavigationAgent3D`, en sautant un point
##   dont l'unité ne se rapproche plus (occupé par une unité immobile, ou
##   décalé en hauteur par rapport au sol sur une pente) ;
## - `step_up` : franchit une marche basse que la navigation accepte mais que
##   le corps physique ne monte pas seul.

## Durée sans progrès vers le point suivant avant de le sauter, en secondes.
const STALL_TIME := 0.4
## Progrès minimal (m) qui remet ce délai à zéro.
const STALL_PROGRESS := 0.05
## Distance horizontale (m) en deçà de laquelle un point bloqué peut être sauté.
const SKIP_RANGE := 1.5
## Hauteur maximale d'une marche franchie automatiquement (m) : un peu plus que
## le dénivelé accepté par la navigation (0,3 m), arrondi des cellules compris.
const MAX_STEP := 0.35
## Avancée maximale (m) pour poser le pied à plat sur la marche.
const STEP_REACH := 0.3

var _point: Vector3 = Vector3.INF
var _best: float = INF
var _stall: float = 0.0


## Point suivant du chemin de `agent`, pour `body`.
func next_point(agent: NavigationAgent3D, body: Node3D, delta: float) -> Vector3:
	var desired := agent.path_desired_distance
	var next := agent.get_next_path_position()
	if not next.is_equal_approx(_point):
		_point = next
		_best = INF
		_stall = 0.0
	var distance := body.global_position.distance_to(next)
	if distance < _best - STALL_PROGRESS:
		_best = distance
		_stall = 0.0
		return next
	_stall += delta
	var flat := Vector2(next.x - body.global_position.x, next.z - body.global_position.z).length()
	if _stall < STALL_TIME or flat > SKIP_RANGE or agent.is_navigation_finished():
		return next
	# L'agent passe au point suivant dès qu'on en est plus près que la
	# distance voulue : on l'élargit le temps d'une requête.
	_stall = 0.0
	agent.path_desired_distance = distance + 0.05
	next = agent.get_next_path_position()
	agent.path_desired_distance = desired
	return next


## Après un `move_and_slide` qui n'a pas avancé comme voulu (`wanted` :
## déplacement horizontal visé pendant l'image), monte `body` sur la marche
## devant lui si elle fait au plus `MAX_STEP`. Renvoie vrai s'il l'a montée.
static func step_up(body: CharacterBody3D, wanted: Vector3) -> bool:
	wanted.y = 0.0
	if wanted.length_squared() < 0.000001 or not body.is_on_floor():
		return false
	var start := body.global_transform
	if body.test_move(start, Vector3.UP * MAX_STEP):
		return false
	var raised := start.translated(Vector3.UP * MAX_STEP)
	# On avance pas à pas au-dessus de la marche jusqu'à un appui plat : au
	# premier pas, l'arrondi de la capsule ne touche que l'arête et glisserait.
	var direction := wanted.normalized()
	for distance in [wanted.length(), STEP_REACH * 0.5, STEP_REACH]:
		var motion: Vector3 = direction * maxf(distance, wanted.length())
		if body.test_move(raised, motion):
			return false
		var ahead := raised.translated(motion)
		var landing := KinematicCollision3D.new()
		if not body.test_move(ahead, Vector3.DOWN * (MAX_STEP + 0.05), landing):
			return false
		var landed := ahead.translated(landing.get_travel())
		if landed.origin.y - start.origin.y < 0.02:
			return false
		if landing.get_normal().y >= cos(body.floor_max_angle):
			body.global_transform = landed
			return true
	return false
