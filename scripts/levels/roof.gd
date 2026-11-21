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
## ait quelqu'un dessous ou non. Un toit survolé par la souris s'efface aussi.

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

## Marge (m) autour de l'intérieur couvert, effacée avec lui (murs,
## parapets, débord du toit).
const REVEAL_MARGIN := 0.5
## Résolution du masque d'effacement (m par pixel).
const MASK_STEP := 0.25

## Matériaux propres à ce toit (copies de ceux du décor), qui portent son
## masque d'effacement.
var materials: Array[ShaderMaterial] = []

## 0 : toit affiché ; 1 : toit effacé.
var _fade: float = 0.0
var _occupied: bool = false
## Un opérateur est directement sous ce toit.
var _inside: bool = false
var _check_left: float = 0.0

## Niveau de vue choisi par le joueur : les toits d'étage (`storey`) égal ou
## supérieur sont effacés. -1 : aucun effacement imposé.
static var view_level: int = -1
## Toit sous la souris (`PlayerController`) : il s'efface au bout de
## `HOVER_DELAY` secondes, pour voir l'intérieur sans y entrer.
static var hovered: Roof = null
const HOVER_DELAY := 0.8
var _hover_time: float = 0.0


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
	# Immeubles à étages (`Tower`) : un niveau de vue par étage.
	for node in tree.get_nodes_in_group(Tower.GROUP):
		count = maxi(count, (node as Tower).storeys)
	return count


## Vrai si `point` (pieds d'une unité) est sous ce toit.
func covers(point: Vector3) -> bool:
	var flat := Vector2(point.x, point.z)
	for i in areas.size():
		if areas[i].has_point(flat) and point.y < ceilings[i] and point.y > floors[i] - FLOOR_TOLERANCE:
			return true
	return false


## Vrai si `collider` est le corps d'un toit effacé (les clics le
## traversent), touché en `point` (s'il est donné) dans sa partie effacée.
static func is_revealed_body(collider: Object, point: Vector3 = Vector3.INF) -> bool:
	var body := collider as Node
	if body == null:
		return false
	var roof := body.get_parent() as Roof
	if roof == null or roof.body != body or roof._fade <= 0.5:
		return false
	return point == Vector3.INF or roof.reveals_point(point)


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
		_hover_time = _hover_time + CHECK_INTERVAL if hovered == self else 0.0
		_occupied = _inside or _hover_time >= HOVER_DELAY or below.any(func(roof: Roof) -> bool: return roof._inside) \
				or (view_level >= 0 and storey() >= view_level)
	var target := 1.0 if _occupied else 0.0
	if _fade == target:
		return
	_fade = move_toward(_fade, target, delta / FADE_TIME)
	_apply_fade()


func _has_operator_below() -> bool:
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and covers(unit.global_position):
			return true
	return false


## Donne au toit ses propres matériaux, avec le masque de ce qui s'efface :
## l'intérieur couvert (`areas`) et `REVEAL_MARGIN` autour. Une dalle de
## terrain qui couvre une tranchée ne s'efface ainsi qu'au-dessus d'elle.
func prepare_reveal() -> void:
	if view == null or view.mesh == null or areas.is_empty():
		return
	var bounds := areas[0]
	for area in areas:
		bounds = bounds.merge(area)
	bounds = bounds.grow(REVEAL_MARGIN + MASK_STEP)
	var size := Vector2i((bounds.size / MASK_STEP).ceil())
	var image := Image.create_empty(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_R8)
	for area in areas:
		var grown := area.grow(REVEAL_MARGIN)
		var from := Vector2i(((grown.position - bounds.position) / MASK_STEP).floor())
		var to := Vector2i(((grown.end - bounds.position) / MASK_STEP).ceil())
		image.fill_rect(Rect2i(from, to - from), Color.WHITE)
	var mask := ImageTexture.create_from_image(image)
	var rect := Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y)
	var mesh := view.mesh
	for i in mesh.get_surface_count():
		var shared := mesh.surface_get_material(i) as ShaderMaterial
		if shared == null:
			continue
		var own := shared.duplicate() as ShaderMaterial
		for key in shared.get_meta_list():
			own.set_meta(key, shared.get_meta(key))
		own.set_shader_parameter(&"reveal_mask", mask)
		own.set_shader_parameter(&"reveal_rect", rect)
		own.set_shader_parameter(&"reveal", 0.0)
		mesh.surface_set_material(i, own)
		materials.append(own)


## Vrai si `point` (monde) tombe dans la partie effaçable du toit.
func reveals_point(point: Vector3) -> bool:
	var flat := Vector2(point.x, point.z)
	for area in areas:
		if area.grow(REVEAL_MARGIN).has_point(flat):
			return true
	return false


func _apply_fade() -> void:
	# Effacement en pointillé, ombres comprises : l'intérieur s'éclaire.
	for material in materials:
		material.set_shader_parameter(&"reveal", _fade)
