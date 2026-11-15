class_name TraversalLink
extends NavigationLink3D
## Passage de navigation qu'on franchit en grimpant : échelle (du pied au
## toit), muret (d'un côté à l'autre) ou corde d'un grappin (du pied d'un
## relief à son sommet). La navigation le compte dans les
## chemins, des opérateurs comme des ennemis ; arrivée à son entrée, l'unité
## le franchit par une animation scriptée (`LinkTraversal`).
##
## Les deux extrémités (`start_position`, `end_position`) sont au sol, sur le
## maillage de navigation. Pour une échelle, `start_position` est le pied.

enum Kind { LADDER, VAULT, ROPE }

@export var kind: Kind = Kind.VAULT
## Muret : hauteur du dessus au-dessus des extrémités.
@export var height: float = 1.0
## Échelle : distance horizontale du pied à la face du mur.
@export var face_distance: float = 0.7
## Corde : faces du relief à gravir, du pied vers le haut (x et z de la face
## dans le monde, sol bas, sol haut).
@export var faces: Array[Vector4] = []


func _ready() -> void:
	bidirectional = true
	# Un détour à pied de quelques mètres reste préférable à une escalade.
	enter_cost = 2.0
	travel_cost = 2.0
	add_to_group(&"traversal_links")


## Extrémités dans le monde.
func global_start() -> Vector3:
	return global_transform * start_position


func global_end() -> Vector3:
	return global_transform * end_position
