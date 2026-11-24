class_name ShotImpact
extends RefCounted
## Retour visuel des tirs :
## - une balle manquée (`stray`) s'arrête sur le premier obstacle (mur,
##   caisse, véhicule, sol) au-delà de la cible, ou touche une autre unité
##   sur sa trajectoire (opérateur ou ennemi) ;
## - un impact sur un obstacle (`impact`) se voit (éclats selon la matière,
##   trace qui reste) et s'entend ; les gardes proches viennent voir ;
## - une balle qui touche fait jaillir une gerbe rouge sur la cible, et un
##   chiffre de dégâts s'élève au-dessus d'elle (`hit`) ;
## - une balle arrêtée par un bouclier fait des étincelles (`spark`).

## Obstacles qu'une balle manquée peut frapper (sol, murs et caisses).
const MASK_OBSTACLES := 0b011
## Unités qu'une balle perdue peut toucher : opérateurs (et VIP), ennemis
## debout.
const MASK_UNITS := 0b1100
## Rayon (m) du bruit d'impact d'une balle perdue : les gardes proches
## viennent voir (type « impact »).
const IMPACT_NOISE_RADIUS := 7.0
## Distance au-delà du point visé jusqu'où une balle manquée peut aller.
const MISS_RANGE := 25.0
const DUST := Color(0.78, 0.7, 0.56)
const BLOOD := Color(0.62, 0.05, 0.04)
const SPARK := Color(1.0, 0.8, 0.35)
const WOOD := Color(0.55, 0.4, 0.24)
## Traces d'impact : taille (m), nombre maximal gardé, groupe.
const MARK_SIZE := 0.09
const MARKS_MAX := 150
const MARKS_GROUP := &"bullet_marks"
static var _mark_meshes: Dictionary = {}
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


## Fin de la trajectoire d'une balle tirée de `muzzle` vers `aim`, sans
## toucher d'unité : premier obstacle (avec son `impact`), sinon le point
## visé prolongé.
static func land(parent: Node3D, muzzle: Vector3, aim: Vector3, exclude: Array[RID] = []) -> Vector3:
	var direction := (aim - muzzle).normalized()
	var query := PhysicsRayQueryParameters3D.create(muzzle, aim + direction * MISS_RANGE, MASK_OBSTACLES, exclude)
	var hit := parent.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return aim + direction * 4.0
	var point: Vector3 = hit["position"]
	impact(parent, point, hit["normal"], hit.get("collider") as Node)
	return point


## Impact d'une balle sur un obstacle (`collider`) en `point` : éclats selon
## la matière (étincelles sur le métal des véhicules, échardes sur le bois
## des caisses et des portes, poussière ailleurs), bruit d'impact, et trace
## qui reste (`mark`), accrochée à l'objet (elle suit un véhicule).
static func impact(parent: Node3D, point: Vector3, normal: Vector3, collider: Node) -> void:
	match material_of(collider):
		&"metal":
			burst(parent, point, normal, SPARK, 12, 3.0)
			Sfx.play_at(&"ricochet", point, -8.0, 0.2)
		&"wood":
			burst(parent, point, normal, WOOD, 9, 2.0)
			Sfx.play_at(&"impact_wood", point, -4.0, 0.12)
		_:
			burst(parent, point, normal, DUST, 10, 2.2)
			Sfx.play_at(&"impact", point, -4.0, 0.12)
	mark(collider as Node3D if collider is Node3D else parent, point, normal, material_of(collider) == &"metal")


## Matière de l'obstacle touché : &"metal" (véhicules), &"wood" (caisses,
## portes) ou &"stone" (murs, sol, le reste).
static func material_of(collider: Node) -> StringName:
	if collider is Tiltrotor or collider is TrafficCar or collider is Sabre or collider is Technical:
		return &"metal"
	if collider is Climbable or collider is Door:
		return &"wood"
	# Pièce d'un véhicule ou d'une porte (corps enfant).
	var owner_node := collider.get_parent() if collider else null
	if owner_node is Tiltrotor or owner_node is Sabre or owner_node is TrafficCar or owner_node is Technical:
		return &"metal"
	if owner_node is Door:
		return &"wood"
	return &"stone"


