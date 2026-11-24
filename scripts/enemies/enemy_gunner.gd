class_name EnemyGunner
extends RefCounted
## Tir d'un ennemi armé : sur sa cible en alerte (précision selon la
## distance, la posture et la couverture de la cible ; un otage dans la
## ligne de tir le retient), et riposte contre un convertible en l'air (au
## fusil, ou au lance-roquettes, en priorité).

## Riposte contre un convertible en l'air (`Tiltrotor.is_in_air`) : portée
## (part de `fire_range`), intervalle de recherche (s), bonus de précision
## (grande cible).
const AIR_RANGE_SHARE := 1.5
const AIR_CHECK_INTERVAL := 0.25
const AIR_HIT_BONUS := 0.15
## Lance-roquettes : portée contre un appareil en vol (m), temps de visée,
## rechargement (s), écart au point visé (m).
const LAUNCHER_RANGE := 60.0
const LAUNCHER_AIM := 2.2
const LAUNCHER_RELOAD := 6.0
const LAUNCHER_SPREAD := 3.0

var enemy: Enemy
## Délai (s) avant le prochain tir (visée, puis cadence).
var cooldown: float = 0.0
## Cartouches dans le chargeur engagé, et rechargement restant (s).
var magazine: int = 0
var reload_left: float = 0.0
## Convertible en l'air pris pour cible (aucun opérateur en vue), ou null.
var aircraft: Tiltrotor
var _aircraft_check_left: float = 0.0
## Lance-roquettes : visée en cours (s) et rechargement restant (s).
var _launch_aim: float = 0.0
var _launch_reload: float = 0.0


func _init(owner: Enemy) -> void:
	enemy = owner


## Chargeur plein au départ.
func setup() -> void:
	magazine = _full_magazine()
	reload_left = 0.0


## Vrai pendant un rechargement : il ne tire pas.
func is_reloading() -> bool:
	return reload_left > 0.0


## Rechargement en cours (avancé de `delta`) ; au calme, il complète de
## lui-même un chargeur entamé.
func update_reload(delta: float) -> void:
	if not enemy.armed or enemy.disarmed:
		return
	if reload_left <= 0.0:
		if enemy.state == Enemy.State.PATROL and magazine < enemy.stats.magazine_size and enemy.ammo != 0 and magazine < enemy.ammo:
			start_reload()
		return
	reload_left -= delta
	enemy._model.reload_progress = clampf(1.0 - reload_left / enemy.stats.reload_time, 0.0, 1.0)
	if reload_left <= 0.0:
		reload_left = 0.0
		enemy._model.reload_progress = -1.0
		magazine = _full_magazine()


## Commence un rechargement (s'il reste des cartouches).
func start_reload() -> void:
	if is_reloading() or enemy.ammo == 0:
		return
	reload_left = enemy.stats.reload_time
	enemy._model.reload_progress = 0.0
	Sfx.play_at(&"reload", enemy.global_position + Vector3.UP, -6.0)


## Rechargement interrompu (assommé, saisi…) : il le reprendra.
func cancel_reload() -> void:
	reload_left = 0.0
	enemy._model.reload_progress = -1.0


## Une cartouche tirée : chargeur vide, il recharge.
func _spend() -> void:
	magazine -= 1
	if enemy.ammo > 0:
		enemy.ammo -= 1
	if magazine <= 0 and enemy.ammo != 0:
		start_reload()


func _full_magazine() -> int:
	var size := enemy.stats.magazine_size
	return size if enemy.ammo < 0 else mini(size, enemy.ammo)


