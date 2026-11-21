class_name MountedGun
extends RefCounted
## Arme montée sur un véhicule (canon latéral du convertible, mitrailleuse
## de 12,7 du Sabre). Servie (`update` avec `manned`), elle cherche l'ennemi
## debout le plus proche qu'elle peut atteindre (`covers` : son champ de
## tir ; en vue, ou seulement derrière une caisse ou un mur fragile que ses
## balles rongent), pivote vers lui (`pivot`, bouche vers -Z) et tire des
## rafales. Une balle blesse le premier ennemi touché ou abîme le premier
## objet destructible (`take_shot`). Chaque rafale fait du bruit. Une cible
## désignée (`designated` : ennemi, caisse…) passe avant toute autre, tant
## qu'elle tient debout et reste à portée.

## Couches touchées : murs, caisses, ennemis debout ou au sol.
const MASK := 0b11011

## Véhicule porteur (monde physique, bruit, scène des effets).
var vehicle: Node3D
## Pivot orienté vers la cible (bouche vers -Z) et bouche dans son repère.
var pivot: Node3D
var muzzle_local: Vector3
## Portée, dégâts d'une balle, rafale (coups, intervalle, pause en s), écart
## (m par m de distance), bruit d'une rafale, vitesse de visée (rad/s),
## tolérance de visée (rad), intervalle de recherche de cible (s).
var reach: float = 40.0
var damage: float = 45.0
var burst: int = 6
var round_interval: float = 0.09
var burst_pause: float = 0.9
var spread: float = 0.035
var noise: float = 50.0
var turn_speed: float = 3.0
var aim_tolerance: float = 0.12
var search_interval: float = 0.3
var tracer_color := Color(1.0, 0.75, 0.35)
## Champ de tir : (point monde) -> bool.
var covers: Callable
## Corps à ignorer (le véhicule lui-même) : () -> Array[RID].
var excluded: Callable
## Appelé au début de chaque rafale.
var on_burst: Callable

var target: Enemy
## Cible désignée par le joueur (ennemi ou objet destructible), ou null.
var designated: Node3D
var _search_left: float = 0.0
var _rounds_left: int = 0
var _cooldown: float = 0.0


func _init(carrier: Node3D, gun_pivot: Node3D, muzzle: Vector3) -> void:
	vehicle = carrier
	pivot = gun_pivot
	muzzle_local = muzzle


## Bouche de l'arme (monde).
func muzzle() -> Vector3:
	return pivot.to_global(muzzle_local)


## Arme lâchée : plus de cible ni de rafale en cours.
func reset() -> void:
	target = null
	designated = null
	_rounds_left = 0
	_search_left = 0.0


## Vrai si l'arme peut tirer sur `enemy`.
func can_reach(enemy: Enemy) -> bool:
	var aim := enemy.global_position + Vector3.UP * 1.0
	if pivot.global_position.distance_to(aim) > reach or (covers.is_valid() and not covers.call(aim)):
		return false
	var query := PhysicsRayQueryParameters3D.create(muzzle(), aim, MASK, _excluded())
	var hit := vehicle.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit["collider"] as Node
	return collider == enemy or (collider != null and collider.has_method(&"take_shot"))


## Vrai tant que la cible désignée `node` vaut la peine (ennemi debout,
## objet intact).
static func designation_alive(node: Node3D) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return false
	var enemy := node as Enemy
	if enemy:
		return not enemy.is_dead and enemy.state != Enemy.State.STUNNED
	if node.get(&"is_broken") == true or node.get(&"is_destroyed") == true or node.get(&"is_wrecked") == true:
		return false
	return true


## Point visé sur la cible désignée.
static func designation_point(node: Node3D) -> Vector3:
	if node is Enemy:
		return node.global_position + Vector3.UP * 1.0
	var crate := node as Climbable
	if crate:
		return crate.global_position + Vector3.UP * crate.top_height * 0.5
	return node.global_position + Vector3.UP * 0.8


## Vrai si l'arme peut tirer sur `point` de `node` (portée, champ, vue ou
## obstacle qu'elle ronge).
func _reaches_point(point: Vector3, node: Node3D) -> bool:
	if pivot.global_position.distance_to(point) > reach or (covers.is_valid() and not covers.call(point)):
		return false
	var query := PhysicsRayQueryParameters3D.create(muzzle(), point, MASK, _excluded())
	var hit := vehicle.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit["collider"] as Node
	return collider == node or (collider != null and collider.has_method(&"take_shot"))


