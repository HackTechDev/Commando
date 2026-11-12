class_name Commando
extends CharacterBody3D
## Unité contrôlable par le joueur : déplacement par navigation et postures.

signal selected_changed(is_selected: bool)

const MASK_OCCLUDERS := 0b10

@export var stats: UnitStats
## Numéro de l'unité dans l'escouade (touches 1 à 6).
@export_range(1, 6) var unit_index: int = 1
@export var display_name: String = "Opérateur"

var is_selected: bool = false
var is_dead: bool = false
var posture: SoldierModel.Posture = SoldierModel.Posture.STANDING
## Cartouches dans le chargeur engagé.
var ammo_in_magazine: int = 0
## Cartouches en réserve.
var ammo_reserve: int = 0

var _running: bool = false
var _has_order: bool = false
var _attack_target: Enemy
var _fire_cooldown: float = 0.0
var _reload_left: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _model: SoldierModel = $SoldierModel
@onready var _ring: MeshInstance3D = $SelectionRing
@onready var health: HealthComponent = $HealthComponent


func _ready() -> void:
	health.reset(stats.max_health)
	ammo_in_magazine = stats.magazine_size
	ammo_reserve = stats.reserve_ammo
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	_update_reload(delta)
	var horizontal := Vector3.ZERO
	if is_dead:
		pass
	elif _attack_target:
		horizontal = _attack(delta)
	elif _has_order:
		if _agent.is_navigation_finished():
			_has_order = false
		else:
			horizontal = _follow_path(delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()

	_model.posture = posture
	_model.move_ratio = Vector2(velocity.x, velocity.z).length() / stats.walk_speed


## Ordonne un déplacement vers `target`. `run` n'a d'effet que debout.
func move_to(target: Vector3, run: bool) -> void:
	if is_dead:
		return
	_attack_target = null
	_running = run
	_has_order = true
	_agent.target_position = target


## Ordonne d'attaquer `enemy` : l'unité s'approche jusqu'à avoir une ligne de
## tir, puis tire jusqu'à ce que la cible soit neutralisée.
func attack(enemy: Enemy, run: bool) -> void:
	if is_dead or enemy == null or enemy.is_dead or not has_ammo():
		return
	_has_order = false
	_running = run
	_attack_target = enemy
	_fire_cooldown = stats.aim_time


## Vrai s'il reste au moins une cartouche (chargeur ou réserve).
func has_ammo() -> bool:
	return ammo_in_magazine > 0 or ammo_reserve > 0


## Vrai pendant un rechargement.
func is_reloading() -> bool:
	return _reload_left > 0.0


## Lance un rechargement si le chargeur n'est pas plein et qu'il reste de la réserve.
func reload() -> void:
	if is_dead or is_reloading() or ammo_reserve <= 0 or ammo_in_magazine >= stats.magazine_size:
		return
	_reload_left = stats.reload_time
	EventBus.unit_ammo_changed.emit(self)


## Arrête le déplacement et l'attaque en cours.
func stop() -> void:
	_has_order = false
	_attack_target = null


## Bascule entre `new_posture` et debout.
func toggle_posture(new_posture: SoldierModel.Posture) -> void:
	if is_dead:
		return
	posture = SoldierModel.Posture.STANDING if posture == new_posture else new_posture


## Met à jour l'état de sélection et l'anneau au sol.
func set_selected(value: bool) -> void:
	if is_selected == value or (value and is_dead):
		return
	is_selected = value
	_ring.visible = value
	selected_changed.emit(value)


func _update_reload(delta: float) -> void:
	if not is_reloading() or is_dead:
		return
	_reload_left -= delta
	if _reload_left <= 0.0:
		_reload_left = 0.0
		var loaded := mini(stats.magazine_size - ammo_in_magazine, ammo_reserve)
		ammo_in_magazine += loaded
		ammo_reserve -= loaded
		EventBus.unit_ammo_changed.emit(self)


func _follow_path(delta: float) -> Vector3:
	var to_next := _agent.get_next_path_position() - global_position
	to_next.y = 0.0
	if to_next.length_squared() < 0.0001:
		return Vector3.ZERO
	_face(to_next, delta)
	return to_next.normalized() * _current_speed()


func _face(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-stats.turn_speed * delta))


func _attack(delta: float) -> Vector3:
	if not is_instance_valid(_attack_target) or _attack_target.is_dead:
		_attack_target = null
		return Vector3.ZERO
	if not has_ammo():
		_attack_target = null
		return Vector3.ZERO
	var to_target := _attack_target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= stats.fire_range and _has_line_of_fire(_attack_target):
		if distance > 0.01:
			_face(to_target, delta)
		_fire_cooldown -= delta
		if ammo_in_magazine <= 0:
			reload()
		elif not is_reloading() and _fire_cooldown <= 0.0 and (-global_basis.z).angle_to(to_target) < 0.25:
			_fire(_attack_target, distance)
		return Vector3.ZERO
	# Pas de ligne de tir : s'approcher, puis viser de nouveau.
	_fire_cooldown = stats.aim_time
	if _agent.target_position.distance_to(_attack_target.global_position) > 0.5:
		_agent.target_position = _attack_target.global_position
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	return _follow_path(delta)


func _weapon_height() -> float:
	match posture:
		SoldierModel.Posture.CROUCHED:
			return 0.9
		SoldierModel.Posture.PRONE:
			return 0.3
	return 1.4


func _has_line_of_fire(enemy: Enemy) -> bool:
	var from := global_position + Vector3.UP * _weapon_height()
	var to := enemy.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_OCCLUDERS)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _fire(enemy: Enemy, distance: float) -> void:
	_fire_cooldown = stats.fire_interval
	ammo_in_magazine -= 1
	EventBus.unit_ammo_changed.emit(self)
	var forward := -global_basis.z
	var muzzle := global_position + Vector3.UP * _weapon_height() + forward * 0.7
	var aim := enemy.global_position + Vector3.UP * 1.2
	var chance := lerpf(stats.hit_chance_near, stats.hit_chance_far, clampf(distance / stats.fire_range, 0.0, 1.0))
	var hit := randf() < chance
	if not hit:
		var side := global_basis.x * (0.5 + randf() * 0.5) * (1.0 if randf() < 0.5 else -1.0)
		aim += side + (aim - muzzle).normalized() * 4.0
	Tracer.spawn(get_tree().current_scene, muzzle, aim, Color(0.6, 0.9, 1.0))
	EventBus.noise_emitted.emit(global_position, stats.gunshot_noise_radius, &"gunshot")
	if hit:
		enemy.take_hit(stats.fire_damage, global_position)


func _current_speed() -> float:
	match posture:
		SoldierModel.Posture.CROUCHED:
			return stats.crouch_speed
		SoldierModel.Posture.PRONE:
			return stats.crawl_speed
	return stats.run_speed if _running else stats.walk_speed


func _on_health_changed(_current: float, _maximum: float) -> void:
	EventBus.unit_damaged.emit(self, health.max_health - health.health)


func _on_died() -> void:
	is_dead = true
	_has_order = false
	_attack_target = null
	remove_from_group(&"commandos")
	collision_layer = 0
	_model.is_dead = true
	SelectionManager.remove(self)
	EventBus.unit_died.emit(self)