## Tire sur sa cible (`to_target` : vers elle, à plat) si le délai est
## passé, qu'elle est à portée et à peu près dans l'axe.
func try_fire(delta: float, to_target: Vector3) -> void:
	if not enemy.can_fire():
		return
	var stats := enemy.stats
	cooldown -= delta
	if is_reloading():
		cooldown = maxf(cooldown, stats.aim_time * 0.5)
		return
	if magazine <= 0:
		start_reload()
		return
	var distance := to_target.length()
	if cooldown > 0.0 or distance > stats.fire_range:
		return
	# Ne tire que s'il est à peu près dans l'axe.
	var forward := -enemy.global_basis.z
	if distance > 0.01 and forward.angle_to(to_target) > 0.3:
		return
	cooldown = stats.fire_interval
	if enemy.ammo > 0 or magazine > 0:
		_spend()
		if enemy.ammo == 0:
			# À sec : déclic à vide, puis il charge au corps à corps.
			var shooter := enemy
			enemy.get_tree().create_timer(stats.fire_interval * 0.5, false).timeout.connect(func() -> void:
				if is_instance_valid(shooter) and not shooter.is_dead:
					Sfx.play_at(&"clink", shooter.global_position + Vector3.UP * 1.3, -6.0))

	var target := enemy._target
	var chance := lerpf(stats.hit_chance_near, stats.hit_chance_far, clampf(distance / stats.fire_range, 0.0, 1.0))
	match target.posture:
		SoldierModel.Posture.CROUCHED:
			chance *= 0.8
		SoldierModel.Posture.PRONE:
			chance *= 0.6
	var muzzle := enemy.global_position + Vector3.UP * 1.3 + forward * 0.7
	var aim := target.global_position + Vector3.UP * (0.3 if target.posture == SoldierModel.Posture.PRONE else 1.0)
	var tree := enemy.get_tree()
	if Enemy.hostage_in_the_way(tree, muzzle, aim) != null:
		# Un camarade en bouclier humain : il ne tire pas.
		enemy.hesitations += 1
		return
	# Cible en partie à couvert (caisse, muret, angle de mur) : plus dure à
	# toucher ; la balle manquée finit souvent dans l'abri.
	var ignored: Array[RID] = [enemy.get_rid(), target.get_rid()]
	var ride := target.get(&"riding") as Sabre
	if ride:
		ignored.append_array(ride.body_rids())
	var cover := Cover.measure(enemy.get_world_3d(), muzzle, target.global_position, target.posture, ignored)
	enemy.last_cover = cover
	chance *= cover.hit_factor()
	var hit := GameRng.chance(enemy, chance)
	var scene := tree.current_scene as Node3D
	if not hit and cover.miss_hits_cover(GameRng.of(enemy)):
		aim = ShotImpact.land(scene, muzzle, cover.hidden_point, ignored)
	elif not hit:
		var side := enemy.global_basis.x * (0.5 + GameRng.of(enemy).randf() * 0.5) * GameRng.side(enemy)
		aim = ShotImpact.land(scene, muzzle, aim + side, ignored)
	# Un bouclier levé sur la trajectoire arrête la balle.
	var stop := Commando.shield_in_the_way(tree, muzzle, aim)
	Tracer.spawn(scene, muzzle, aim if stop == Vector3.INF else stop)
	enemy._model.play_shot()
	Sfx.play_at(&"shot", muzzle)
	EventBus.noise_emitted.emit(enemy.global_position, stats.gunshot_noise_radius, &"gunshot")
	if stop != Vector3.INF:
		Sfx.play_at(&"ricochet", stop, -2.0)
		ShotImpact.spark(scene, stop, muzzle)
		enemy.shots_blocked += 1
	elif hit and ride == null \
			and Sabre.blocks_shot(tree, muzzle, aim, stats.fire_damage) != null:
		# Abrité derrière un Sabre : la caisse prend la balle.
		Sfx.play_at(&"ricochet", aim, -2.0)
		ShotImpact.spark(scene, aim, muzzle)
		enemy.shots_blocked += 1
	elif hit and ride != null and ride.shields_rider(stats.fire_damage, muzzle):
		# Passager du Sabre : la carrosserie a pris la balle.
		Sfx.play_at(&"ricochet", aim, -2.0)
		ShotImpact.spark(scene, aim, muzzle)
		enemy.shots_blocked += 1
	elif hit:
		ShotImpact.hit(scene, target, aim, muzzle, stats.fire_damage, true)
		target.health.take_damage(stats.fire_damage)


