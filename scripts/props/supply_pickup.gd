@tool
class_name SupplyPickup
extends Node3D
## Ravitaillement à ramasser : chargeurs, grenades, fumigènes ou trousse de
## soins, posé au sol (carte) ou laissé par un ennemi abattu (chargeur).
##
## Un opérateur à pied qui passe dessus (à 0,9 m) prend ce qui lui manque
## (`Commando.take_supplies`) ; le reste demeure pour un autre. Un repère au
## sol, de la couleur du lot, aide à le retrouver ; un clic droit à côté y
## envoie l'unité, comme pour le couteau de lancer.

enum Kind { AMMO, GRENADES, SMOKE, MEDKIT }

const GROUP := &"supply_pickups"
const PICKUP_RADIUS := 0.9
const PICKUP_HEIGHT := 0.8
const CHECK_INTERVAL := 0.1
const MASK_GROUND := 0b1
## Couleur du repère au sol, par lot.
const MARK_COLORS := {
	Kind.AMMO: Color(1.0, 0.8, 0.25, 0.75),
	Kind.GRENADES: Color(0.55, 0.85, 0.3, 0.75),
	Kind.SMOKE: Color(0.8, 0.8, 0.85, 0.75),
	Kind.MEDKIT: Color(1.0, 0.35, 0.35, 0.75),
}
## Nom du lot (texte flottant au ramassage), au singulier et au pluriel.
const NAMES := {
	Kind.AMMO: ["chargeur", "chargeurs"],
	Kind.GRENADES: ["grenade", "grenades"],
	Kind.SMOKE: ["fumigène", "fumigènes"],
	Kind.MEDKIT: ["trousse de soins", "trousses de soins"],
}

@export var kind: Kind = Kind.AMMO:
	set(value):
		kind = value
		_queue_rebuild()
## Quantité : chargeurs (de l'arme de celui qui les prend), grenades,
## fumigènes ou trousses.
@export_range(1, 10) var amount: int = 2

var _check_left: float = 0.0
var _rebuild_queued: bool = false


## Pose un lot en `at` (au sol sous ce point) dans `parent`.
static func drop(parent: Node, at: Vector3, what: Kind, count: int) -> SupplyPickup:
	var pickup := SupplyPickup.new()
	pickup.kind = what
	pickup.amount = count
	pickup.name = "Supply"
	parent.add_child(pickup)
	pickup.global_position = at
	pickup.rotation.y = randf() * TAU
	pickup.settle()
	return pickup


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(QuickSave.GROUP)
		add_to_group(GROUP)


func _ready() -> void:
	_build()
	_check_left = randf() * CHECK_INTERVAL


## Pose le lot sur le sol (ou la caisse) sous lui.
func settle() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.DOWN * 3.0, MASK_GROUND)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.has("position"):
		global_position.y = (hit["position"] as Vector3).y


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or amount <= 0:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit == null or unit.is_dead or unit.riding or unit.airborne_in:
			continue
		var offset := unit.global_position - global_position
		if absf(offset.y) > PICKUP_HEIGHT or Vector2(offset.x, offset.z).length() > PICKUP_RADIUS:
			continue
		var taken := unit.take_supplies(kind, amount)
		if taken <= 0:
			continue
		amount -= taken
		_float_text(unit, "+%d %s" % [taken, NAMES[kind][0 if taken == 1 else 1]])
		if amount <= 0:
			queue_free()
			return


## Texte qui monte au-dessus de l'opérateur et s'efface.
func _float_text(unit: Node3D, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.font_size = 26
	label.outline_size = 8
	label.modulate = Color(MARK_COLORS[kind], 1.0)
	unit.get_parent().add_child(label)
	label.global_position = unit.global_position + Vector3.UP * 2.3
	var tween := label.create_tween()
	tween.tween_property(label, "global_position", label.global_position + Vector3.UP * 0.8, 1.4)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.4).set_delay(0.6)
	tween.tween_callback(label.queue_free)


func save_state() -> Dictionary:
	return {"amount": amount}


## Lot entièrement pris dans la partie sauvegardée : il disparaît.
func load_state(data: Dictionary) -> void:
	amount = data.get("amount", amount)
	if amount <= 0:
		queue_free()


func _queue_rebuild() -> void:
	if not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child.owner == null:
			remove_child(child)
			child.queue_free()
	_build()


## Modèle du lot (boîtes simples) et repère au sol.
func _build() -> void:
	match kind:
		Kind.AMMO:
			# Caisse à munitions kaki, poignée sur le dessus.
			var olive := _material(Color(0.33, 0.36, 0.2))
			_box(Vector3(0.34, 0.2, 0.16), Vector3(0, 0.1, 0), olive)
			_box(Vector3(0.36, 0.03, 0.18), Vector3(0, 0.2, 0), olive)
			_box(Vector3(0.12, 0.025, 0.025), Vector3(0, 0.23, 0), _material(Color(0.15, 0.15, 0.14)))
			_box(Vector3(0.2, 0.06, 0.005), Vector3(0, 0.12, 0.081), _material(Color(0.85, 0.75, 0.3)))
		Kind.GRENADES, Kind.SMOKE:
			# Sacoche, et deux grenades (ou deux fumigènes) posées dessus.
			_box(Vector3(0.3, 0.1, 0.22), Vector3(0, 0.05, 0), _material(Color(0.3, 0.32, 0.22)))
			for side in [-1.0, 1.0]:
				if kind == Kind.GRENADES:
					var ball := MeshInstance3D.new()
					var sphere := SphereMesh.new()
					sphere.radius = 0.045
					sphere.height = 0.1
					ball.mesh = sphere
					ball.material_override = _material(Color(0.25, 0.3, 0.18))
					ball.position = Vector3(side * 0.07, 0.15, 0)
					add_child(ball)
				else:
					var can := MeshInstance3D.new()
					var cylinder := CylinderMesh.new()
					cylinder.top_radius = 0.032
					cylinder.bottom_radius = 0.032
					cylinder.height = 0.14
					can.mesh = cylinder
					can.material_override = _material(Color(0.55, 0.56, 0.58))
					can.position = Vector3(side * 0.07, 0.17, 0)
					add_child(can)
		Kind.MEDKIT:
			# Trousse blanche à croix rouge.
			_box(Vector3(0.3, 0.12, 0.22), Vector3(0, 0.06, 0), _material(Color(0.9, 0.9, 0.88)))
			var red := _material(Color(0.8, 0.1, 0.1))
			_box(Vector3(0.12, 0.005, 0.04), Vector3(0, 0.122, 0), red)
			_box(Vector3(0.04, 0.005, 0.12), Vector3(0, 0.122, 0), red)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.36
	var marker := MeshInstance3D.new()
	marker.mesh = ring
	var material := _material(MARK_COLORS[kind])
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.scale = Vector3(1.0, 0.15, 1.0)
	marker.position.y = 0.02
	add_child(marker)


func _box(size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)


func _material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.9
	return material
