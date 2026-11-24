@tool
class_name WeatherParticles
extends Node3D
## Précipitations (neige, pluie) : particules émises dans un volume centré
## sur le point du sol que vise la caméra, qu'il suit. Les particules
## restent dans le monde (`local_coords` faux) quand le volume se déplace :
## le coût est fixe, quelle que soit la taille de la carte.
##
## Effets de jeu (réglés par type, voir `sight_factor` et `hearing_factor`
## des sous-classes) : les gardes voient moins loin (zone lointaine), et
## entendent moins loin les bruits discrets (pas, chutes, appâts…) ; les
## coups de feu, explosions et cris portent toujours.
##
## Les particules sont celles d'un enfant interne (`Fall`, sans
## propriétaire, jamais enregistré), placé hors du repère du nœud
## (`top_level`) : le nœud de la scène ne change pas, ni en jeu ni dans
## l'éditeur, où la météo s'affiche aussi (vue 3D de l'éditeur de mission,
## case « Météo » pour la masquer : `editor_hidden`).

## Demi-côté (m) du volume, et hauteur d'où tombent les particules.
const EXTENT := 34.0
const HEIGHT := 16.0
## Toutes les précipitations de la scène (pour la case de l'éditeur).
const GROUP := &"weather"

## Éditeur de mission : météo masquée dans la vue 3D.
static var editor_hidden: bool = false

## Particules affichées (enfant interne).
var fall: GPUParticles3D


## Part de la portée de vue lointaine des gardes qui reste (1 : aucun effet).
func sight() -> float:
	return 1.0


## Part de la portée d'ouïe des bruits discrets qui reste (1 : aucun effet).
func hearing() -> float:
	return 1.0


## Météo de la scène en cours, ou null.
static func of(tree: SceneTree) -> WeatherParticles:
	return tree.get_first_node_in_group(GROUP) as WeatherParticles if tree else null


## Part de la portée de vue lointaine qui reste avec la météo de la scène
## `root` (éditeur de mission : la scène éditée).
static func sight_factor_under(root: Node) -> float:
	if root == null or not root.is_inside_tree():
		return 1.0
	for node in root.get_tree().get_nodes_in_group(GROUP):
		if root.is_ancestor_of(node):
			return (node as WeatherParticles).sight()
	return 1.0


## Part de la portée de vue lointaine qui reste avec la météo de `tree`.
static func sight_factor_of(tree: SceneTree) -> float:
	var weather := of(tree)
	return weather.sight() if weather else 1.0


## Part de la portée d'ouïe (bruits discrets) qui reste avec la météo de
## `tree`.
static func hearing_factor_of(tree: SceneTree) -> float:
	var weather := of(tree)
	return weather.hearing() if weather else 1.0


func _ready() -> void:
	add_to_group(GROUP)
	fall = GPUParticles3D.new()
	fall.name = "Fall"
	fall.top_level = true
	add_child(fall, false, Node.INTERNAL_MODE_FRONT)
	_configure(fall)
	refresh_visibility()
	_follow_camera()
	if not Engine.is_editor_hint():
		_start_game()


## En jeu seulement : ce qui accompagne la météo (traces, son…).
func _start_game() -> void:
	pass


## Réglages propres au type (neige, pluie) de `particles`.
func _configure(_particles: GPUParticles3D) -> void:
	pass


## Réglage changé (inspecteur) : particules refaites.
func _reconfigure() -> void:
	if fall:
		_configure(fall)
		fall.restart()


## Réglages communs ; les sous-classes ajoutent `process_material` et
## `draw_pass_1`.
func _setup(particles: GPUParticles3D, count: int, life: float) -> void:
	particles.amount = count
	particles.lifetime = life
	particles.preprocess = life
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-EXTENT - 10.0, -HEIGHT - 4.0, -EXTENT - 10.0), Vector3(2.0 * EXTENT + 20.0, HEIGHT + 8.0, 2.0 * EXTENT + 20.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = true


## Affichée en jeu ; dans l'éditeur, sauf case « Météo » décochée.
func refresh_visibility() -> void:
	if fall:
		fall.visible = not (Engine.is_editor_hint() and editor_hidden)


## Applique `editor_hidden` à toutes les précipitations de `tree`.
static func refresh_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group(GROUP):
		(node as WeatherParticles).refresh_visibility()


func _process(_delta: float) -> void:
	_follow_camera()


## Au-dessus du point du sol que vise la caméra (celle du jeu, ou celle de la
## vue 3D de l'éditeur).
func _follow_camera() -> void:
	if fall == null or not is_inside_tree():
		return
	var camera := _camera()
	if camera == null:
		return
	var forward := -camera.global_basis.z
	var origin := camera.global_position
	var focus := origin
	if absf(forward.y) > 0.01:
		focus = origin + forward * (-origin.y / forward.y)
	fall.global_position = Vector3(focus.x, HEIGHT, focus.z)


func _camera() -> Camera3D:
	if Engine.is_editor_hint():
		var editor := Engine.get_singleton(&"EditorInterface")
		if editor:
			var viewport: SubViewport = editor.call(&"get_editor_viewport_3d", 0)
			return viewport.get_camera_3d() if viewport else null
		return null
	return get_viewport().get_camera_3d()


## Boîte d'émission au sommet du volume, de demi-côté `EXTENT`.
static func falling_motion(speed_min: float, speed_max: float, gravity_y: float, wind: Vector3) -> ParticleProcessMaterial:
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(EXTENT, 1.0, EXTENT)
	motion.direction = Vector3(0, -1, 0)
	motion.initial_velocity_min = speed_min
	motion.initial_velocity_max = speed_max
	motion.gravity = Vector3(wind.x, gravity_y, wind.z)
	return motion
