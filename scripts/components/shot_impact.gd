class_name ShotImpact
extends RefCounted
## Retour visuel des tirs :
## - une balle manquée s'arrête sur le premier obstacle (mur, caisse, sol)
##   au-delà de la cible, dans une gerbe de poussière (`land`) ;
## - une balle qui touche fait jaillir une gerbe rouge sur la cible, et un
##   chiffre de dégâts s'élève au-dessus d'elle (`hit`) ;
## - une balle arrêtée par un bouclier fait des étincelles (`spark`).

## Obstacles qu'une balle manquée peut frapper (sol, murs et caisses).
const MASK_OBSTACLES := 0b011
## Distance au-delà du point visé jusqu'où une balle manquée peut aller.
const MISS_RANGE := 25.0
const DUST := Color(0.78, 0.7, 0.56)
const BLOOD := Color(0.62, 0.05, 0.04)
const SPARK := Color(1.0, 0.8, 0.35)
## Chiffre de dégâts : couleur (cible ennemie, opérateur touché), montée et
## durée.
const DAMAGE_ENEMY := Color(1.0, 0.92, 0.55)
const DAMAGE_FRIEND := Color(1.0, 0.35, 0.3)
const DAMAGE_RISE := 0.9
const DAMAGE_TIME := 0.9

## Hasard propre aux gerbes : le générateur global sert aux tirages du jeu
## (précision, parade), qu'un effet visuel ne doit pas modifier.
static var _rng := RandomNumberGenerator.new()
## Durée d'une gerbe.
const BURST_TIME := 0.45


## Fin de la trajectoire d'une balle manquée tirée de `muzzle` vers `aim` :
## premier obstacle touché (et gerbe de poussière), sinon le point visé
## prolongé.
static func land(parent: Node3D, muzzle: Vector3, aim: Vector3, exclude: Array[RID] = []) -> Vector3:
	var direction := (aim - muzzle).normalized()
	var end := aim + direction * MISS_RANGE
	var query := PhysicsRayQueryParameters3D.create(muzzle, end, MASK_OBSTACLES, exclude)
	var hit := parent.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return aim + direction * 4.0
	var point: Vector3 = hit["position"]
	burst(parent, point, hit["normal"], DUST, 10, 2.2)
	return point


## Balle qui touche `target` en `at`, tirée depuis `from` : gerbe rouge et
## chiffre des dégâts.
static func hit(parent: Node3D, target: Node3D, at: Vector3, from: Vector3, damage: float, friendly: bool) -> void:
	var back := (from - at)
	back.y = 0.0
	burst(parent, at, back.normalized() if back.length_squared() > 0.0001 else Vector3.UP, BLOOD, 8, 1.6)
	damage_label(parent, target.global_position + Vector3.UP * 2.0, damage, DAMAGE_FRIEND if friendly else DAMAGE_ENEMY)


## Balle arrêtée par un bouclier en `at`.
static func spark(parent: Node3D, at: Vector3, from: Vector3) -> void:
	burst(parent, at, (from - at).normalized(), SPARK, 12, 3.0)


## Petite gerbe de `amount` éclats en `at`, projetés autour de `normal`.
## Éclats animés à la main (et non `CPUParticles3D`, qui puise dans le
## générateur global du jeu).
static func burst(parent: Node, at: Vector3, normal: Vector3, color: Color, amount: int, speed: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Impact"
	parent.add_child(root)
	root.global_position = at
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	mesh.material = material
	var normal_dir := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var velocities: Array[Vector3] = []
	for i in amount:
		var chip := MeshInstance3D.new()
		chip.mesh = mesh
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chip.scale = Vector3.ONE * _rng.randf_range(0.6, 1.2)
		root.add_child(chip)
		var spread := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 0.8
		velocities.append((normal_dir + spread).normalized() * speed * _rng.randf_range(0.5, 1.0))
	var tween := root.create_tween()
	tween.tween_method(func(t: float) -> void:
		for i in velocities.size():
			(root.get_child(i) as Node3D).position = velocities[i] * t + Vector3.DOWN * 3.0 * t * t
		material.albedo_color.a = 1.0 - t / BURST_TIME
	, 0.0, BURST_TIME, BURST_TIME)
	tween.tween_callback(root.queue_free)
	return root


## Chiffre de dégâts (« -25 ») qui s'élève et s'efface au-dessus de `at`.
static func damage_label(parent: Node, at: Vector3, damage: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = "Damage"
	label.text = "-%d" % roundi(damage)
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.font_size = 44
	label.outline_size = 12
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.fixed_size = false
	parent.add_child(label)
	label.global_position = at
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position", at + Vector3.UP * DAMAGE_RISE, DAMAGE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, DAMAGE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "outline_modulate:a", 0.0, DAMAGE_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
	return label
