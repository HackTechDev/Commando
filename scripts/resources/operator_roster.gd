class_name OperatorRoster
extends RefCounted
## Les trois opérateurs de l'équipe (`OperatorProfile`), sauvegardés en JSON
## dans le dossier utilisateur. JSON plutôt qu'une ressource Godot : un
## fichier `.tres` modifié à la main peut charger et exécuter un script.
## `current()` est l'équipe en usage, lue une fois puis partagée par l'écran
## « Opérateurs » et les niveaux.

const SIZE := 3
const DEFAULT_PATH := "user://operators.json"

## Fichier de sauvegarde (les tests en utilisent un autre).
static var save_path: String = DEFAULT_PATH
static var _current: OperatorRoster

var operators: Array[OperatorProfile] = []


func _init() -> void:
	for i in SIZE:
		operators.append(OperatorProfile.defaults(i))


## Équipe en usage : lue du fichier au premier appel (défauts s'il n'existe
## pas ou s'il est illisible).
static func current() -> OperatorRoster:
	if _current == null:
		_current = load_file(save_path)
	return _current


## Remplace l'équipe en usage (tests).
static func use(roster: OperatorRoster) -> void:
	_current = roster


## Profil de l'opérateur numéro `unit_index` (1 à 3), ou null au-delà.
func profile(unit_index: int) -> OperatorProfile:
	if unit_index < 1 or unit_index > operators.size():
		return null
	return operators[unit_index - 1]


## Remet l'opérateur `index` (0 à 2) à son profil par défaut.
func reset(index: int) -> void:
	operators[index] = OperatorProfile.defaults(index)


static func load_file(path: String) -> OperatorRoster:
	var roster := OperatorRoster.new()
	if not FileAccess.file_exists(path):
		return roster
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not (data as Dictionary).get("operators") is Array:
		push_warning("Fichier des opérateurs illisible : %s" % path)
		return roster
	var entries: Array = data["operators"]
	for i in mini(entries.size(), SIZE):
		if entries[i] is Dictionary:
			roster.operators[i] = OperatorProfile.from_dict(entries[i], i)
	return roster


func save(path: String = save_path) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "operators": operators.map(func(p: OperatorProfile) -> Dictionary: return p.to_dict())}, "\t"))
	return OK
