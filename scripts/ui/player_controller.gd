class_name PlayerController
extends Control
## Entrées du joueur : sélection (clic, rectangle, touches), ordres de
## déplacement, d'attaque et postures. Dessine aussi le rectangle de sélection.
##
## Actions ciblées (couteau, assommer, lancer de couteau, caisse) : la touche
## ou le bouton arme l'action, puis un clic gauche sur un ennemi (ou une
## caisse) la confie à l'opérateur sélectionné le plus proche. Un clic droit,
## ou un clic ailleurs que sur une cible valable, l'annule.
##
## Clic du milieu (sans glisser, sinon c'est la caméra) sur un VIP : son menu
## circulaire d'ordres (« Suivre l'opérateur », « Attendre ici »).
##
## Le curseur change selon ce qu'il survole (`GameCursor`) : ennemi à
## abattre, cible de l'action armée, caisse ou corniche où grimper, VIP,
## endroit inaccessible.
##
## Pause tactique (Espace) : le jeu s'arrête, mais les ordres restent
## possibles. Ordres simultanés : Tab passe en préparation (chaque unité
## garde son dernier ordre, affiché à l'écran), Entrée les lance tous
## ensemble, Tab à nouveau les abandonne (voir `SelectionManager`).

signal pending_action_changed(action: StringName)

## Une surface cliquée dont la normale monte au moins autant se parcourt
## (sol, toit) : le point visé garde sa hauteur.
const FLAT_SURFACE := 0.7
const ACTION_NONE := &""
const ACTION_KNIFE := &"knife"
const ACTION_KNOCKOUT := &"knockout"
const ACTION_THROW := &"throw"
const ACTION_CRATE := &"crate"
## Grenade : puis clic gauche au sol (ou sur un ennemi).
const ACTION_GRENADE := &"grenade"
## Fumigène : puis clic gauche au sol.
const ACTION_SMOKE := &"smoke"
## Tir libre : puis clic gauche sur un mur, un objet ou le sol.
const ACTION_FIRE_AT := &"fire_at"
## Porter un corps : puis clic gauche sur le corps.
const ACTION_CARRY := &"carry"
## Distance (m) entre le clic et le bassin d'un corps pour le désigner.
const BODY_PICK_RADIUS := 1.2
## Grappin : puis clic gauche sur un point en hauteur.
const ACTION_GRAPPLE := &"grapple"
## Déplacement du convertible en vol stationnaire : puis clic gauche sur la
## carte (`_action_aircraft`).
const ACTION_FLY := &"fly"
## Diversion par le convertible parti : puis clic gauche sur la carte.
const ACTION_DIVERT := &"divert"
## Missile antichar du Sabre : puis clic gauche sur la cible.
const ACTION_MISSILE := &"missile"
## Tir désigné à la 12,7 : puis clic gauche sur un ennemi ou un objet.
const ACTION_DESIGNATE := &"designate"

const DRAG_THRESHOLD := 6.0
const RAY_LENGTH := 500.0
const MASK_GROUND := 0b011
const MASK_COMMANDOS := 0b100
## Ennemis actifs (couche 4) et assommés (couche 5).
const MASK_ENEMIES := 0b11000
## Intervalle (s) entre deux mises à jour du curseur.
const CURSOR_INTERVAL := 0.08
## Écart toléré entre un point visé et le maillage de navigation pour le
## dire accessible (le maillage flotte jusqu'à 0,5 m au-dessus du sol).
const REACH_TOLERANCE := 0.6
const REACH_HEIGHT := 1.0

@export var box_fill := Color(0.2, 0.6, 1.0, 0.15)
@export var box_border := Color(0.3, 0.7, 1.0, 0.9)
## Un clic droit sur un obstacle grimpable (caisse) y fait monter une unité.
@export var marker_color := Color(0.3, 0.9, 0.4)
@export var marker_run_color := Color(1.0, 0.75, 0.2)
@export var marker_attack_color := Color(1.0, 0.25, 0.2)
@export var marker_melee_color := Color(0.75, 0.4, 1.0)

## Action ciblée en attente d'un clic sur un ennemi (`ACTION_NONE` sinon).
var pending_action: StringName = ACTION_NONE

var _dragging: bool = false
var _drag_start: Vector2
var _drag_end: Vector2
## Clic du milieu en cours (position de l'appui), pour le distinguer d'un
## glissé de caméra.
var _middle_start: Vector2 = Vector2.INF
## Menu circulaire des ordres au VIP, et le VIP concerné.
var _radial: RadialMenu
var _menu_vip: Vip
## Ennemi du menu de corps à corps ouvert (null : aucun).
var _menu_enemy: Enemy
## Appareil et opérateur du menu de bord ouvert.
var _menu_aircraft: Tiltrotor
var _menu_crew: Commando
## Menu radio ouvert (sur un opérateur au sol).
var _menu_radio: bool = false
## Sabre du menu du véhicule (ouvert depuis le sol) et opérateurs à pied
## sélectionnés qui en reçoivent les ordres.
var _menu_vehicle: Sabre
var _menu_walkers: Array[Commando] = []
## Véhicule et passager du menu de bord du Sabre ouvert.
var _menu_sabre: Sabre
## Convertible visé par l'action armée (`ACTION_FLY`).
var _action_aircraft: Tiltrotor
## Sabre et tireur du missile armé (`ACTION_MISSILE`).
var _action_sabre: Sabre
var _action_rider: Commando
var _menu_rider: Commando
var _cursor_left: float = 0.0
## Pause tactique en cours (le jeu est en pause, les ordres restent possibles).
var tactical_paused: bool = false
## Bandeau d'état (pause tactique, ordres simultanés).
var _banner: Label


func _ready() -> void:
	_banner = Label.new()
	_banner.name = "Banner"
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_font_size_override(&"font_size", 22)
	_banner.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.4))
	_banner.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override(&"outline_size", 6)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 96.0
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.visible = false
	add_child(_banner)
	SelectionManager.plans_changed.connect(_update_banner)
	SelectionManager.planning_changed.connect(func(_active: bool) -> void:
		_update_banner()
		queue_redraw())
	_radial = RadialMenu.new()
	_radial.name = "RadialMenu"
	add_child(_radial)
	_radial.chosen.connect(_on_radial_chosen)
	_radial.closed.connect(func() -> void:
		_menu_vip = null
		_menu_enemy = null
		_menu_aircraft = null
		_menu_crew = null
		_menu_radio = false
		_menu_sabre = null
		_menu_rider = null
		_menu_vehicle = null
		_menu_walkers = [])
	SelectionManager.selection_changed.connect(func(units: Array[Commando]) -> void:
		if units.is_empty():
			cancel_pending_action()
		else:
			Sfx.play_ui(&"select"))


## Arme l'action ciblée `action`, ou la désarme si elle l'était déjà.
## Touche ou bouton « Porter » : les unités sélectionnées qui portent un
## corps le déposent ; sinon, attend un clic sur le corps à prendre.
func press_carry() -> void:
	if pending_action != ACTION_CARRY and SelectionManager.drop_bodies():
		pending_action_changed.emit(pending_action)
		return
	toggle_pending_action(ACTION_CARRY)


## Corps (ennemi mort ou assommé, que personne ne porte) dont le bassin est
## près de `point`, ou null.
static func body_at(tree: SceneTree, point: Vector3) -> Enemy:
	var best: Enemy
	var best_distance := BODY_PICK_RADIUS
	for node in tree.get_nodes_in_group(Enemy.ALL_GROUP):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_body() or enemy.carrier != null:
			continue
		var offset := enemy.body_center() - point
		offset.y = 0.0
		if offset.length() < best_distance:
			best = enemy
			best_distance = offset.length()
	return best


func toggle_pending_action(action: StringName) -> void:
	if action == pending_action or SelectionManager.selected.is_empty():
		cancel_pending_action()
		return
	pending_action = action
	Sfx.play_ui(&"arm")
	_cursor_left = 0.0
	pending_action_changed.emit(pending_action)


## Arme une action du convertible `aircraft` (sans dépendre de la sélection).
func arm_aircraft_action(action: StringName, aircraft: Tiltrotor) -> void:
	_action_aircraft = aircraft
	pending_action = action
	Sfx.play_ui(&"arm")
	_cursor_left = 0.0
	pending_action_changed.emit(pending_action)


