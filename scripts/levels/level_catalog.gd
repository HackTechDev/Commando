class_name LevelCatalog
extends RefCounted
## Liste des niveaux proposés par le menu de démarrage.
##
## Pour ajouter un niveau : une entrée de plus dans `LEVELS`. `map` (facultatif)
## désigne la carte UFO:AI dont le niveau a besoin, relative au dossier des
## cartes : sans elle, le niveau est grisé dans le menu. `camo` est le
## camouflage conseillé par l'écran de préparation (`GearCatalog.CAMOS`).

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

const LEVELS: Array[Dictionary] = [
	{
		"title": "Terrain d'essai",
		"scene": "res://scenes/levels/sandbox/sandbox.tscn",
		"description": "Petite carte d'exemple : une sentinelle en patrouille, une cible d'entraînement, des caisses à escalader et à déplacer.",
		"camo": "woodland",
	},
	{
		"title": "Escorte",
		"scene": "res://scenes/levels/escort/escort.tscn",
		"description": "Carte d'essai : un VIP à ramener jusqu'à la zone d'extraction, au nord-est, à travers deux lignes de murs gardées par deux patrouilles et une sentinelle. Il suit l'opérateur le plus proche et imite sa posture ; s'il meurt, la mission échoue.",
		"camo": "woodland",
	},
	{
		"title": "Entraînement A",
		"scene": "res://scenes/levels/training_a/training_a.tscn",
		"description": "Carte UFO:AI de 38 × 38 m : dédale de murs à escalader, de caisses et de bidons à déplacer, gardé par huit sentinelles fixes.",
		"map": "training_a.map",
		"camo": "urban",
	},
	{
		"title": "Entraînement B",
		"scene": "res://scenes/levels/training_b/training_b.tscn",
		"description": "Grande carte UFO:AI de 100 × 62 m : bunkers, tranchées et murets, douze sentinelles réparties sur tout le terrain.",
		"map": "training_b.map",
		"camo": "woodland",
	},
	{
		"title": "Gare du désert",
		"scene": "res://scenes/levels/fighter_crash/fighter_crash.tscn",
		"description": "Carte UFO:AI de 56 × 58 m : hameau en ruine, voie ferrée et wagons sur un relief en terrasses, douze sentinelles. (L'épave du vaisseau, un modèle 3D absent, n'apparaît pas.)",
		"map": "fighter_crash.map",
		"camo": "desert",
	},
]


## Titre du niveau dont la scène est `scene_path`, ou vide s'il n'est pas au
## catalogue.
static func title_of(scene_path: String) -> String:
	for level in LEVELS:
		if level["scene"] == scene_path:
			return level["title"]
	return ""


## Camouflage conseillé pour `level`.
static func suggested_camo(level: Dictionary) -> StringName:
	return StringName(level.get("camo", "woodland"))


## Raison pour laquelle le niveau ne peut pas être lancé, ou vide s'il le peut.
static func unavailable_reason(level: Dictionary) -> String:
	if not ResourceLoader.exists(level["scene"]):
		return "Scène introuvable : %s" % level["scene"]
	if level.has("map"):
		var path := AssetPaths.maps_dir().path_join(level["map"])
		if not FileAccess.file_exists(path):
			return "Carte introuvable : %s" % path
	return ""
