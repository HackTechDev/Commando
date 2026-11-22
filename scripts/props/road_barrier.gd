@tool
class_name RoadBarrier
extends Node3D
## Barrière de poste de contrôle : deux poteaux et une lisse rayée rouge et
## blanc en travers de la piste (le long de l'axe X local, centrée).
##
## Fermée, elle arrête le Sabre : il la force en roulant dessus (`smash`),
## ce qui la brise dans un fracas qui attire les gardes et abîme le véhicule,
## d'autant plus qu'il va vite. Un opérateur à pied peut aussi aller au
## poteau de commande et la lever (ou la baisser) sans bruit
## (`request_toggle`).
##
## La lisse n'a pas de collision (elle couperait la piste dans la
## navigation) : le véhicule la teste devant lui (`ahead`), le clic la
## cherche le long du rayon de la souris (`picked`). Les fantassins passent
## dessous.

const GROUP := &"road_barriers"
## Hauteur de la lisse (m), portée du clic autour d'elle.
const BOOM_HEIGHT := 1.0
const PICK_REACH := 0.4
## Lever ou baisser à la main : distance au poteau, durée du geste (s).
const OPERATE_REACH := 1.3
const OPERATE_TIME := 1.2
## Forcer : profondeur testée devant le pare-chocs (m), dégâts au véhicule
## (à l'arrêt presque, et à pleine vitesse), rayon du fracas (m).
const RAM_DEPTH := 1.2
const RAM_DAMAGE_SLOW := 20.0
const RAM_DAMAGE_FAST := 90.0
const RAM_TIRE_CHANCE := 0.5
const RAM_NOISE := 30.0

## Largeur de la piste barrée (entre les poteaux, m).
@export var width: float = 4.4
@export var start_open: bool = false

var is_open: bool = false
var is_broken: bool = false
var _pivot: Node3D
var _wreck: Node3D
var _operator: Commando
var _operate_left: float = 0.0


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	var post_mat := _mat(Color(0.25, 0.26, 0.27))
	for x: float in [-width * 0.5 - 0.15, width * 0.5 + 0.15]:
		var post := StaticBody3D.new()
		post.collision_layer = 0b10
		post.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.3, 1.2, 0.3)
		shape.shape = box
		shape.position.y = 0.6
		post.add_child(shape)
		post.position.x = x
		add_child(post)
		_box(post, Vector3(0.3, 1.2, 0.3), Vector3(0, 0.6, 0), post_mat)
	# Coffret de commande sur le poteau gauche.
	_box(self, Vector3(0.4, 0.5, 0.35), Vector3(-width * 0.5 - 0.15, 0.7, 0.3), _mat(Color(0.8, 0.62, 0.1)))
	_pivot = Node3D.new()
	_pivot.position = Vector3(-width * 0.5 - 0.15, BOOM_HEIGHT, 0)
	add_child(_pivot)
	_build_boom(_pivot, width + 0.3)
	is_open = start_open
	_pivot.rotation.z = _open_angle() if is_open else 0.0


func _open_angle() -> float:
	return deg_to_rad(80.0)


## Lisse rayée, de l'origine de `parent` vers +X, sur `length` m.
func _build_boom(parent: Node3D, length: float) -> void:
	var red := _mat(Color(0.78, 0.12, 0.1))
	var white := _mat(Color(0.92, 0.92, 0.9))
	var stripe := 0.5
	var count := ceili(length / stripe)
	for i in count:
		var piece := minf(stripe, length - i * stripe)
		_box(parent, Vector3(piece, 0.1, 0.1), Vector3(i * stripe + piece * 0.5, 0, 0), red if i % 2 == 0 else white)


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material


## Vrai si la lisse barre la route.
func is_closed() -> bool:
	return not is_open and not is_broken


## Extrémités de la lisse (monde), fermée.
func boom_ends() -> PackedVector3Array:
	return PackedVector3Array([to_global(Vector3(-width * 0.5, BOOM_HEIGHT, 0)), to_global(Vector3(width * 0.5, BOOM_HEIGHT, 0))])


## Barrière fermée juste devant le pare-chocs de `sabre`, ou null.
static func ahead(sabre: Sabre) -> RoadBarrier:
	for node in sabre.get_tree().get_nodes_in_group(GROUP):
		var barrier := node as RoadBarrier
		if barrier == null or not barrier.is_closed():
			continue
		var ends := barrier.boom_ends()
		for i in 9:
			var local := sabre.to_local(ends[0].lerp(ends[1], i / 8.0))
			if local.z < -2.0 and local.z > -2.0 - RAM_DEPTH and absf(local.x) < SabreModel.HALF_WIDTH + 0.1:
				return barrier
	return null


