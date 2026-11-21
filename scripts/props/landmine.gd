class_name Landmine
extends Node3D
## Mine antichar ou engin explosif improvisé (`improvised`) enfoui sur une
## piste. Les fantassins ne la déclenchent pas ; un véhicule qui passe dessus
## saute (explosion, `Sabre.take_ram` à la mesure d'une épave).
##
## Cachée, elle est invisible : un opérateur à pied qui passe à moins de
## `DETECT_RADIUS` m (moins de nuit) la repère (`reveal`). Repérée, elle
## est balisée d'un fanion, devient un obstacle de navigation, et le Sabre
## s'arrête devant au lieu de rouler dessus (`blocks`). Un opérateur la
## désamorce (`request_disarm`), après quoi elle est inerte.

const GROUP := &"landmines"
## Repérage par un opérateur à pied : distance (m) de jour, de nuit.
const DETECT_RADIUS := 2.5
const NIGHT_DETECT_RADIUS := 1.5
const SCAN_INTERVAL := 0.2
## Désamorçage : distance (m), durée (s).
const DISARM_REACH := 1.2
const DISARM_TIME := 4.0
## Charge : rayon (m), dégâts aux hommes, dégâts au véhicule, bruit (m).
const BLAST_RADIUS := 3.5
const BLAST_DAMAGE := 70.0
const VEHICLE_DAMAGE := 400.0
const BLAST_NOISE := 45.0
## Obstacle de navigation d'une mine repérée (rayon, m).
const OBSTACLE_RADIUS := 0.8

## Engin improvisé (bidon et fils) plutôt que mine de série.
@export var improvised: bool = false

var is_revealed: bool = false
var is_disarmed: bool = false
var is_exploded: bool = false
var _scan_left: float = 0.0
var _model: Node3D
var _flag: Node3D
var _obstacle: StaticBody3D
var _deminer: Commando
var _disarm_left: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(QuickSave.GROUP)


func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)
	if improvised:
		_box(_model, Vector3(0.45, 0.3, 0.32), Vector3(0, 0.08, 0), _mat(Color(0.3, 0.33, 0.24)))
		_box(_model, Vector3(0.6, 0.02, 0.02), Vector3(0.3, 0.02, 0.1), _mat(Color(0.7, 0.15, 0.1)))
		_box(_model, Vector3(0.02, 0.02, 0.5), Vector3(-0.2, 0.02, 0.3), _mat(Color(0.15, 0.3, 0.7)))
	else:
		var disc := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.17
		mesh.bottom_radius = 0.17
		mesh.height = 0.08
		disc.mesh = mesh
		disc.material_override = _mat(Color(0.28, 0.32, 0.22))
		disc.position.y = 0.03
		_model.add_child(disc)
		_box(_model, Vector3(0.06, 0.04, 0.06), Vector3(0, 0.08, 0), _mat(Color(0.15, 0.15, 0.15)))
	_flag = Node3D.new()
	add_child(_flag)
	_box(_flag, Vector3(0.03, 0.9, 0.03), Vector3(0.45, 0.45, 0), _mat(Color(0.5, 0.42, 0.3)))
	_box(_flag, Vector3(0.3, 0.2, 0.01), Vector3(0.61, 0.8, 0), _mat(Color(0.85, 0.1, 0.08)))
	var skull := Label3D.new()
	skull.text = "MINE"
	skull.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	skull.font_size = 40
	skull.pixel_size = 0.01
	skull.outline_size = 10
	skull.modulate = Color(1.0, 0.35, 0.25)
	skull.position = Vector3(0.45, 1.25, 0)
	_flag.add_child(skull)
	_update_look()


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
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
	material.roughness = 0.9
	return material


## Vrai tant qu'elle peut sauter.
func is_armed() -> bool:
	return not is_disarmed and not is_exploded


func _update_look() -> void:
	_model.visible = (is_revealed or is_disarmed) and not is_exploded
	_flag.visible = is_revealed and is_armed()
	var label := _flag.get_child(_flag.get_child_count() - 1) as Label3D
	label.text = "IED" if improvised else "MINE"
	# Repérée et armée : obstacle que la navigation contourne.
	var wants_obstacle := is_revealed and is_armed()
	if wants_obstacle and _obstacle == null:
		_obstacle = StaticBody3D.new()
		_obstacle.collision_layer = 0b10
		_obstacle.collision_mask = 0
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = OBSTACLE_RADIUS
		cylinder.height = 0.3
		shape.shape = cylinder
		shape.position.y = 0.15
		_obstacle.add_child(shape)
		add_child(_obstacle)
		EventBus.navigation_obstacle_moved.emit()
	elif not wants_obstacle and _obstacle:
		_obstacle.queue_free()
		_obstacle = null
		EventBus.navigation_obstacle_moved.emit()


