extends Node
## Unités sélectionnées et transmission des ordres.
##
## Ordres simultanés : en mode préparation (`planning`), les ordres donnés
## (déplacement, attaque, tir libre, couteau, lancer, grenade, fumigène, grappin,
## caisse, escalade, pose et mise à feu d'une charge, soins, roulade) ne
## partent pas : chaque unité garde le dernier reçu, et
## `execute_plans` les lance tous ensemble. Les gestes immédiats (posture,
## rechargement, arrêt…) ne se préparent pas.

signal selection_changed(units: Array[Commando])
## Ordres préparés modifiés (ajout, exécution, abandon).
signal plans_changed
## Mode préparation activé ou désactivé.
signal planning_changed(active: bool)

## Écart entre unités lorsqu'un ordre de déplacement vise plusieurs unités.
const FORMATION_SPACING := 1.1

var selected: Array[Commando] = []
## Mode préparation des ordres simultanés.
var planning: bool = false
## Ordres préparés : {Commando: {"call": Callable, "point": Vector3, "kind": StringName}}.
var _plans: Dictionary = {}


## Remplace (ou complète si `additive`) la sélection courante.
func select(units: Array[Commando], additive: bool = false) -> void:
	if not additive:
		for unit in selected:
			if is_instance_valid(unit) and not units.has(unit):
				unit.set_selected(false)
		selected.clear()
	for unit in units:
		if not selected.has(unit) and not unit.is_dead:
			selected.append(unit)
			unit.set_selected(true)
	selection_changed.emit(selected)


## Retire une unité de la sélection (unité morte, par exemple).
func remove(unit: Commando) -> void:
	if selected.has(unit):
		selected.erase(unit)
		unit.set_selected(false)
		selection_changed.emit(selected)


## Vide la sélection.
func clear() -> void:
	select([] as Array[Commando])


## Active ou désactive le mode préparation. Le quitter sans exécuter
## abandonne les ordres préparés.
func set_planning(active: bool) -> void:
	if active == planning:
		return
	planning = active
	if not active and not _plans.is_empty():
		_plans.clear()
		plans_changed.emit()
	planning_changed.emit(planning)


## Ordres préparés (voir `_plans`), unités mortes ou retirées exclues.
func planned_orders() -> Dictionary:
	for unit: Commando in _plans.keys():
		if not is_instance_valid(unit) or unit.is_dead:
			_plans.erase(unit)
	return _plans


## Lance tous les ordres préparés en même temps et quitte le mode
## préparation. Renvoie le nombre d'ordres acceptés.
func execute_plans() -> int:
	var accepted := 0
	var plans := planned_orders().duplicate()
	_plans.clear()
	planning = false
	for unit: Commando in plans:
		var result: Variant = (plans[unit]["call"] as Callable).call()
		if not (result is bool) or result:
			accepted += 1
	plans_changed.emit()
	planning_changed.emit(false)
	return accepted


## Donne l'ordre `call` à `unit`, ou le garde pour plus tard en mode
## préparation (`point` : où il mène, pour l'afficher). Renvoie le résultat de
## l'ordre (vrai en préparation).
func _issue(unit: Commando, call: Callable, point: Vector3, kind: StringName) -> bool:
	if planning:
		_plans[unit] = {"call": call, "point": point, "kind": kind}
		plans_changed.emit()
		return true
	var result: Variant = call.call()
	return result if result is bool else true


## Ordonne aux unités sélectionnées de rejoindre `target` (en formation).
func order_move(target: Vector3, run: bool) -> void:
	var count := selected.size()
	for i in count:
		var offset := Vector3.ZERO
		if count > 1:
			var angle := TAU * float(i) / float(count)
			offset = Vector3(cos(angle), 0.0, sin(angle)) * FORMATION_SPACING
		# Une unité qui tient une caisse la déplace vers le point visé.
		var point := target if selected[i].is_handling_crate() else target + offset
		_issue(selected[i], selected[i].move_to.bind(point, run), point, &"move")


## Envoie les unités sélectionnées (pas encore à bord) monter dans `sabre`.
## Renvoie vrai si au moins une a obéi.
func order_mount(sabre: Sabre, run: bool) -> bool:
	var any := false
	for unit in selected:
		any = sabre.request_board(unit, run) or any
	return any


## Envoie les unités sélectionnées au pied de la corde de `aircraft` (en vol
## stationnaire), pour y être hélitreuillées. Renvoie vrai si au moins une a
## obéi.
func order_winch(aircraft: Tiltrotor, run: bool) -> bool:
	var any := false
	for unit in selected:
		any = aircraft.request_winch(unit, run) or any
	return any


