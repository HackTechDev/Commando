@tool
extends RefCounted
## Événements scriptés d'une mission (renforts, pick-ups qui arrivent :
## `Reinforcements`) et leurs zones de déclenchement (`TriggerZone`), pour le
## dock, les repères et la vérification.


## Événements de la scène `root`, dans l'ordre de l'arbre.
static func events(root: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if root:
		for node in root.find_children("*", "", true, false):
			if node is Reinforcements:
				found.append(node)
	return found


## Zones de déclenchement de la scène `root`.
static func zones(root: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if root:
		for node in root.find_children("*", "", true, false):
			if node is TriggerZone:
				found.append(node)
	return found


## Événement que la zone `zone` déclenche, ou null (lien vide, cassé, ou vers
## un nœud qui ne se déclenche pas).
static func event_of(zone: Node) -> Node3D:
	var path: NodePath = zone.get("event")
	if path.is_empty():
		return null
	var node := zone.get_node_or_null(path)
	return node as Node3D if node is Reinforcements else null


## Zones de `root` qui déclenchent `event`.
static func zones_of(root: Node, event: Node) -> Array[Node3D]:
	return zones(root).filter(func(zone: Node3D) -> bool: return event_of(zone) == event)


## Ce qui déclenche `event`, en clair (« objectif « depot », 2 zones »),
## vide si rien.
static func trigger_text(root: Node, event: Node) -> String:
	var parts: Array[String] = []
	var objective: StringName = event.get("start_objective")
	if objective != &"":
		parts.append("objectif « %s »" % objective)
	var count := zones_of(root, event).size()
	if count > 0:
		parts.append("%d zone%s" % [count, "s" if count > 1 else ""])
	return ", ".join(parts)


## Ce qui arrive, en clair (« 4 soldats et un pick-up »).
static func arrival_text(event: Node) -> String:
	var count: int = event.get("count")
	var parts: Array[String] = []
	if count > 0:
		parts.append("%d soldat%s" % [count, "s" if count > 1 else ""])
	if event.get("technical"):
		parts.append("un pick-up armé")
	return " et ".join(parts) if not parts.is_empty() else "personne"


## Chemin vers `event` depuis une zone rangée sous un enfant direct de
## `root` (`Triggers`), avant même qu'elle soit dans l'arbre.
static func link_from(root: Node, event: Node) -> NodePath:
	return NodePath("../../%s" % root.get_path_to(event))
