@tool
extends EditorPlugin
## Greffon « Éditeur de mission » (voir MISSION_EDITOR.md).
##
## - Aperçu des textures externes sur la scène ouverte, retirées le temps de
##   chaque enregistrement (`TexturePreview`).
## - Dock « Mission » : réglages de la carte (nuit, tenue de rigueur), grille,
##   palette des éléments à poser, avertissement sur les cartes générées.
## - Pose au clic dans la vue 3D, au sol ou sur les toits, avec annulation ;
##   rondes tracées point par point.
## - Repères dans la vue 3D (`gizmos.gd`) : cônes de vue, trajets à poignées,
##   portée des bruits.
## - Informations de la mission (`MissionInfo`) : objectifs et leurs cibles,
##   modifiées dans l'inspecteur, enregistrées avec la scène.
## - Carte de couverture des gardes (`coverage.gd`), dessinée sans être
##   enregistrée.
## - Nouvelle mission (gabarit `template.tscn`), « Vérifier » (`checker.gd`)
##   et « Essayer » (lance la scène seule).

const TexturePreview := preload("res://addons/mission_editor/texture_preview.gd")
const Dock := preload("res://addons/mission_editor/dock.gd")
const Palette := preload("res://addons/mission_editor/palette.gd")
const Gizmos := preload("res://addons/mission_editor/gizmos.gd")
const Checker := preload("res://addons/mission_editor/checker.gd")
const Coverage := preload("res://addons/mission_editor/coverage.gd")
## Gabarit d'une nouvelle mission (`tools/gen_mission_template.py`).
const TEMPLATE := "res://addons/mission_editor/template.tscn"
const LEVELS_DIR := "res://scenes/levels"

## Pas de la grille magnétique (m) et de la rotation (degrés).
const GRID_STEP := 0.5
const ROTATION_STEP := 15.0
## Raccourcis du greffon (Éditeur > Paramètres de l'éditeur > Raccourcis).
const SHORTCUTS := {
	"mission_editor/rotate_right": {"key": KEY_R, "shift": false, "label": "Tourner de 15° (sens horaire)"},
	"mission_editor/rotate_left": {"key": KEY_R, "shift": true, "label": "Tourner de 15° (sens inverse)"},
	"mission_editor/cancel": {"key": KEY_ESCAPE, "shift": false, "label": "Arrêter la pose"},
	"mission_editor/finish_route": {"key": KEY_ENTER, "shift": false, "label": "Finir le tracé d'une ronde"},
	"mission_editor/remove_route_point": {"key": KEY_BACKSPACE, "shift": false, "label": "Retirer le dernier point d'une ronde"},
}
## Sol (couleur du terrain, couleur des pistes), comme `tools/mapkit.py`.
const GROUNDS := {
	"desert": [Color(0.62, 0.52, 0.36), Color(0.5, 0.42, 0.3)],
	"sand": [Color(0.55, 0.47, 0.33), Color(0.45, 0.38, 0.27)],
	"dirt": [Color(0.4, 0.36, 0.28), Color(0.32, 0.28, 0.21)],
	"grass": [Color(0.3, 0.36, 0.22), Color(0.36, 0.32, 0.24)],
	"urban": [Color(0.36, 0.36, 0.35), Color(0.22, 0.22, 0.23)],
	"rock": [Color(0.42, 0.4, 0.37), Color(0.33, 0.3, 0.26)],
}
## Gabarit : équipe à 6 m du bord sud, extraction à 6 m du bord nord,
## caméra à 10 m du bord sud, limites de la caméra à 2 m des bords.
const TEAM_INSET := 6.0
const CAMERA_INSET := 10.0
const BOUNDS_INSET := 2.0
## Éclairage selon le moment : fond, lumière ambiante, soleil ou lune
## (mêmes valeurs que `tools/mapkit.py`).
const LIGHTING := {
	false: {"background_color": Color(0.55, 0.62, 0.7), "ambient_light_color": Color(0.66, 0.66, 0.64), "ambient_light_energy": 0.65,
		"light_color": Color(1, 0.96, 0.9), "light_energy": 1.1},
	true: {"background_color": Color(0.01, 0.015, 0.03), "ambient_light_color": Color(0.2, 0.25, 0.4), "ambient_light_energy": 0.22,
		"light_color": Color(0.6, 0.7, 1), "light_energy": 0.16},
}

