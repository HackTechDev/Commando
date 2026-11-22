class_name LevelRoot
extends Node3D
## Racine d'un niveau : charge les textures externes de ses matériaux
## (`TextureLibrary`), génère la navigation à partir de la géométrie, et la
## recalcule quand un obstacle est déplacé.
##
## La première génération se fait en arrière-plan derrière un écran de
## chargement, jeu en pause : personne ne bouge avant que les chemins existent.
## `level_ready` est émis à la fin.

signal level_ready

## Images de physique attendues au plus pour que la carte de navigation
## intègre le maillage généré.
const MAP_SYNC_MAX_FRAMES := 300
## Intervalle (images) avant de renvoyer le maillage à une carte qui ne l'a pas pris.
const MAP_SYNC_RETRY_FRAMES := 20

## Carte de nuit : les ennemis voient moins loin (`NIGHT_SIGHT`), et les
## opérateurs qui portent des JVN voient en vision nocturne (`NightVision`).
@export var night: bool = false
## Tenue de rigueur (`GearCatalog.CLOTHING`, vide : aucune) : l'occasion de la
## mission (réception, rue animée…). Un opérateur en tenue civile s'y fond
## dans la foule (`Commando.blend_factor`).
@export var dress_code: StringName = &""
## Part de la portée de vue lointaine des ennemis qui reste la nuit.
const NIGHT_SIGHT := 0.55

## Vrai une fois la navigation générée et le jeu lancé.
var is_level_ready: bool = false

@onready var _navigation: NavigationRegion3D = $NavigationRegion3D

## Une nouvelle demande est arrivée pendant un calcul en cours.
var _bake_pending: bool = false
var _loading_screen: LoadingScreen
var _was_paused: bool = false


func _ready() -> void:
	# Nouvelle partie : l'alerte du niveau précédent ne compte plus.
	GameState.alert_level = GameState.AlertLevel.CALM
	Roof.view_level = -1
	Roof.hovered = null
	# La carte de navigation doit avoir la même résolution que le maillage
	# (plus fine sur les cartes aux couloirs étroits).
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, _navigation.navigation_mesh.cell_size)
	NavigationServer3D.map_set_cell_height(map, _navigation.navigation_mesh.cell_height)
	# Jumelles : vue verte dès qu'elles sont abaissées (d'office la nuit).
	add_child(NightVision.new(night))
	_loading_screen = LoadingScreen.new(LevelCatalog.title_of(scene_file_path))
	add_child(_loading_screen)
	_was_paused = get_tree().paused
	get_tree().paused = true
	_navigation.bake_finished.connect(_on_bake_finished)
	EventBus.navigation_obstacle_moved.connect(_rebake)
	# Cartes UFO:AI : construites sur plusieurs images, avant la navigation.
	for builder: UfoMapLevel in find_children("*", "UfoMapLevel", true, false):
		while not builder.is_built:
			_loading_screen.set_status(builder.build_stage)
			await get_tree().process_frame
			if not is_inside_tree():
				return
	TextureLibrary.apply_to_tree(self)
	# Les caisses ont déjà choisi leur variante (`_ready` des enfants).
	_loading_screen.set_status("Préparation des chemins")
	_navigation.bake_navigation_mesh(true)


## Tenue de rigueur de la carte de `node` (vide hors d'une carte).
static func dress_code_of(node: Node) -> StringName:
	var parent := node.get_parent()
	while parent:
		if parent is LevelRoot:
			return (parent as LevelRoot).dress_code
		parent = parent.get_parent()
	return &""


## Vrai si `node` est dans une carte de nuit.
static func is_night(node: Node) -> bool:
	var parent := node.get_parent()
	while parent:
		if parent is LevelRoot:
			return (parent as LevelRoot).night
		parent = parent.get_parent()
	return false


## Clé de ce niveau (aperçu, dernière carte jouée : `LevelCatalog.key_of`).
func level_key() -> String:
	var map := find_child("Map", true, false) as UfoMapLevel
	return LevelCatalog.key_for(scene_file_path, map.map_file if map else "")


func _exit_tree() -> void:
	TextureLibrary.clear()
	# Niveau quitté pendant le chargement : ne pas laisser le jeu en pause.
	if not is_level_ready:
		get_tree().paused = _was_paused


## Recalcule la navigation en arrière-plan (un seul calcul à la fois).
func _rebake() -> void:
	if not is_level_ready or _navigation.is_baking():
		_bake_pending = true
		return
	_navigation.bake_navigation_mesh(true)


func _on_bake_finished() -> void:
	if not is_level_ready:
		# La carte de navigation ne prend le nouveau maillage qu'après une ou
		# plusieurs synchronisations (images de physique, plus sur une grande
		# carte) : les chemins demandés avant seraient vides.
		await _wait_for_navigation_map()
		if not is_inside_tree():
			return
		is_level_ready = true
		get_tree().paused = _was_paused
		_loading_screen.queue_free()
		_loading_screen = null
		level_ready.emit()
		LevelPreview.capture_if_missing(self, level_key())
	if _bake_pending:
		_bake_pending = false
		_rebake()


## Attend que la carte de navigation contienne le maillage généré : un de ses
## sommets s'y retrouve (au plus `MAP_SYNC_MAX_FRAMES` images).
func _wait_for_navigation_map() -> void:
	var vertices := _navigation.navigation_mesh.get_vertices()
	if vertices.is_empty():
		return
	var probe := _navigation.global_transform * vertices[0]
	var map := get_world_3d().navigation_map
	for i in MAP_SYNC_MAX_FRAMES:
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		if NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) < 0.5:
			return
		# Parfois (environ une fois sur six, quand la génération se termine
		# très vite), la carte ne prend jamais le maillage livré : on le lui
		# renvoie.
		if i % MAP_SYNC_RETRY_FRAMES == MAP_SYNC_RETRY_FRAMES - 1:
			NavigationServer3D.region_set_navigation_mesh(_navigation.get_rid(), _navigation.navigation_mesh)
