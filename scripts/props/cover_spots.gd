class_name CoverSpots
extends RefCounted
## Places à l'abri derrière un véhicule (Sabre, voiture) : côté opposé aux
## ennemis, côte à côte le long de la caisse (« S'abriter derrière »).


## Direction (à plat) des ennemis à craindre vus depuis `origin` : moyenne
## des ennemis en alerte ou méfiants, sinon le plus proche debout ;
## `fallback` s'il n'y en a aucun.
static func threat_direction(tree: SceneTree, origin: Vector3, fallback: Vector3) -> Vector3:
	var sum := Vector3.ZERO
	var nearest := Vector3.ZERO
	var nearest_distance := INF
	for node in tree.get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy.state == Enemy.State.STUNNED:
			continue
		var to_enemy := enemy.global_position - origin
		to_enemy.y = 0.0
		if enemy.state != Enemy.State.PATROL:
			sum += to_enemy.normalized()
		if to_enemy.length() < nearest_distance:
			nearest_distance = to_enemy.length()
			nearest = to_enemy.normalized()
	var direction := sum if sum.length() > 0.1 else nearest
	return direction.normalized() if direction.length() > 0.1 else fallback


## `count` points au sol, côte à côte, derrière une caisse de demi-largeur
## `half_width` et demi-longueur `half_length` placée en `frame`, par
## rapport à la direction `threat` ; ramenés sur le maillage de navigation
## de `world`.
static func points(world: World3D, frame: Transform3D, half_width: float, half_length: float, threat: Vector3, count: int) -> Array[Vector3]:
	var local := frame.basis.inverse() * threat
	local.y = 0.0
	local = local.normalized()
	# Distance du centre au bord de la caisse dans cette direction.
	var edge := minf(half_width / maxf(absf(local.x), 0.01), half_length / maxf(absf(local.z), 0.01))
	var across := Vector3(-threat.z, 0.0, threat.x)
	# Longueur abritée, le long de la caisse vue des ennemis.
	var span := absf(local.x) * half_length * 2.0 + absf(local.z) * half_width * 2.0
	var map := world.navigation_map
	var result: Array[Vector3] = []
	for i in count:
		var offset := 0.0 if count == 1 else lerpf(-0.5, 0.5, float(i) / (count - 1)) * minf(span - 0.6, count * 0.9)
		result.append(NavigationServer3D.map_get_closest_point(map, frame.origin - threat * (edge + 0.65) + across * offset))
	return result


## Envoie `units` en `spots`, accroupis.
static func send(units: Array[Commando], spots: Array[Vector3], run: bool) -> void:
	for i in units.size():
		var unit := units[i]
		unit.move_to(spots[i], run)
		if unit.posture != SoldierModel.Posture.CROUCHED:
			unit.toggle_posture(SoldierModel.Posture.CROUCHED)