var _textures := TexturePreview.new()
var _dock: Control
## Outil de la palette en cours (vide : aucun), cap de pose (degrés, 0 =
## nord), point visé au sol et début d'un tracé (INF : aucun).
var _tool: String = ""
var _facing: float = 0.0
var _point: Vector3 = Vector3.INF
var _start: Vector3 = Vector3.INF
## Points du tracé d'une ronde en cours (outil « route ») ; le premier est
## aussi dans `_start`.
var _trace := PackedVector3Array()
var _camera: Camera3D
var _gizmos: EditorNode3DGizmoPlugin
## Informations de la mission ouverte et leur état à l'ouverture (pour
## n'enregistrer le fichier que s'il a changé).
var _info: MissionInfo
var _info_state: String = ""
## Passant ou voiture sélectionné, dont le dock montre le trajet.
var _route: Node3D
## Dessin de la couverture des gardes (sans propriétaire : jamais
## enregistré) ; recalcul déjà demandé pour cette image.
var _coverage: MeshInstance3D
var _coverage_pending: bool = false
## Historique de la scène ouverte, suivi en plus du gestionnaire : une
## annulation qui passe directement par lui n'émet que `version_changed`.
var _history: UndoRedo


## Nom de la métadonnée du moteur qui désigne le greffon (scénarios de
## vérification).
const META := &"mission_editor"


func _enter_tree() -> void:
	Engine.set_meta(META, self)
	_register_shortcuts()
	_dock = Dock.new()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_dock.tool_selected.connect(_on_tool_selected)
	_dock.night_toggled.connect(_on_night_toggled)
	_dock.dress_code_selected.connect(_on_dress_code_selected)
	_dock.info_edit_requested.connect(_on_info_edit_requested)
	_dock.info_create_requested.connect(_on_info_create_requested)
	_dock.nodes_selected.connect(func(nodes: Array) -> void: _select(nodes))
	_dock.route_point_added.connect(_on_route_point.bind(true))
	_dock.route_point_removed.connect(_on_route_point.bind(false))
	_dock.new_mission_requested.connect(new_mission)
	_dock.check_requested.connect(check)
	_dock.play_requested.connect(_on_play_requested)
	_dock.coverage_toggled.connect(func(_on: bool) -> void: refresh_coverage())
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	_gizmos = Gizmos.new()
	_gizmos.plugin = self
	add_node_3d_gizmo_plugin(_gizmos)
	scene_changed.connect(_on_scene_changed)
	scene_saved.connect(_on_scene_saved)
	# Action faite, annulée ou rétablie : le dock suit (`version_changed`
	# n'est pas émis par l'historique de l'éditeur, `history_changed` l'est).
	get_undo_redo().history_changed.connect(_refresh_dock)
	get_undo_redo().history_changed.connect(_request_coverage)
	set_input_event_forwarding_always_enabled()
	set_force_draw_over_forwarding_enabled()
	_on_scene_changed.call_deferred(EditorInterface.get_edited_scene_root())


func _exit_tree() -> void:
	Engine.remove_meta(META)
	scene_changed.disconnect(_on_scene_changed)
	scene_saved.disconnect(_on_scene_saved)
	get_undo_redo().history_changed.disconnect(_refresh_dock)
	get_undo_redo().history_changed.disconnect(_request_coverage)
	_follow_history(null)
	_clear_coverage()
	EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)
	remove_node_3d_gizmo_plugin(_gizmos)
	_save_info()
	_textures.revert()
	remove_control_from_docks(_dock)
	_dock.queue_free()


