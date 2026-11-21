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
		"description": "Parcours d'apprentissage en huit ateliers, du sud au nord : se déplacer, courir et se baisser, grimper, corps à corps, tir, tir à longue distance (Charlie porte un PGM Hécate II), infiltration. Une petite fenêtre explique chaque atelier quand un opérateur y entre ; un « ? » jaune les signale, un « ✓ » vert marque ceux réussis.",
		"camo": "woodland",
		"objectives": [
			{"id": "tuto_move", "text": "Se déplacer jusqu'au premier cercle"},
			{"id": "tuto_run", "text": "Courir jusqu'au bout de l'allée"},
			{"id": "tuto_climb", "text": "Monter sur le toit du bunker"},
			{"id": "tuto_melee", "text": "Neutraliser les trois mannequins au corps à corps"},
			{"id": "tuto_shoot", "text": "Abattre les trois cibles du stand de tir"},
			{"id": "tuto_sniper", "text": "Abattre les trois cibles lointaines à l'Hécate"},
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
		"title": "Base aérienne",
		"scene": "res://scenes/levels/airbase/airbase.tscn",
		"description": "Un convertible quadrirotor est posé au centre d'une base gardée par sept soldats : deux patrouilles, des sentinelles autour de la plateforme, un garde dans le hangar, au poste et devant l'armurerie (verrouillée). Alpha et Charlie ont chacun une charge explosive : la poser contre l'appareil, s'éloigner (le réservoir saute à son tour), puis la faire sauter. Ou bien voler l'appareil : toute l'équipe monte dans la soute par la rampe arrière, puis un opérateur prend les commandes (clic milieu sur lui).",
		"camo": "desert",
		"objectives": [
			{"id": "aircraft_destroyed", "text": "Détruire le convertible (charge explosive) ou le voler"},
			{"id": "no_operator_lost", "text": "Ne perdre aucun opérateur"},
		],
	},
	{
		"title": "Héliportage",
		"scene": "res://scenes/levels/heliport/heliport.tscn",
		"description": "Un convertible seul sur sa plateforme, pour s'exercer à l'héliportage. Montez dans la soute par la rampe arrière (clic droit sur l'appareil), puis clic milieu sur un opérateur à bord : « Monter » (vol stationnaire à 10 m), « Ouverture » / « Fermeture » de la porte, « Descendre en rappel » (porte ouverte), « Atterrir ». Porte ouverte en vol, les opérateurs à bord tirent sur les trois cibles d'entraînement.",
		"camo": "woodland",
		"objectives": [
			{"id": "heli_hover", "text": "Monter en vol stationnaire avec un opérateur à bord"},
			{"id": "heli_rappel", "text": "Descendre un opérateur en rappel"},
			{"id": "all_enemies_down", "text": "Abattre les trois cibles depuis l'appareil en vol (porte ouverte)"},
			{"id": "no_operator_lost", "text": "Ne perdre aucun opérateur"},
		],
	},
	{
		"title": "Nuit sans lune",
		"scene": "res://scenes/levels/night/night.tscn",
		"description": "Un dépôt gardé, de nuit : cinq soldats, dont deux en ronde. Les opérateurs portent des jumelles de vision nocturne (touche à gauche de 1 : ² sur AZERTY) qui amplifient la lumière en vert ; sans elles, on ne distingue presque rien hors des lampadaires. Dans le noir, les sentinelles voient moins loin. Raid : l'équipe arrive à bord du convertible, en vol stationnaire à 30 m au sud-ouest ; descendez en rappel, puis renvoyez l'appareil (clic milieu sur un opérateur : « Renvoyer l'appareil »). Sabotez le groupe électrogène au fond de la cour avec une charge : les lampadaires s'éteignent. Un convertible ennemi tourne au-dessus du dépôt : le cercle de son projecteur balaie le sol, et quiconque s'y trouve à découvert donne l'alerte ; attendez qu'il passe, ou restez sous un toit ou dans un buisson. Pour repartir, rappelez le convertible par radio (« Appeler l'extraction ») : il revient se poser au même endroit, mais le bruit de ses rotors attire les gardes.",
		"camo": "night",
		"objectives": [
			{"id": "sabotage", "text": "Saboter le groupe électrogène du dépôt"},
			{"id": "extracted", "text": "Repartir à bord du convertible d'extraction"},
			{"id": "no_operator_lost", "text": "Ne perdre aucun opérateur"},
		],
	},
	{
		"title": "Patrouille Sabre",
		"scene": "res://scenes/levels/patrol/patrol.tscn",
		"description": "Un convertible a posé l'équipe au départ de la piste, un Sabre (véhicule léger des forces spéciales) garé dans sa soute. Clic droit sur le véhicule pour monter (cinq places : volant, chef de bord, arrière, tourelle) ; avec un opérateur à bord sélectionné, clic droit au sol pour rouler. Clic milieu sur un opérateur à bord : descendre, prendre le volant, passer à la tourelle et ouvrir le feu avec la 12,7. Le Sabre sort de la soute en marche arrière ; clic droit sur le convertible pour l'y ramener. Le moteur s'entend de loin ; un poste de contrôle, fermé par une barrière, garde le point de ralliement. Un pick-up armé patrouille à l'est du poste : il fonce vers les bruits et mitraille ce qu'il voit ; la 12,7 en vient à bout, le missile aussi. La piste est peut-être piégée : un opérateur à pied devant le véhicule repère les mines (clic droit dessus pour la désamorcer). Pour repartir, appelez l'extraction par radio : elle ne se pose pas et ne reste que 60 s en vol stationnaire à l'ouest du poste ; treuillez toute l'équipe (clic droit sur l'appareil) avant qu'elle reparte.",
		"camo": "desert",
		"objectives": [
			{"id": "sabre_rally", "text": "Conduire le Sabre jusqu'au point de ralliement (drapeau)"},
			{"id": "all_enemies_down", "text": "Neutraliser le poste de contrôle et la patrouille"},
			{"id": "extracted", "text": "Être treuillé à bord de l'extraction en moins de 60 s"},
			{"id": "no_operator_lost", "text": "Ne perdre aucun opérateur"},
		],
	},
	{
		"title": "Convoi de nuit",
		"scene": "res://scenes/levels/convoy/convoy.tscn",
		"description": "De nuit, l'équipe doit ramener son Sabre : le convertible d'extraction ne repartira qu'avec le véhicule dans sa soute. Montez à bord au départ de la piste (sud-ouest) et rejoignez le terrain d'extraction au nord-est. Phares éteints, le Sabre se faufile mais roule moins vite ; allumés, il se voit de loin. Un poste fermé par une barrière garde le tronçon nord : forcez-la (bruit, dégâts) ou envoyez quelqu'un la lever. La piste est minée par endroits : un opérateur à pied devant le véhicule repère les engins. Un pick-up armé tourne à l'est. Au terrain, appelez l'extraction par radio : elle se pose, rampe vers la piste ; clic droit sur l'appareil avec un passager sélectionné pour y faire monter le Sabre, tout l'équipage à bord.",
		"camo": "night",
		"objectives": [
			{"id": "sabre_extracted", "text": "Faire monter le Sabre dans la soute du convertible d'extraction"},
			{"id": "extracted", "text": "Repartir à bord du convertible d'extraction"},
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
