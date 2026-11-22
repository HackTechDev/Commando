class_name Explosion
extends Node3D
## Explosion d'une grenade ou d'une charge : dégâts qui décroissent avec la
## distance (ennemis et opérateurs à découvert, les murs protègent), décor
## touché (murs fragiles abattus, caisses et bidons détruits ou projetés), grand
## bruit (les ennemis qui l'entendent donnent l'alerte), éclair et boule de feu.

## Véhicules au sol que le souffle abîme (`blast(at, radius)`).
const VEHICLES_GROUP := &"ground_vehicles"

const MASK_OCCLUDERS := 0b10
const DURATION := 0.7

var radius: float = 4.0


## Fait exploser une charge à `at` : `damage` au centre, nul à `blast_radius`.
static func detonate(parent: Node, at: Vector3, blast_radius: float, damage: float, noise_radius: float) -> Explosion:
	var explosion := Explosion.new()
	explosion.radius = blast_radius
	parent.add_child(explosion)
	explosion.global_position = at
	explosion._blast(damage, noise_radius)
	return explosion


## Dégâts reçus à `distance` du centre.
static func damage_at(distance: float, blast_radius: float, damage: float) -> float:
	return damage * clampf(1.0 - distance / blast_radius, 0.0, 1.0)


func _blast(damage: float, noise_radius: float) -> void:
	var center := global_position + Vector3.UP * 0.4
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		var distance := enemy.global_position.distance_to(global_position)
		if distance < radius and _exposed(center, enemy.global_position + Vector3.UP):
			enemy.take_hit(damage_at(distance, radius, damage), global_position)
	for unit in Unit.targets(get_tree()):
		var distance := unit.global_position.distance_to(global_position)
		if distance < radius and _exposed(center, unit.global_position + Vector3.UP):
			unit.health.take_damage(damage_at(distance, radius, damage))
	_damage_scenery()
	EventBus.noise_emitted.emit(global_position, noise_radius, &"explosion")
	Sfx.play_at(&"explosion", global_position)
	_show()


## Dégâts au décor : murs fragiles abattus, caisses et bidons détruits tout
## près ou projetés (`Climbable.blast`).
func _damage_scenery() -> void:
	for node in get_tree().get_nodes_in_group(FragileWall.GROUP):
		var wall := node as FragileWall
		if wall and wall.is_breached_by(global_position, radius):
			wall.break_apart(global_position)
	for node in get_tree().get_nodes_in_group(Tiltrotor.GROUP):
		(node as Tiltrotor).blast(global_position, radius)
	for node in get_tree().get_nodes_in_group(VEHICLES_GROUP):
		node.call(&"blast", global_position, radius)
	for node in get_tree().get_nodes_in_group(SabotageTarget.GROUP):
		(node as SabotageTarget).blast(global_position, radius)
	for node in get_tree().get_nodes_in_group(Door.GROUP):
		(node as Door).blast(global_position, radius)
	for node in get_tree().get_nodes_in_group(&"climbables"):
		var prop := node as Climbable
		if prop:
			prop.blast(global_position, radius)


func _exposed(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_OCCLUDERS)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Boule de feu qui gonfle et s'efface, éclair de lumière.
func _show() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.65, 0.25, 0.9)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	ball.mesh = sphere
	ball.material_override = material
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.scale = Vector3.ONE * 0.2
	ball.position.y = 0.5
	add_child(ball)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 8.0
	light.omni_range = radius * 2.5
	light.position.y = 1.0
	add_child(light)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ball, "scale", Vector3.ONE * radius * 0.55, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(material, "albedo_color", Color(0.25, 0.22, 0.2, 0.0), DURATION)
	tween.tween_property(light, "light_energy", 0.0, DURATION * 0.6)
	tween.chain().tween_callback(queue_free)