# --- Textures ---------------------------------------------------------------

## Avant tout enregistrement (et changement d'onglet, perte du focus…),
## les textures quittent les matériaux ; elles reviennent juste après,
## une fois l'enregistrement fait.
func _apply_changes() -> void:
	_textures.revert()
	_reapply.call_deferred()


func _save_external_data() -> void:
	_textures.revert()
	_reapply.call_deferred()
	_save_info()


func _refresh_textures() -> void:
	_textures.revert()
	_reapply()


func _reapply() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root is LevelRoot:
		_textures.apply(root)


func _on_scene_saved(path: String) -> void:
	_reapply.call_deferred()
	# Un fichier de mission enregistré : le catalogue du jeu le relira.
	LevelCatalog.reload()


func _on_scene_changed(root: Node) -> void:
	_save_info()
	_textures.revert()
	_cancel_tool()
	_load_info(root)
	_dock.show_report([])
	_follow_history(root)
	refresh_coverage()
	_dock.show_scene(root, generator_of(root))
	if root is LevelRoot:
		_textures.apply(root)


func _refresh_dock() -> void:
	var root := EditorInterface.get_edited_scene_root()
	_dock.show_scene(root, generator_of(root))


## Script qui génère la carte `root` (`tools/gen_<dossier>.py`), ou vide.
static func generator_of(root: Node) -> String:
	if root == null or root.scene_file_path.is_empty():
		return ""
	var folder := root.scene_file_path.get_base_dir().get_file()
	var path := "res://tools/gen_%s.py" % folder
	return path.trim_prefix("res://") if FileAccess.file_exists(path) else ""


# --- Réglages de la carte ---------------------------------------------------

func _on_night_toggled(night: bool) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if not root is LevelRoot:
		return
	var undo := get_undo_redo()
	undo.create_action("Carte de nuit" if night else "Carte de jour")
	undo.add_do_property(root, &"night", night)
	undo.add_undo_property(root, &"night", root.get("night"))
	var preset: Dictionary = LIGHTING[night]
	var environment := root.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if environment and environment.environment:
		for key: String in ["background_color", "ambient_light_color", "ambient_light_energy"]:
			undo.add_do_property(environment.environment, key, preset[key])
			undo.add_undo_property(environment.environment, key, environment.environment.get(key))
	for light_name: String in ["Sun", "Moon"]:
		var light := root.get_node_or_null(NodePath(light_name)) as DirectionalLight3D
		if light:
			for key: String in ["light_color", "light_energy"]:
				undo.add_do_property(light, key, preset[key])
				undo.add_undo_property(light, key, light.get(key))
	undo.commit_action()


func _on_dress_code_selected(code: StringName) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if not root is LevelRoot:
		return
	var undo := get_undo_redo()
	undo.create_action("Tenue de rigueur")
	undo.add_do_property(root, &"dress_code", code)
	undo.add_undo_property(root, &"dress_code", root.get("dress_code"))
	undo.commit_action()


# --- Pose -------------------------------------------------------------------

func _on_tool_selected(id: String) -> void:
	_tool = id
	_start = Vector3.INF
	_trace.clear()
	_update_status()
	update_overlays()


