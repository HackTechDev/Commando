class_name LevelCatalog
extends RefCounted
## Liste des niveaux proposés par le menu de démarrage.
##
## Pour ajouter un niveau : une entrée de plus dans `LEVELS`. `map` (facultatif)
## désigne la carte UFO:AI dont le niveau a besoin, relative au dossier des
## cartes : sans elle, le niveau est grisé dans le menu.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

const LEVELS: Array[Dictionary] = [
	{
		"title": "Terrain d'essai",
		"scene": "res://scenes/levels/sandbox/sandbox.tscn",
		"description": "Petite carte d'exemple : une sentinelle en patrouille, une cible d'entraînement, des caisses à escalader et à déplacer.",
	},
	{
		"title": "Entraînement A",
		"scene": "res://scenes/levels/training_a/training_a.tscn",
		"description": "Carte UFO:AI de 38 × 38 m : dédale de murs, de caisses (neuf à escalader ou déplacer) et de tonneaux, gardé par huit sentinelles fixes.",
		"map": "training_a.map",
	},
]


## Raison pour laquelle le niveau ne peut pas être lancé, ou vide s'il le peut.
static func unavailable_reason(level: Dictionary) -> String:
	if not ResourceLoader.exists(level["scene"]):
		return "Scène introuvable : %s" % level["scene"]
	if level.has("map"):
		var path := AssetPaths.maps_dir().path_join(level["map"])
		if not FileAccess.file_exists(path):
			return "Carte introuvable : %s" % path
	return ""
