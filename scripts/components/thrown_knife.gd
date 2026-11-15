class_name ThrownKnife
extends Node3D
## Couteau de lancer : vole en tournoyant vers sa cible et la tue sans bruit
## s'il la touche. Il reste alors planté dans le corps (et le suit dans sa
## chute) ; raté, il tombe au sol. Un opérateur le ramasse en passant tout
## près.

const SPEED := 14.0
const SPIN_SPEED := 22.0
## Hauteur visée sur la cible (poitrine).
const TARGET_HEIGHT := 1.2
## Flèche de la trajectoire par mètre parcouru.
const ARC_PER_METER := 0.03
## Distance (horizontale) à laquelle un opérateur ramasse le couteau.
const PICKUP_RADIUS := 0.9
## Couteau raté : il file encore un peu au-delà de la cible avant de tomber.
const MISS_OVERSHOOT := 1.8
const MISS_SPREAD := 0.7
## Bruit de la lame qui tombe au sol après un raté.
const MISS_NOISE_RADIUS := 4.0
const MASK_GROUND := 0b011
## Planté : la garde reste à cette distance (m) en avant du centre du torse.
const PLANT_DEPTH := 0.2

var _target: Enemy
var _thrower_position: Vector3
var _hit: bool = false
var _from: Vector3
var _miss_point: Vector3
var _travel: float = 0.0
var _on_ground: bool = false
## Planté dans le corps de la cible.
var _planted: bool = false
var _spin: Node3D
var _marker: MeshInstance3D


## Lance un couteau de `from` vers `target`. `hit` : le lancer porte.
static func spawn(parent: Node, from: Vector3, target: Enemy, hit: bool, thrower_position: Vector3) -> ThrownKnife:
	var knife := ThrownKnife.new()
	knife._target = target
	knife._hit = hit
	knife._from = from
	knife._thrower_position = thrower_position
	parent.add_child(knife)
	knife.global_position = from
	if not hit:
		var aim := target.global_position + Vector3.UP * TARGET_HEIGHT
		var flat := aim - from
		flat.y = 0.0
		var side := flat.normalized().cross(Vector3.UP) * MISS_SPREAD * (1.0 if randf() < 0.5 else -1.0)
		knife._miss_point = aim + flat.normalized() * MISS_OVERSHOOT + side
	return knife


func _ready() -> void:
	_spin = Node3D.new()
	add_child(_spin)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.028, 0.09, 0.032)
	handle.mesh = handle_mesh
	handle.material_override = _material(Color(0.16, 0.17, 0.14), 0.85, 0.0)
	_spin.add_child(handle)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.012, 0.19, 0.03)
	blade.mesh = blade_mesh
	blade.material_override = _material(Color(0.72, 0.74, 0.78), 0.25, 0.9)
	blade.position = Vector3(0.0, -0.13, 0.0)
	_spin.add_child(blade)


func _physics_process(delta: float) -> void:
	if _on_ground:
		if _planted:
			_follow_marker()
		_check_pickup()
		return
	var goal := _goal()
	var total := _from.distance_to(goal)
	_travel += SPEED * delta
	var t := 1.0 if total < 0.01 else minf(_travel / total, 1.0)
	var position_now := _from.lerp(goal, t) + Vector3.UP * (4.0 * t * (1.0 - t) * ARC_PER_METER * total)
	var direction := position_now - global_position
	global_position = position_now
	if direction.length_squared() > 0.000001 and absf(direction.normalized().y) < 0.99:
		look_at(global_position + direction, Vector3.UP)
	_spin.rotation.x -= SPIN_SPEED * delta
	if t >= 1.0:
		_arrive()


## Point d'arrivée : la poitrine de la cible (qui peut bouger), ou un point
## au-delà en cas de raté.
func _goal() -> Vector3:
	if _hit and is_instance_valid(_target):
		return _target.global_position + Vector3.UP * TARGET_HEIGHT
	return _miss_point


func _arrive() -> void:
	var rest := global_position
	if _hit and is_instance_valid(_target):
		if not _target.is_dead:
			# Touché dans le dos, il s'effondre vers l'avant.
			_target.kill_silently(_target.is_behind(_thrower_position))
			Sfx.play_at(&"knife", global_position, -4.0)
		_plant(_target)
		return
	else:
		if is_instance_valid(_target) and not _target.is_dead:
			# La lame tombe près de lui : il l'entend et va voir.
			if _target.global_position.distance_to(global_position) <= MISS_NOISE_RADIUS:
				_target.startle(global_position)
		EventBus.noise_emitted.emit(global_position, MISS_NOISE_RADIUS, &"knife")
		Sfx.play_at(&"clink", global_position, -4.0)
	_land(rest)


## Plante la lame dans le torse de `target`, dans l'axe du lancer : le
## couteau suit le corps dans sa chute et se ramasse sur lui.
func _plant(target: Enemy) -> void:
	var forward := target.global_position + Vector3.UP * TARGET_HEIGHT - _from
	forward.y *= 0.3
	forward = forward.normalized()
	var chest := target.global_position + Vector3.UP * TARGET_HEIGHT
	global_position = chest - forward * PLANT_DEPTH
	look_at(global_position + forward, Vector3.UP if absf(forward.y) < 0.99 else Vector3.FORWARD)
	# Lame vers l'avant (-Z), enfoncée ; la garde dépasse.
	_spin.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	var torso: Node3D = target._model._torso if target._model else null
	if torso:
		reparent(torso, true)
	_on_ground = true
	_planted = true
	add_to_group(&"knife_pickups")
	_add_marker()
	_marker.top_level = true
	_follow_marker()


## Repère au sol, sous la garde du couteau planté.
func _follow_marker() -> void:
	_marker.global_transform = Transform3D(Basis.IDENTITY, Vector3(global_position.x, _ground_y(global_position) + 0.03, global_position.z))


func _ground_y(at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 3.0, MASK_GROUND)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"].y if hit.has("position") else 0.0


## Pose le couteau à plat au sol (ou sur une caisse) et le rend ramassable.
func _land(at: Vector3) -> void:
	_on_ground = true
	global_position = Vector3(at.x, _ground_y(at) + 0.02, at.z)
	rotation = Vector3(0.0, randf() * TAU, 0.0)
	_spin.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	add_to_group(&"knife_pickups")
	_add_marker()


## Repère discret pour que le joueur retrouve le couteau.
func _add_marker() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.16
	ring.outer_radius = 0.2
	_marker = MeshInstance3D.new()
	_marker.mesh = ring
	var material := _material(Color(0.75, 0.4, 1.0, 0.7), 1.0, 0.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker.material_override = material
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)
	_marker.position = Vector3(0.0, 0.01, -0.05)


func _check_pickup() -> void:
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit == null or unit.is_dead:
			continue
		var offset := unit.global_position - global_position
		if absf(offset.y) > 0.8:
			continue
		offset.y = 0.0
		if offset.length() <= PICKUP_RADIUS and unit.pick_up_knife():
			queue_free()
			return


## Vrai une fois le couteau au sol ou planté, prêt à être ramassé.
func is_on_ground() -> bool:
	return _on_ground


## Vrai si le couteau est resté planté dans le corps de sa cible.
func is_planted() -> bool:
	return _planted


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
