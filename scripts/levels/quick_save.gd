class_name QuickSave
extends RefCounted
## Sauvegarde rapide (préparation de M7) : chaque nœud qui garde un état de
## partie rejoint le groupe `saveable` et fournit `save_state() ->
## Dictionary` et `load_state(data: Dictionary)`. `capture` réunit ces
## états par chemin de nœud, avec l'état global ; `restore` les rend.
##
## `restore` s'applique à un niveau fraîchement chargé (la même scène) : les
## nœuds créés en cours de partie (charges posées, couteaux au sol, cordes)
## ne sont pas encore repris, et les ordres en cours non plus (les unités
## reviennent immobiles, à leur place).

const GROUP := &"saveable"
const VERSION := 1


## État de partie de tous les nœuds sauvegardables sous `root`.
static func capture(root: Node) -> Dictionary:
	var nodes := {}
	for node in root.get_tree().get_nodes_in_group(GROUP):
		if root == node or root.is_ancestor_of(node):
			nodes[String(root.get_path_to(node))] = node.call(&"save_state")
	return {"version": VERSION, "alert_level": GameState.alert_level, "nodes": nodes}


## Rend l'état `data` (résultat de `capture`) aux nœuds de `root`. Renvoie
## le nombre de nœuds restaurés.
static func restore(root: Node, data: Dictionary) -> int:
	if data.get("version", 0) != VERSION:
		return 0
	var count := 0
	var nodes: Dictionary = data.get("nodes", {})
	for path: String in nodes:
		var node := root.get_node_or_null(NodePath(path))
		if node and node.has_method(&"load_state"):
			node.call(&"load_state", nodes[path])
			count += 1
	GameState.refresh_alert()
	return count


## Écrit `data` dans le fichier `path` (`user://…`). Renvoie faux en cas
## d'échec.
static func write(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(data)
	return true


## Relit un fichier écrit par `write` (vide s'il manque).
static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var()
	return data if data is Dictionary else {}
