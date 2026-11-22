@tool
class_name MissionInfo
extends Resource
## Informations d'une mission du catalogue (`LevelCatalog`) : titre,
## description du briefing, camouflage conseillé, carte UFO:AI requise et
## objectifs. Rangée dans `scenes/levels/<nom>/mission.tres`, à côté de la
## scène `<nom>.tscn` qu'elle décrit ; modifiable dans l'inspecteur et le
## greffon « Éditeur de mission ».

## Nom du fichier, dans le dossier de la scène.
const FILE_NAME := "mission.tres"

@export var title: String = ""
@export_multiline var description: String = ""
## Camouflage conseillé par l'écran de préparation (`GearCatalog.CAMOS`).
@export_enum("woodland", "desert", "urban", "night", "snow") var camo: String = "woodland"
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
## "camo", "map"?, "objectives"?}.
func to_entry() -> Dictionary:
	var entry := {"title": title, "scene": scene_path(), "description": description, "camo": camo}
	if not map.is_empty():
		entry["map"] = map
	if not objectives.is_empty():
		var list: Array[Dictionary] = []
		for objective in objectives:
			if objective:
				list.append(objective.to_dict())
		entry["objectives"] = list
	return entry
