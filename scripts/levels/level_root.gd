class_name LevelRoot
extends Node3D
## Racine d'un niveau : charge les textures externes de ses matériaux
## (`TextureLibrary`), génère la navigation à partir de la géométrie, et la
## recalcule quand un obstacle est déplacé.

@onready var _navigation: NavigationRegion3D = $NavigationRegion3D

## Une nouvelle demande est arrivée pendant un calcul en cours.
var _bake_pending: bool = false


func _ready() -> void:
	# Après le `_ready` des enfants : les caisses ont déjà choisi leur variante.
	TextureLibrary.apply_to_tree(self)
	# La carte de navigation doit avoir la même résolution que le maillage
	# (plus fine sur les cartes aux couloirs étroits).
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, _navigation.navigation_mesh.cell_size)
	NavigationServer3D.map_set_cell_height(map, _navigation.navigation_mesh.cell_height)
	_navigation.bake_navigation_mesh(false)
	_navigation.bake_finished.connect(_on_bake_finished)
	EventBus.navigation_obstacle_moved.connect(_rebake)


func _exit_tree() -> void:
	TextureLibrary.clear()


## Recalcule la navigation en arrière-plan (un seul calcul à la fois).
func _rebake() -> void:
	if _navigation.is_baking():
		_bake_pending = true
		return
	_navigation.bake_navigation_mesh(true)


func _on_bake_finished() -> void:
	if _bake_pending:
		_bake_pending = false
		_rebake()
