class_name LevelPreview
extends RefCounted
## Aperçu vu du dessus d'un niveau : rendu une fois, à la fin du chargement,
## par une caméra orthographique au-dessus de toute la carte, puis gardé dans
## `user://previews` pour le menu et la préparation de mission. Le même
## rendu sert de fond à la minicarte.

const DIR := "user://previews"
## Plus grand côté de l'image (pixels).
const SIZE := 384
## Couche visuelle des indications posées sur le décor (cônes de vision),
## absentes de l'aperçu.
const OVERLAY_LAYER := 1 << 1


## Fichier d'aperçu du niveau `key` (scène ou carte).
static func file_for(key: String) -> String:
	return DIR.path_join("%s.png" % key.get_file().get_basename())


## Aperçu enregistré du niveau `key`, ou null.
static func load_texture(key: String) -> Texture2D:
	var file := file_for(key)
	if not FileAccess.file_exists(file):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(file))
	return ImageTexture.create_from_image(image) if image else null


## Emprise au sol (x, z) du niveau `level` : carte UFO:AI construite, sinon
## limites de la caméra.
static func bounds_of(level: Node) -> Rect2:
	var map := level.find_child("Map", true, false) as UfoMapLevel
	if map and map.map_bounds.size != Vector3.ZERO:
		var box := map.map_bounds
		return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	var rig := level.find_child("CameraRig", true, false)
	if rig and "bounds" in rig:
		var box: AABB = rig.bounds
		return Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(4.0)
	return Rect2(-30, -30, 60, 60)


## Rend la vue du dessus de `level` (emprise `area`) et la renvoie, ou null
## sans rendu (serveur sans affichage).
static func render(level: Node3D, area: Rect2) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var aspect := area.size.x / maxf(area.size.y, 0.01)
	var size := Vector2i(SIZE, roundi(SIZE / aspect)) if aspect >= 1.0 else Vector2i(roundi(SIZE * aspect), SIZE)
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = area.size.y
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.far = 400.0
	camera.cull_mask = ~OVERLAY_LAYER & 0xFFFFF
	viewport.add_child(camera)
	level.add_child(viewport)
	var center := area.get_center()
	camera.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0)), Vector3(center.x, 150.0, center.y))
	camera.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image


## Enregistre l'aperçu de `level` s'il n'existe pas encore.
static func capture_if_missing(level: Node3D, key: String) -> void:
	if key.is_empty() or FileAccess.file_exists(file_for(key)):
		return
	var image := await render(level, bounds_of(level))
	if image == null or image.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	image.save_png(file_for(key))
