class_name AssetPaths
extends RefCounted
## Dossiers des ressources externes (textures, cartes), rangés hors du
## projet et lus à la volée.
##
## Chaque dossier vient d'une variable d'environnement, sinon d'un réglage de
## projet. Un chemin relatif part du dossier du projet (jeu lancé depuis
## l'éditeur) ou du dossier de l'exécutable (jeu exporté).
##
## Le jeu Web n'a pas de disque : il lit le paquet embarqué
## `res://web_assets/` (préparé par `tools/web_pack.py`), s'il a été emporté.

## Paquet de cartes et de textures embarqué dans le jeu.
const PACK_DIR := "res://web_assets"


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


## Dossier externe `dir`, sauf sur le Web si le paquet embarqué a `sub` :
## `res://web_assets/<sub>`.
static func with_pack(dir: String, sub: String) -> String:
	var packed := PACK_DIR.path_join(sub)
	if OS.has_feature("web") and DirAccess.dir_exists_absolute(packed):
		return packed
	return dir


static func textures_dir() -> String:
	return with_pack(resolve("COMMANDO_TEXTURES", "commando/assets/texture_dir", "../CommandoAsset/textures"), "textures")


static func maps_dir() -> String:
	return with_pack(resolve("COMMANDO_MAPS", "commando/assets/map_dir", "../CommandoAsset/maps"), "maps")
