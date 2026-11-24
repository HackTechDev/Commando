class_name SnowTracks
extends Node3D
## Traces de pas dans la neige (cartes à `Snowfall`, `tracks`) : un
## opérateur qui marche, court ou rampe au sol, dehors, laisse une empreinte
## tous les `STEP` mètres. La neige qui tombe les recouvre peu à peu
## (`LIFETIME`). Un garde au calme ou méfiant qui voit des traces fraîches
## (`NOTICE_AGE`) va voir, et suit la piste vers les plus récentes
## (`Enemy._look_for_tracks`).

const GROUP := &"snow_tracks"
## Pas (m) entre deux empreintes, et écart latéral entre pied gauche et droit.
const STEP := 0.75
const FOOT_SPREAD := 0.13
## Durée (s) avant d'être recouverte, et âge au-delà duquel un garde ne la
## remarque plus.
const LIFETIME := 150.0
const NOTICE_AGE := 75.0
## Empreintes gardées au plus.
const MAX_PRINTS := 600
## Hauteur (m) au-dessus de laquelle on n'est plus sur la neige du sol.
const GROUND_HEIGHT := 0.25
## Empreintes examinées au plus par un garde, à chaque regard.
const LOOK_LIMIT := 8

## Empreintes : {"at": Vector3, "yaw": float, "time": float, "prone": bool}.
var prints: Array[Dictionary] = []
var _time: float = 0.0
## Dernière empreinte de chaque opérateur : {unit: [position, côté]}.
var _last: Dictionary = {}
var _mesh: MultiMeshInstance3D
var _dirty: bool = false
var _refresh_left: float = 0.0


## Traces de la scène en cours, ou null.
static func of(tree: SceneTree) -> SnowTracks:
	return tree.get_first_node_in_group(GROUP) as SnowTracks if tree else null


## Temps de jeu (s) des traces.
func now() -> float:
	return _time


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")
	top_level = true
	global_transform = Transform3D.IDENTITY
	_mesh = MultiMeshInstance3D.new()
	_mesh.name = "Prints"
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var foot := QuadMesh.new()
	foot.size = Vector2(0.12, 0.28)
	foot.orientation = PlaneMesh.FACE_Y
	var look := StandardMaterial3D.new()
	look.albedo_color = Color(0.55, 0.62, 0.72)
	look.vertex_color_use_as_albedo = true
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.roughness = 1.0
	foot.material = look
	multi.mesh = foot
	_mesh.multimesh = multi
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_time += delta
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit == null or unit.is_dead or not _on_snow(unit):
			continue
		var here := unit.global_position
		var last: Array = _last.get(unit, [])
		if last.is_empty():
			_last[unit] = [here, 1]
			continue
		var from: Vector3 = last[0]
		var step := Vector2(here.x - from.x, here.z - from.z)
		if step.length() < STEP:
			continue
		var side: int = -int(last[1])
		var yaw := atan2(-step.x, -step.y)
		var prone := unit.posture == SoldierModel.Posture.PRONE
		var offset := Vector3(cos(yaw), 0.0, -sin(yaw)) * (0.0 if prone else FOOT_SPREAD * side)
		add_print(Vector3(here.x, 0.0, here.z) + offset, yaw, prone)
		_last[unit] = [here, side]
	_refresh_left -= delta
	if _dirty or _refresh_left <= 0.0:
		_refresh_left = 2.0
		_dirty = false
		_rebuild()


## Ajoute une empreinte en `at` (au sol), orientée selon `yaw` ; trace large
## pour un opérateur qui rampe.
func add_print(at: Vector3, yaw: float, prone: bool = false) -> void:
	prints.append({"at": at, "yaw": yaw, "time": _time, "prone": prone})
	if prints.size() > MAX_PRINTS:
		prints.pop_front()
	_dirty = true


## Au sol, dehors, à pied : il marque la neige.
func _on_snow(unit: Commando) -> bool:
	if unit.global_position.y > GROUND_HEIGHT or unit.airborne_in or unit.riding or unit.perched_on:
		return false
	var probe := unit.global_position + Vector3.UP * 0.3
	return Building.at(get_tree(), probe) == null and Tower.at(get_tree(), probe) == null


## Empreintes affichées : les recouvertes disparaissent, les autres pâlissent
## avec l'âge.
func _rebuild() -> void:
	while not prints.is_empty() and _time - float(prints[0]["time"]) > LIFETIME:
		prints.pop_front()
	var multi := _mesh.multimesh
	multi.instance_count = prints.size()
	for i in prints.size():
		var entry := prints[i]
		var basis := Basis(Vector3.UP, entry["yaw"])
		if entry["prone"]:
			basis = basis.scaled(Vector3(4.0, 1.0, 2.0))
		multi.set_instance_transform(i, Transform3D(basis, (entry["at"] as Vector3) + Vector3.UP * 0.015))
		var age := clampf((_time - float(entry["time"])) / LIFETIME, 0.0, 1.0)
		multi.set_instance_color(i, Color(1, 1, 1, 0.75 * (1.0 - age)))


## Empreinte fraîche, plus récente que `newer_than`, que voit `enemy` :
## la plus récente parmi les plus proches de lui ; vide sinon.
func freshest_seen_by(enemy: Enemy, newer_than: float) -> Dictionary:
	var reach := enemy._vision.config.far_range if enemy._vision.config else 10.0
	var candidates: Array[Dictionary] = []
	for i in range(prints.size() - 1, -1, -1):
		var entry := prints[i]
		var time: float = entry["time"]
		if time <= newer_than or _time - time > NOTICE_AGE:
			continue
		if (entry["at"] as Vector3).distance_to(enemy.global_position) > reach:
			continue
		candidates.append(entry)
		if candidates.size() >= LOOK_LIMIT:
			break
	for entry in candidates:
		if enemy._vision.sees_point((entry["at"] as Vector3) + Vector3.UP * 0.05):
			return entry
	return {}


## Sauvegarde rapide : les empreintes et l'heure des traces.
func save_state() -> Dictionary:
	return {"time": _time, "prints": prints.duplicate(true)}


func load_state(data: Dictionary) -> void:
	_time = data.get("time", _time)
	prints.clear()
	for entry: Dictionary in data.get("prints", []):
		prints.append(entry)
	_last.clear()
	_dirty = true
