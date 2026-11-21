class_name Rocket
extends Node3D
## Roquette tirée par un ennemi armé d'un lance-roquettes : file en ligne
## droite en laissant une traînée de fumée. Près de la coque d'un convertible
## en vol, elle explose et l'endommage lourdement (`Tiltrotor.take_rocket`) ;
## sinon elle explose sur le premier obstacle, ou se perd au bout de sa
## course.

const SPEED := 34.0
const MAX_TRAVEL := 110.0
## Distance à la coque (m) à laquelle la fusée de proximité déclenche.
const PROXIMITY := 1.4
## Couches qui arrêtent la roquette : sol, murs, coques.
const MASK := 0b11
const TRAIL_INTERVAL := 0.03
const TRAIL_LIFE := 1.4

var _velocity: Vector3
var _travel: float = 0.0
var _trail_left: float = 0.0
var _exclude: Array[RID] = []


## Tire une roquette de `from` vers `toward`.
static func launch(parent: Node, from: Vector3, toward: Vector3, exclude: Array[RID]) -> Rocket:
	var rocket := Rocket.new()
	rocket._velocity = (toward - from).normalized() * SPEED
	rocket._exclude = exclude
	parent.add_child(rocket)
	rocket.global_position = from
	rocket._build()
	Sfx.play_at(&"explosion", from, -8.0)
	return rocket


func _build() -> void:
	look_at(global_position + _velocity, Vector3.UP if absf(_velocity.normalized().y) < 0.99 else Vector3.FORWARD)
	var body := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.05
	tube.bottom_radius = 0.05
	tube.height = 0.7
	body.mesh = tube
	body.rotation.x = PI / 2.0
	var olive := StandardMaterial3D.new()
	olive.albedo_color = Color(0.3, 0.33, 0.22)
	body.material_override = olive
	add_child(body)
	var flame := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.12
	ball.height = 0.24
	flame.mesh = ball
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.75, 0.3)
	flame.material_override = glow
	flame.position = Vector3(0, 0, 0.4)
	add_child(flame)


func _physics_process(delta: float) -> void:
	var step := _velocity * delta
	var next := global_position + step
	for node in get_tree().get_nodes_in_group(Tiltrotor.GROUP):
		var aircraft := node as Tiltrotor
		if aircraft and aircraft.is_in_air() and aircraft.distance_to_hull(next) <= PROXIMITY:
			aircraft.take_rocket(next)
			_explode(next)
			return
	var query := PhysicsRayQueryParameters3D.create(global_position, next, MASK, _exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var aircraft := hit["collider"] as Tiltrotor
		if aircraft == null and hit["collider"] is Node:
			aircraft = (hit["collider"] as Node).get_parent() as Tiltrotor
		if aircraft and aircraft.is_in_air():
			aircraft.take_rocket(hit["position"])
			_explode(hit["position"])
		else:
			_explode(hit["position"], true)
		return
	global_position = next
	_travel += step.length()
	_trail_left -= delta
	if _trail_left <= 0.0:
		_trail_left = TRAIL_INTERVAL
		_puff()
	if _travel >= MAX_TRAVEL:
		_explode(global_position)


## Bouffée de fumée laissée derrière la roquette.
func _puff() -> void:
	var puff := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	sphere.radial_segments = 8
	sphere.rings = 4
	puff.mesh = sphere
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.75, 0.74, 0.72, 0.55)
	puff.material_override = material
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(puff)
	puff.global_position = global_position
	var tween := puff.create_tween().set_parallel(true)
	tween.tween_property(puff, "scale", Vector3.ONE * 3.0, TRAIL_LIFE)
	tween.tween_property(material, "albedo_color:a", 0.0, TRAIL_LIFE)
	tween.chain().tween_callback(puff.queue_free)


## Explosion à `at` : en l'air, simple éclair (la coque encaisse) ; au sol,
## petite charge (`grounded`).
func _explode(at: Vector3, grounded: bool = false) -> void:
	if grounded:
		Explosion.detonate(get_parent(), at, 3.0, 90.0, 35.0)
	else:
		Explosion.detonate(get_parent(), at, 2.0, 0.0, 40.0)
	queue_free()
