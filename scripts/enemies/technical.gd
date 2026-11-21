class_name Technical
extends StaticBody3D
## Pick-up ennemi armé (« technical ») : un chauffeur et un mitrailleur
## debout sur le plateau derrière une mitrailleuse lourde.
##
## Il patrouille une boucle (`patrol_path`) sur le maillage de navigation.
## Il entend les bruits (moteur du Sabre, tirs, explosions) à leur portée
## plus `HEAR_BONUS` m, et fonce vers le dernier entendu. Quand il voit un
## opérateur (ou un VIP) à portée et à découvert, il s'arrête, donne
## l'alerte et tire par rafales. Faute de nouvelle trace pendant
## `SEARCH_TIME` s, il reprend sa ronde.
##
## Il encaisse balles (`take_shot`), souffle (`blast` : grenade, missile,
## charge) et mines ; à bout de structure, c'est une épave fumante.

const GROUP := &"technicals"
const SPEED := 6.5
const CHASE_SPEED := 8.5
const TURN_RATE := 2.0
const WAYPOINT_REACH := 1.5
const STRUCTURE := 300.0
## Blindage léger : part des dégâts d'une balle qui porte.
const BULLET_SHARE := 0.35
## Ouïe : marge ajoutée à la portée d'un bruit (m).
const HEAR_BONUS := 10.0
const HEARD_KINDS: Array[StringName] = [&"gunshot", &"explosion", &"distraction", &"help", &"engine"]
## Vue : portée de jour, de nuit (m) ; un opérateur couché est vu de moitié
## moins loin.
const SIGHT := 28.0
const NIGHT_SIGHT := 13.0
const SCAN_INTERVAL := 0.3
## Recherche après le dernier contact (s).
const SEARCH_TIME := 10.0
## Tir : visée avant la première rafale, rafale, cadence, pause, dégâts par
## balle, chance de toucher (près, à portée max), bruit.
const AIM_TIME := 1.2
const BURST := 5
const ROUND_INTERVAL := 0.12
const BURST_PAUSE := 1.5
const DAMAGE := 18.0
const HIT_NEAR := 0.6
const HIT_FAR := 0.25
const GUN_NOISE := 45.0
## Alerte : rayon du cri, délai entre deux.
const ALARM_RADIUS := 40.0
const ALARM_COOLDOWN := 8.0
## Gabarit : demi-largeur, demi-longueur (m) ; position de la mitrailleuse.
const HALF_WIDTH := 1.0
const HALF_LENGTH := 2.4
const GUN_MUZZLE := Vector3(0.0, 2.25, 0.2)

enum State { PATROL, CHASE, ENGAGE, WRECKED }

@export var patrol_path: NodePath

var state: State = State.PATROL
var structure: float = STRUCTURE
var is_wrecked: bool = false
var _loop: Array[Vector3] = []
var _loop_index: int = 0
var _path := PackedVector3Array()
var _path_index: int = 0
var _goal := Vector3.INF
var _search_left: float = 0.0
var _scan_left: float = 0.0
var _target: Unit
var _aim_left: float = 0.0
var _rounds_left: int = 0
var _cooldown: float = 0.0
var _alarm_left: float = 0.0
## Délai avant de redemander un chemin (carte de navigation pas prête).
var _repath_left: float = 0.0
var _materials: Array[StandardMaterial3D] = []
var _gun_pivot: Node3D
var _crew: Array[Node3D] = []
var _smoke: CPUParticles3D


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(Explosion.VEHICLES_GROUP)
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	collision_layer = 0b10
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALF_WIDTH * 2.0, 1.6, HALF_LENGTH * 2.0)
	shape.shape = box
	shape.position.y = 0.95
	add_child(shape)
	_build_model()
	var path := get_node_or_null(patrol_path) as Path3D
	if path and path.curve:
		for i in path.curve.point_count:
			_loop.append(path.to_global(path.curve.get_point_position(i)))
	EventBus.noise_emitted.connect(_on_noise)
	_next_loop_point.call_deferred()


# --- Modèle ---------------------------------------------------------------------

