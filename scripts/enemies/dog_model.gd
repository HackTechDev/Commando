class_name DogModel
extends Node3D
## Chien de garde procédural (berger au poil sombre), posé à la place du
## `SoldierModel` d'un `Enemy` de type chien (caché, il garde ses états).
## Il trotte selon la vitesse de l'ennemi, se jette en avant pour mordre
## (`strike_progress` du modèle caché), se couche sur le flanc assommé ou
## mort, et dresse la tête en alerte.

## Hauteur (m) du dos, longueur du corps.
const BACK_HEIGHT := 0.5
const BODY_LENGTH := 0.8
## Fréquence du trot (Hz) à pleine vitesse.
const TROT_RATE := 3.2

var enemy: Enemy
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []
var _phase: float = 0.0
var _down: float = 0.0


func _init(owner: Enemy) -> void:
	enemy = owner
	name = "DogModel"


func _ready() -> void:
	var fur := _mat(Color(0.2, 0.15, 0.1), 0.95)
	var tan := _mat(Color(0.55, 0.38, 0.2), 0.95)
	var dark := _mat(Color(0.05, 0.04, 0.04), 0.6)
	var collar := _mat(Color(0.6, 0.1, 0.08), 0.5)
	_body = Node3D.new()
	_body.name = "Body"
	_body.position = Vector3(0, BACK_HEIGHT - 0.1, 0)
	add_child(_body)
	_box(_body, Vector3(0.25, 0.25, BODY_LENGTH), Vector3.ZERO, fur)
	_box(_body, Vector3(0.21, 0.1, BODY_LENGTH * 0.8), Vector3(0, -0.11, 0.02), tan)
	_box(_body, Vector3(0.27, 0.27, 0.3), Vector3(0, 0.02, -BODY_LENGTH * 0.32), fur)
	# Cou et tête (l'avant du chien est vers -Z, comme le soldat).
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.06, -BODY_LENGTH * 0.5)
	_body.add_child(_head)
	_box(_head, Vector3(0.17, 0.17, 0.18), Vector3(0, 0.04, -0.05), fur).rotation.x = deg_to_rad(-40)
	_box(_head, Vector3(0.19, 0.04, 0.07), Vector3(0, 0.0, -0.03), collar).rotation.x = deg_to_rad(-40)
	_box(_head, Vector3(0.2, 0.17, 0.2), Vector3(0, 0.13, -0.17), fur)
	_box(_head, Vector3(0.1, 0.09, 0.2), Vector3(0, 0.08, -0.34), tan)
	_box(_head, Vector3(0.05, 0.04, 0.03), Vector3(0, 0.11, -0.45), dark)
	for side in [-1.0, 1.0]:
		var ear := _box(_head, Vector3(0.05, 0.08, 0.025), Vector3(0.065 * side, 0.25, -0.13), fur)
		ear.rotation.z = deg_to_rad(-15.0 * side)
		_box(_head, Vector3(0.025, 0.025, 0.01), Vector3(0.055 * side, 0.17, -0.275), dark)
	# Pattes : pivots à l'épaule et à la hanche.
	for z in [-BODY_LENGTH * 0.38, BODY_LENGTH * 0.38]:
		for side in [-1.0, 1.0]:
			var leg := Node3D.new()
			leg.position = Vector3(0.09 * side, -0.05, z)
			_body.add_child(leg)
			_box(leg, Vector3(0.07, BACK_HEIGHT - 0.12, 0.08), Vector3(0, -(BACK_HEIGHT - 0.12) * 0.5, 0), tan if z > 0.0 else fur)
			_box(leg, Vector3(0.08, 0.05, 0.11), Vector3(0, -(BACK_HEIGHT - 0.1), -0.02), tan)
			_legs.append(leg)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.08, BODY_LENGTH * 0.5)
	_body.add_child(_tail)
	_box(_tail, Vector3(0.07, 0.07, 0.34), Vector3(0, 0, 0.16), fur)


func _process(delta: float) -> void:
	if enemy == null:
		return
	var model := enemy._model
	var lying := enemy.is_dead or enemy.is_stunned()
	_down = move_toward(_down, 1.0 if lying else 0.0, delta * 3.0)
	var speed := Vector2(enemy.velocity.x, enemy.velocity.z).length()
	var ratio := clampf(speed / maxf(enemy.stats.chase_speed, 0.1), 0.0, 1.0) * (1.0 - _down)
	_phase = fmod(_phase + delta * TROT_RATE * (0.6 + ratio) * TAU * (1.0 if ratio > 0.02 else 0.0), TAU)
	# Trot : pattes en diagonale, en opposition.
	var swing := 0.55 * ratio
	for i in _legs.size():
		var opposite := 1.0 if i == 0 or i == 3 else -1.0
		_legs[i].rotation.x = sin(_phase) * swing * opposite + _down * (0.9 if i < 2 else -0.9)
	# Morsure : il se jette en avant, tête basse.
	var lunge := 0.0
	if model.strike_progress >= 0.0:
		lunge = sin(clampf(model.strike_progress, 0.0, 1.0) * PI)
	var alert := enemy.state == Enemy.State.ALERT
	_body.position = Vector3(0, (BACK_HEIGHT - 0.1) * (1.0 - _down * 0.7) + absf(sin(_phase)) * 0.03 * ratio, -lunge * 0.35)
	_body.rotation.z = _down * deg_to_rad(85.0)
	_body.rotation.x = lunge * deg_to_rad(8.0)
	_head.rotation.x = deg_to_rad(10.0 if alert else -8.0) - lunge * deg_to_rad(20.0)
	# Tête : elle suit le regard (cône de vision).
	_head.rotation.y = enemy._vision.rotation.y
	_tail.rotation.x = deg_to_rad(-35.0 if alert else 15.0) + sin(_phase * 2.0) * 0.2 * ratio
	_tail.rotation.y = sin(Time.get_ticks_msec() * 0.008) * (0.4 if not alert and not lying else 0.05)


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