## Désarme l'action ciblée en cours.
func cancel_pending_action() -> void:
	if pending_action == ACTION_NONE:
		return
	pending_action = ACTION_NONE
	_cursor_left = 0.0
	pending_action_changed.emit(pending_action)


func _process(delta: float) -> void:
	if SelectionManager.planning or not SelectionManager.planned_orders().is_empty():
		queue_redraw()
	_cursor_left -= delta
	if _cursor_left > 0.0:
		return
	_cursor_left = CURSOR_INTERVAL
	var viewport := get_viewport()
	# Au-dessus de l'interface (boutons, portraits) : curseur normal.
	if viewport.gui_get_hovered_control() != null:
		Roof.hovered = null
		GameCursor.apply(GameCursor.Kind.DEFAULT)
		return
	Roof.hovered = roof_at(viewport.get_mouse_position())
	GameCursor.apply(cursor_kind_at(viewport.get_mouse_position()))


## Toit sous le point `screen_position` de l'écran (effacé ou non), ou null.
func roof_at(screen_position: Vector2) -> Roof:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var from := camera.project_ray_origin(screen_position)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen_position) * RAY_LENGTH, MASK_GROUND)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var roof := (hit["collider"] as Node).get_parent() as Roof
	return roof if roof and roof.body == hit["collider"] else null


func _exit_tree() -> void:
	GameCursor.apply(GameCursor.Kind.DEFAULT)
	SelectionManager.set_planning(false)
	Roof.hovered = null
	if tactical_paused and is_inside_tree():
		get_tree().paused = false


## Met le jeu en pause tactique (ou le relance). Sans effet si le jeu est
## déjà en pause pour une autre raison (chargement, dialogue).
func set_tactical_pause(active: bool) -> void:
	if active == tactical_paused or (active and get_tree().paused):
		return
	tactical_paused = active
	get_tree().paused = active
	Sfx.play_ui(&"arm" if active else &"select")
	_update_banner()


## Passe en préparation d'ordres simultanés, ou l'abandonne.
func toggle_planning() -> void:
	SelectionManager.set_planning(not SelectionManager.planning)
	Sfx.play_ui(&"arm" if SelectionManager.planning else &"denied")


## Lance les ordres préparés.
func execute_plans() -> void:
	if not SelectionManager.planning:
		return
	var accepted := SelectionManager.execute_plans()
	Sfx.play_ui(&"order" if accepted > 0 else &"denied")


func _update_banner() -> void:
	var lines: PackedStringArray = []
	if tactical_paused:
		lines.append("PAUSE TACTIQUE — %s : reprendre" % KeyNames.label(&"tactical_pause"))
	if SelectionManager.planning:
		lines.append("ORDRES SIMULTANÉS (%d) — %s : exécuter, %s : annuler" % [
			SelectionManager.planned_orders().size(), KeyNames.label(&"execute_orders"), KeyNames.label(&"plan_orders")])
	if Roof.view_level >= 0:
		lines.append("VUE : %s — %s / %s : changer d'étage" % [
			view_level_name(Roof.view_level), KeyNames.label(&"view_level_down"), KeyNames.label(&"view_level_up")])
	_banner.text = "\n".join(lines)
	_banner.visible = not lines.is_empty()


## Change d'étage de vue (`direction` : -1 pour descendre, 1 pour monter) :
## au-dessus du dernier étage, tout est de nouveau affiché. Sans toit, rien.
func step_view_level(direction: int) -> void:
	var count := Roof.storey_count(get_tree())
	if count == 0:
		return
	var level := Roof.view_level
	if direction < 0:
		level = count - 1 if level < 0 else maxi(level - 1, 0)
	elif level >= 0:
		level = -1 if level + 1 >= count else level + 1
	if level == Roof.view_level:
		return
	Roof.view_level = level
	Sfx.play_ui(&"select")
	_update_banner()


## Nom de l'étage de vue `level`.
static func view_level_name(level: int) -> String:
	return "rez-de-chaussée" if level == 0 else "étage %d" % level


## Curseur à afficher au point `screen_position` de l'écran.
func cursor_kind_at(screen_position: Vector2) -> GameCursor.Kind:
	if _radial.is_open() or get_viewport().get_camera_3d() == null:
		return GameCursor.Kind.DEFAULT
	if pending_action != ACTION_NONE:
		return _pending_cursor(screen_position)
	var unit_hit := _raycast(screen_position, MASK_COMMANDOS)
	var vip := unit_hit.get("collider") as Vip
	if vip and vip.takes_orders():
		return GameCursor.Kind.ORDERS
	if SelectionManager.selected.is_empty():
		return GameCursor.Kind.DEFAULT
	var enemy := _raycast(screen_position, MASK_ENEMIES).get("collider") as Enemy
	if enemy and not enemy.is_dead:
		return GameCursor.Kind.ATTACK
	if door_at(screen_position) or (barrier_at(screen_position) and _selected_vehicle() == null):
		return GameCursor.Kind.CRATE
	if _selected_vehicle() == null and _mine_at(screen_position):
		return GameCursor.Kind.CRATE
	var hit := _raycast(screen_position, MASK_GROUND)
	if hit.is_empty():
		return GameCursor.Kind.DEFAULT
	if _climbable_at(hit):
		return GameCursor.Kind.CLIMB
	if hit["collider"] is Tiltrotor or hit["collider"] is Sabre:
		return GameCursor.Kind.ORDERS
	return GameCursor.Kind.DEFAULT if _is_reachable(hit["position"]) else GameCursor.Kind.FORBIDDEN


## Curseur d'une action armée : sa cible, ou interdit hors d'une cible valable.
func _pending_cursor(screen_position: Vector2) -> GameCursor.Kind:
	match pending_action:
		ACTION_GRENADE, ACTION_SMOKE:
			return GameCursor.Kind.GRENADE
		ACTION_FIRE_AT:
			return GameCursor.Kind.ATTACK
		ACTION_CARRY:
			var ground := _raycast(screen_position, MASK_GROUND)
			if not ground.is_empty() and body_at(get_tree(), ground["position"]) != null:
				return GameCursor.Kind.CRATE
			return GameCursor.Kind.FORBIDDEN
		ACTION_GRAPPLE:
			return _grapple_cursor(screen_position)
		ACTION_MISSILE:
			return GameCursor.Kind.ATTACK
		ACTION_DESIGNATE:
			var picked := _designation_at(screen_position)
			return GameCursor.Kind.ATTACK if picked and MountedGun.designation_alive(picked) else GameCursor.Kind.FORBIDDEN
		ACTION_FLY, ACTION_DIVERT:
			var spot := _raycast(screen_position, MASK_GROUND)
			return GameCursor.Kind.ORDERS if not spot.is_empty() and not _is_aircraft_part(spot["collider"]) else GameCursor.Kind.FORBIDDEN
		ACTION_CRATE:
			var crate := _raycast(screen_position, MASK_GROUND).get("collider") as Climbable
			return GameCursor.Kind.CRATE if crate and crate.movable else GameCursor.Kind.FORBIDDEN
	var enemy := _raycast(screen_position, MASK_ENEMIES).get("collider") as Enemy
	if enemy == null or enemy.is_dead:
		return GameCursor.Kind.FORBIDDEN
	return GameCursor.Kind.THROW if pending_action == ACTION_THROW else GameCursor.Kind.MELEE


## Vrai si un opérateur sélectionné, vivant, porte un grappin.
func _has_grapnel() -> bool:
	return SelectionManager.selected.any(func(unit: Commando) -> bool: return not unit.is_dead and unit.grapnels > 0)


## Grappin : crochet si un opérateur sélectionné peut y monter, sens
## interdit sinon.
func _grapple_cursor(screen_position: Vector2) -> GameCursor.Kind:
	var spot := _raycast(screen_position, MASK_GROUND)
	if spot.is_empty():
		return GameCursor.Kind.FORBIDDEN
	for unit in SelectionManager.selected:
		if unit.grapnels > 0 and not unit.is_dead and unit.grapple_route(spot["position"])["ok"]:
			return GameCursor.Kind.GRAPPLE
	return GameCursor.Kind.FORBIDDEN


