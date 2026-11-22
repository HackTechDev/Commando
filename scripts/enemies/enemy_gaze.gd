class_name EnemyGaze
extends RefCounted
## Regard d'un ennemi (le cône de vision suit la tête). Au calme : coups
## d'œil sur le côté de temps en temps (plus souvent et plus loin s'il est
## vigilant), balayage de gauche à droite pendant les pauses et les haltes
## de la ronde (pas un garde fixe, qui n'a que les coups d'œil). Une cible
## en vue (jauge qui monte) retient son regard. Ailleurs, il regarde droit
## devant (ce qu'il fixe, il le fixe du corps entier).

## Coups d'œil : angle (degrés), durée et intervalle (s), tirés au hasard.
const GLANCE_ANGLE := Vector2(25.0, 55.0)
const GLANCE_TIME := Vector2(1.0, 1.8)
const GLANCE_INTERVAL := Vector2(3.0, 8.0)
## Balayage : amplitude (degrés) et vitesse.
const SCAN_ANGLE := 60.0
const SCAN_SPEED := 1.3
## Vitesse de rotation du regard (rad/s).
const GAZE_SPEED := 2.2

var enemy: Enemy
## Lacet du regard par rapport au corps (rad).
var yaw: float = 0.0
var _glance_yaw: float = 0.0
var _glance_left: float = 0.0
var _glance_wait: float = 0.0
var _scan_phase: float = 0.0


func _init(owner: Enemy) -> void:
	enemy = owner


## Premier intervalle avant un coup d'œil (au `_ready` de l'ennemi).
func start() -> void:
	_glance_wait = GameRng.of(enemy).randf_range(GLANCE_INTERVAL.x, GLANCE_INTERVAL.y)


## Une image ; `walking` : il se déplace.
func update(delta: float, walking: bool) -> void:
	var goal := 0.0
	var calm := enemy.state == Enemy.State.PATROL and enemy.activity == Enemy.Activity.NONE and not enemy._model.aiming
	if calm and is_instance_valid(enemy._target):
		# Quelque chose a attiré son regard : il ne s'en détourne pas.
		var local := enemy.to_local(enemy._target.global_position)
		goal = clampf(atan2(-local.x, -local.z), -deg_to_rad(SCAN_ANGLE), deg_to_rad(SCAN_ANGLE))
		_glance_left = 0.0
	elif calm and not walking and not enemy.stationary and not enemy._waypoints.is_empty() and enemy.patrol_behavior.is_stopped():
		_scan_phase += delta * SCAN_SPEED
		goal = sin(_scan_phase) * deg_to_rad(SCAN_ANGLE)
		_glance_left = 0.0
	elif calm:
		_scan_phase = 0.0
		var wary := enemy.wary_left > 0.0
		if _glance_left > 0.0:
			_glance_left -= delta
			goal = _glance_yaw
		else:
			_glance_wait -= delta * (2.0 if wary else 1.0)
			if _glance_wait <= 0.0:
				var rng := GameRng.of(enemy)
				_glance_wait = rng.randf_range(GLANCE_INTERVAL.x, GLANCE_INTERVAL.y)
				_glance_left = rng.randf_range(GLANCE_TIME.x, GLANCE_TIME.y)
				var angle := rng.randf_range(GLANCE_ANGLE.x, GLANCE_ANGLE.y) * (1.2 if wary else 1.0)
				_glance_yaw = deg_to_rad(angle) * GameRng.side(enemy)
	else:
		_glance_left = 0.0
		_scan_phase = 0.0
	yaw = move_toward(yaw, goal, GAZE_SPEED * delta)
	enemy._vision.rotation.y = yaw