## Repérée : balisée, contournée.
func reveal(by: Commando = null) -> void:
	if is_revealed or not is_armed():
		return
	is_revealed = true
	_update_look()
	if by:
		by.flash_message(("IED" if improvised else "Mine") + " repérée !")
		Sfx.play_ui(&"suspicious")


func _physics_process(delta: float) -> void:
	if not is_armed():
		return
	_update_disarm(delta)
	if is_revealed:
		return
	_scan_left -= delta
	if _scan_left > 0.0:
		return
	_scan_left = SCAN_INTERVAL
	var reach := NIGHT_DETECT_RADIUS if LevelRoot.is_night(self) else DETECT_RADIUS
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit and not unit.is_dead and unit.riding == null and _flat_distance(unit.global_position) <= reach:
			reveal(unit)
			return


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


## Mine armée sous l'empreinte de `sabre` (roues comprises), repérée ou
## non selon `revealed`, ou null. `ahead` allonge l'empreinte vers l'avant.
static func under(sabre: Sabre, ahead: float = 0.0, revealed: bool = false) -> Landmine:
	for node in sabre.get_tree().get_nodes_in_group(GROUP):
		var mine := node as Landmine
		if mine == null or not mine.is_armed() or mine.is_revealed != revealed:
			continue
		var local := sabre.to_local(mine.global_position)
		# Repérée : seulement devant (on peut toujours s'en éloigner).
		var back := -1.0 if revealed else 2.3
		if absf(local.x) < SabreModel.HALF_WIDTH + 0.15 and local.z < back and local.z > -2.3 - ahead and absf(local.y) < 1.0:
			return mine
	return null


## Le véhicule `sabre` roule dessus : elle saute.
func detonate(sabre: Sabre = null) -> void:
	if not is_armed():
		return
	is_exploded = true
	_deminer = null
	_update_look()
	Explosion.detonate(get_parent(), global_position, BLAST_RADIUS, BLAST_DAMAGE, BLAST_NOISE)
	if sabre:
		sabre.take_ram(VEHICLE_DAMAGE, true)


## Mine repérée la plus proche de `point` (à `reach` m au plus), ou null.
static func revealed_near(tree: SceneTree, point: Vector3, reach: float = 1.0) -> Landmine:
	var best: Landmine = null
	var best_distance := reach
	for node in tree.get_nodes_in_group(GROUP):
		var mine := node as Landmine
		if mine and mine.is_revealed and mine.is_armed() and mine._flat_distance(point) <= best_distance:
			best = mine
			best_distance = mine._flat_distance(point)
	return best


## Point d'où l'on désamorce, du côté de `from`.
func disarm_point(from: Vector3) -> Vector3:
	var away := from - global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	return global_position + away * (OBSTACLE_RADIUS + 0.4)


## Envoie `unit` désamorcer la mine (repérée). Renvoie faux sinon.
func request_disarm(unit: Commando, run: bool) -> bool:
	if not is_revealed or not is_armed() or unit == null or unit.is_dead or unit.riding:
		return false
	_deminer = unit
	_disarm_left = DISARM_TIME
	unit.move_to(disarm_point(unit.global_position), run)
	return true


func _update_disarm(delta: float) -> void:
	if _deminer == null:
		return
	if not is_instance_valid(_deminer) or _deminer.is_dead or _deminer.riding:
		_deminer = null
		return
	if _flat_distance(_deminer.global_position) > OBSTACLE_RADIUS + DISARM_REACH:
		if not _deminer.is_walking():
			_deminer = null
		return
	if _deminer.posture == SoldierModel.Posture.STANDING:
		_deminer.toggle_posture(SoldierModel.Posture.CROUCHED)
	_disarm_left -= delta
	if _disarm_left <= 0.0:
		var unit := _deminer
		_deminer = null
		is_disarmed = true
		_update_look()
		unit.flash_message(("IED" if improvised else "Mine") + " désamorcée")
		Sfx.play_at(&"clink", global_position, -4.0)


## Sauvegarde rapide (`QuickSave`).
func save_state() -> Dictionary:
	return {"revealed": is_revealed, "disarmed": is_disarmed, "exploded": is_exploded}


func load_state(data: Dictionary) -> void:
	_deminer = null
	is_revealed = data.get("revealed", false)
	is_disarmed = data.get("disarmed", false)
	is_exploded = data.get("exploded", false)
	_update_look()
