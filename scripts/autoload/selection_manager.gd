extends Node
## Unités sélectionnées et transmission des ordres.

signal selection_changed(units: Array[Commando])

## Écart entre unités lorsqu'un ordre de déplacement vise plusieurs unités.
const FORMATION_SPACING := 1.1

var selected: Array[Commando] = []


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


## Ordonne aux unités sélectionnées de rejoindre `target` (en formation).
func order_move(target: Vector3, run: bool) -> void:
	var count := selected.size()
	for i in count:
		var offset := Vector3.ZERO
		if count > 1:
			var angle := TAU * float(i) / float(count)
			offset = Vector3(cos(angle), 0.0, sin(angle)) * FORMATION_SPACING
		# Une unité qui tient une caisse la déplace vers le point visé.
		selected[i].move_to(target if selected[i].is_handling_crate() else target + offset, run)


## Ordonne aux unités sélectionnées d'attaquer `enemy`.
func order_attack(enemy: Enemy, run: bool) -> void:
	for unit in selected:
		unit.attack(enemy, run)


## Confie l'élimination au corps à corps de `enemy` à l'unité sélectionnée
## la plus proche qui peut s'en charger. Renvoie faux si aucune ne le peut.
func order_melee(enemy: Enemy, kind: Commando.MeleeKind, run: bool = false) -> bool:
	var candidates: Array[Commando] = selected.duplicate()
	candidates.sort_custom(func(a: Commando, b: Commando) -> bool:
		return a.global_position.distance_squared_to(enemy.global_position) < b.global_position.distance_squared_to(enemy.global_position))
	for unit in candidates:
		if unit.melee(enemy, kind, run):
			return true
	return false


## Confie un lancer de couteau sur `enemy` à l'unité sélectionnée la plus
## proche qui a encore un couteau. Renvoie faux si aucune ne le peut.
func order_throw(enemy: Enemy, run: bool = false) -> bool:
	var candidates: Array[Commando] = selected.duplicate()
	candidates.sort_custom(func(a: Commando, b: Commando) -> bool:
		return a.global_position.distance_squared_to(enemy.global_position) < b.global_position.distance_squared_to(enemy.global_position))
	for unit in candidates:
		if unit.throw_knife(enemy, run):
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


## Confie la caisse `crate` à l'unité sélectionnée la plus proche, qui se
## place du côté le plus proche de `near`. Renvoie faux si aucune ne le peut.
func order_crate(crate: Climbable, near: Vector3) -> bool:
	var candidates: Array[Commando] = selected.duplicate()
	candidates.sort_custom(func(a: Commando, b: Commando) -> bool:
		return a.global_position.distance_squared_to(near) < b.global_position.distance_squared_to(near))
	for unit in candidates:
		if unit.handle_crate(crate, near):
			return true
	return false


## Fait grimper une unité sélectionnée sur `target` ; les autres unités au
## sol se regroupent autour.
func order_climb(target: Climbable, run: bool) -> void:
	var climber_found := false
	var others := 0
	for unit in selected:
		if not climber_found and unit.climb(target, run):
			climber_found = true
		elif unit.perched_on == null:
			# Une unité déjà perchée qui ne peut pas y aller reste où elle est.
			var angle := TAU * float(others) / float(maxi(selected.size() - 1, 1))
			unit.move_to(target.global_position + Vector3(cos(angle), 0.0, sin(angle)) * (target.half_extent + FORMATION_SPACING), run)
			others += 1


## Annule le déplacement ou l'attaque des unités sélectionnées.
func stop() -> void:
	for unit in selected:
		unit.stop()


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