## Fait embarquer les unités sélectionnées dans la soute de `aircraft`, les
## unes derrière les autres.
func order_board(aircraft: Tiltrotor, run: bool) -> void:
	for i in selected.size():
		var point := aircraft.cabin_point(i)
		_issue(selected[i], selected[i].move_to.bind(point, run), point, &"move")


## Ordonne aux unités sélectionnées une rafale de tir libre sur `target`
## (mur, objet, sol). Renvoie vrai si au moins une a obéi.
func order_fire_at(target: Vector3, run: bool = false) -> bool:
	var any := false
	for unit in selected:
		any = _issue(unit, unit.fire_at.bind(target, run), target, &"attack") or any
	return any


## Envoie l'unité sélectionnée la plus proche de `body` (mains libres) le
## prendre sur les épaules. Renvoie vrai si une unité a obéi.
func order_carry(body: Enemy, run: bool = false) -> bool:
	var best: Commando
	for unit in selected:
		if unit.carried_body != null or unit.is_dead:
			continue
		if best == null or unit.global_position.distance_to(body.global_position) < best.global_position.distance_to(body.global_position):
			best = unit
	if best == null:
		return false
	return _issue(best, best.carry_body.bind(body, run), body.body_center(), &"move")


## Envoie l'unité sélectionnée la plus proche ouvrir, fermer ou crocheter
## la porte `door`. Renvoie vrai si une unité a obéi.
func order_door(door: Door, run: bool = false) -> bool:
	var best: Commando
	for unit in selected:
		if unit.is_dead:
			continue
		if best == null or unit.global_position.distance_to(door.global_position) < best.global_position.distance_to(door.global_position):
			best = unit
	if best == null:
		return false
	return _issue(best, best.use_door.bind(door, run), door.near_side(best.global_position), &"move")


## Les unités sélectionnées qui portent un corps le déposent. Renvoie vrai
## si au moins une l'a fait.
func drop_bodies() -> bool:
	var any := false
	for unit in selected:
		any = unit.drop_body() or any
	return any


## Ordonne aux unités sélectionnées d'attaquer `enemy`.
func order_attack(enemy: Enemy, run: bool) -> void:
	for unit in selected:
		_issue(unit, unit.attack.bind(enemy, run), enemy.global_position, &"attack")


## Confie l'élimination au corps à corps de `enemy` à l'unité sélectionnée
## la plus proche qui peut s'en charger. Renvoie faux si aucune ne le peut.
func order_melee(enemy: Enemy, kind: Commando.MeleeKind, run: bool = false) -> bool:
	var candidates: Array[Commando] = selected.duplicate()
	candidates.sort_custom(func(a: Commando, b: Commando) -> bool:
		return a.global_position.distance_squared_to(enemy.global_position) < b.global_position.distance_squared_to(enemy.global_position))
	for unit in candidates:
		if planning:
			if not unit.is_dead:
				return _issue(unit, unit.melee.bind(enemy, kind, run), enemy.global_position, &"melee")
		elif unit.melee(enemy, kind, run):
			return true
	return false


## Confie un lancer de couteau sur `enemy` à l'unité sélectionnée la plus
## proche qui a encore un couteau. Renvoie faux si aucune ne le peut.
func order_throw(enemy: Enemy, run: bool = false) -> bool:
	var candidates: Array[Commando] = selected.duplicate()
	candidates.sort_custom(func(a: Commando, b: Commando) -> bool:
		return a.global_position.distance_squared_to(enemy.global_position) < b.global_position.distance_squared_to(enemy.global_position))
	for unit in candidates:
		if planning:
			if not unit.is_dead and unit.throwing_knives > 0:
				return _issue(unit, unit.throw_knife.bind(enemy, run), enemy.global_position, &"melee")
		elif unit.throw_knife(enemy, run):
			return true
	return false


## Fait lâcher leur caisse aux unités sélectionnées. Renvoie faux si
## aucune n'en tenait.
func release_crates() -> bool:
	var released := false
	for unit in selected:
		if unit.is_handling_crate():
			unit.release_crate()
			released = true
	return released


## Fait pivoter d'un huitième de tour les caisses tenues par la sélection.
## Renvoie faux si personne n'en tient.
func turn_crates() -> bool:
	var turned := false
	for unit in selected:
		if unit.is_handling_crate():
			(unit._order as CrateHoldOrder).turn()
			turned = true
	return turned


