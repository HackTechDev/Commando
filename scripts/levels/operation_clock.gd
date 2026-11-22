class_name OperationClock
extends Node
## Date et heure de l'opération (le lancement de la mission, heure locale)
## et chronomètre de sa durée : temps de jeu, arrêté pendant les pauses (menu,
## options, fin de mission). Ajouté par `LevelRoot` ; affiché par le HUD et
## l'écran de fin ; gardé par la sauvegarde rapide.

const GROUP := &"operation_clock"

## Lancement de l'opération (secondes Unix, UTC).
var started_unix: int = 0
## Durée de l'opération (s de jeu).
var elapsed: float = 0.0


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


## « 22/11/2026 à 14:32 » : date et heure locales du lancement.
func date_text() -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var local := Time.get_datetime_dict_from_unix_time(started_unix + bias * 60)
	return "%02d/%02d/%04d à %02d:%02d" % [local["day"], local["month"], local["year"], local["hour"], local["minute"]]


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
