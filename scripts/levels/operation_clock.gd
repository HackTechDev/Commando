class_name OperationClock
extends Node
## Date et heure de l'opération (celles de la mission, `MissionInfo.date`
## et `time`, sinon le lancement, heure locale) et chronomètre de sa durée : temps de jeu, arrêté pendant les pauses (menu,
## options, fin de mission). Ajouté par `LevelRoot` ; affiché par le HUD et
## l'écran de fin ; gardé par la sauvegarde rapide.

const GROUP := &"operation_clock"

## Lancement de l'opération (secondes Unix, UTC).
var started_unix: int = 0
## Durée de l'opération (s de jeu).
var elapsed: float = 0.0
## Date et heure fictives de la mission (« JJ/MM/AAAA », « HH:MM ») ;
## vides : celles du lancement.
var mission_date: String = ""
var mission_time: String = ""


func _init() -> void:
	name = "OperationClock"
	started_unix = int(Time.get_unix_time_from_system())


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(QuickSave.GROUP)


func _process(delta: float) -> void:
	elapsed += delta


## Horloge de l'opération en cours, ou null.
static func of(tree: SceneTree) -> OperationClock:
	return tree.get_first_node_in_group(GROUP) as OperationClock


## Date et heure de la mission `entry` (`LevelCatalog`), s'il en a.
func setup(entry: Dictionary) -> void:
	mission_date = entry.get("date", "")
	mission_time = entry.get("time", "")


## « 22/11/2026 à 14:32 » : date et heure de la mission, sinon (pour ce
## qui manque) date et heure locales du lancement.
func date_text() -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var local := Time.get_datetime_dict_from_unix_time(started_unix + bias * 60)
	var day := mission_date if MissionInfo.is_date(mission_date) else "%02d/%02d/%04d" % [local["day"], local["month"], local["year"]]
	var hour := mission_time if MissionInfo.is_time(mission_time) else "%02d:%02d" % [local["hour"], local["minute"]]
	return "%s à %s" % [day, hour]


## Durée de l'opération, « 00:05:12 ».
func duration_text() -> String:
	return format_duration(elapsed)


## `seconds` en heures, minutes et secondes : « 01:02:03 ».
static func format_duration(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


func save_state() -> Dictionary:
	return {"started_unix": started_unix, "elapsed": elapsed}


func load_state(data: Dictionary) -> void:
	started_unix = data.get("started_unix", started_unix)
	elapsed = data.get("elapsed", elapsed)