## Barrière (lisse ou poteaux) le long du rayon `from` → `to`, ou null.
static func picked(tree: SceneTree, from: Vector3, to: Vector3) -> RoadBarrier:
	for node in tree.get_nodes_in_group(GROUP):
		var barrier := node as RoadBarrier
		if barrier == null or barrier.is_broken:
			continue
		var a := barrier.to_global(Vector3(-barrier.width * 0.5 - 0.15, 0.2, 0))
		var b := barrier.to_global(Vector3(-barrier.width * 0.5 - 0.15, 1.2, 0))
		var segments: Array[PackedVector3Array] = [PackedVector3Array([a, b])]
		if barrier.is_open:
			segments.append(PackedVector3Array([barrier._pivot.global_position, barrier._pivot.to_global(Vector3(barrier.width, 0, 0))]))
		else:
			segments.append(barrier.boom_ends())
		for segment in segments:
			var closest := Geometry3D.get_closest_points_between_segments(from, to, segment[0], segment[1])
			if closest[0].distance_to(closest[1]) <= PICK_REACH:
				return barrier
	return null


## Point au sol près du coffret de commande, du côté de `from`.
func control_point(from: Vector3) -> Vector3:
	var side := signf(to_local(from).z)
	if side == 0.0:
		side = 1.0
	return to_global(Vector3(-width * 0.5 - 0.15, 0.0, side * 0.8))


## Raison pour laquelle on ne peut pas lever ou baisser la barrière (vide :
## c'est possible).
func toggle_problem() -> String:
	if is_broken:
		return "barrière brisée"
	return ""


## Envoie `unit` au coffret lever (ou baisser) la barrière.
func request_toggle(unit: Commando, run: bool) -> bool:
	if toggle_problem() != "" or unit == null or unit.is_dead or unit.riding:
		return false
	_operator = unit
	_operate_left = OPERATE_TIME
	unit.move_to(control_point(unit.global_position), run)
	return true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _operator == null:
		return
	if not is_instance_valid(_operator) or _operator.is_dead or _operator.riding or is_broken:
		_operator = null
		return
	var spot := control_point(_operator.global_position)
	var flat := Vector2(_operator.global_position.x - spot.x, _operator.global_position.z - spot.z).length()
	if flat > OPERATE_REACH:
		# Il est parti ailleurs : ordre abandonné.
		if not _operator.is_walking():
			_operator = null
		return
	_operate_left -= delta
	if _operate_left <= 0.0:
		var unit := _operator
		_operator = null
		set_open(not is_open)
		unit.flash_message("Barrière levée" if is_open else "Barrière baissée")


## Lève ou baisse la lisse (sans bruit, sauf un grincement tout proche).
func set_open(value: bool, animate: bool = true) -> void:
	if is_broken:
		return
	is_open = value
	var angle := _open_angle() if value else 0.0
	if animate and is_inside_tree():
		create_tween().tween_property(_pivot, "rotation:z", angle, 0.9).set_trans(Tween.TRANS_SINE)
		Sfx.play_at(&"scrape", global_position + Vector3.UP, -10.0)
		EventBus.noise_emitted.emit(global_position, 3.0, &"distraction")
	else:
		_pivot.rotation.z = angle


## Le Sabre force la barrière à `speed` m/s : la lisse se brise (fracas qui
## attire les gardes), le véhicule est abîmé, d'autant plus qu'il va vite.
func smash(sabre: Sabre, speed: float) -> void:
	if not is_closed():
		return
	_set_broken(true, sabre.global_basis.z * -1.0)
	var share := clampf(speed / Sabre.SPEED, 0.0, 1.0)
	sabre.take_ram(lerpf(RAM_DAMAGE_SLOW, RAM_DAMAGE_FAST, share), share >= 0.7 and randf() < RAM_TIRE_CHANCE)
	Sfx.play_at(&"block", global_position + Vector3.UP, 4.0)
	Sfx.play_at(&"fall", global_position + Vector3.UP, 0.0)
	EventBus.noise_emitted.emit(global_position, RAM_NOISE, &"distraction")


## Lisse brisée : elle tombe au sol, poussée dans le sens `push`.
func _set_broken(value: bool, push: Vector3 = Vector3.FORWARD) -> void:
	is_broken = value
	_operator = null
	_pivot.visible = not value
	if _wreck:
		_wreck.queue_free()
		_wreck = null
	if not value:
		return
	_wreck = Node3D.new()
	add_child(_wreck)
	# Un tronçon reste au poteau, le reste gît sur la piste, de travers.
	var stub := Node3D.new()
	stub.position = Vector3(-width * 0.5 - 0.15, BOOM_HEIGHT, 0)
	stub.rotation.z = deg_to_rad(-35.0)
	_wreck.add_child(stub)
	_build_boom(stub, 0.9)
	var piece := Node3D.new()
	var local_push := (global_basis.inverse() * push).normalized()
	piece.position = Vector3(-width * 0.5 + 0.8, 0.06, signf(local_push.z) * 1.6)
	piece.rotation.y = deg_to_rad(18.0)
	_wreck.add_child(piece)
	_build_boom(piece, width - 0.6)


## Sauvegarde rapide (`QuickSave`).
func save_state() -> Dictionary:
	return {"open": is_open, "broken": is_broken}


func load_state(data: Dictionary) -> void:
	_operator = null
	if data.get("broken", false) != is_broken:
		_set_broken(data.get("broken", false))
	set_open(data.get("open", false), false)
