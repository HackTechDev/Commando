class_name LevelCatalog
extends RefCounted
## Liste des niveaux proposés par le menu de démarrage.
##
## Pour ajouter un niveau : une entrée de plus dans `LEVELS`. `map` (facultatif)
## désigne la carte UFO:AI dont le niveau a besoin, relative au dossier des
## cartes : sans elle, le niveau est grisé dans le menu. `camo` est le
## camouflage conseillé par l'écran de préparation (`GearCatalog.CAMOS`).

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
## Niveau générique qui construit n'importe quelle carte UFO:AI
## (`UfoMapLevel.requested_map`) : il sert aux cartes hors catalogue.
const GENERIC_SCENE := "res://scenes/levels/ufo_map/ufo_map.tscn"
## Objectifs d'une carte qui n'en précise pas.
const DEFAULT_OBJECTIVES: Array[Dictionary] = [
	{"id": "all_enemies_down", "text": "Neutraliser toutes les sentinelles"},
	{"id": "no_operator_lost", "text": "Ne perdre aucun opérateur"},
]
## Camouflage deviné d'après le nom d'une carte hors catalogue.
const CAMO_HINTS: Dictionary = {
	"desert": "desert", "dam": "desert", "excavation": "desert", "mine": "desert",
	"city": "urban", "office": "urban", "subway": "urban", "neighbourhood": "urban",
	"harbour": "urban", "ferry": "urban", "resort": "urban", "bunker": "urban", "pipes": "urban",
}

const LEVELS: Array[Dictionary] = [
	{
		"title": "Didacticiel",
		"scene": "res://scenes/levels/tutorial/tutorial.tscn",
		"description": "Parcours d'apprentissage en sept ateliers, du sud au nord : se déplacer, courir et se baisser, grimper, corps à corps, tir, infiltration. Une petite fenêtre explique chaque atelier quand un opérateur y entre ; un « ? » jaune les signale, un « ✓ » vert marque ceux réussis.",
		"camo": "woodland",
		"objectives": [
			{"id": "tuto_move", "text": "Se déplacer jusqu'au premier cercle"},
			{"id": "tuto_run", "text": "Courir jusqu'au bout de l'allée"},
			{"id": "tuto_climb", "text": "Monter sur le toit du bunker"},
			{"id": "tuto_melee", "text": "Neutraliser les trois mannequins au corps à corps"},
			{"id": "tuto_shoot", "text": "Abattre les trois cibles du stand de tir"},
			{"id": "tuto_stealth", "text": "Neutraliser la sentinelle"},
			{"id": "tuto_end", "text": "Rejoindre la zone de fin"},
		],
	},
	{
		"title": "Terrain d'essai",
		"scene": "res://scenes/levels/sandbox/sandbox.tscn",
		"description": "Petite carte d'exemple : une sentinelle en patrouille, une cible d'entraînement, des caisses à escalader et à déplacer.",
		"camo": "woodland",
		"objectives": [
			{"id": "all_enemies_down", "text": "Neutraliser la sentinelle et la cible d'entraînement"},
			{"id": "no_operator_lost", "text": "Ne perdre aucun opérateur"},
		],
	},
	{
		"title": "Escorte",
		"scene": "res://scenes/levels/escort/escort.tscn",
		"description": "Carte d'essai : un VIP à ramener jusqu'à la zone d'extraction, au nord-est, à travers deux lignes de murs gardées par deux patrouilles et une sentinelle. Clic du milieu sur lui : « Suivre l'opérateur » sélectionné (il imite alors sa posture) ou « Attendre ici ». S'il meurt, la mission échoue.",
		"camo": "woodland",
		"objectives": [
			{"id": "vip_extracted", "text": "Escorter le VIP jusqu'à la zone d'extraction, au nord-est"},
			{"id": "vip_alive", "text": "Le VIP doit survivre"},
			{"id": "no_operator_lost", "text": "Ne perdre aucun opérateur"},
		],
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


## Cartes UFO:AI du dossier des cartes qui n'ont pas de niveau au
## catalogue : elles se jouent dans le niveau générique, avec les sentinelles
## de la carte (non testées une à une).
static func extra_levels() -> Array[Dictionary]:
	var known: Array[String] = []
	for level in LEVELS:
		if level.has("map"):
			known.append(level["map"])
	var extras: Array[Dictionary] = []
	var dir := AssetPaths.maps_dir()
	if not DirAccess.dir_exists_absolute(dir):
		return extras
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	for file: String in files:
		if file.get_extension() != "map" or known.has(file):
			continue
		var base := file.get_basename()
		var camo := "woodland"
		for hint: String in CAMO_HINTS:
			if base.contains(hint):
				camo = CAMO_HINTS[hint]
		extras.append({
			"title": base.replace("_", " ").capitalize(),
			"scene": GENERIC_SCENE,
			"description": "Carte UFO:AI « %s », trouvée dans le dossier des cartes. Non adaptée au jeu : sentinelles placées sur les positions des aliens, toits repérés automatiquement." % file,
			"map": file,
			"camo": camo,
			"extra": true,
		})
	return extras


## Tous les niveaux proposés : catalogue, puis cartes UFO:AI en plus.
static func all_levels() -> Array[Dictionary]:
	var levels: Array[Dictionary] = LEVELS.duplicate()
	levels.append_array(extra_levels())
	return levels


## Clé d'un niveau (dernière carte jouée, aperçus) : la carte pour le niveau
## générique, la scène sinon.
static func key_of(level: Dictionary) -> String:
	return level["map"] if level.get("extra", false) else level["scene"]


## Clé du niveau en cours : scène `scene_path` construisant la carte
## `map_file` (voir `key_of`).
static func key_for(scene_path: String, map_file: String) -> String:
	return map_file if scene_path == GENERIC_SCENE else scene_path


## Niveau de clé `key` (voir `key_of`), ou vide.
static func find(key: String) -> Dictionary:
	for level in all_levels():
		if key_of(level) == key:
			return level
	return {}


## Titre du niveau dont la scène est `scene_path`, ou vide s'il n'est pas au
## catalogue. Pour le niveau générique : le nom de la carte demandée.
static func title_of(scene_path: String) -> String:
	if scene_path == GENERIC_SCENE:
		return find(UfoMapLevel.requested_map).get("title", "")
	for level in LEVELS:
		if level["scene"] == scene_path:
			return level["title"]
	return ""


## Objectifs de `level` : [{"id": String, "text": String}] (voir
## `Objectives` pour les identifiants suivis en jeu).
static func objectives_of(level: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(level.get("objectives", DEFAULT_OBJECTIVES))
	return result


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
