@tool
class_name TriggerZone
extends Area3D
## Zone de déclenchement d'un événement scripté (`Reinforcements` : renforts,
## pick-up qui arrive) : le premier opérateur qui y entre déclenche
## l'événement `event` (méthode `trigger(zone)`), une seule fois. Invisible
## en jeu ; l'éditeur de mission la dessine (cadre au sol, lien vers
## l'événement).

## Emprise au sol (m, x et z), centrée sur le nœud.
@export var size := Vector2(8.0, 8.0)
## Hauteur de la zone (m) au-dessus du nœud : un toit au-dessus n'en fait
## pas partie.
@export var height: float = 3.0
## Événement déclenché (`Reinforcements`).
@export var event: NodePath

## Déjà déclenchée.
var fired: bool = false


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = 0
	# Couche des unités du joueur ; seuls les opérateurs comptent.
	collision_mask = 0b100
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, height, size.y)
	shape.shape = box
	shape.position.y = height * 0.5
	add_child(shape)
	body_entered.connect(_on_body_entered)


## Événement désigné par `event`, s'il sait se déclencher.
func target_event() -> Node:
	var node := get_node_or_null(event) if not event.is_empty() else null
	return node if node and node.has_method(&"trigger") else null


## Le point `at` (monde) est-il dans la zone ?
func covers(at: Vector3) -> bool:
	var local := global_transform.affine_inverse() * at
	return absf(local.x) <= size.x * 0.5 and absf(local.z) <= size.y * 0.5 and local.y >= -0.5 and local.y <= height


func _on_body_entered(body: Node3D) -> void:
	if fired or not body is Commando:
		return
	var target := target_event()
	if target == null:
		return
	fired = true
	target.call(&"trigger", self)


## Sauvegarde rapide (`QuickSave`).
func save_state() -> Dictionary:
	return {"fired": fired}


func load_state(data: Dictionary) -> void:
	fired = data.get("fired", false)
