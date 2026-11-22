@tool
class_name MissionInfo
extends Resource
## Informations d'une mission du catalogue (`LevelCatalog`) : titre,
## description du briefing, camouflage conseillé, date et heure de
## l'opération, carte UFO:AI requise et objectifs. Rangée dans `scenes/levels/<nom>/mission.tres`, à côté de la
## scène `<nom>.tscn` qu'elle décrit ; modifiable dans l'inspecteur et le
## greffon « Éditeur de mission ».

## Nom du fichier, dans le dossier de la scène.
const FILE_NAME := "mission.tres"

@export var title: String = ""
@export_multiline var description: String = ""
## Camouflage conseillé par l'écran de préparation (`GearCatalog.CAMOS`).
@export_enum("woodland", "desert", "urban", "night", "snow") var camo: String = "woodland"
## Date et heure fictives de l'opération (« JJ/MM/AAAA », « HH:MM »),
## affichées en jeu (`OperationClock`) ; vides : celles du lancement.
@export_placeholder("JJ/MM/AAAA") var date: String = ""
@export_placeholder("HH:MM") var time: String = ""
## Carte UFO:AI dont le niveau a besoin, relative au dossier des cartes
## (vide : aucune). Sans elle, le niveau est grisé dans le menu.
@export var map: String = ""
## Place dans le menu (croissant).
@export var order: int = 0
## Objectifs (vides : `LevelCatalog.DEFAULT_OBJECTIVES`).
@export var objectives: Array[MissionObjective] = []


## Scène décrite : `<dossier>/<nom du dossier>.tscn`.
func scene_path() -> String:
	return scene_for(resource_path)


## Scène décrite par le fichier d'informations `info_path`.
static func scene_for(info_path: String) -> String:
	var dir := info_path.get_base_dir()
	return dir.path_join(dir.get_file() + ".tscn")


## Fichier d'informations de la scène `scene_path`.
static func path_for(scene_path: String) -> String:
	return scene_path.get_base_dir().path_join(FILE_NAME)


## Entrée de catalogue (`LevelCatalog`) : {"title", "scene", "description",
## "camo", "date"?, "time"?, "map"?, "objectives"?}.
func to_entry() -> Dictionary:
	var entry := {"title": title, "scene": scene_path(), "description": description, "camo": camo}
	if is_date(date):
		entry["date"] = date
	if is_time(time):
		entry["time"] = time
	if not map.is_empty():
		entry["map"] = map
	if not objectives.is_empty():
		var list: Array[Dictionary] = []
		for objective in objectives:
			if objective:
				list.append(objective.to_dict())
		entry["objectives"] = list
	return entry


## Vrai pour une date « JJ/MM/AAAA » valide.
static func is_date(text: String) -> bool:
	var parts := text.split("/")
	if parts.size() != 3 or parts[0].length() != 2 or parts[1].length() != 2 or parts[2].length() != 4:
		return false
	for part in parts:
		if not part.is_valid_int():
			return false
	var day := parts[0].to_int()
	var month := parts[1].to_int()
	return month >= 1 and month <= 12 and day >= 1 and day <= 31


## Vrai pour une heure « HH:MM » valide.
static func is_time(text: String) -> bool:
	var parts := text.split(":")
	if parts.size() != 2 or parts[0].length() != 2 or parts[1].length() != 2 \
			or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return false
	return parts[0].to_int() <= 23 and parts[1].to_int() <= 59
