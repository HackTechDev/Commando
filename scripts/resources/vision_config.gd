class_name VisionConfig
extends Resource
## Paramètres du cône de vision d'un type d'ennemi.

## Ouverture totale du cône, en degrés.
@export_range(10.0, 180.0) var fov_degrees: float = 70.0
## Zone proche : détection immédiate, quelle que soit la posture.
@export var near_range: float = 5.0
## Zone lointaine : détection progressive, uniquement des cibles debout.
@export var far_range: float = 12.0
## Hauteur des yeux.
@export var eye_height: float = 1.6
## Hauteur des rayons servant à dessiner le cône au sol.
@export var cone_ray_height: float = 1.0
## Nombre de segments du cône affiché.
@export_range(8, 128) var segments: int = 48
