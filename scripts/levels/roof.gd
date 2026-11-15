class_name Roof
extends Node3D
## Toit d'un bâtiment (plafond et ce qui repose dessus), construit par
## `UfoMapLevel` : il s'efface en fondu quand un opérateur est dessous, pour
## qu'on voie l'intérieur, et réapparaît quand il n'y a plus personne.
## Effacé, il ne masque plus les clics destinés au sol de l'intérieur
## (`is_revealed_body`), mais son corps reste solide : on peut toujours s'y
## tenir et il masque toujours la vue.
##
## Étages : le joueur peut aussi choisir un niveau de vue (`view_level`) ;
## les toits de cet étage et des étages supérieurs sont alors effacés, qu'il y
## ait quelqu'un dessous ou non.

## Durée du fondu, en secondes.
const FADE_TIME := 0.3
## Intervalle entre deux recherches d'opérateurs dessous, en secondes.
const CHECK_INTERVAL := 0.1
## Marge (m) sous le sol d'une emprise (pente, marche) pour y être encore.
const FLOOR_TOLERANCE := 0.5

## Emprises au sol de l'intérieur couvert (rectangles x, z du monde), avec la
## hauteur (y du monde) du sol et du plafond de chacune : un opérateur est
## « dessous » s'il est dans une emprise, entre son sol et son plafond.
var areas: Array[Rect2] = []
var floors: Array[float] = []
var ceilings: Array[float] = []
## Plafond le plus bas.
var ceiling: float = 0.0
## Toits des étages inférieurs du même bâtiment : un opérateur sous l'un
## d'eux efface aussi celui-ci.
var below: Array[Roof] = []
## Maillage affiché et corps de collision du toit.
var view: MeshInstance3D
var body: StaticBody3D

## 0 : toit affiché ; 1 : toit effacé.
var _fade: float = 0.0
var _occupied: bool = false
## Un opérateur est directement sous ce toit.
var _inside: bool = false
var _check_left: float = 0.0

## Niveau de vue choisi par le joueur : les toits d'étage (`storey`) égal ou
## supérieur sont effacés. -1 : aucun effacement imposé.
static var view_level: int = -1


func _ready() -> void:
	add_to_group(&"roofs")


## Étage que ce toit couvre : 0 pour le rez-de-chaussée, 1 pour le premier
## étage (un toit plus bas dessous), etc.
func storey() -> int:
	return below.size()


## Nombre d'étages couverts par les toits de la partie (0 sans toit).
static func storey_count(tree: SceneTree) -> int:
	var count := 0
	for node in tree.get_nodes_in_group(&"roofs"):
		count = maxi(count, (node as Roof).storey() + 1)
	return count


## Vrai si `point` (pieds d'une unité) est sous ce toit.
func covers(point: Vector3) -> bool:
	var flat := Vector2(point.x, point.z)
	for i in areas.size():
		if areas[i].has_point(flat) and point.y < ceilings[i] and point.y > floors[i] - FLOOR_TOLERANCE:
			return true
	return false


## Vrai si `collider` est le corps d'un toit effacé (les clics le traversent).
static func is_revealed_body(collider: Object) -> bool:
	var body := collider as Node
	if body == null:
		return false
	var roof := body.get_parent() as Roof
	return roof != null and roof.body == body and roof._fade > 0.5


## Vrai si une emprise de ce toit chevauche une de `other`.
func overlaps(other: Roof) -> bool:
	for area in areas:
		for other_area in other.areas:
			if area.intersects(other_area):
				return true
	return false


## Vrai si le toit est (en train d'être) effacé.
func is_revealed() -> bool:
	return _occupied or _fade > 0.0


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		_inside = _has_operator_below()
		_occupied = _inside or below.any(func(roof: Roof) -> bool: return roof._inside) \
				or (view_level >= 0 and storey() >= view_level)
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