## Cherche un convertible en l'air à abattre : seulement armé, sans
## opérateur en vue, à portée et en vue directe.
func update_aircraft_target(delta: float) -> void:
	if aircraft and (not is_instance_valid(aircraft) or not aircraft.is_in_air() or aircraft.is_disabled):
		aircraft = null
	_aircraft_check_left -= delta
	if _aircraft_check_left > 0.0:
		return
	_aircraft_check_left = AIR_CHECK_INTERVAL
	var previous := aircraft
	aircraft = null
	var anti_air := enemy.has_rockets()
	if not anti_air and (not enemy.can_fire() or enemy._target != null):
		_launch_aim = 0.0
		return
	var eye := enemy.global_position + Vector3.UP * 1.5
	var reach := LAUNCHER_RANGE if anti_air else enemy.stats.fire_range * AIR_RANGE_SHARE
	for node in enemy.get_tree().get_nodes_in_group(Tiltrotor.GROUP):
		var candidate := node as Tiltrotor
		if candidate and candidate.is_in_air() and not candidate.is_disabled and candidate.exposed_to(eye, reach):
			aircraft = candidate
			if candidate != previous:
				_launch_aim = 0.0
			return
	_launch_aim = 0.0


## Tire sur le convertible pris pour cible, sur place.
func engage_aircraft(delta: float) -> void:
	var target := aircraft.aim_point()
	var to_target := target - enemy.global_position
	to_target.y = 0.0
	enemy._face(to_target, delta)
	if enemy.has_rockets():
		_launch_rocket(delta, target, to_target)
		return
	var stats := enemy.stats
	cooldown -= delta
	if cooldown > 0.0 or not enemy.can_fire() or is_reloading():
		return
	if magazine <= 0:
		start_reload()
		return
	var forward := -enemy.global_basis.z
	if to_target.length() > 0.5 and forward.angle_to(to_target) > 0.3:
		return
	cooldown = stats.fire_interval
	_spend()
	var muzzle := enemy.global_position + Vector3.UP * 1.3 + forward * 0.7
	var reach := stats.fire_range * AIR_RANGE_SHARE
	var chance := lerpf(stats.hit_chance_near, stats.hit_chance_far, clampf(muzzle.distance_to(target) / reach, 0.0, 1.0)) + AIR_HIT_BONUS
	var scene := _scene()
	var rng := GameRng.of(enemy)
	var spread := Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(-0.6, 0.8), rng.randf_range(-1.2, 1.2))
	if rng.randf() < chance:
		var query := PhysicsRayQueryParameters3D.create(muzzle, target + spread, Tiltrotor.LAYER_OCCLUDERS, [enemy.get_rid()])
		var hit := enemy.get_world_3d().direct_space_state.intersect_ray(query)
		var at: Vector3 = hit.get("position", target)
		Tracer.spawn(scene, muzzle, at)
		aircraft.take_hit(stats.fire_damage, at, muzzle)
	else:
		# Balle qui passe à côté, vers le ciel.
		var miss := target + spread * 3.0 + Vector3.UP * 2.0
		Tracer.spawn(scene, muzzle, muzzle + (miss - muzzle) * 1.6)
	enemy._model.play_shot()
	Sfx.play_at(&"shot", muzzle)
	EventBus.noise_emitted.emit(enemy.global_position, stats.gunshot_noise_radius, &"gunshot")


## Lance-roquettes : visée (`LAUNCHER_AIM`), puis une roquette vers
## l'appareil, avec un écart ; rechargement entre deux.
func _launch_rocket(delta: float, target: Vector3, to_target: Vector3) -> void:
	_launch_reload = maxf(_launch_reload - delta, 0.0)
	var forward := -enemy.global_basis.z
	if to_target.length() > 0.5 and forward.angle_to(to_target) > 0.3:
		return
	_launch_aim += delta
	if _launch_aim < LAUNCHER_AIM or _launch_reload > 0.0:
		return
	_launch_aim = 0.0
	_launch_reload = LAUNCHER_RELOAD
	enemy.rockets -= 1
	var muzzle := enemy.global_position + Vector3.UP * 1.55 + forward * 0.5
	var rng := GameRng.of(enemy)
	var scatter := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.5, 0.5), rng.randf_range(-1.0, 1.0)) * LAUNCHER_SPREAD
	Rocket.launch(_scene(), muzzle, target + scatter, [enemy.get_rid()])
	EventBus.noise_emitted.emit(enemy.global_position, enemy.stats.gunshot_noise_radius * 1.5, &"gunshot")
	if enemy.rockets <= 0:
		enemy._model.set_launcher(false)


func _scene() -> Node3D:
	var scene := enemy.get_tree().current_scene as Node3D
	return scene if scene != null else enemy.get_parent() as Node3D