## Confie la caisse `crate` à l'unité sélectionnée la plus proche, qui se
## place du côté le plus proche de `near`. Renvoie faux si aucune ne le peut.
func order_crate(crate: Climbable, near: Vector3) -> bool:
	var candidates: Array[Commando] = selected.duplicate()
	candidates.sort_custom(func(a: Commando, b: Commando) -> bool:
		return a.global_position.distance_squared_to(near) < b.global_position.distance_squared_to(near))
	for unit in candidates:
		if planning:
			if not unit.is_dead:
				return _issue(unit, unit.handle_crate.bind(crate, near), crate.global_position, &"move")
		elif unit.handle_crate(crate, near):
			return true
	return false


## Fait grimper une unité sélectionnée sur `target` ; les autres unités au
## sol se regroupent autour.
func order_climb(target: Climbable, run: bool) -> void:
	var climber_found := false
	var others := 0
	for unit in selected:
		if not climber_found and planning and not unit.is_dead:
			climber_found = _issue(unit, unit.climb.bind(target, run), target.get_top_position(), &"move")
		elif not climber_found and not planning and unit.climb(target, run):
			climber_found = true
		elif unit.perched_on == null:
			# Une unité déjà perchée qui ne peut pas y aller reste où elle est.
			var angle := TAU * float(others) / float(maxi(selected.size() - 1, 1))
			var point := target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * (target.half_extent + FORMATION_SPACING)
			_issue(unit, unit.move_to.bind(point, run), point, &"move")
			others += 1


## Annule le déplacement ou l'attaque des unités sélectionnées.
func stop() -> void:
	for unit in selected:
		unit.stop()


## Arrête les unités sélectionnées qui marchent vers une destination.
## Renvoie vrai si au moins une a été arrêtée.
func stop_walkers() -> bool:
	var stopped := false
	for unit in selected:
		if unit.is_walking():
			unit.stop()
			stopped = true
	return stopped


## Fait recharger les unités sélectionnées.
func reload() -> void:
	for unit in selected:
		unit.reload()


## Passe l'arme à la bretelle si au moins une unité sélectionnée l'a en main,
## sinon la fait reprendre en main à toutes.
func toggle_sling() -> void:
	var sling := selected.any(func(unit: Commando) -> bool: return not unit.weapon_slung)
	for unit in selected:
		unit.weapon_slung = sling


## Applique une posture à toutes les unités sélectionnées (bascule).
func toggle_posture(posture: SoldierModel.Posture) -> void:
	for unit in selected:
		unit.toggle_posture(posture)


## Confie un lancer de grenade vers `target` à l'unité sélectionnée la plus
## proche qui en a encore. Renvoie faux si aucune ne le peut.
func order_grenade(target: Vector3, run: bool = false) -> bool:
	for unit in _nearest_first(target):
		if planning:
			if not unit.is_dead and unit.grenades > 0:
				return _issue(unit, unit.throw_grenade.bind(target, run), target, &"attack")
		elif unit.throw_grenade(target, run):
			return true
	return false


## Confie un lancer de fumigène vers `target` à l'unité sélectionnée la plus
## proche qui en a encore. Renvoie faux si aucune ne le peut.
func order_smoke(target: Vector3, run: bool = false) -> bool:
	for unit in _nearest_first(target):
		if planning:
			if not unit.is_dead and unit.smoke_grenades > 0:
				return _issue(unit, unit.throw_smoke.bind(target, run), target, &"attack")
		elif unit.throw_smoke(target, run):
			return true
	return false


## Confie le lancer d'une grenade assourdissante vers `target` à l'unité
## sélectionnée la plus proche qui en a une.
func order_stun(target: Vector3, run: bool = false) -> bool:
	for unit in _nearest_first(target):
		if planning:
			if not unit.is_dead and unit.stun_grenades > 0:
				return _issue(unit, unit.throw_stun.bind(target, run), target, &"attack")
		elif unit.throw_stun(target, run):
			return true
	return false


## Confie un tir au lance-grenades M320 (obus `shell`, `Commando.SHELLS`)
## vers `target` à l'unité sélectionnée la plus proche qui a encore de ces
## obus.
func order_launcher(target: Vector3, run: bool = false, shell: StringName = Commando.SHELL_EXPLOSIVE) -> bool:
	for unit in _nearest_first(target):
		if planning:
			if not unit.is_dead and unit.launcher_rounds(shell) > 0:
				return _issue(unit, unit.fire_launcher.bind(target, run, shell), target, &"attack")
		elif unit.fire_launcher(target, run, shell):
			return true
	return false


## Confie le Taser sur `enemy` à l'unité sélectionnée la plus proche qui a
## encore une cartouche.
func order_taser(enemy: Enemy, run: bool = false) -> bool:
	for unit in _nearest_first(enemy.global_position):
		if planning:
			if not unit.is_dead and unit.tasers > 0:
				return _issue(unit, unit.tase.bind(enemy, run), enemy.global_position, &"melee")
		elif unit.tase(enemy, run):
			return true
	return false