## Caisse ou corniche où l'on peut se tenir sous le point `hit` (sinon null).
func _climbable_at(hit: Dictionary) -> Climbable:
	var climbable := hit["collider"] as Climbable
	if climbable and not climbable.can_stand_on:
		climbable = null
	if climbable == null and (hit["normal"] as Vector3).y > 0.7:
		climbable = Climbable.find_at(get_tree(), hit["position"])
	return climbable


## Vrai si `point` est sur le maillage de navigation (ou tout près).
func _is_reachable(point: Vector3) -> bool:
	var map := get_viewport().get_camera_3d().get_world_3d().navigation_map
	var closest := NavigationServer3D.map_get_closest_point(map, point)
	return Vector2(closest.x - point.x, closest.z - point.z).length() < REACH_TOLERANCE \
			and absf(closest.y - point.y) < REACH_HEIGHT


func _unhandled_input(event: InputEvent) -> void:
	# En pause pour autre chose qu'une pause tactique (chargement, dialogue,
	# aide) : aucun ordre.
	if get_tree().paused and not tactical_paused:
		return
	if event.is_action_pressed(&"ui_cancel"):
		# Échap annule d'abord une action armée, sinon ouvre le menu pause.
		if pending_action != ACTION_NONE:
			cancel_pending_action()
		else:
			var menu := get_node_or_null(^"../PauseMenu") as PauseMenu
			if menu:
				menu.open()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"toggle_objectives") or event.is_action_pressed(&"toggle_minimap"):
		var hud := get_parent() as Hud
		if hud and event.is_action_pressed(&"toggle_objectives"):
			hud.objectives_panel.toggle()
		elif hud:
			hud.minimap.visible = not hud.minimap.visible
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"toggle_help"):
		var help := get_node_or_null(^"../HelpOverlay") as HelpOverlay
		if help:
			help.open()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"tactical_pause"):
		set_tactical_pause(not tactical_paused)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"plan_orders"):
		toggle_planning()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"execute_orders"):
		execute_plans()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"view_level_down") or event.is_action_pressed(&"view_level_up"):
		step_view_level(-1 if event.is_action_pressed(&"view_level_down") else 1)
		get_viewport().set_input_as_handled()
		return
	if pending_action != ACTION_NONE and event is InputEventMouseButton:
		if event.is_action_pressed(&"select"):
			_use_pending_action((event as InputEventMouseButton).position)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"order"):
			cancel_pending_action()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE:
		var middle := event as InputEventMouseButton
		if middle.pressed:
			_middle_start = middle.position
		elif _middle_start != Vector2.INF:
			if _middle_start.distance_to(middle.position) < DRAG_THRESHOLD:
				if open_vip_menu(middle.position) or open_sabre_menu(middle.position) or open_vehicle_menu(middle.position) \
						or open_aircraft_menu(middle.position) \
						or open_radio_menu(middle.position) or open_melee_menu(middle.position):
					get_viewport().set_input_as_handled()
			_middle_start = Vector2.INF
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if event.is_action_pressed(&"select"):
			_dragging = true
			_drag_start = button.position
			_drag_end = button.position
		elif event.is_action_released(&"select") and _dragging:
			_dragging = false
			queue_redraw()
			_finish_selection()
		elif event.is_action_pressed(&"order"):
			# Clic droit simple sur une unité en route : elle s'arrête (le clic
			# suivant donne la nouvelle destination). Le double clic (course)
			# reste un ordre ; hors ordres simultanés (Tab).
			if not button.double_click and not SelectionManager.planning and SelectionManager.stop_walkers():
				Sfx.play_ui(&"order")
				return
			_order(button.position, button.double_click)
	elif event is InputEventMouseMotion and _dragging:
		_drag_end = (event as InputEventMouseMotion).position
		queue_redraw()
	elif event.is_action_pressed(&"posture_crouch"):
		SelectionManager.toggle_posture(SoldierModel.Posture.CROUCHED)
	elif event.is_action_pressed(&"posture_prone"):
		SelectionManager.toggle_posture(SoldierModel.Posture.PRONE)
	elif event.is_action_pressed(&"action_knife"):
		toggle_pending_action(ACTION_KNIFE)
	elif event.is_action_pressed(&"action_knockout"):
		toggle_pending_action(ACTION_KNOCKOUT)
	elif event.is_action_pressed(&"action_crate"):
		# P lâche la caisse tenue ; sinon, arme l'action.
		if not SelectionManager.release_crates():
			toggle_pending_action(ACTION_CRATE)
	elif event.is_action_pressed(&"action_throw"):
		toggle_pending_action(ACTION_THROW)
	elif event.is_action_pressed(&"action_grenade"):
		toggle_pending_action(ACTION_GRENADE)
	elif event.is_action_pressed(&"action_smoke"):
		toggle_pending_action(ACTION_SMOKE)
	elif event.is_action_pressed(&"action_fire_at"):
		toggle_pending_action(ACTION_FIRE_AT)
	elif event.is_action_pressed(&"action_carry"):
		press_carry()
	elif event.is_action_pressed(&"action_grapple"):
		if pending_action == ACTION_GRAPPLE or _has_grapnel():
			toggle_pending_action(ACTION_GRAPPLE)
		else:
			# Personne n'en porte : on le dit, plutôt qu'un curseur interdit partout.
			for unit in SelectionManager.selected:
				unit.flash_hint(Commando.Hint.NO_GRAPNEL)
			_feedback(false)
	elif event.is_action_pressed(&"action_plant"):
		_feedback(SelectionManager.plant_explosive())
	elif event.is_action_pressed(&"action_detonate"):
		_feedback(SelectionManager.detonate_explosives() > 0)
	elif event.is_action_pressed(&"action_medkit"):
		_feedback(SelectionManager.use_medkit())
	elif event.is_action_pressed(&"parry"):
		# Parade au moment du coup : pas de bip, il faut pouvoir la presser vite.
		for unit in SelectionManager.selected:
			unit.ready_parry()
	elif event.is_action_pressed(&"action_shield"):
		_feedback(SelectionManager.toggle_shield())
	elif event.is_action_pressed(&"dive"):
		# Roulade vers le curseur.
		var mouse := get_viewport().get_mouse_position()
		var ground := _raycast(mouse, MASK_GROUND)
		if not ground.is_empty():
			_feedback(SelectionManager.dive(ground["position"]))
	elif event.is_action_pressed(&"switch_weapon"):
		SelectionManager.switch_weapons()
	elif event.is_action_pressed(&"action_sling"):
		SelectionManager.toggle_sling()
	elif event.is_action_pressed(&"reload"):
		SelectionManager.reload()
	elif event.is_action_pressed(&"stop"):
		SelectionManager.stop()
	elif event.is_action_pressed(&"camera_focus"):
		_focus_camera()
	else:
		for index in range(1, 7):
			if event.is_action_pressed("select_unit_%d" % index):
				_select_by_index(index)
				break


func _draw() -> void:
	if _dragging and _drag_start.distance_to(_drag_end) >= DRAG_THRESHOLD:
		var rect := Rect2(_drag_start, _drag_end - _drag_start).abs()
		draw_rect(rect, box_fill)
		draw_rect(rect, box_border, false, 1.5)
	_draw_plans()


