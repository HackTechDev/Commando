class_name ExtractionZone
extends Area3D
## Zone d'extraction et objectif d'escorte : la mission est réussie quand
## tous les VIP du niveau (groupe « vips ») y sont entrés, manquée si l'un
## d'eux est tué. Au sol : un cadre lumineux et son nom.

@export var size := Vector2(6.0, 6.0)
@export var color := Color(0.3, 0.85, 1.0)
@export var objective_id: StringName = &"vip_extracted"

## Mission terminée (réussie ou manquée).
var is_over: bool = false
## VIP du niveau à évacuer, et ceux déjà arrivés.
var _vips: Array[Vip] = []
var _arrived: Array[Vip] = []


func _enter_tree() -> void:
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	collision_layer = 0
	# Couche des unités du joueur (opérateurs, VIP).
	collision_mask = 0b100
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 2.0, size.y)
	shape.shape = box
	shape.position.y = 1.0
	add_child(shape)
	_build_marking()
	body_entered.connect(_on_body_entered)
	for node in get_tree().get_nodes_in_group(&"vips"):
		var vip := node as Vip
		if vip:
			_vips.append(vip)
			vip.killed.connect(_on_vip_killed.bind(vip))


## Nombre de VIP déjà évacués et à évacuer.
func progress() -> Vector2i:
	return Vector2i(_arrived.size(), _vips.size())


## Point où se met à l'abri le `index`-ième VIP arrivé (ils se rangent côte à côte).
func shelter_point(index: int) -> Vector3:
	var x := (float(index % 3) - 1.0) * 1.2
	var z := (float(index / 3) - 0.5) * 1.2
	return global_transform * Vector3(x, 0.0, z)


func _on_body_entered(body: Node3D) -> void:
	var vip := body as Vip
	if vip == null or is_over or vip.is_dead or _arrived.has(vip):
		return
	vip.evacuate(shelter_point(_arrived.size()))
	_arrived.append(vip)
	if _arrived.size() >= _vips.size():
		is_over = true
		EventBus.objective_completed.emit(objective_id)
		EventBus.mission_ended.emit(true, "RÉUSSITE — VIP évacué" if _vips.size() == 1 else "RÉUSSITE — VIP évacués")


func _on_vip_killed(vip: Vip) -> void:
	if is_over:
		return
	is_over = true
	EventBus.mission_ended.emit(false, "ÉCHEC — %s tué" % vip.display_name)


func _build_marking() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.85)
	var fill := material.duplicate() as StandardMaterial3D
	fill.albedo_color = Color(color, 0.12)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = size
	var area := MeshInstance3D.new()
	area.name = "Area"
	area.mesh = floor_mesh
	area.material_override = fill
	area.position.y = 0.02
	area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(area)
	# Cadre : quatre bandes au bord.
	var band := 0.18
	for side: Vector4 in [Vector4(0, -1, 1, 0), Vector4(0, 1, 1, 0), Vector4(-1, 0, 0, 1), Vector4(1, 0, 0, 1)]:
		var strip := PlaneMesh.new()
		strip.size = Vector2(size.x if side.z > 0.0 else band, size.y if side.w > 0.0 else band)
		var edge := MeshInstance3D.new()
		edge.mesh = strip
		edge.material_override = material
		edge.position = Vector3(side.x * (size.x - band) * 0.5, 0.03, side.y * (size.y - band) * 0.5)
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(edge)
	var label := Label3D.new()
	label.name = "Label"
	label.text = "EXTRACTION"
	label.modulate = color
	label.font_size = 96
	label.pixel_size = 0.011
	label.rotation.x = -PI / 2.0
	label.position = Vector3(0.0, 0.04, 0.0)
	label.shaded = false
	add_child(label)


## Sauvegarde rapide (`QuickSave`) : VIP déjà évacués, mission terminée.
func save_state() -> Dictionary:
	var arrived: Array[String] = []
	for vip in _arrived:
		arrived.append(String(vip.get_path()))
	return {"arrived": arrived, "is_over": is_over}


func load_state(data: Dictionary) -> void:
	_arrived.clear()
	for path: String in data.get("arrived", []):
		var vip := get_node_or_null(NodePath(path)) as Vip
		if vip:
			_arrived.append(vip)
	is_over = is_over or data.get("is_over", false)
