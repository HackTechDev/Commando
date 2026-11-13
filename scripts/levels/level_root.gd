class_name LevelRoot
extends Node3D
## Racine d'un niveau : génère la navigation à partir de la géométrie, et la
## recalcule quand un obstacle est déplacé.

@onready var _navigation: NavigationRegion3D = $NavigationRegion3D

## Une nouvelle demande est arrivée pendant un calcul en cours.
var _bake_pending: bool = false


func _ready() -> void:
	_navigation.bake_navigation_mesh(false)
	_navigation.bake_finished.connect(_on_bake_finished)
	EventBus.navigation_obstacle_moved.connect(_rebake)


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