func _cancel_tool() -> void:
	_tool = ""
	_start = Vector3.INF
	_trace.clear()
	_point = Vector3.INF
	if _dock:
		_dock.clear_tool()
		_update_status()
	update_overlays()


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _tool.is_empty() or not EditorInterface.get_edited_scene_root() is LevelRoot:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	_camera = camera
	var settings := EditorInterface.get_editor_settings()
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if settings.is_shortcut("mission_editor/cancel", event):
			_abandon()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if not _trace.is_empty() and settings.is_shortcut("mission_editor/finish_route", event):
			_finish_route()
		elif not _trace.is_empty() and settings.is_shortcut("mission_editor/remove_route_point", event):
			_trace.remove_at(_trace.size() - 1)
			_start = _trace[0] if not _trace.is_empty() else Vector3.INF
		elif settings.is_shortcut("mission_editor/rotate_right", event):
			_facing = fposmod(_facing + ROTATION_STEP, 360.0)
		elif settings.is_shortcut("mission_editor/rotate_left", event):
			_facing = fposmod(_facing - ROTATION_STEP, 360.0)
		else:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		_update_status()
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion:
		_point = _aim(camera, (event as InputEventMouseMotion).position)
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.is_pressed():
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_abandon()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if button.button_index != MOUSE_BUTTON_LEFT:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		_point = _aim(camera, button.position)
		if _point == Vector3.INF:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		var entry := Palette.find(_tool)
		if entry.get("tool") == "route":
			# Le premier clic d'un double-clic a déjà posé le point.
			if button.double_click:
				_finish_route()
			elif _trace.is_empty() or _trace[_trace.size() - 1].distance_to(_point) > 0.2:
				_trace.append(_point)
				_start = _trace[0]
		elif entry.get("tool") == "line" and _start == Vector3.INF:
			_start = _point
		elif entry.get("tool") == "line":
			if _start.distance_to(_point) > 0.2:
				place(_tool, _start, _facing, _point)
			_start = Vector3.INF
		else:
			place(_tool, _point, _facing)
		_update_status()
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


## Clic droit ou Échap : abandonne le tracé en cours, sinon l'outil.
func _abandon() -> void:
	if _start == Vector3.INF:
		_cancel_tool()
		return
	_start = Vector3.INF
	_trace.clear()
	_update_status()
	update_overlays()


## Pose la ronde tracée (au moins deux points), puis attend la suivante.
func _finish_route() -> void:
	if _trace.size() >= 2:
		place(_tool, _trace[0], _facing, Vector3.INF, _trace.duplicate())
	_trace.clear()
	_start = Vector3.INF


## Point visé pour l'outil en cours : sur les toits et les étages si
## l'élément le permet et que la case du dock est cochée, sinon au sol.
## Le second point d'un tracé reste à la hauteur du premier.
func _aim(camera: Camera3D, screen: Vector2) -> Vector3:
	var step := GRID_STEP if _dock.grid_enabled() else 0.0
	var entry := Palette.find(_tool)
	if entry.get("ground", false) or not _dock.surface_enabled():
		return Palette.ground_point(camera, screen, step)
	if _start != Vector3.INF:
		var plane := Plane(Vector3.UP, _start.y)
		var hit: Variant = plane.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
		if hit == null:
			return Vector3.INF
		var level: Vector3 = hit
		return Vector3(snappedf(level.x, step), level.y, snappedf(level.z, step)) if step > 0.0 else level
	return Palette.surface_point(camera, screen, step, EditorInterface.get_edited_scene_root().get_world_3d())


## Pose l'élément `id` de la palette (voir `Palette.make`), en une action
## annulable. Renvoie les nœuds posés.
func place(id: String, at: Vector3, facing: float, to: Vector3 = Vector3.INF, route := PackedVector3Array()) -> Array[Node3D]:
	var root := EditorInterface.get_edited_scene_root()
	var entry := Palette.find(id)
	if root == null or entry.is_empty():
		return []
	var nodes := Palette.make(id, at, facing, to, root, route)
	if nodes.is_empty():
		return nodes
	var undo := get_undo_redo()
	undo.create_action("Poser : %s" % entry["label"])
	var created := {}
	for node in nodes:
		var parent_path: String = node.get_meta(Palette.PARENT_META, entry["parent"])
		node.remove_meta(Palette.PARENT_META)
		var parent := _parent_for(root, parent_path, undo, created)
		# Nœuds à enregistrer : le nœud et ses enfants créés par la palette,
		# relevés avant l'entrée dans l'arbre (les enfants qu'un script
		# construit en aperçu ne doivent pas l'être) ; d'une scène instanciée,
		# la racine seule.
		var owned: Array[Node] = [node]
		if node.scene_file_path.is_empty():
			owned.append_array(node.find_children("*", "", true, false))
		undo.add_do_method(parent, &"add_child", node, true)
		for item in owned:
			undo.add_do_property(item, &"owner", root)
		undo.add_do_reference(node)
		undo.add_undo_method(parent, &"remove_child", node)
	undo.commit_action()
	_select(nodes)
	# Textures externes sur les nouveaux éléments aussi.
	_refresh_textures.call_deferred()
	return nodes


