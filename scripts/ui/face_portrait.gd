class_name FacePortrait
extends RefCounted
## Petite vue 3D du visage d'un opérateur, dans son propre monde : sert aux
## sélecteurs de l'écran « Opérateurs » et aux portraits du HUD de mission.


## Crée sous `parent` la vue (`size` pixels de côté) d'un `SoldierModel`
## silencieux vu de trois quarts, à la tenue `outfit` (null : tenue par
## défaut). Renvoie {"texture": Texture2D, "model": SoldierModel,
## "viewport": SubViewport}. `distance` : recul de la caméra (m) ; `fill` :
## lumière d'appoint de face (visages sous un casque).
static func build(parent: Node, size: int, outfit: OperatorProfile = null, node_name: String = "Face", distance: float = 0.78, fill: float = 0.0) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = node_name
	viewport.size = Vector2i(size, size)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.62, 0.6)
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.5, 0.4, 0.0)
	viewport.add_child(light)
	if fill > 0.0:
		var front := DirectionalLight3D.new()
		front.rotation = Vector3(-0.15, 0.35, 0.0)
		front.light_energy = fill
		viewport.add_child(front)
	var face := SoldierModel.new()
	face.silent = true
	face.rotation.y = PI + 0.35
	if outfit:
		face.outfit = outfit
	viewport.add_child(face)
	var camera := Camera3D.new()
	camera.fov = 30.0
	# Plus près, on vise un peu plus haut : le haut du crâne reste dans le cadre.
	var lift := (0.78 - distance) * 0.25
	camera.transform = Transform3D(Basis(), Vector3(0.0, 1.62 + lift, distance)).looking_at(Vector3(0.0, 1.57 + lift, 0.0))
	viewport.add_child(camera)
	return {"texture": viewport.get_texture(), "model": face, "viewport": viewport}