## Trace d'impact posée sur la surface en `point`, enfant de `host` : petit
## disque sombre, ou éraflure claire sur le métal et les vitres (`metal`).
## Les plus anciennes disparaissent au-delà de `MARKS_MAX`.
static func mark(host: Node3D, point: Vector3, normal: Vector3, metal: bool = false) -> MeshInstance3D:
	if host == null or not host.is_inside_tree():
		return null
	var key := 1 if metal else 0
	if not _mark_meshes.has(key):
		var mesh := QuadMesh.new()
		mesh.size = Vector2(MARK_SIZE, MARK_SIZE)
		# Disque au bord adouci (dégradé radial) : trou sombre, ou éraflure
		# claire cerclée de sombre sur le métal.
		var gradient := Gradient.new()
		if metal:
			gradient.set_color(0, Color(0.12, 0.12, 0.13, 1.0))
			gradient.set_color(1, Color(0.85, 0.85, 0.82, 0.0))
			gradient.add_point(0.3, Color(0.88, 0.88, 0.86, 0.95))
		else:
			gradient.set_color(0, Color(0.04, 0.035, 0.03, 0.95))
			gradient.set_color(1, Color(0.1, 0.09, 0.08, 0.0))
			gradient.add_point(0.45, Color(0.05, 0.045, 0.04, 0.85))
		var disc := GradientTexture2D.new()
		disc.gradient = gradient
		disc.fill = GradientTexture2D.FILL_RADIAL
		disc.fill_from = Vector2(0.5, 0.5)
		disc.fill_to = Vector2(1.0, 0.5)
		disc.width = 32
		disc.height = 32
		var look := StandardMaterial3D.new()
		look.albedo_texture = disc
		look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		look.roughness = 1.0
		mesh.material = look
		_mark_meshes[key] = mesh
	var spot := MeshInstance3D.new()
	spot.name = "BulletMark"
	spot.mesh = _mark_meshes[key]
	spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spot.add_to_group(MARKS_GROUP)
	host.add_child(spot)
	var n := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var up := Vector3.FORWARD if absf(n.dot(Vector3.UP)) > 0.95 else Vector3.UP
	# Le quad regarde vers +Z local : on l'aligne sur la normale.
	spot.global_basis = Basis.looking_at(-n, up)
	spot.global_position = point + n * 0.01
	spot.rotate_object_local(Vector3.BACK, _rng.randf() * TAU)
	var marks := host.get_tree().get_nodes_in_group(MARKS_GROUP)
	if marks.size() > MARKS_MAX:
		(marks[0] as Node).queue_free()
	return spot


## Balle manquée tirée de `muzzle` vers `aim` (hors `exclude` : le tireur
## et sa cible) : elle frappe le premier obstacle ou la première unité sur
## sa trajectoire. Une unité touchée encaisse `damage` (un ennemi se tourne
## vers `from`) ; un obstacle fait une gerbe de poussière et un bruit
## d'impact. Renvoie le point d'arrivée.
static func stray(parent: Node3D, muzzle: Vector3, aim: Vector3, exclude: Array[RID], damage: float, from: Vector3) -> Vector3:
	var direction := (aim - muzzle).normalized()
	var end := aim + direction * MISS_RANGE
	var query := PhysicsRayQueryParameters3D.create(muzzle, end, MASK_OBSTACLES | MASK_UNITS, exclude)
	var hit := parent.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return aim + direction * 4.0
	var point: Vector3 = hit["position"]
	var collider := hit.get("collider") as Node3D
	if collider is Enemy:
		var enemy := collider as Enemy
		ShotImpact.hit(parent, enemy, point, muzzle, damage, false)
		enemy.take_hit(damage, from)
		return point
	if collider is Unit and not (collider as Unit).is_dead:
		var unit := collider as Unit
		ShotImpact.hit(parent, unit, point, muzzle, damage, true)
		unit.health.take_damage(damage)
		return point
	impact(parent, point, hit["normal"], collider)
	EventBus.noise_emitted.emit(point, IMPACT_NOISE_RADIUS, &"impact")
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