## Confie le lancer d'un caillou de diversion vers `target` à l'unité
## sélectionnée la plus proche.
func order_pebble(target: Vector3, run: bool = false) -> bool:
	for unit in _nearest_first(target):
		if planning:
			if not unit.is_dead:
				return _issue(unit, unit.throw_pebble.bind(target, run), target, &"move")
		elif unit.throw_pebble(target, run):
			return true
	return false


## Confie le lancer du grappin vers `target` à l'unité sélectionnée la plus
## proche qui peut y monter. Renvoie faux si aucune ne le peut.
func order_grapple(target: Vector3, run: bool = false) -> bool:
	for unit in _nearest_first(target):
		if planning:
			if not unit.is_dead and unit.grapnels > 0 and unit.grapple_route(target)["ok"]:
				return _issue(unit, unit.grapple.bind(target, run), target, &"move")
		elif unit.grapple(target, run):
			return true
	return false


## Fait poser une charge explosive à la première unité sélectionnée qui en a.
func plant_explosive(timed: bool = false) -> bool:
	for unit in _by_index():
		if planning:
			if not unit.is_dead and unit.explosives > 0:
				return _issue(unit, unit.plant_explosive.bind(timed), unit.global_position, &"plant")
		elif unit.plant_explosive(timed):
			return true
	return false


## Fait sauter les charges posées par les unités sélectionnées. Renvoie leur
## nombre.
func detonate_explosives() -> int:
	var count := 0
	for unit in selected:
		var charges := ExplosiveCharge.planted_by(unit.get_tree(), unit)
		if planning:
			if not charges.is_empty():
				_issue(unit, unit.detonate_explosives, (charges[0] as Node3D).global_position, &"detonate")
				count += charges.size()
		else:
			count += unit.detonate_explosives()
	return count


## Fait soigner le blessé le plus proche par la première unité sélectionnée
## qui a une trousse (et un blessé à portée).
func use_medkit() -> bool:
	for unit in _by_index():
		if planning:
			if not unit.is_dead and unit.medkits > 0:
				return _issue(unit, unit.use_medkit, unit.global_position, &"medkit")
		elif unit.use_medkit():
			return true
	return false


## Brouilleur de drones : le premier opérateur sélectionné qui en a un.
func use_jammer() -> bool:
	for unit in _by_index():
		if not unit.is_dead and unit.jammers > 0:
			return unit.use_jammer()
	if not selected.is_empty():
		selected[0].use_jammer()
	return false


## Fait lever le bouclier aux unités sélectionnées qui en ont un, ou le leur
## fait baisser s'il est déjà levé chez toutes. Renvoie vrai si au moins une
## a obéi.
func toggle_shield() -> bool:
	var carriers := selected.filter(func(unit: Commando) -> bool: return unit.shields > 0)
	var raise := not carriers.all(func(unit: Commando) -> bool: return unit.shield_raised)
	var done := false
	for unit: Commando in carriers:
		done = unit.set_shield(raise) or done
	return done


## Fait changer d'arme (principale ↔ secondaire) aux unités sélectionnées.
## Roulade de chaque unité sélectionnée vers `toward`. Renvoie vrai si au
## moins une plonge.
func dive(toward: Vector3) -> bool:
	var any := false
	for unit in selected:
		any = _issue(unit, unit.dive.bind(toward), toward, &"dive") or any
	return any


func switch_weapons() -> void:
	for unit in selected:
		unit.switch_weapon()


## Allume (ou éteint, si toutes sont allumées) la lampe de l'arme de poing
## des unités sélectionnées qui en ont une. Renvoie faux si aucune.
func toggle_lamps() -> bool:
	var carriers := selected.filter(func(unit: Commando) -> bool: return unit.has_lamp())
	var light := not carriers.all(func(unit: Commando) -> bool: return unit.lamp_on)
	for unit: Commando in carriers:
		if unit.lamp_on != light:
			unit.toggle_lamp()
	return not carriers.is_empty()


func _nearest_first(point: Vector3) -> Array[Commando]:
	var candidates: Array[Commando] = selected.duplicate()
	candidates.sort_custom(func(a: Commando, b: Commando) -> bool:
		return a.global_position.distance_squared_to(point) < b.global_position.distance_squared_to(point))
	return candidates


func _by_index() -> Array[Commando]:
	var candidates: Array[Commando] = selected.duplicate()
	candidates.sort_custom(func(a: Commando, b: Commando) -> bool: return a.unit_index < b.unit_index)
	return candidates