## Ordres préparés : trait pointillé de l'unité à sa destination (ou sa
## cible), cercle et numéro de l'unité.
func _draw_plans() -> void:
	var plans := SelectionManager.planned_orders()
	var camera := get_viewport().get_camera_3d()
	if plans.is_empty() or camera == null:
		return
	var font := get_theme_default_font()
	for unit: Commando in plans:
		var plan: Dictionary = plans[unit]
		var color := marker_color
		match plan["kind"]:
			&"attack":
				color = marker_attack_color
			&"melee", &"detonate":
				color = marker_melee_color
		var point: Vector3 = plan["point"]
		if camera.is_position_behind(point) or camera.is_position_behind(unit.global_position):
			continue
		var from := camera.unproject_position(unit.global_position + Vector3.UP * 0.1)
		var to := camera.unproject_position(point + Vector3.UP * 0.05)
		draw_dashed_line(from, to, Color(color, 0.85), 2.0, 8.0)
		draw_arc(to, 10.0, 0.0, TAU, 24, color, 2.5, true)
		var label := str(unit.unit_index)
		draw_string_outline(font, to + Vector2(12, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0, 0.85))
		draw_string(font, to + Vector2(12, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)


func _commandos() -> Array[Commando]:
	var result: Array[Commando] = []
	for node in get_tree().get_nodes_in_group(&"commandos"):
		if node is Commando:
			result.append(node as Commando)
	return result


func _finish_selection() -> void:
	var additive := Input.is_action_pressed(&"select_additive")
	var picked: Array[Commando] = []
	if _drag_start.distance_to(_drag_end) < DRAG_THRESHOLD:
		var hit := _raycast(_drag_end, MASK_COMMANDOS)
		if hit.has("collider") and hit["collider"] is Commando:
			picked.append(hit["collider"] as Commando)
	else:
		var camera := get_viewport().get_camera_3d()
		var rect := Rect2(_drag_start, _drag_end - _drag_start).abs()
		for unit in _commandos():
			var center := unit.global_position + Vector3.UP * 0.9
			if rect.has_point(camera.unproject_position(center)):
				picked.append(unit)
	if picked.is_empty() and additive:
		return
	SelectionManager.select(picked, additive)


func _select_by_index(index: int) -> void:
	for unit in _commandos():
		if unit.unit_index == index:
			SelectionManager.select([unit] as Array[Commando], Input.is_action_pressed(&"select_additive"))
			return


## Clic droit : attaque si un ennemi est visé, sinon déplacement.
func _order(screen_position: Vector2, run: bool) -> void:
	if SelectionManager.selected.is_empty():
		return
	var enemy_hit := _raycast(screen_position, MASK_ENEMIES)
	if enemy_hit.has("collider") and enemy_hit["collider"] is Enemy:
		var enemy := enemy_hit["collider"] as Enemy
		SelectionManager.order_attack(enemy, run)
		_spawn_marker(enemy.global_position, marker_attack_color)
		return
	# Barrière : l'opérateur à pied le plus proche va la lever (ou la baisser).
	var barrier := barrier_at(screen_position) if _selected_vehicle() == null else null
	if barrier:
		var operator: Commando = null
		for unit: Commando in SelectionManager.selected:
			if unit.riding == null and not unit.is_dead and (operator == null \
					or unit.global_position.distance_to(barrier.global_position) < operator.global_position.distance_to(barrier.global_position)):
				operator = unit
		if operator and barrier.request_toggle(operator, run):
			_spawn_marker(barrier.control_point(operator.global_position), marker_run_color if run else marker_color)
		else:
			Sfx.play_ui(&"denied")
		return
	# Mine repérée : l'opérateur à pied le plus proche va la désamorcer.
	var mine := _mine_at(screen_position) if _selected_vehicle() == null else null
	if mine:
		var deminer: Commando = null
		for unit: Commando in SelectionManager.selected:
			if unit.riding == null and not unit.is_dead and (deminer == null \
					or unit.global_position.distance_to(mine.global_position) < deminer.global_position.distance_to(mine.global_position)):
				deminer = unit
		if deminer and mine.request_disarm(deminer, run):
			_spawn_marker(mine.disarm_point(deminer.global_position), marker_run_color if run else marker_color)
		else:
			Sfx.play_ui(&"denied")
		return
	var door := door_at(screen_position)
	if door:
		if SelectionManager.order_door(door, run):
			_spawn_marker(door.near_side(SelectionManager.selected[0].global_position), marker_run_color if run else marker_color)
		else:
			Sfx.play_ui(&"denied")
		return
	var hit := _raycast(screen_position, MASK_GROUND)
	if hit.is_empty():
		return
	# Sabre : on monte à bord.
	var sabre := hit["collider"] as Sabre
	if sabre:
		if SelectionManager.order_mount(sabre, run):
			_spawn_marker(sabre.boarding_point(SelectionManager.selected[0].global_position), marker_run_color if run else marker_color)
		else:
			Sfx.play_ui(&"denied")
		return
	# Un opérateur sélectionné est à bord d'un Sabre : le véhicule roule
	# jusqu'au point visé.
	var vehicle := _selected_vehicle()
	if vehicle:
		# Clic sur un convertible : le Sabre monte dans sa soute.
		var collider := hit["collider"] as Node
		var aircraft := collider as Tiltrotor
		if aircraft == null and collider:
			aircraft = collider.get_parent() as Tiltrotor
		var problem: String
		if aircraft and aircraft != vehicle.stowed_in:
			problem = vehicle.load_into(aircraft)
		elif Input.is_action_pressed(&"select_additive"):
			# Maj : point de passage au bout de l'itinéraire.
			problem = vehicle.queue_waypoint(hit["position"])
		else:
			problem = vehicle.drive_to(hit["position"])
		if problem == "":
			_spawn_marker(hit["position"], marker_run_color if run else marker_color)
		else:
			Sfx.play_ui(&"denied")
			var who := vehicle.crew()
			if not who.is_empty():
				who[0].flash_message(problem[0].to_upper() + problem.substr(1))
		return
	# Convertible : on embarque (la soute, par la rampe arrière).
	var aircraft := hit["collider"] as Tiltrotor
	if aircraft:
		# En vol stationnaire, porte ouverte : on rejoint la corde pour être
		# hélitreuillé.
		if aircraft.is_airborne and SelectionManager.order_winch(aircraft, run):
			_spawn_marker(aircraft.rope_foot(), marker_run_color if run else marker_color)
			return
		if aircraft.is_airborne or aircraft.is_moving or aircraft.is_flying:
			Sfx.play_ui(&"denied")
			return
		var cabin := aircraft.cabin_point()
		SelectionManager.order_board(aircraft, run)
		_spawn_marker(cabin, marker_run_color if run else marker_color)
		return
	# Caisse, ou dessus d'un mur où l'on peut se tenir (corniche). Un bidon
	# ne se gravit pas : on va à côté.
	var climbable := _climbable_at(hit)
	if climbable:
		SelectionManager.order_climb(climbable, run)
		_spawn_marker(climbable.get_top_position(), marker_run_color if run else marker_color)
		return
	var target: Vector3 = hit["position"]
	# Dessus d'un toit, d'un bunker… : on y va (la navigation passe par
	# l'échelle). Flanc d'un mur : on vise le sol à son pied.
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	if normal.y < FLAT_SURFACE:
		target.y = 0.0
	SelectionManager.order_move(target, run)
	_spawn_marker(target, marker_run_color if run else marker_color)


## Ouvre le menu d'ordres du VIP sous `screen_position`. Renvoie faux s'il
## n'y en a pas (ou s'il ne peut plus recevoir d'ordres).
func open_vip_menu(screen_position: Vector2) -> bool:
	var hit := _raycast(screen_position, MASK_COMMANDOS)
	var vip := hit.get("collider") as Vip
	if vip == null or not vip.takes_orders():
		return false
	cancel_pending_action()
	_menu_vip = vip
	var guide := _guide_for(vip)
	var options: Array[Dictionary] = [
		{"id": &"follow", "label": "Suivre l'opérateur",
			"detail": guide.display_name if guide else "Sélectionnez un opérateur",
			"enabled": guide != null},
		{"id": &"stay", "label": "Attendre ici", "enabled": vip.leader != null},
	]
	_radial.open(screen_position, options, vip.display_name)
	Sfx.play_ui(&"select")
	return true


## Ouvre le menu de bord sur l'opérateur sous `screen_position`, s'il est
## dans la soute d'un convertible : relever / abaisser la rampe, piloter.
## Renvoie faux sinon.
func open_aircraft_menu(screen_position: Vector2) -> bool:
	var hit := _raycast(screen_position, MASK_COMMANDOS)
	var unit := hit.get("collider") as Commando
	if unit == null or unit.is_dead:
		return false
	var aircraft := Tiltrotor.cabin_at(get_tree(), unit.global_position + Vector3.UP * 0.3)
	if aircraft == null or aircraft.is_destroyed or aircraft.is_flying or aircraft.is_moving:
		return false
	cancel_pending_action()
	_menu_aircraft = aircraft
	_menu_crew = unit
	_radial.open(screen_position, aircraft_options(aircraft, unit), unit.display_name)
	Sfx.play_ui(&"select")
	return true


## Sabre à bord duquel est un opérateur sélectionné, ou null.
func _selected_vehicle() -> Sabre:
	for unit: Commando in SelectionManager.selected:
		if is_instance_valid(unit) and unit.riding:
			return unit.riding
	return null


## Ouvre le menu de bord du Sabre sur l'opérateur à bord sous
## `screen_position`. Renvoie faux sinon.
func open_sabre_menu(screen_position: Vector2) -> bool:
	var hit := _raycast(screen_position, MASK_COMMANDOS)
	var unit := hit.get("collider") as Commando
	if unit == null or unit.is_dead or unit.riding == null:
		return false
	cancel_pending_action()
	_menu_sabre = unit.riding
	_menu_rider = unit
	_radial.open(screen_position, sabre_options(unit.riding, unit), unit.display_name)
	Sfx.play_ui(&"select")
	return true


## Ouvre le menu du véhicule sur le Sabre sous `screen_position` (pas sur un
## passager), pour les opérateurs à pied sélectionnés. Renvoie faux sinon.
func open_vehicle_menu(screen_position: Vector2) -> bool:
	var hit := _raycast(screen_position, MASK_GROUND)
	var sabre := hit.get("collider") as Sabre
	if sabre == null:
		return false
	cancel_pending_action()
	_menu_vehicle = sabre
	_menu_walkers = walkers()
	_radial.open(screen_position, vehicle_options(sabre, _menu_walkers), "Sabre")
	Sfx.play_ui(&"select")
	return true


## Opérateurs sélectionnés à pied (ni à bord ni en vol).
static func walkers() -> Array[Commando]:
	var result: Array[Commando] = []
	for unit: Commando in SelectionManager.selected:
		if is_instance_valid(unit) and not unit.is_dead and unit.riding == null and unit.airborne_in == null:
			result.append(unit)
	return result


## Options du menu du véhicule pour `units` (à pied) : s'abriter derrière,
## moteur au ralenti (leurre, opérateur tout près), se ravitailler, coucher
## un corps ou un otage sur le plateau, décharger le plateau, réparer.
static func vehicle_options(sabre: Sabre, units: Array[Commando]) -> Array[Dictionary]:
	var nobody := "sélectionnez un opérateur à pied" if units.is_empty() else ""
	var options: Array[Dictionary] = []
	var cover := nobody if nobody != "" else sabre.cover_problem()
	options.append({"id": &"cover", "label": "S'abriter derrière",
		"detail": "accroupis, côté opposé aux ennemis" if cover == "" else cover, "enabled": cover == ""})
	var near := units.any(func(unit: Commando) -> bool: return unit.global_position.distance_to(sabre.global_position) <= Sabre.IDLE_REACH)
	var idle := nobody if nobody != "" else ("trop loin : approchez un opérateur" if not near else ("" if sabre.idling else sabre.idle_problem()))
	options.append({"id": &"idle", "label": "Couper le ralenti" if sabre.idling else "Moteur au ralenti",
		"detail": ("le leurre se tait" if sabre.idling else "leurre : le bruit attire les gardes") if idle == "" else idle, "enabled": idle == ""})
	var supply := nobody
	if supply == "":
		var needy := units.filter(func(unit: Commando) -> bool: return sabre.resupply_problem(unit) == "")
		supply = "" if not needy.is_empty() else sabre.resupply_problem(units[0])
	options.append({"id": &"resupply", "label": "Se ravitailler (%d)" % sabre.supplies,
		"detail": "au hayon : dotation de départ" if supply == "" else supply, "enabled": supply == ""})
	var bed := nobody
	if bed == "":
		var holders := units.filter(func(unit: Commando) -> bool: return sabre.bed_problem(unit) == "")
		bed = "" if not holders.is_empty() else sabre.bed_problem(units[0])
	options.append({"id": &"bed", "label": "Coucher sur le plateau",
		"detail": "corps ou otage ligoté, depuis le hayon (%d place%s)" % [sabre.bed.count(null), "s" if sabre.bed.count(null) > 1 else ""] if bed == "" else bed,
		"enabled": bed == ""})
	var unload := sabre.unload_problem()
	options.append({"id": &"unload", "label": "Décharger le plateau",
		"detail": "derrière le hayon" if unload == "" else unload, "enabled": unload == ""})
	var repair := nobody if nobody != "" else sabre.repair_problem()
	options.append({"id": &"repair", "label": "Réparer",
		"detail": "pneus et moteur, %d s à l'avant" % int(Sabre.REPAIR_TIME) if repair == "" else repair, "enabled": repair == ""})
	return options


## Ordre du menu du véhicule.
func _on_vehicle_order(id: StringName) -> void:
	var sabre := _menu_vehicle
	var units := _menu_walkers
	_menu_vehicle = null
	_menu_walkers = []
	var ok := false
	if id == &"unload" and is_instance_valid(sabre):
		ok = sabre.unload_bed()
	elif is_instance_valid(sabre) and not units.is_empty():
		var run := false
		match id:
			&"cover":
				ok = sabre.take_cover(units, run)
				if ok:
					for point in sabre.cover_points(units.size()):
						_spawn_marker(point, marker_color)
			&"idle":
				ok = sabre.set_idling(not sabre.idling)
			&"bed":
				for unit in units:
					if sabre.request_bed(unit, run):
						ok = true
				if ok:
					_spawn_marker(sabre.supply_point(), marker_color)
			&"resupply":
				for unit in units:
					if sabre.request_resupply(unit, run):
						ok = true
				if ok:
					_spawn_marker(sabre.supply_point(), marker_color)
			&"repair":
				var nearest := units[0]
				for unit in units:
					if unit.global_position.distance_to(sabre.global_position) < nearest.global_position.distance_to(sabre.global_position):
						nearest = unit
				ok = sabre.request_repair(nearest, run)
				if ok:
					_spawn_marker(sabre.repair_point(), marker_run_color if run else marker_color)
	Sfx.play_ui(&"order" if ok else &"denied")


## Options du menu de bord du Sabre, ouvert sur `rider` : descendre (lui,
## tout le monde), prendre le volant ou la tourelle, ouvrir ou cesser le feu
## avec la 12,7.
static func sabre_options(sabre: Sabre, rider: Commando) -> Array[Dictionary]:
	var moving := "en route" if sabre.is_driving else ""
	var options: Array[Dictionary] = [
		{"id": &"dismount", "label": "Descendre", "detail": "à côté de sa place" if moving == "" else moving, "enabled": moving == ""},
		{"id": &"dismount_all", "label": "Tout le monde descend", "detail": "%d à bord" % (sabre.crew().size() + sabre.vips().size()) if moving == "" else moving,
			"enabled": moving == ""},
	]
	var index := sabre.seat_of(rider)
	if index != Sabre.DRIVER_SEAT:
		var free := sabre.driver() == null
		options.append({"id": &"drive", "label": "Prendre le volant",
			"detail": "le véhicule roule au clic droit" if free and moving == "" else (moving if moving != "" else "%s conduit" % sabre.driver().display_name),
			"enabled": free and moving == ""})
	if index == Sabre.DRIVER_SEAT and LevelRoot.is_night(sabre):
		options.append({"id": &"lights", "label": "Éteindre les phares" if sabre.headlights else "Allumer les phares",
			"detail": "tous feux éteints : plus lent, repéré de près seulement" if sabre.headlights else "pleine vitesse, mais repéré de loin"})
	if index == Sabre.DRIVER_SEAT:
		var idle := sabre.idle_problem()
		options.append({"id": &"idle", "label": "Couper le ralenti" if sabre.idling else "Moteur au ralenti",
			"detail": "le leurre se tait" if sabre.idling else ("leurre : le bruit attire les gardes" if idle == "" else idle),
			"enabled": sabre.idling or idle == ""})
	options.append({"id": &"assault", "label": "Rester à bord à l'arrivée" if sabre.dismount_on_arrival else "Débarquer à l'arrivée",
		"detail": "les passagers restent assis" if sabre.dismount_on_arrival else "passagers à terre et à couvert dès l'arrêt (%d)" % sabre.assault_party().size()})
	if index == Sabre.DRIVER_SEAT:
		options.append({"id": &"coast", "label": "Relancer le moteur" if sabre.coasting else "Couper le moteur",
			"detail": ("le moteur s'entend de nouveau" if sabre.coasting else "roue libre silencieuse, %d m/s, %d m" % [int(Sabre.COAST_SPEED), int(Sabre.COAST_RANGE)]) if moving == "" else moving,
			"enabled": moving == "" and sabre.stowed_in == null})
	var side := sabre.side_gun_of(rider)
	if side >= 0:
		var firing := sabre.side_firing[side]
		options.append({"id": &"side_gun", "label": "7,62 : cesser le feu" if firing else "7,62 : feu à volonté",
			"detail": "la mitrailleuse se tait" if firing else ("à l'avant et à droite" if side == 0 else "à l'arrière et à gauche") + ", %d m" % int(Sabre.SIDE_RANGE)})
	var supply := sabre.resupply_problem(rider)
	options.append({"id": &"resupply", "label": "Se ravitailler (%d)" % sabre.supplies,
		"detail": "dotation de départ, sur le plateau" if supply == "" else supply, "enabled": supply == ""})
	if index != Sabre.DRIVER_SEAT:
		var missile := sabre.missile_problem(rider)
		options.append({"id": &"missile", "label": "Missile antichar (%d)" % sabre.missiles,
			"detail": "puis clic sur la cible : %.1f s de visée, à l'arrêt" % Sabre.MISSILE_AIM if missile == "" else missile,
			"enabled": missile == ""})
	if index == Sabre.GUNNER_SEAT:
		options.append({"id": &"gun", "label": "12,7 : cesser le feu" if sabre.gun_firing or sabre.designated_target() else "12,7 : feu à volonté",
			"detail": "la mitrailleuse se tait" if sabre.gun_firing or sabre.designated_target() else "tir automatique tout autour (bruyant)"})
		options.append({"id": &"designate", "label": "12,7 : tir désigné",
			"detail": "puis clic sur un ennemi ou un objet : feu concentré", "enabled": not sabre.model.is_folded})
	else:
		var free_turret := sabre.gunner() == null
		options.append({"id": &"turret", "label": "Tourelle 12,7",
			"detail": "passer à la mitrailleuse" if free_turret and moving == "" else (moving if moving != "" else "%s y est" % sabre.gunner().display_name),
			"enabled": free_turret and moving == ""})
	return options


## Ouvre le menu radio sur l'opérateur au sol sous `screen_position`, si un
## appareil d'extraction attend d'être appelé. Renvoie faux sinon.
func open_radio_menu(screen_position: Vector2) -> bool:
	var hit := _raycast(screen_position, MASK_COMMANDOS)
	var unit := hit.get("collider") as Commando
	if unit == null or unit.is_dead or unit.airborne_in != null:
		return false
	var options := radio_options(get_tree())
	if options.is_empty():
		return false
	cancel_pending_action()
	_menu_radio = true
	_radial.open(screen_position, options, unit.display_name)
	Sfx.play_ui(&"select")
	return true


## Options du menu radio : renvoyer l'appareil d'insertion (soute vide),
## diversion par l'appareil parti, appeler l'extraction.
static func radio_options(tree: SceneTree) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var inserted := Tiltrotor.dismissable(tree)
	if inserted:
		var problem := inserted.dismiss_problem()
		options.append({"id": &"dismiss", "label": "Renvoyer l'appareil",
			"detail": "il quitte la zone" + (" (rappel possible)" if inserted.extraction else "") if problem == "" else problem,
			"enabled": problem == ""})
	var diverter := Tiltrotor.diverter(tree)
	if diverter:
		var problem := diverter.diversion_problem()
		options.append({"id": &"divert", "label": "Diversion",
			"detail": "puis clic sur la carte : passage en rase-mottes (une fois)" if problem == "" else problem, "enabled": problem == ""})
	var awaited := Tiltrotor.awaiting_call(tree)
	if awaited:
		var problem := awaited.call_problem()
		options.append({"id": &"extract", "label": "Appeler l'extraction",
			"detail": "le convertible vient se poser (bruyant)" if problem == "" else problem, "enabled": problem == ""})
	return options


## Options du menu de bord de `aircraft`, ouvert sur `crew` : la porte
## (rampe), puis au sol « Monter » (et « Piloter » si le décollage termine
## la mission), en vol « Descendre en rappel » et « Atterrir ».
static func aircraft_options(aircraft: Tiltrotor, crew: Commando = null) -> Array[Dictionary]:
	var ramp_free := not aircraft.is_ramp_blocked()
	var options: Array[Dictionary] = [
		{"id": &"ramp", "label": "Ouverture" if aircraft.is_ramp_closed else "Fermeture",
			"detail": "abaisser la rampe" if aircraft.is_ramp_closed else ("relever la rampe" if ramp_free else "quelqu'un sur la rampe"),
			"enabled": aircraft.is_ramp_closed or ramp_free},
	]
	if aircraft.gunner == crew and crew != null:
		options.append({"id": &"gun", "label": "Lâcher le canon", "detail": "le canon latéral se tait"})
	else:
		var gun := aircraft.gun_problem(crew)
		options.append({"id": &"gun", "label": "Canon latéral",
			"detail": "feu à volonté, côté droit (bruyant)" if gun == "" else gun, "enabled": gun == ""})
	if aircraft.is_airborne:
		if aircraft.slung_load:
			var drop := aircraft.drop_problem()
			options.append({"id": &"drop_load", "label": "Larguer la charge",
				"detail": "la dépose sous l'appareil" if drop == "" else drop, "enabled": drop == ""})
		else:
			var sling := aircraft.sling_problem()
			options.append({"id": &"sling", "label": "Élinguer",
				"detail": "caisse ou Sabre vide sous l'appareil" if sling == "" else sling, "enabled": sling == ""})
	var supply := aircraft.resupply_problem(crew)
	options.append({"id": &"resupply", "label": "Ravitaillement",
		"detail": ("dotation de départ (%d lot%s)" % [aircraft.supplies, "s" if aircraft.supplies > 1 else ""]) if supply == "" else supply,
		"enabled": supply == ""})
	if crew and crew.is_wounded():
		var leaving := aircraft.evacuation_problem(crew)
		options.append({"id": &"evacuate", "label": "Évacuer le blessé",
			"detail": "il quitte la mission, sauvé" if leaving == "" else leaving, "enabled": leaving == ""})
	if aircraft.is_airborne:
		var rappel := aircraft.rappel_problem(crew)
		options.append({"id": &"rappel", "label": "Descendre en rappel",
			"detail": "par la rampe, jusqu'au sol" if rappel == "" else rappel, "enabled": rappel == ""})
		var flying := aircraft.fly_problem()
		options.append({"id": &"fly", "label": "Déplacer",
			"detail": "puis clic sur la carte : rampe au-dessus du point" if flying == "" else flying, "enabled": flying == ""})
		for up: bool in [true, false]:
			var height := aircraft.next_altitude(up)
			if height < 0.0:
				continue
			var problem := aircraft.fly_problem()
			var radius := Tiltrotor.ROTOR_NOISE * lerpf(1.0, Tiltrotor.HIGH_NOISE_SHARE, (height - Tiltrotor.HOVER_LEVELS[0]) / (Tiltrotor.HOVER_LEVELS[-1] - Tiltrotor.HOVER_LEVELS[0]))
			options.append({"id": &"climb" if up else &"descend", "label": "Prendre de l'altitude" if up else "Perdre de l'altitude",
				"detail": ("%d m : bruit à %d m" % [height, radius]) if problem == "" else problem, "enabled": problem == ""})
		var landing := aircraft.land_problem()
		options.append({"id": &"land", "label": "Atterrir", "detail": "avec ceux à bord" if landing == "" else landing,
			"enabled": landing == ""})
		return options
	var rising := aircraft.rise_problem()
	options.append({"id": &"rise", "label": "Monter",
		"detail": "vol stationnaire à %d m" % Tiltrotor.HOVER_HEIGHT if rising == "" else rising, "enabled": rising == ""})
	# L'appareil d'extraction repart seul, une fois tout le monde à bord.
	if aircraft.ends_mission and not aircraft.extraction:
		var problem := aircraft.take_off_problem()
		options.append({"id": &"pilot", "label": "Piloter", "detail": "décoller avec l'équipe" if problem == "" else problem,
			"enabled": problem == ""})
	return options


## Ouvre le menu de corps à corps sur l'ennemi sous `screen_position` :
## l'opérateur sélectionné le plus proche s'en charge. Renvoie faux sans
## ennemi visé ou sans opérateur sélectionné.
func open_melee_menu(screen_position: Vector2) -> bool:
	var hit := _raycast(screen_position, MASK_ENEMIES)
	var enemy := hit.get("collider") as Enemy
	if enemy == null or enemy.is_dead or SelectionManager.selected.is_empty():
		return false
	cancel_pending_action()
	_menu_enemy = enemy
	_radial.open(screen_position, melee_options(enemy), "Corps à corps")
	Sfx.play_ui(&"select")
	return true


## Options du menu de corps à corps sur `enemy`.
static func melee_options(enemy: Enemy) -> Array[Dictionary]:
	if enemy.captor != null:
		return [
			{"id": &"release", "label": "Relâcher", "detail": "il donne l'alerte"},
			{"id": &"knockout", "label": "Assommer", "detail": "coup sur la tempe"},
		]
	var standing := not enemy.is_stunned()
	return [
		{"id": &"knockout", "label": "Assommer", "detail": "coup ou prise par derrière", "enabled": standing},
		{"id": &"knife", "label": "Couteau", "detail": "silencieux par derrière"},
		{"id": &"hatchet", "label": "Hachette", "detail": "tue même de face, bruyant",
			"enabled": SelectionManager.selected.any(func(unit: Commando) -> bool: return unit.hatchets > 0)},
		{"id": &"sweep", "label": "Balayage", "detail": "il tombe, sonné peu de temps", "enabled": standing},
		{"id": &"throw", "label": "Projection", "detail": "au sol, puis assommé", "enabled": standing},
		{"id": &"disarm", "label": "Désarmer", "detail": "pris de court, il se rend", "enabled": enemy.can_be_disarmed()},
		{"id": &"hostage", "label": "Bouclier humain", "detail": "par derrière, arme de poing", "enabled": standing},
	]


## Choix dans le menu circulaire ouvert (VIP ou corps à corps).
func _on_radial_chosen(id: StringName) -> void:
	if _menu_vip:
		_on_vip_order(id)
		return
	if _menu_vehicle:
		_on_vehicle_order(id)
		return
	if _menu_sabre:
		var sabre := _menu_sabre
		var rider := _menu_rider
		_menu_sabre = null
		_menu_rider = null
		var ok := false
		if is_instance_valid(sabre) and is_instance_valid(rider):
			match id:
				&"dismount":
					ok = sabre.dismount(rider)
				&"dismount_all":
					ok = sabre.dismount_all()
				&"drive":
					ok = sabre.move_seat(rider, Sabre.DRIVER_SEAT)
				&"turret":
					ok = sabre.move_seat(rider, Sabre.GUNNER_SEAT)
				&"gun":
					ok = sabre.set_gun_firing(not (sabre.gun_firing or sabre.designated_target() != null))
				&"designate":
					_action_sabre = sabre
					_action_rider = rider
					arm_aircraft_action(ACTION_DESIGNATE, null)
					return
				&"lights":
					ok = sabre.set_headlights(not sabre.headlights)
				&"coast":
					ok = sabre.set_coasting(not sabre.coasting)
				&"assault":
					ok = sabre.set_dismount_on_arrival(not sabre.dismount_on_arrival)
				&"idle":
					ok = sabre.set_idling(not sabre.idling)
				&"resupply":
					ok = sabre.request_resupply(rider, false)
				&"missile":
					if sabre.missile_problem(rider) == "":
						_action_sabre = sabre
						_action_rider = rider
						arm_aircraft_action(ACTION_MISSILE, null)
						return
				&"side_gun":
					var side := sabre.side_gun_of(rider)
					ok = side >= 0 and sabre.set_side_firing(rider, not sabre.side_firing[side])
		Sfx.play_ui(&"order" if ok else &"denied")
		return
	if _menu_radio:
		_menu_radio = false
		if id == &"divert":
			var diverter := Tiltrotor.diverter(get_tree())
			if diverter and diverter.diversion_problem() == "":
				arm_aircraft_action(ACTION_DIVERT, diverter)
			else:
				Sfx.play_ui(&"denied")
			return
		var aircraft: Tiltrotor = Tiltrotor.awaiting_call(get_tree()) if id == &"extract" else Tiltrotor.dismissable(get_tree())
		var done := false
		if aircraft:
			done = aircraft.call_in() if id == &"extract" else aircraft.dismiss()
		Sfx.play_ui(&"order" if done else &"denied")
		return
	if _menu_aircraft:
		var aircraft := _menu_aircraft
		var crew := _menu_crew
		_menu_aircraft = null
		_menu_crew = null
		var done := false
		if is_instance_valid(aircraft):
			if id == &"ramp":
				done = aircraft.set_ramp_closed(not aircraft.is_ramp_closed)
			elif id == &"pilot":
				done = aircraft.take_off(crew)
			elif id == &"rise":
				done = aircraft.rise()
			elif id == &"land":
				done = aircraft.land()
			elif id == &"rappel":
				done = aircraft.rappel(crew)
			elif id == &"evacuate":
				done = aircraft.evacuate(crew)
			elif id == &"sling":
				done = aircraft.sling()
			elif id == &"drop_load":
				done = aircraft.drop_load()
			elif id == &"resupply":
				done = aircraft.resupply(crew)
			elif id == &"climb" or id == &"descend":
				done = aircraft.change_altitude(id == &"climb")
			elif id == &"fly":
				arm_aircraft_action(ACTION_FLY, aircraft)
				return
			elif id == &"gun":
				if aircraft.gunner == crew:
					aircraft.leave_gun()
					done = true
				else:
					done = aircraft.man_gun(crew)
		Sfx.play_ui(&"order" if done else &"denied")
		return
	var enemy := _menu_enemy
	_menu_enemy = null
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
		return
	if enemy.captor != null:
		# L'otage : seul celui qui le tient décide.
		if id == &"release" or id == &"knockout":
			enemy.captor.release_hostage(id == &"knockout")
			Sfx.play_ui(&"order")
		return
	var kinds := {&"knockout": Commando.MeleeKind.KNOCKOUT, &"knife": Commando.MeleeKind.KNIFE,
			&"sweep": Commando.MeleeKind.SWEEP, &"throw": Commando.MeleeKind.THROW,
			&"disarm": Commando.MeleeKind.DISARM, &"hostage": Commando.MeleeKind.HOSTAGE,
			&"hatchet": Commando.MeleeKind.HATCHET}
	if not kinds.has(id):
		return
	var accepted := SelectionManager.order_melee(enemy, kinds[id])
	Sfx.play_ui(&"order" if accepted else &"denied")
	if accepted:
		_spawn_marker(enemy.global_position, marker_melee_color)


## Menu d'ordres du VIP (pour l'interface et les tests).
func radial_menu() -> RadialMenu:
	return _radial


## Opérateur que suivra le VIP : le sélectionné, ou le sélectionné le plus
## proche de lui s'il y en a plusieurs.
func _guide_for(vip: Vip) -> Commando:
	var best: Commando = null
	for unit: Commando in SelectionManager.selected:
		if not is_instance_valid(unit) or unit.is_dead:
			continue
		if best == null or unit.global_position.distance_squared_to(vip.global_position) \
				< best.global_position.distance_squared_to(vip.global_position):
			best = unit
	return best


func _on_vip_order(id: StringName) -> void:
	var vip := _menu_vip
	_menu_vip = null
	if vip == null or not is_instance_valid(vip):
		return
	var accepted := false
	match id:
		&"follow":
			accepted = vip.follow(_guide_for(vip))
		&"stay":
			accepted = vip.stay()
	Sfx.play_ui(&"order" if accepted else &"denied")
	if accepted:
		_spawn_marker(vip.global_position, marker_color)


## Bip d'ordre reçu, ou de refus.
func _feedback(accepted: bool) -> void:
	if SelectionManager.selected.is_empty():
		return
	Sfx.play_ui(&"order" if accepted else &"denied")


## Vrai si `collider` est la coque ou le plancher d'un convertible.
static func _is_aircraft_part(collider: Object) -> bool:
	var node := collider as Node
	return node is Tiltrotor or (node != null and node.get_parent() is Tiltrotor)


## Ennemi ou objet destructible sous `screen_position` (pas un Sabre), ou
## null.
func _designation_at(screen_position: Vector2) -> Node3D:
	var hit := _raycast(screen_position, MASK_GROUND | MASK_ENEMIES)
	var node := hit.get("collider") as Node3D
	if node is Enemy or (node != null and node.has_method(&"take_shot") and not node is Sabre):
		return node
	return null


func _use_pending_action(screen_position: Vector2) -> void:
	if pending_action == ACTION_DESIGNATE:
		var sabre := _action_sabre
		_action_sabre = null
		_action_rider = null
		cancel_pending_action()
		var picked := _designation_at(screen_position)
		var problem := sabre.designate(picked) if is_instance_valid(sabre) else "pas de véhicule"
		if problem == "":
			_spawn_marker(picked.global_position, marker_run_color)
			Sfx.play_ui(&"order")
		else:
			if is_instance_valid(sabre) and sabre.gunner():
				sabre.gunner().flash_message(problem[0].to_upper() + problem.substr(1))
			Sfx.play_ui(&"denied")
		return
	if pending_action == ACTION_MISSILE:
		var spot := _raycast(screen_position, MASK_GROUND | MASK_ENEMIES)
		var sabre := _action_sabre
		var rider := _action_rider
		_action_sabre = null
		_action_rider = null
		cancel_pending_action()
		if spot.is_empty() or not is_instance_valid(sabre) or not is_instance_valid(rider) or spot["collider"] == sabre:
			Sfx.play_ui(&"denied")
			return
		var target: Vector3 = spot["position"]
		if spot["collider"] is Enemy:
			target = (spot["collider"] as Enemy).global_position + Vector3.UP
		var problem := sabre.fire_missile(rider, target)
		if problem == "":
			_spawn_marker(target, marker_run_color)
			Sfx.play_ui(&"order")
		else:
			rider.flash_message(problem[0].to_upper() + problem.substr(1))
			Sfx.play_ui(&"denied")
		return
	if pending_action == ACTION_FLY or pending_action == ACTION_DIVERT:
		var spot := _raycast(screen_position, MASK_GROUND)
		var aircraft := _action_aircraft
		_action_aircraft = null
		var valid := not spot.is_empty() and not _is_aircraft_part(spot["collider"]) and is_instance_valid(aircraft)
		if valid and (aircraft.divert(spot["position"]) if pending_action == ACTION_DIVERT else aircraft.fly_to(spot["position"])):
			_spawn_marker(spot["position"], marker_color)
			Sfx.play_ui(&"order")
		else:
			Sfx.play_ui(&"denied")
		cancel_pending_action()
		return
	if pending_action == ACTION_GRAPPLE:
		var spot := _raycast(screen_position, MASK_GROUND)
		if not spot.is_empty():
			var point: Vector3 = spot["position"]
			if SelectionManager.order_grapple(point):
				_spawn_marker(point, marker_color)
			else:
				Sfx.play_ui(&"denied")
		cancel_pending_action()
		return
	if pending_action == ACTION_CARRY:
		var ground := _raycast(screen_position, MASK_GROUND)
		var body := body_at(get_tree(), ground["position"]) if not ground.is_empty() else null
		if body and SelectionManager.order_carry(body):
			_spawn_marker(body.body_center(), marker_color)
		else:
			Sfx.play_ui(&"denied")
		cancel_pending_action()
		return
	if pending_action == ACTION_FIRE_AT:
		var spot := _raycast(screen_position, MASK_GROUND)
		if not spot.is_empty():
			var aim: Vector3 = spot["position"]
			if SelectionManager.order_fire_at(aim):
				_spawn_marker(aim, marker_attack_color)
			else:
				Sfx.play_ui(&"denied")
		cancel_pending_action()
		return
	if pending_action == ACTION_GRENADE or pending_action == ACTION_SMOKE:
		var ground := _raycast(screen_position, MASK_GROUND)
		if not ground.is_empty():
			var point: Vector3 = ground["position"]
			var ordered := SelectionManager.order_smoke(point) if pending_action == ACTION_SMOKE else SelectionManager.order_grenade(point)
			if ordered:
				_spawn_marker(point, marker_attack_color)
			else:
				Sfx.play_ui(&"denied")
		cancel_pending_action()
		return
	if pending_action == ACTION_CRATE:
		var crate_hit := _raycast(screen_position, MASK_GROUND)
		if crate_hit.has("collider") and crate_hit["collider"] is Climbable:
			var crate := crate_hit["collider"] as Climbable
			if SelectionManager.order_crate(crate, crate_hit["position"]):
				_spawn_marker(crate.global_position, marker_color)
			else:
				Sfx.play_ui(&"denied")
		cancel_pending_action()
		return
	var hit := _raycast(screen_position, MASK_ENEMIES)
	if pending_action == ACTION_THROW and not (hit.has("collider") and hit["collider"] is Enemy):
		# Au sol : un caillou pour faire diversion.
		var ground := _raycast(screen_position, MASK_GROUND)
		if not ground.is_empty():
			var point: Vector3 = ground["position"]
			if SelectionManager.order_pebble(point):
				_spawn_marker(point, marker_color)
			else:
				Sfx.play_ui(&"denied")
		cancel_pending_action()
		return
	if hit.has("collider") and hit["collider"] is Enemy:
		var enemy := hit["collider"] as Enemy
		if pending_action == ACTION_THROW:
			if SelectionManager.order_throw(enemy):
				_spawn_marker(enemy.global_position, marker_melee_color)
			else:
				Sfx.play_ui(&"denied")
		else:
			var kind := Commando.MeleeKind.KNIFE if pending_action == ACTION_KNIFE else Commando.MeleeKind.KNOCKOUT
			if SelectionManager.order_melee(enemy, kind):
				_spawn_marker(enemy.global_position, marker_melee_color)
			else:
				Sfx.play_ui(&"denied")
	cancel_pending_action()


func _focus_camera() -> void:
	if SelectionManager.selected.is_empty():
		return
	var rig := get_viewport().get_camera_3d().get_parent() as CameraRig
	if rig:
		rig.focus_on(SelectionManager.selected[0].global_position)


## Porte (fermée ou ouverte, pas détruite) sous `screen_position`, ou null.
## Mine repérée sous `screen_position`, ou null.
func _mine_at(screen_position: Vector2) -> Landmine:
	var hit := _raycast(screen_position, MASK_GROUND)
	return Landmine.revealed_near(get_tree(), hit["position"]) if not hit.is_empty() else null


## Barrière de poste de contrôle sous `screen_position`, ou null.
func barrier_at(screen_position: Vector2) -> RoadBarrier:
	var camera := get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(screen_position)
	return RoadBarrier.picked(get_tree(), from, from + camera.project_ray_normal(screen_position) * RAY_LENGTH)


func door_at(screen_position: Vector2) -> Door:
	var hit := _raycast(screen_position, MASK_GROUND | Door.DOOR_LAYER)
	var door := hit.get("collider") as Door
	return door if door and not door.is_broken else null


func _raycast(screen_position: Vector2, mask: int) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	var space := camera.get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	# Un toit effacé (opérateur à l'intérieur) ou le haut des murs d'un
	# bâtiment vu en coupe laissent passer les clics vers l'intérieur.
	while not hit.is_empty() and (Roof.is_revealed_body(hit["collider"], hit["position"]) \
			or Building.is_revealed_body(hit["collider"], hit["position"]) \
			or Tiltrotor.is_revealed_body(hit["collider"])):
		query.exclude += [hit["rid"]]
		hit = space.intersect_ray(query)
	return hit


## Anneau éphémère indiquant la destination, et bip d'ordre reçu.
func _spawn_marker(at: Vector3, color: Color) -> void:
	Sfx.play_ui(&"order")
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.28
	mesh.outer_radius = 0.36
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	var marker := MeshInstance3D.new()
	marker.mesh = mesh
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(marker)
	marker.global_position = at + Vector3.UP * 0.04
	var tween := marker.create_tween().set_parallel(true)
	tween.tween_property(marker, "scale", Vector3.ONE * 0.3, 0.6)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.6)
	tween.chain().tween_callback(marker.queue_free)