## Parent `path` (relatif à la racine) ; créé dans l'action `undo` s'il
## manque (`Decor`, `Lamps`…).
func _parent_for(root: Node, path: String, undo: EditorUndoRedoManager, made: Dictionary) -> Node:
	if path == ".":
		return root
	var parent := root.get_node_or_null(NodePath(path))
	if parent:
		return parent
	if made.has(path):
		return made[path]
	var created := Node3D.new()
	made[path] = created
	created.name = path.get_file()
	var holder := root.get_node_or_null(NodePath(path.get_base_dir())) if path.contains("/") else root
	undo.add_do_method(holder, &"add_child", created, true)
	undo.add_do_property(created, &"owner", root)
	undo.add_do_reference(created)
	undo.add_undo_method(holder, &"remove_child", created)
	return created


func _select(nodes: Array) -> void:
	var selection := EditorInterface.get_selection()
	selection.clear()
	for node in nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			selection.add_node(node)


func _update_status() -> void:
	if _dock == null:
		return
	if _tool.is_empty():
		_dock.set_status("")
		return
	var entry := Palette.find(_tool)
	var text := "%s — cap %d°" % [entry.get("label", _tool), int(_facing)]
	if entry.get("tool") == "line":
		text += " — cliquez la fin du tracé" if _start != Vector3.INF else " — cliquez le début du tracé"
	elif entry.get("tool") == "route":
		match _trace.size():
			0:
				text += " — cliquez le premier point de la ronde"
			1:
				text += " — cliquez le point suivant"
			_:
				text += " — %d points : point suivant, ou double-clic / Entrée pour finir (Retour arrière : retirer le dernier)" % _trace.size()
	_dock.set_status(text)


