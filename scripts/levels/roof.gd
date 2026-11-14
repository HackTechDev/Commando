class_name Roof
extends Node3D
## Toit d'un bâtiment (plafond et ce qui repose dessus), construit par
## `UfoMapLevel` : il s'efface en fondu quand un opérateur est dessous, pour
## qu'on voie l'intérieur, et réapparaît quand il n'y a plus personne.
## Effacé, il ne masque plus les clics destinés au sol de l'intérieur
## (`is_revealed_body`), mais son corps reste solide : on peut toujours s'y
## tenir et il masque toujours la vue.

## Durée du fondu, en secondes.
const FADE_TIME := 0.3
## Intervalle entre deux recherches d'opérateurs dessous, en secondes.
const CHECK_INTERVAL := 0.1

## Emprises au sol du plafond (rectangles x, z du monde).
var areas: Array[Rect2] = []
## Hauteur (y du monde) du dessous du plafond : un opérateur est « dessous »
## s'il est dans une emprise et plus bas que ça.
var ceiling: float = 0.0
## Maillage affiché et corps de collision du toit.
var view: MeshInstance3D
var body: StaticBody3D

## 0 : toit affiché ; 1 : toit effacé.
var _fade: float = 0.0
var _occupied: bool = false
var _check_left: float = 0.0


## Vrai si `point` (pieds d'une unité) est sous ce toit.
func covers(point: Vector3) -> bool:
	if point.y >= ceiling:
		return false
	var flat := Vector2(point.x, point.z)
	for area in areas:
		if area.has_point(flat):
			return true
	return false


## Vrai si `collider` est le corps d'un toit effacé (les clics le traversent).
static func is_revealed_body(collider: Object) -> bool:
	var body := collider as Node
	if body == null:
		return false
	var roof := body.get_parent() as Roof
	return roof != null and roof.body == body and roof._fade > 0.5


## Vrai si le toit est (en train d'être) effacé.
func is_revealed() -> bool:
	return _occupied or _fade > 0.0


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		_occupied = _has_operator_below()
	var target := 1.0 if _occupied else 0.0
	if is_equal_approx(_fade, target):
		return
	_fade = move_toward(_fade, target, delta / FADE_TIME)
	_apply_fade()


func _has_operator_below() -> bool:
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and covers(unit.global_position):
			return true
	return false


func _apply_fade() -> void:
	if view:
		view.transparency = _fade
		view.visible = _fade < 1.0
		# Un toit effacé ne fait plus d'ombre : l'intérieur s'éclaire.
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _fade > 0.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