## À chaque image : cherche, vise et tire si l'arme est servie.
func update(delta: float, manned: bool) -> void:
	if not manned:
		if target:
			reset()
		return
	_cooldown -= delta
	_search_left -= delta
	if designated and not designation_alive(designated):
		designated = null
	if target and (not is_instance_valid(target) or target.is_dead or target.state == Enemy.State.STUNNED):
		target = null
	if _search_left <= 0.0:
		_search_left = search_interval
		if designated == null and (target == null or not can_reach(target)):
			target = _find_target()
			# Faute d'ennemi à pied : un véhicule ennemi à portée.
			if target == null:
				designated = _find_vehicle()
	var aim: Vector3
	if designated and _reaches_point(designation_point(designated), designated):
		aim = designation_point(designated)
	elif target:
		aim = target.global_position + Vector3.UP * 1.0
	else:
		_rounds_left = 0
		return
	var parent := pivot.get_parent() as Node3D
	var wanted := parent.global_basis.inverse() * (aim - pivot.global_position)
	if wanted.length_squared() < 0.01:
		return
	var goal := Quaternion(Basis.looking_at(wanted.normalized(), Vector3.UP))
	pivot.quaternion = pivot.quaternion.slerp(goal, minf(1.0, delta * turn_speed * 2.0))
	var barrel := -pivot.global_basis.z.normalized()
	if barrel.angle_to((aim - pivot.global_position).normalized()) > aim_tolerance or _cooldown > 0.0:
		return
	if _rounds_left <= 0:
		_rounds_left = burst
		EventBus.noise_emitted.emit(vehicle.global_position, noise, &"gunshot")
		if on_burst.is_valid():
			on_burst.call()
	_rounds_left -= 1
	_cooldown = round_interval if _rounds_left > 0 else burst_pause
	_fire_round(aim)


func _excluded() -> Array[RID]:
	if excluded.is_valid():
		return excluded.call()
	return []


## Ennemi debout le plus proche que l'arme peut atteindre, ou null.
## Véhicule ennemi debout le plus proche à portée et en vue, ou null.
func _find_vehicle() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node in vehicle.get_tree().get_nodes_in_group(Technical.GROUP):
		var other := node as Node3D
		if other == null or other == vehicle or not designation_alive(other):
			continue
		var distance := pivot.global_position.distance_to(other.global_position)
		if distance < best_distance and _reaches_point(designation_point(other), other):
			best = other
			best_distance = distance
	return best


func _find_target() -> Enemy:
	var best: Enemy = null
	var best_distance := INF
	var from := pivot.global_position
	for node in vehicle.get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy.state == Enemy.State.STUNNED:
			continue
		var distance := from.distance_to(enemy.global_position)
		if distance < best_distance and can_reach(enemy):
			best = enemy
			best_distance = distance
	return best


## Un coup vers `aim`, avec un écart qui croît avec la distance.
func _fire_round(aim: Vector3) -> void:
	var from := muzzle()
	var scatter := spread * from.distance_to(aim)
	aim += Vector3(randf_range(-scatter, scatter), randf_range(-scatter, scatter) * 0.6, randf_range(-scatter, scatter))
	var direction := (aim - from).normalized()
	var query := PhysicsRayQueryParameters3D.create(from, aim + direction * ShotImpact.MISS_RANGE, MASK, _excluded())
	var hit := vehicle.get_world_3d().direct_space_state.intersect_ray(query)
	var scene := vehicle.get_tree().current_scene as Node3D
	if scene == null:
		scene = vehicle.get_parent() as Node3D
	var end := aim + direction * 4.0
	if not hit.is_empty():
		end = hit["position"]
		var struck := hit["collider"] as Node
		if struck is Enemy and not (struck as Enemy).is_dead:
			ShotImpact.hit(scene, struck as Node3D, end, from, damage, false)
			(struck as Enemy).take_hit(damage, from)
		else:
			ShotImpact.burst(scene, end, hit["normal"], ShotImpact.DUST, 10, 2.2)
			if struck and struck.has_method(&"take_shot"):
				struck.call(&"take_shot", damage, end, from)
	Tracer.spawn(scene, from, end, tracer_color)
	Sfx.play_at(&"shot", from, 2.0)
