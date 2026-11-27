class_name EnemyChat
extends RefCounted
## Discussion entre deux gardes (`Enemy.talk_partner`, lien posé des deux
## côtés). Tant qu'ils sont au calme, à leur poste et à moins de
## `RANGE` m l'un de l'autre, ils se font face et bavardent (bulle « … »
## au-dessus de celui qui parle) : ils repèrent moins vite (`GAIN`).
##
## Chacun remarque la disparition de l'autre : partenaire tué, assommé,
## saisi, emporté, ou parti hors de vue (plus de `MISS_RANGE` m) sans
## mission ni alerte. Après `MISS_DELAY` s, le garde resté devient méfiant
## et va voir là où l'autre se tenait (`Enemy.investigate`). Le lien est
## alors rompu.

const RANGE := 4.0
const MISS_RANGE := 8.0
const MISS_DELAY := 3.0
## Facteur de la jauge de repérage pendant la discussion.
const GAIN := 0.5
## Temps de parole (s) de chacun, tiré au hasard.
const TURN_TIME := Vector2(1.8, 3.5)
const BUBBLE_HEIGHT := 2.25
const BUBBLE_TEXTS: Array[String] = ["…", "… ah ah", "… ouais", "…?"]

var enemy: Enemy
var partner: Enemy
## En pleine discussion (cette image).
var active: bool = false
## Prend la parole (bulle affichée).
var speaking: bool = false
## Disparition remarquée : lien rompu.
var noticed: bool = false
var _spot: Vector3 = Vector3.INF
var _missing_left: float = -1.0
var _turn_left: float = 0.0
var _bubble: Label3D


func _init(owner: Enemy) -> void:
	enemy = owner


## Lie `other` (et lui à cet ennemi) ; le premier des deux parle.
func setup(other: Enemy) -> void:
	if other == null or other == enemy:
		return
	partner = other
	if other.chat.partner == null:
		other.chat.partner = enemy
		other.chat._spot = enemy.global_position
		speaking = true
	_spot = other.global_position
	_turn_left = GameRng.of(enemy).randf_range(TURN_TIME.x, TURN_TIME.y)


func _make_bubble() -> void:
	_bubble = Label3D.new()
	_bubble.name = "ChatBubble"
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.font_size = 64
	_bubble.outline_size = 10
	_bubble.pixel_size = 0.01
	_bubble.modulate = Color(0.95, 0.95, 0.85)
	_bubble.position = Vector3.UP * BUBBLE_HEIGHT
	_bubble.visible = false
	enemy.add_child(_bubble)


## Facteur de repérage : `GAIN` en pleine discussion, sinon 1.
func gain() -> float:
	return GAIN if active else 1.0


## Une image (au calme ou non). `moving` : l'ennemi se déplace.
func update(delta: float, moving: bool) -> void:
	if partner == null or noticed:
		_set_active(false)
		return
	if not is_instance_valid(partner):
		_watch_missing(delta, true)
		_set_active(false)
		return
	var gone := _is_gone()
	_watch_missing(delta, gone)
	var close := enemy.global_position.distance_to(partner.global_position) <= RANGE
	_set_active(not gone and close and not moving and _at_ease(enemy) and _at_ease(partner))
	if close and _at_ease(partner):
		_spot = partner.global_position
	if not active:
		return
	if _bubble == null:
		_make_bubble()
	enemy._face(partner.global_position - enemy.global_position, delta)
	_turn_left -= delta
	if _turn_left <= 0.0:
		_turn_left = GameRng.of(enemy).randf_range(TURN_TIME.x, TURN_TIME.y)
		speaking = not speaking
		if speaking:
			_bubble.text = BUBBLE_TEXTS[GameRng.of(enemy).randi() % BUBBLE_TEXTS.size()]
	_bubble.visible = speaking


func _set_active(value: bool) -> void:
	active = value
	if _bubble and not value:
		_bubble.visible = false


## Au calme à son poste ou sur sa ronde, sans activité.
static func _at_ease(who: Enemy) -> bool:
	return not who.is_dead and who.state == Enemy.State.PATROL and who.behavior == who.patrol_behavior \
			and who.carrier == null and who.on_vehicle == null


## Le partenaire a disparu : neutralisé, emporté, ou parti au loin sans
## raison connue (une mission, une enquête ou une alerte n'en sont pas).
func _is_gone() -> bool:
	if partner.is_dead or partner.state == Enemy.State.STUNNED or partner.state == Enemy.State.GRABBED \
			or partner.carrier != null:
		return true
	# Un partenaire en ronde s'éloigne normalement : seul un garde posté
	# « disparaît » en s'en allant.
	return _at_ease(partner) and partner._waypoints.is_empty() \
			and enemy.global_position.distance_to(partner.global_position) > MISS_RANGE


func _watch_missing(delta: float, gone: bool) -> void:
	if not gone:
		_missing_left = -1.0
		return
	if _missing_left < 0.0:
		_missing_left = MISS_DELAY
	_missing_left -= delta
	if _missing_left > 0.0 or enemy.is_dead or enemy.behavior.takes_over():
		return
	# Déjà méfiant ou en alerte : il a mieux à faire, mais l'a remarqué.
	noticed = true
	_set_active(false)
	if enemy.state == Enemy.State.PATROL and _spot != Vector3.INF:
		enemy.investigate(_spot)


func save_state() -> Dictionary:
	return {"noticed": noticed}


func load_state(data: Dictionary) -> void:
	noticed = data.get("noticed", false)
	_missing_left = -1.0