func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	if _tool.is_empty() or _camera == null or _point == Vector3.INF:
		return
	if _camera.is_position_behind(_point):
		return
	var color := Color(0.4, 1.0, 0.5)
	var at := _camera.unproject_position(_point)
	overlay.draw_arc(at, 10.0, 0.0, TAU, 24, color, 2.0)
	if not _trace.is_empty():
		var length := 0.0
		for i in _trace.size():
			var next := _trace[i + 1] if i + 1 < _trace.size() else _point
			length += _trace[i].distance_to(next)
			if _camera.is_position_behind(_trace[i]) or _camera.is_position_behind(next):
				continue
			var a := _camera.unproject_position(_trace[i])
			overlay.draw_line(a, _camera.unproject_position(next), color, 2.0)
			overlay.draw_circle(a, 4.0, color)
		overlay.draw_string(overlay.get_theme_default_font(), at + Vector2(12, -12), "%d points, %.1f m" % [_trace.size() + 1, length],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	elif _start != Vector3.INF and not _camera.is_position_behind(_start):
		var from := _camera.unproject_position(_start)
		overlay.draw_line(from, at, color, 2.0)
		overlay.draw_string(overlay.get_theme_default_font(), (from + at) * 0.5 + Vector2(6, -6), "%.1f m" % _start.distance_to(_point),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	elif Palette.find(_tool).get("tool") == "point":
		var radians := deg_to_rad(_facing)
		var ahead := _point + Vector3(sin(radians), 0.0, -cos(radians)) * 2.0
		if not _camera.is_position_behind(ahead):
			overlay.draw_line(at, _camera.unproject_position(ahead), color, 2.0)


func _register_shortcuts() -> void:
	var settings := EditorInterface.get_editor_settings()
	for path: String in SHORTCUTS:
		if settings.has_shortcut(path):
			continue
		var spec: Dictionary = SHORTCUTS[path]
		var key := InputEventKey.new()
		key.physical_keycode = spec["key"]
		key.shift_pressed = spec["shift"]
		var shortcut := Shortcut.new()
		shortcut.resource_name = spec["label"]
		shortcut.events = [key]
		settings.add_shortcut(path, shortcut)


## Grille magnétique active (repères : déplacement des points de trajet).
func grid_enabled() -> bool:
	return _dock.grid_enabled() if _dock else true


# --- Informations de la mission -------------------------------------------

func _load_info(root: Node) -> void:
	_info = Dock.info_of(root) if root is LevelRoot else null
	_info_state = _state_of(_info)


static func _state_of(info: MissionInfo) -> String:
	return var_to_str(info.to_entry()) if info else ""


## Enregistre les informations de la mission si elles ont changé
## (inspecteur), et prévient le catalogue du jeu.
func _save_info() -> void:
	if _info == null or _info.resource_path.is_empty():
		return
	var state := _state_of(_info)
	if state == _info_state:
		return
	ResourceSaver.save(_info)
	_info_state = state
	LevelCatalog.reload()


func _on_info_edit_requested() -> void:
	if _info:
		EditorInterface.edit_resource(_info)


## Crée `mission.tres` à côté de la scène ouverte : titre tiré du nom de la
## racine, placée après les missions existantes, objectif d'extraction.
func _on_info_create_requested() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if not root is LevelRoot or root.scene_file_path.is_empty():
		return
	var path := _write_info(root.scene_file_path, String(root.name).capitalize())
	EditorInterface.get_resource_filesystem().update_file(path)
	LevelCatalog.reload()
	_load_info(root)
	_refresh_dock()
	EditorInterface.edit_resource(_info)


# --- Trajets ----------------------------------------------------------------

func _on_selection_changed() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	_route = null
	if selected.size() == 1 and (selected[0] is Passerby or selected[0] is TrafficCar):
		_route = selected[0]
	_dock.show_route(_route)


## Ajoute un point au trajet sélectionné (`add`), ou retire le dernier (il en
## reste au moins deux). Un trajet en boucle reçoit le milieu du segment qui
## la ferme ; un trajet ouvert est prolongé de 5 m dans sa direction.
func _on_route_point(add: bool) -> void:
	if not is_instance_valid(_route):
		return
	var before: PackedVector3Array = _route.get("points")
	var after := before.duplicate()
	if add:
		if before.size() < 2:
			return
		if Gizmos.is_loop(_route):
			after.append((before[-1] + before[0]) * 0.5)
		else:
			after.append(before[-1] + (before[-1] - before[-2]).normalized() * 5.0)
	elif before.size() > 2:
		after.resize(before.size() - 1)
	else:
		return
	var undo := get_undo_redo()
	undo.create_action("Ajouter un point au trajet" if add else "Retirer un point du trajet")
	undo.add_do_property(_route, &"points", after)
	undo.add_undo_property(_route, &"points", before)
	for method: StringName in [&"place_preview", &"update_gizmos"]:
		undo.add_do_method(_route, method)
		undo.add_undo_method(_route, method)
	undo.commit_action()
	_dock.show_route(_route)


## Écrit `mission.tres` pour la scène `scene_path` : titre `title`, placée
## après les missions existantes, objectif d'extraction. Renvoie son chemin.
static func _write_info(scene_path: String, title: String) -> String:
	var info := MissionInfo.new()
	info.title = title
	info.description = "À écrire."
	var last := 0
	for entry: Dictionary in LevelCatalog.levels():
		var other := load(MissionInfo.path_for(entry["scene"])) as MissionInfo
		last = maxi(last, other.order if other else 0)
	info.order = last + 10
	info.objectives = [MissionObjective.make("extracted", "Ramener l'équipe à la zone d'extraction")] as Array[MissionObjective]
	var path := MissionInfo.path_for(scene_path)
	ResourceSaver.save(info, path)
	return path


# --- Vérification, essai, nouvelle mission ---------------------------------

## Vérifie la scène ouverte et affiche le résultat dans le dock (coroutine).
func check() -> Array[Dictionary]:
	_dock.show_report([{"level": "ok", "text": "Vérification en cours…", "nodes": []}])
	var report: Array[Dictionary] = await Checker.check(EditorInterface.get_edited_scene_root())
	_dock.show_report(report)
	return report


## Enregistre la scène ouverte et la lance seule. Comme depuis le choix des
## missions, `LevelRoot` monte objectifs (lus dans `mission.tres` par
## `LevelCatalog`), équipe et équipement des profils.
func _on_play_requested() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if not root is LevelRoot or root.scene_file_path.is_empty():
		return
	_cancel_tool()
	EditorInterface.save_scene()
	EditorInterface.play_custom_scene(root.scene_file_path)


## Crée `scenes/levels/<folder>/<folder>.tscn` à partir du gabarit, et son
## `mission.tres`, puis l'ouvre. Renvoie le chemin de la scène, ou vide
## (raison affichée dans le dock).
## `options` : {"size": Vector2 (m), "ground" (clé de `GROUNDS`), "night"} ;
## à défaut, les réglages du dock.
func new_mission(folder: String, options: Dictionary = {}) -> String:
	var error := _new_mission_error(folder)
	_dock.set_new_mission_status(error)
	if not error.is_empty():
		return ""
	if options.is_empty():
		options = _dock.new_mission_options()
	var scene_path := "%s/%s/%s.tscn" % [LEVELS_DIR, folder, folder]
	var text := mission_text(FileAccess.get_file_as_string(TEMPLATE), folder.to_pascal_case(), options)
	if text.is_empty():
		_dock.set_new_mission_status("Gabarit inattendu (%s) : régénérez-le avec tools/gen_mission_template.py." % TEMPLATE)
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scene_path.get_base_dir()))
	var file := FileAccess.open(scene_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var info_path := _write_info(scene_path, folder.capitalize())
	var files := EditorInterface.get_resource_filesystem()
	files.update_file(scene_path)
	files.update_file(info_path)
	LevelCatalog.reload()
	EditorInterface.open_scene_from_path(scene_path)
	return scene_path


## Texte de la scène d'une nouvelle mission, d'après le gabarit `template`
## (80 × 80 m, herbe, de jour) : racine `root_name`, terrain, positions et
## éclairage selon `options`. Vide si le gabarit n'a pas la forme attendue.
static func mission_text(template: String, root_name: String, options: Dictionary) -> String:
	var size: Vector2 = options.get("size", Vector2(80, 80))
	var colors: Array = GROUNDS.get(options.get("ground", "grass"), GROUNDS["grass"])
	var night: bool = options.get("night", false)
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	# Plus un fichier généré : sans le nom du générateur ni son empreinte.
	var lines := Array(template.split("\n")).filter(func(line: String) -> bool: return not line.begins_with("metadata/generat"))
	var text := "\n".join(lines)
	var root_line := '[node name="Mission" type="Node3D"]\nscript = ExtResource("4")'
	var changes: Array = [
		[root_line, root_line.replace("Mission", root_name) + ("\nnight = true" if night else "")],
		["size = Vector3(80, 1, 80)", "size = Vector3(%s, 1, %s)" % [_num(size.x), _num(size.y)]],
		['id="ground_mat"]\nalbedo_color = Color(0.3, 0.36, 0.22, 1)', 'id="ground_mat"]\nalbedo_color = %s' % _color(colors[0])],
		['id="track_mat"]\nalbedo_color = Color(0.36, 0.32, 0.24, 1)', 'id="track_mat"]\nalbedo_color = %s' % _color(colors[1])],
		["bounds = AABB(-38, 0, -38, 76, 0, 76)", "bounds = AABB(%s, 0, %s, %s, 0, %s)" % [
			_num(-(hx - BOUNDS_INSET)), _num(-(hz - BOUNDS_INSET)), _num(size.x - 2.0 * BOUNDS_INSET), _num(size.y - 2.0 * BOUNDS_INSET)]],
	]
	if night:
		var preset: Dictionary = LIGHTING[true]
		var day: Dictionary = LIGHTING[false]
		for key: String in ["background_color", "ambient_light_color", "light_color"]:
			changes.append(["%s = %s" % [key, _color(day[key])], "%s = %s" % [key, _color(preset[key])]])
		for key: String in ["ambient_light_energy", "light_energy"]:
			changes.append(["%s = %s" % [key, _num(day[key])], "%s = %s" % [key, _num(preset[key])]])
	for change: Array in changes:
		if not text.contains(change[0]):
			return ""
		text = text.replace(change[0], change[1])
	# Équipe au sud, extraction au nord, caméra sur l'équipe.
	for node_z: Array in [["Alpha", hz - TEAM_INSET], ["Bravo", hz - TEAM_INSET], ["Charlie", hz - TEAM_INSET],
			["ExtractionZone", -(hz - TEAM_INSET)], ["CameraRig", hz - CAMERA_INSET]]:
		var pattern := RegEx.create_from_string('(\\[node name="%s"[^\\n]*\\]\\ntransform = Transform3D\\(1, 0, 0, 0, 1, 0, 0, 0, 1, [^,]+, 0, )[^)]+\\)' % node_z[0])
		var found := pattern.search(text)
		if found == null:
			return ""
		text = text.substr(0, found.get_start()) + found.get_string(1) + _num(node_z[1]) + ")" + text.substr(found.get_end())
	return text


## Nombre écrit comme dans une scène : « 34 », « 0.96 ».
static func _num(value: float) -> String:
	value = snappedf(value, 0.0001)
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(value)


static func _color(color: Color) -> String:
	return "Color(%s, %s, %s, 1)" % [_num(color.r), _num(color.g), _num(color.b)]


static func _new_mission_error(folder: String) -> String:
	var pattern := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	if pattern.search(folder) == null:
		return "Nom de dossier : lettres minuscules, chiffres et _, en commençant par une lettre."
	if DirAccess.dir_exists_absolute("%s/%s" % [LEVELS_DIR, folder]):
		return "Le dossier scenes/levels/%s existe déjà." % folder
	return ""


# --- Couverture des gardes -------------------------------------------------

## Recalcul au plus une fois par image, après une action de l'historique.
func _request_coverage() -> void:
	if _coverage_pending or not _dock.coverage_enabled():
		return
	_coverage_pending = true
	refresh_coverage.call_deferred()


## Dessine (ou retire) la couverture des gardes sur la scène ouverte.
## Renvoie les cases calculées.
func refresh_coverage() -> Dictionary:
	_coverage_pending = false
	_clear_coverage()
	var root := EditorInterface.get_edited_scene_root()
	if not _dock.coverage_enabled() or not root is LevelRoot:
		return {}
	var cells := Coverage.compute(root)
	_coverage = MeshInstance3D.new()
	_coverage.name = "MissionEditorCoverage"
	_coverage.mesh = Coverage.build_mesh(cells)
	_coverage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_coverage.top_level = true
	root.add_child(_coverage)
	return cells


func _clear_coverage() -> void:
	if is_instance_valid(_coverage):
		_coverage.get_parent().remove_child(_coverage)
		_coverage.queue_free()
	_coverage = null


func _follow_history(root: Node) -> void:
	if _history and _history.version_changed.is_connected(_on_history_version):
		_history.version_changed.disconnect(_on_history_version)
	_history = null
	if root == null:
		return
	var manager := get_undo_redo()
	_history = manager.get_history_undo_redo(manager.get_object_history_id(root))
	_history.version_changed.connect(_on_history_version)


func _on_history_version() -> void:
	_refresh_dock.call_deferred()
	_request_coverage()
