class_name Reinforcements
extends Node3D
## Renforts d'un raid éclair : quand l'objectif `start_objective` est rempli
## (dépôt détruit), un compte à rebours de `delay` s s'affiche en haut de
## l'écran. À zéro, `count` soldats en alerte (et un pick-up armé si
## `technical`) arrivent au point du nœud et foncent vers la cible
## (`target`) ; l'objectif bonus `objective_id` (« repartir avant les
## renforts ») est manqué. Partir avant (mission réussie) arrête tout.

const ENEMY_SCENE := "res://scenes/enemies/enemy.tscn"
## Écart entre deux soldats à l'arrivée (m).
const SPREAD := 1.6

@export var start_objective: StringName = &"depot"
@export var objective_id: StringName = &"raid_in_time"
@export var delay: float = 120.0
@export var count: int = 4
@export var technical: bool = true
## Point vers lequel les renforts foncent (le dépôt).
@export var target: NodePath

## Temps restant (s) ; négatif : compte à rebours pas commencé.
var time_left: float = -1.0
var arrived: bool = false
var _over: bool = false
var _spawned: Array[Node3D] = []
var _layer: CanvasLayer
var _label: Label
var _banner_left: float = 0.0


func _enter_tree() -> void:
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.objective_completed.connect(_on_objective)
	EventBus.mission_ended.connect(func(_success: bool, _message: String) -> void:
		_over = true
		_update_label())
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.offset_top = 56.0
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", 26)
	_label.add_theme_constant_override(&"outline_size", 8)
	_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	_layer.add_child(_label)
	_update_label()


func _on_objective(id: StringName) -> void:
	if id == start_objective and time_left < 0.0 and not arrived and not _over:
		time_left = delay
		_update_label()


func _process(delta: float) -> void:
	if _over:
		return
	if _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left <= 0.0:
			_update_label()
	if time_left < 0.0 or arrived:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_arrive()
	_update_label()


func _update_label() -> void:
	if _label == null:
		return
	if _over or (time_left < 0.0 and not arrived) or (arrived and _banner_left <= 0.0):
		_label.visible = false
		return
	_label.visible = true
	if arrived:
		_label.text = "Les renforts sont là !"
		_label.add_theme_color_override(&"font_color", Color(1.0, 0.35, 0.25))
		return
	var seconds := ceili(time_left)
	_label.text = "Renforts dans %d:%02d" % [seconds / 60, seconds % 60]
	_label.add_theme_color_override(&"font_color", Color(1.0, 0.35, 0.25) if seconds <= 20 else Color(1.0, 0.85, 0.4))


## Les renforts arrivent : soldats en alerte et pick-up, vers la cible.
func _arrive() -> void:
	arrived = true
	_banner_left = 5.0
	var objectives := get_tree().get_first_node_in_group(Objectives.GROUP) as Objectives
	if objectives and objective_id != &"":
		objectives.fail(String(objective_id))
	_spawn()
	Sfx.play_ui(&"alert")


func _spawn() -> void:
	var goal := global_position
	var aim := get_node_or_null(target) as Node3D
	if aim:
		goal = aim.global_position
	var side := global_basis.x
	var scene := load(ENEMY_SCENE) as PackedScene
	for i in count:
		var enemy := scene.instantiate() as Enemy
		get_parent().add_child(enemy)
		enemy.global_position = global_position + side * (float(i) - (count - 1) * 0.5) * SPREAD
		enemy.look_at(Vector3(goal.x, enemy.global_position.y, goal.z) + Vector3(0.001, 0, 0))
		enemy.hear_alarm.call_deferred(goal)
		_spawned.append(enemy)
	if technical:
		var truck := Technical.new()
		get_parent().add_child(truck)
		truck.global_position = global_position - global_basis.z * 6.0
		truck.global_rotation.y = global_rotation.y
		truck.hunt.call_deferred(goal)
		_spawned.append(truck)


## Sauvegarde rapide (`QuickSave`).
func save_state() -> Dictionary:
	return {"left": time_left, "arrived": arrived}


func load_state(data: Dictionary) -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	time_left = data.get("left", -1.0)
	arrived = data.get("arrived", false)
	_banner_left = 0.0
	if arrived:
		_spawn()
	_update_label()
