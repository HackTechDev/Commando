@tool
extends RefCounted
## Cibles des objectifs sur une carte : les nœuds qui remplissent chaque
## objectif (`MissionObjective.id`) en émettant son identifiant, ou qui en
## sont l'objet (porteur des documents, VIP, gardes).

## Propriétés qui portent l'identifiant d'un objectif rempli par le nœud.
const OBJECTIVE_PROPERTIES: Array[StringName] = [
	&"objective_id", &"hover_objective", &"rappel_objective", &"documents_objective",
	&"arrival_objective", &"stow_objective",
]
## Objectifs suivis par le jeu lui-même, sans cible sur la carte.
const NO_TARGET: Array[String] = ["no_operator_lost", "no_alert"]


## Identifiant d'objectif -> nœuds de `root` qui en sont la cible.
static func targets(root: Node) -> Dictionary:
	var found := {}
	if root == null:
		return found
	for node in root.find_children("*", "", true, true):
		for property in OBJECTIVE_PROPERTIES:
			var value: Variant = node.get(property)
			if (value is StringName or value is String) and not String(value).is_empty():
				_add(found, String(value), node)
		if node is Enemy:
			_add(found, "all_enemies_down", node)
			if node.get("documents"):
				_add(found, "documents", node)
		elif node is Vip:
			_add(found, "vip_alive", node)
	return found


## Nœuds cibles de l'objectif `id` (vide : aucun) ; null si l'objectif n'a
## pas besoin de cible.
static func targets_of(id: String, found: Dictionary) -> Variant:
	if id in NO_TARGET:
		return null
	return found.get(id, [])


static func _add(found: Dictionary, id: String, node: Node) -> void:
	if not found.has(id):
		found[id] = []
	if not (found[id] as Array).has(node):
		(found[id] as Array).append(node)


## Texte proposé pour un objectif ajouté depuis le dock (à reprendre).
const SUGGESTED_TEXT := {
	"extracted": "Ramener l'équipe à la zone d'extraction",
	"no_operator_lost": "Ne perdre aucun opérateur",
	"no_alert": "Ne jamais donner l'alerte",
	"all_enemies_down": "Neutraliser tous les ennemis",
	"vip_alive": "Le VIP doit survivre",
	"vip_extracted": "Escorter le VIP jusqu'à la zone d'extraction",
	"documents": "Ramener les documents à bord de l'extraction",
	"sabotage": "Saboter le groupe électrogène",
	"depot": "Détruire le dépôt de carburant avec une charge",
	"aircraft_destroyed": "Détruire le convertible (charge explosive) ou le voler",
	"raid_in_time": "Bonus : repartir avant l'arrivée des renforts",
	"sabre_rally": "Conduire le Sabre jusqu'au point de ralliement (drapeau)",
	"sabre_extracted": "Faire monter le Sabre dans la soute du convertible d'extraction",
	"heli_hover": "Monter en vol stationnaire avec un opérateur à bord",
	"heli_rappel": "Descendre un opérateur en rappel",
}


static func suggested_text(id: String) -> String:
	return SUGGESTED_TEXT.get(id, id)