func _build_model() -> void:
	var body := _mat(Color(0.8, 0.77, 0.68))
	var rust := _mat(Color(0.5, 0.33, 0.2))
	var dark := _mat(Color(0.1, 0.1, 0.11))
	var glass := _mat(Color(0.18, 0.22, 0.26))
	var steel := _mat(Color(0.25, 0.26, 0.27))
	# Châssis, capot, cabine, plateau.
	_box(Vector3(1.9, 0.35, 4.7), Vector3(0, 0.62, 0), dark)
	_box(Vector3(1.9, 0.5, 1.3), Vector3(0, 1.0, -1.7), body)
	_box(Vector3(1.9, 0.95, 1.2), Vector3(0, 1.27, -0.5), body)
	_box(Vector3(1.75, 0.45, 0.05), Vector3(0, 1.5, -1.12), glass)
	for x: float in [-0.96, 0.96]:
		_box(Vector3(0.04, 0.4, 0.8), Vector3(x, 1.5, -0.5), glass)
	_box(Vector3(1.9, 0.12, 2.3), Vector3(0, 0.86, 1.2), body)
	for x: float in [-0.92, 0.92]:
		_box(Vector3(0.06, 0.5, 2.3), Vector3(x, 1.15, 1.2), body)
	_box(Vector3(1.9, 0.5, 0.06), Vector3(0, 1.15, 2.33), rust)
	_box(Vector3(1.6, 0.2, 0.3), Vector3(0, 0.75, -2.4), steel)
	# Roues.
	for x: float in [-0.9, 0.9]:
		for z: float in [-1.6, 1.5]:
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.4
			cylinder.bottom_radius = 0.4
			cylinder.height = 0.3
			wheel.mesh = cylinder
			wheel.material_override = dark
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(x, 0.4, z)
			add_child(wheel)
	# Mitrailleuse sur affût, avec bouclier, au milieu du plateau.
	_box(Vector3(0.12, 0.9, 0.12), Vector3(0, 1.35, 0.9), steel)
	_gun_pivot = Node3D.new()
	_gun_pivot.position = Vector3(0, 1.85, 0.9)
	add_child(_gun_pivot)
	_box_in(_gun_pivot, Vector3(0.16, 0.18, 0.9), Vector3(0, 0, -0.25), dark)
	_box_in(_gun_pivot, Vector3(0.06, 0.06, 0.8), Vector3(0, 0.02, -1.0), dark)
	_box_in(_gun_pivot, Vector3(0.8, 0.5, 0.04), Vector3(0, 0.1, -0.45), steel)
	# Équipage : chauffeur (en cabine), mitrailleur debout derrière l'arme.
	_crew.append(_figure(Vector3(-0.45, 0.9, -0.5), 0.45))
	_crew.append(_figure(Vector3(0, 0.92, 1.55), 1.25))


## Silhouette d'ennemi : tronc, tête, béret rouge.
func _figure(at: Vector3, torso: float) -> Node3D:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var uniform := _mat(Color(0.55, 0.47, 0.33))
	_box_in(root, Vector3(0.42, torso, 0.28), Vector3(0, torso * 0.5, 0), uniform)
	_box_in(root, Vector3(0.24, 0.26, 0.24), Vector3(0, torso + 0.15, 0), _mat(Color(0.55, 0.4, 0.3)))
	_box_in(root, Vector3(0.27, 0.07, 0.27), Vector3(0, torso + 0.3, 0), _mat(Color(0.7, 0.1, 0.1)))
	return root


