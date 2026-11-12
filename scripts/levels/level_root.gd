class_name LevelRoot
extends Node3D
## Racine d'un niveau : génère la navigation à partir de la géométrie.

@onready var _navigation: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	_navigation.bake_navigation_mesh(false)
