class_name AssetPaths
extends RefCounted
## Dossiers des ressources externes (textures, cartes), rangés hors du
## projet et lus à la volée.
##
## Chaque dossier vient d'une variable d'environnement, sinon d'un réglage de
## projet. Un chemin relatif part du dossier du projet (jeu lancé depuis
## l'éditeur) ou du dossier de l'exécutable (jeu exporté).


## Dossier absolu désigné par `env_var`, sinon par le réglage `setting`
## (valeur par défaut `default_dir`).
static func resolve(env_var: String, setting: String, default_dir: String) -> String:
	var dir := OS.get_environment(env_var)
	if dir.is_empty():
		dir = str(ProjectSettings.get_setting(setting, default_dir))
	if dir.is_absolute_path():
		return dir
	var base := ProjectSettings.globalize_path("res://")
	if not OS.has_feature("editor"):
		base = OS.get_executable_path().get_base_dir()
	return base.path_join(dir).simplify_path()


static func textures_dir() -> String:
	return resolve("COMMANDO_TEXTURES", "commando/assets/texture_dir", "../CommandoAsset/textures")


static func maps_dir() -> String:
	return resolve("COMMANDO_MAPS", "commando/assets/map_dir", "../CommandoAsset/maps")