func _box(size: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	_box_in(self, size, at, material)


func _box_in(parent: Node3D, size: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)


func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	material.set_meta(&"color", color)
	_materials.append(material)
	return material


# --- Déplacement ----------------------------------------------------------------

func _next_loop_point() -> void:
	if _loop.is_empty() or is_wrecked:
		return
	_set_goal(_loop[_loop_index])


func _set_goal(point: Vector3) -> void:
	_goal = point
	var map := get_world_3d().navigation_map
	# Carte de navigation pas encore prête (chargement) : on réessaiera.
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		_path = PackedVector3Array()
		_path_index = 0
		_repath_left = 0.5
		return
	_repath_left = 0.0
	var start := NavigationServer3D.map_get_closest_point(map, global_position)
	var end := NavigationServer3D.map_get_closest_point(map, point)
	_path = NavigationServer3D.map_get_path(map, start, end, true)
	_path_index = 1 if _path.size() > 1 else _path.size()


## Avance sur le chemin ; renvoie vrai à l'arrivée.
func _drive(delta: float, speed: float) -> bool:
	if _repath_left > 0.0:
		_repath_left -= delta
		if _repath_left <= 0.0:
			_set_goal(_goal)
		return false
	if _path_index >= _path.size():
		return true
	var next := _path[_path_index]
	var to_next := next - global_position
	to_next.y = 0.0
	if to_next.length() <= WAYPOINT_REACH:
		_path_index += 1
		return _path_index >= _path.size()
	var forward := -global_basis.z
	var turn := forward.signed_angle_to(to_next.normalized(), Vector3.UP)
	rotate_y(clampf(turn, -TURN_RATE * delta, TURN_RATE * delta))
	var sharpness := clampf(absf(turn) / 1.2, 0.0, 1.0)
	global_position += -global_basis.z * speed * lerpf(1.0, 0.25, sharpness) * delta
	var map := get_world_3d().navigation_map
	global_position.y = lerpf(global_position.y, NavigationServer3D.map_get_closest_point(map, global_position).y - 0.08, minf(1.0, delta * 4.0))
	return false


# --- Comportement ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_wrecked:
		return
	_alarm_left -= delta
	_cooldown -= delta
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = SCAN_INTERVAL
		_look()
	match state:
		State.PATROL:
			if _loop.is_empty():
				return
			if _drive(delta, SPEED):
				_loop_index = (_loop_index + 1) % _loop.size()
				_next_loop_point()
		State.CHASE:
			_search_left -= delta
			if _search_left <= 0.0:
				state = State.PATROL
				_next_loop_point()
				return
			_drive(delta, CHASE_SPEED)
		State.ENGAGE:
			_engage(delta)
	_aim_gun(delta)


## Cherche un opérateur (ou un VIP) visible ; en vue, il s'arrête et tire.
func _look() -> void:
	var seen := _visible_target()
	if seen:
		_target = seen
		if state != State.ENGAGE:
			state = State.ENGAGE
			_aim_left = AIM_TIME
			_rounds_left = 0
		_search_left = SEARCH_TIME
		_goal = seen.global_position
		if _alarm_left <= 0.0:
			_alarm_left = ALARM_COOLDOWN
			EventBus.noise_emitted.emit(global_position, ALARM_RADIUS, &"help")
	elif state == State.ENGAGE:
		# Contact perdu : il fonce vers la dernière position connue.
		_target = null
		state = State.CHASE
		_search_left = SEARCH_TIME
		_set_goal(_goal)


func _visible_target() -> Unit:
	var best: Unit = null
	var best_distance := INF
	var night := LevelRoot.is_night(self)
	var space := get_world_3d().direct_space_state
	var eye := global_position + Vector3.UP * 2.0
	for unit in Unit.targets(get_tree()):
		var reach := NIGHT_SIGHT if night else SIGHT
		var riding := unit.get(&"riding") as Sabre
		if riding and night and riding.headlights:
			reach = SIGHT
		if riding == null and unit.posture == SoldierModel.Posture.PRONE:
			reach *= 0.5
		var distance := unit.global_position.distance_to(global_position)
		if distance > reach or distance >= best_distance:
			continue
		var exclude: Array[RID] = [get_rid()]
		if riding:
			exclude.append_array(riding.body_rids())
		var query := PhysicsRayQueryParameters3D.create(eye, unit.global_position + Vector3.UP * 1.0, 0b10, exclude)
		if not space.intersect_ray(query).is_empty():
			continue
		best = unit
		best_distance = distance
	return best


## À l'arrêt, il vise puis tire par rafales sur la cible.
func _engage(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or _target.is_dead:
		return
	_aim_left -= delta
	if _aim_left > 0.0 or _cooldown > 0.0:
		return
	if _rounds_left <= 0:
		_rounds_left = BURST
		EventBus.noise_emitted.emit(global_position, GUN_NOISE, &"gunshot")
	_rounds_left -= 1
	_cooldown = ROUND_INTERVAL if _rounds_left > 0 else BURST_PAUSE
	_fire_round(_target)


func _fire_round(target: Unit) -> void:
	var from := _gun_pivot.to_global(Vector3(0, 0.02, -1.4))
	var aim := target.global_position + Vector3.UP * 1.0
	var distance := from.distance_to(aim)
	var chance := lerpf(HIT_NEAR, HIT_FAR, clampf(distance / SIGHT, 0.0, 1.0))
	var scene := get_tree().current_scene as Node3D
	if scene == null:
		scene = get_parent() as Node3D
	var riding := target.get(&"riding") as Sabre
	var end := aim + Vector3(randf_range(-1, 1), randf_range(-0.4, 0.6), randf_range(-1, 1)) * 0.8
	if randf() < chance:
		if riding and riding.shields_rider(DAMAGE, from):
			end = aim
		elif riding == null and Sabre.blocks_shot(get_tree(), from, aim, DAMAGE) != null:
			end = aim
		else:
			end = aim
			ShotImpact.hit(scene, target, aim, from, DAMAGE, false)
			target.health.take_damage(DAMAGE)
	Tracer.spawn(scene, from, end, Color(1.0, 0.55, 0.3))
	Sfx.play_at(&"shot", from, 1.0)


## La mitrailleuse se tourne vers la cible (ou vers l'avant).
func _aim_gun(delta: float) -> void:
	var yaw := 0.0
	if state == State.ENGAGE and _target and is_instance_valid(_target):
		var local := to_local(_target.global_position)
		yaw = atan2(-local.x, -local.z)
	_gun_pivot.rotation.y = lerp_angle(_gun_pivot.rotation.y, yaw, minf(1.0, delta * 5.0))
	_crew[1].rotation.y = _gun_pivot.rotation.y


## Un bruit à portée : il fonce vers lui (sauf s'il tire déjà).
func _on_noise(at: Vector3, radius: float, kind: StringName) -> void:
	if is_wrecked or state == State.ENGAGE or not HEARD_KINDS.has(kind):
		return
	if at.distance_to(global_position) > radius + HEAR_BONUS:
		return
	# Ses propres tirs et cris ne comptent pas.
	if at.distance_to(global_position) < 1.0:
		return
	state = State.CHASE
	_search_left = SEARCH_TIME
	_set_goal(at)


# --- Dégâts ---------------------------------------------------------------------

## Balle reçue (12,7, 7,62, fusils).
func take_shot(damage: float, _at: Vector3, _from: Vector3) -> void:
	_damage(damage * BULLET_SHARE)


## Souffle d'une explosion à `at`, de rayon `radius`.
func blast(at: Vector3, radius: float) -> void:
	var distance := Vector2(at.x - global_position.x, at.z - global_position.z).length()
	var reach := radius + HALF_LENGTH * 0.6
	if distance < reach:
		_damage(lerpf(STRUCTURE * 1.2, STRUCTURE * 0.3, distance / reach))


func _damage(amount: float) -> void:
	if is_wrecked:
		return
	structure = maxf(structure - amount, 0.0)
	if structure <= 0.0:
		_wreck()
	elif state == State.PATROL:
		# Touché sans voir le tireur : il cherche autour de lui.
		state = State.CHASE
		_search_left = SEARCH_TIME
		_set_goal(global_position)


func _wreck() -> void:
	is_wrecked = true
	state = State.WRECKED
	_target = null
	for material in _materials:
		material.albedo_color = (material.get_meta(&"color") as Color).darkened(0.75)
	for figure in _crew:
		figure.visible = false
	if _smoke == null:
		_smoke = Sabre.make_smoke()
		_smoke.position = Vector3(0, 1.4, -1.6)
		add_child(_smoke)
	_smoke.color = Color(0.12, 0.11, 0.1, 0.7)
	_smoke.emitting = true
	Sfx.play_at(&"explosion", global_position + Vector3.UP, 2.0)
	EventBus.sight_blockers_changed.emit()


## Sauvegarde rapide (`QuickSave`).
func save_state() -> Dictionary:
	return {"position": global_position, "yaw": global_rotation.y, "structure": structure, "wrecked": is_wrecked, "loop": _loop_index}


func load_state(data: Dictionary) -> void:
	global_position = data.get("position", global_position)
	global_rotation.y = data.get("yaw", global_rotation.y)
	structure = data.get("structure", STRUCTURE)
	_loop_index = data.get("loop", 0)
	_target = null
	if data.get("wrecked", false):
		if not is_wrecked:
			_wreck()
		return
	state = State.PATROL
	_next_loop_point()
