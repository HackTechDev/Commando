extends Node
## Réglages du joueur, conservés entre les parties (`user://settings.cfg`) :
## dernière carte jouée, volumes, plein écran, défilement par le bord de
## l'écran, parade automatique.

const PATH := "user://settings.cfg"
## Bus audio réglables : nom du bus → libellé.
const BUSES: Dictionary = {&"Master": "Volume général", &"Musique": "Musique", &"SFX": "Effets"}

signal changed

var _config := ConfigFile.new()
## Fichier utilisé (les tests en prennent un autre, pour ne pas toucher aux
## réglages du joueur).
var path: String = PATH


func _ready() -> void:
	_config.load(path)
	apply()


## Bascule sur le fichier `file` (relu ; vide s'il n'existe pas).
func use_file(file: String) -> void:
	path = file
	_config = ConfigFile.new()
	_config.load(path)
	apply()


## Valeur `key` de la section `section` (ou `default`).
func value(section: String, key: String, default: Variant) -> Variant:
	return _config.get_value(section, key, default)


## Change un réglage, l'enregistre et l'applique.
func set_value(section: String, key: String, data: Variant) -> void:
	_config.set_value(section, key, data)
	_config.save(path)
	apply()
	changed.emit()


## Scène du dernier niveau lancé (vide au premier lancement).
func last_level() -> String:
	return value("game", "last_level", "")


func set_last_level(scene_or_map: String) -> void:
	set_value("game", "last_level", scene_or_map)


## Volume (0 à 1) du bus `bus`.
func volume(bus: StringName) -> float:
	return value("audio", String(bus), 1.0)


func edge_scroll() -> bool:
	return value("display", "edge_scroll", true)


## La caméra suit le Sabre qui roule avec un passager sélectionné.
func follow_vehicle() -> bool:
	return value("display", "follow_vehicle", true)


func fullscreen() -> bool:
	return value("display", "fullscreen", false)


## Parade automatique (tirage au sort) au lieu de la touche de parade.
func auto_parry() -> bool:
	return value("gameplay", "auto_parry", false)


## Applique volumes, mode d'affichage et parade automatique.
func apply() -> void:
	Commando.auto_parry = auto_parry()
	for bus: StringName in BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			var linear := volume(bus)
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
			AudioServer.set_bus_mute(index, linear <= 0.001)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen() else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode and not (mode == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(mode)


