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
		if not selected.has(unit):
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
		selected[i].move_to(target + offset, run)


## Applique une posture à toutes les unités sélectionnées (bascule).
func toggle_posture(posture: SoldierModel.Posture) -> void:
	for unit in selected:
		unit.toggle_posture(posture)
