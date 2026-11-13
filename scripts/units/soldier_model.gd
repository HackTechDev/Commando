class_name SoldierModel
extends Node3D
## Modèle 3D procédural d'un opérateur des forces spéciales modernes.
##
## Entièrement construit à partir de primitives (phase prototype, cf. §8) :
## casque balistique avec JVN relevées, cagoule, casque radio, porte-plaques
## avec chargeurs, sac à dos, genouillères, holster de cuisse et carabine avec
## silencieux. Le modèle regarde vers -Z et ses pieds sont à l'origine.
## L'animation (marche, course, postures) est procédurale.

enum Posture { STANDING, CROUCHED, PRONE }
enum ArmPose { RIFLE, REACH, PUSH, STRIKE }

# Images clés de l'escalade, par paires (instant 0..1, valeur). Montée : élan,
# mains sur le rebord, traction, passage d'une jambe, redressement.
const CLIMB_UP_HIPS: Array[float] = [0.0, 0.92, 0.15, 0.78, 0.28, 0.92, 0.5, 0.92, 0.66, 0.5, 0.82, 0.54, 1.0, 0.92]
const CLIMB_UP_THIGH_L: Array[float] = [0.0, 0.0, 0.15, 0.5, 0.28, 0.1, 0.5, 0.25, 0.66, -0.2, 0.82, 1.0, 1.0, 0.0]
const CLIMB_UP_KNEE_L: Array[float] = [0.0, 0.0, 0.15, -1.0, 0.28, -0.1, 0.5, -0.5, 0.66, -0.9, 0.82, -1.9, 1.0, 0.0]
const CLIMB_UP_THIGH_R: Array[float] = [0.0, 0.0, 0.15, 0.5, 0.28, 0.1, 0.5, 0.6, 0.66, 1.75, 0.82, 1.0, 1.0, 0.0]
const CLIMB_UP_KNEE_R: Array[float] = [0.0, 0.0, 0.15, -1.0, 0.28, -0.1, 0.5, -0.9, 0.66, -1.7, 0.82, -1.9, 1.0, 0.0]
const CLIMB_UP_LEAN: Array[float] = [0.0, 0.0, 0.15, -0.25, 0.5, -0.55, 0.82, -0.5, 1.0, 0.0]
const CLIMB_UP_SLING: Array[float] = [0.0, 0.0, 0.14, 1.0, 0.82, 1.0, 1.0, 0.0]
const CLIMB_UP_ARMS: Array[float] = [0.0, ArmPose.RIFLE, 0.18, ArmPose.REACH, 0.5, ArmPose.PUSH, 0.72, ArmPose.PUSH, 0.96, ArmPose.RIFLE]
# Descente : accroupi au bord, appui des mains, chute, réception, redressement.
const CLIMB_DOWN_HIPS: Array[float] = [0.0, 0.92, 0.25, 0.54, 0.45, 0.88, 0.6, 0.9, 0.74, 0.62, 1.0, 0.92]
const CLIMB_DOWN_THIGH: Array[float] = [0.0, 0.0, 0.25, 1.0, 0.45, 0.3, 0.6, 0.15, 0.74, 0.85, 1.0, 0.0]
const CLIMB_DOWN_KNEE: Array[float] = [0.0, 0.0, 0.25, -1.9, 0.45, -0.5, 0.6, -0.3, 0.74, -1.6, 1.0, 0.0]
const CLIMB_DOWN_LEAN: Array[float] = [0.0, 0.0, 0.25, -0.5, 0.5, -0.15, 0.74, -0.4, 1.0, 0.0]
const CLIMB_DOWN_SLING: Array[float] = [0.0, 0.0, 0.15, 1.0, 0.75, 1.0, 1.0, 0.0]
const CLIMB_DOWN_ARMS: Array[float] = [0.0, ArmPose.RIFLE, 0.22, ArmPose.PUSH, 0.5, ArmPose.REACH, 0.82, ArmPose.RIFLE]

const HIP_HEIGHT := 0.92
const THIGH_LENGTH := 0.44
const UPPER_ARM_LENGTH := 0.29
const FOREARM_LENGTH := 0.29

@export var uniform_color := Color(0.30, 0.33, 0.24)
@export var gear_color := Color(0.16, 0.17, 0.14)
@export var boot_color := Color(0.12, 0.10, 0.08)
@export var weapon_color := Color(0.07, 0.07, 0.08)
@export var skin_color := Color(0.80, 0.62, 0.50)
## Couleur d'identification de l'équipe (écussons d'épaule, marqueur de casque).
@export var team_color := Color(0.15, 0.45, 0.95)

## Posture affichée ; la transition est interpolée.
var posture: Posture = Posture.STANDING
## 0 = immobile, 1 = marche, 2 = course.
var move_ratio: float = 0.0
## Unité morte : étendue sur le dos, immobile.
var is_dead: bool = false
## Avancement de l'animation d'escalade (0 à 1), piloté par l'unité ;
## négatif quand aucune escalade n'est en cours.
var climb_progress: float = -1.0
## Vrai pour l'animation de descente, faux pour la montée.
var climb_descending: bool = false
## Avancement d'une attaque au corps à corps (0 à 1) ; négatif hors attaque.
var strike_progress: float = -1.0
## Vrai si l'attaque se fait au couteau (lame visible), faux pour un coup de poing.
var strike_with_knife: bool = false

var _body: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _phase: float = 0.0
var _rifle: Node3D
var _rifle_hold: Transform3D
var _rifle_slung: Transform3D
var _knife: Node3D
## Pivots des bras : [épaule gauche, coude gauche, épaule droite, coude droit].
var _arm_joints: Array[Node3D] = []
## Poses des bras (une rotation par pivot), indexées par `ArmPose`.
var _arm_poses: Array = []
var _time: float = 0.0

var _m_uniform: StandardMaterial3D
var _m_gear: StandardMaterial3D
var _m_boot: StandardMaterial3D
var _m_weapon: StandardMaterial3D
var _m_skin: StandardMaterial3D
var _m_team: StandardMaterial3D
var _m_lens: StandardMaterial3D
var _m_steel: StandardMaterial3D


func _ready() -> void:
	_m_uniform = _mat(uniform_color, 0.95)
	_m_gear = _mat(gear_color, 0.85)
	_m_boot = _mat(boot_color, 0.7)
	_m_weapon = _mat(weapon_color, 0.45, 0.6)
	_m_skin = _mat(skin_color, 0.8)
	_m_team = _mat(team_color, 0.6)
	_m_team.emission_enabled = true
	_m_team.emission = team_color
	_m_team.emission_energy_multiplier = 0.4
	_m_lens = _mat(Color(0.1, 0.5, 0.3), 0.15, 0.8)
	_m_steel = _mat(Color(0.72, 0.74, 0.78), 0.25, 0.9)

	_body = _pivot(self, Vector3.ZERO, "Body")
	_hips = _pivot(_body, Vector3(0.0, HIP_HEIGHT, 0.0), "Hips")
	_build_legs()
	_build_torso()
	_build_head()
	_build_rifle_and_arms()


func _process(delta: float) -> void:
	_time += delta
	if climb_progress >= 0.0 and not is_dead:
		_animate_climb(delta)
		return
	var walk := clampf(move_ratio, 0.0, 2.0)
	_phase += delta * (5.0 + 3.5 * walk) * minf(walk, 1.0)
	var blend := 1.0 - exp(-10.0 * delta)

	# Cibles selon la posture.
	var hips_y := HIP_HEIGHT
	var thigh_base := 0.0
	var knee_base := 0.0
	var lean := -0.12 * maxf(walk - 1.0, 0.0)
	var body_pitch := 0.0
	var body_pos := Vector3.ZERO
	var swing := 0.55 * minf(walk, 1.0) + 0.25 * maxf(walk - 1.0, 0.0)
	# Attaque au corps à corps : élan vers l'avant, puis retour.
	var strike := 0.0
	if strike_progress >= 0.0 and not is_dead:
		strike = sin(PI * clampf(strike_progress, 0.0, 1.0))
	lean -= 0.35 * strike
	match posture:
		Posture.CROUCHED:
			hips_y = 0.56
			thigh_base = 1.0
			knee_base = -1.9
			lean = -0.4
			swing *= 0.5
		Posture.PRONE:
			body_pitch = -PI / 2.0
			body_pos = Vector3(0.0, 0.16, 0.9)
			swing *= 0.35

	if is_dead:
		hips_y = HIP_HEIGHT
		thigh_base = 0.0
		knee_base = 0.0
		lean = 0.0
		swing = 0.0
		body_pitch = PI / 2.0
		body_pos = Vector3(0.0, 0.2, -0.9)

	var s := sin(_phase)
	_body.rotation.x = lerp_angle(_body.rotation.x, body_pitch, blend)
	_body.position = _body.position.lerp(body_pos, blend)
	_hips.position.y = lerpf(_hips.position.y, hips_y + absf(s) * 0.03 * minf(walk, 1.0), blend)
	_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, thigh_base + s * swing, blend)
	_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, thigh_base - s * swing, blend)
	_knee_l.rotation.x = lerp_angle(_knee_l.rotation.x, knee_base - maxf(-cos(_phase), 0.0) * swing * 1.6, blend)
	_knee_r.rotation.x = lerp_angle(_knee_r.rotation.x, knee_base - maxf(cos(_phase), 0.0) * swing * 1.6, blend)
	# Respiration au repos, léger balancement en mouvement.
	var breath := 0.0 if is_dead else sin(_time * 1.8) * 0.012
	_torso.rotation.x = lerp_angle(_torso.rotation.x, lean + breath, blend)
	_torso.rotation.y = lerp_angle(_torso.rotation.y, s * 0.10 * minf(walk, 1.0), blend)
	var head_pitch := 0.0
	if is_dead:
		_time = 0.0
	elif posture == Posture.PRONE:
		head_pitch = 0.9
	elif posture == Posture.CROUCHED:
		head_pitch = 0.3
	_head.rotation.x = lerp_angle(_head.rotation.x, head_pitch, blend)
	# Retour à la tenue de l'arme (après une escalade, par exemple).
	_rifle.transform = _rifle.transform.interpolate_with(_rifle_hold, blend)
	for i in _arm_joints.size():
		_arm_joints[i].quaternion = _arm_joints[i].quaternion.slerp(_arm_poses[ArmPose.RIFLE][i], blend)
	_knife.visible = strike > 0.0 and strike_with_knife
	if strike > 0.0:
		# La main droite lâche la poignée : l'arme pend, les bras frappent.
		_rifle.transform = _rifle_hold.interpolate_with(_rifle_slung, minf(strike * 1.5, 1.0))
		for i in _arm_joints.size():
			var rest: Quaternion = _arm_poses[ArmPose.RIFLE][i]
			_arm_joints[i].quaternion = rest.slerp(_arm_poses[ArmPose.STRIKE][i], strike)
	_head.rotation.y = lerp_angle(_head.rotation.y, sin(_time * 0.6) * 0.25 * (1.0 - minf(walk, 1.0)), blend)


## Valeur interpolée (avec adoucissement) d'une piste d'images clés donnée
## par paires (instant, valeur).
static func sample_keys(keys: Array[float], t: float) -> float:
	var count := keys.size() / 2
	if t <= keys[0]:
		return keys[1]
	for i in range(1, count):
		if t <= keys[i * 2]:
			var from_t := keys[(i - 1) * 2]
			var weight := smoothstep(0.0, 1.0, (t - from_t) / (keys[i * 2] - from_t))
			return lerpf(keys[(i - 1) * 2 + 1], keys[i * 2 + 1], weight)
	return keys[count * 2 - 1]


## Pose d'escalade à l'instant `climb_progress` (le déplacement du corps dans
## le monde est géré par l'unité).
func _animate_climb(delta: float) -> void:
	var t := clampf(climb_progress, 0.0, 1.0)
	var down := climb_descending
	var blend := 1.0 - exp(-25.0 * delta)
	_body.rotation.x = lerp_angle(_body.rotation.x, 0.0, blend)
	_body.position = _body.position.lerp(Vector3.ZERO, blend)
	_hips.position.y = sample_keys(CLIMB_DOWN_HIPS if down else CLIMB_UP_HIPS, t)
	_leg_l.rotation.x = sample_keys(CLIMB_DOWN_THIGH if down else CLIMB_UP_THIGH_L, t)
	_knee_l.rotation.x = sample_keys(CLIMB_DOWN_KNEE if down else CLIMB_UP_KNEE_L, t)
	_leg_r.rotation.x = sample_keys(CLIMB_DOWN_THIGH if down else CLIMB_UP_THIGH_R, t)
	_knee_r.rotation.x = sample_keys(CLIMB_DOWN_KNEE if down else CLIMB_UP_KNEE_R, t)
	_torso.rotation.x = sample_keys(CLIMB_DOWN_LEAN if down else CLIMB_UP_LEAN, t)
	_torso.rotation.y = 0.0
	_head.rotation = Vector3(-0.5 * _torso.rotation.x, 0.0, 0.0)
	var sling := sample_keys(CLIMB_DOWN_SLING if down else CLIMB_UP_SLING, t)
	_rifle.transform = _rifle_hold.interpolate_with(_rifle_slung, sling)
	_apply_arm_keys(CLIMB_DOWN_ARMS if down else CLIMB_UP_ARMS, t)


## Interpole les bras entre les poses d'une piste (instant, `ArmPose`).
func _apply_arm_keys(keys: Array[float], t: float) -> void:
	var count := keys.size() / 2
	var from_index := 0
	while from_index < count - 2 and t > keys[(from_index + 1) * 2]:
		from_index += 1
	var from_t := keys[from_index * 2]
	var to_t := keys[(from_index + 1) * 2]
	var weight := smoothstep(0.0, 1.0, clampf((t - from_t) / (to_t - from_t), 0.0, 1.0))
	var from_pose: Array = _arm_poses[int(keys[from_index * 2 + 1])]
	var to_pose: Array = _arm_poses[int(keys[(from_index + 1) * 2 + 1])]
	for i in _arm_joints.size():
		var from_rotation: Quaternion = from_pose[i]
		_arm_joints[i].quaternion = from_rotation.slerp(to_pose[i], weight)


# --- Construction -----------------------------------------------------------

func _build_legs() -> void:
	for side: float in [-1.0, 1.0]:
		var leg := _pivot(_hips, Vector3(0.11 * side, 0.0, 0.0), "LegL" if side < 0.0 else "LegR")
		_box(leg, Vector3(0.16, THIGH_LENGTH, 0.18), Vector3(0.0, -0.22, 0.0), _m_uniform)
		# Poche cargo.
		_box(leg, Vector3(0.04, 0.16, 0.13), Vector3(0.09 * side, -0.24, 0.0), _m_uniform)
		var knee := _pivot(leg, Vector3(0.0, -THIGH_LENGTH, 0.0), "Knee")
		_box(knee, Vector3(0.14, 0.40, 0.16), Vector3(0.0, -0.20, 0.0), _m_uniform)
		# Genouillère.
		_box(knee, Vector3(0.15, 0.13, 0.07), Vector3(0.0, -0.02, -0.085), _m_gear)
		# Botte : tige + semelle.
		_box(knee, Vector3(0.15, 0.16, 0.18), Vector3(0.0, -0.36, 0.0), _m_boot)
		_box(knee, Vector3(0.15, 0.09, 0.30), Vector3(0.0, -0.435, -0.05), _m_boot)
		if side < 0.0:
			_leg_l = leg
			_knee_l = knee
		else:
			_leg_r = leg
			_knee_r = knee
			# Holster de cuisse avec pistolet.
			_box(leg, Vector3(0.05, 0.20, 0.12), Vector3(0.115, -0.20, 0.0), _m_gear)
			_box(leg, Vector3(0.035, 0.07, 0.10), Vector3(0.12, -0.07, 0.02), _m_weapon)


func _build_torso() -> void:
	_torso = _pivot(_hips, Vector3.ZERO, "Torso")
	# Bassin et ceinturon de combat.
	_box(_torso, Vector3(0.36, 0.14, 0.22), Vector3(0.0, 0.02, 0.0), _m_uniform)
	_box(_torso, Vector3(0.39, 0.06, 0.25), Vector3(0.0, 0.08, 0.0), _m_gear)
	_box(_torso, Vector3(0.07, 0.09, 0.06), Vector3(-0.2, 0.05, 0.0), _m_gear)
	# Buste.
	_box(_torso, Vector3(0.38, 0.46, 0.22), Vector3(0.0, 0.33, 0.0), _m_uniform)
	# Porte-plaques.
	_box(_torso, Vector3(0.36, 0.36, 0.28), Vector3(0.0, 0.33, 0.0), _m_gear)
	_box(_torso, Vector3(0.41, 0.14, 0.20), Vector3(0.0, 0.22, 0.0), _m_gear)
	# Bretelles.
	for side: float in [-1.0, 1.0]:
		_box(_torso, Vector3(0.08, 0.07, 0.26), Vector3(0.12 * side, 0.545, 0.0), _m_gear)
	# Trois porte-chargeurs.
	for i in 3:
		var x := (float(i) - 1.0) * 0.105
		_box(_torso, Vector3(0.09, 0.17, 0.05), Vector3(x, 0.24, -0.16), _m_gear)
		_box(_torso, Vector3(0.06, 0.04, 0.035), Vector3(x, 0.34, -0.155), _m_weapon)
	# Poche utilitaire et écusson de poitrine.
	_box(_torso, Vector3(0.14, 0.07, 0.03), Vector3(0.0, 0.44, -0.15), _m_gear)
	_box(_torso, Vector3(0.08, 0.035, 0.01), Vector3(0.0, 0.445, -0.168), _m_team)
	# Sac d'assaut + radio et antenne.
	_box(_torso, Vector3(0.30, 0.36, 0.14), Vector3(0.0, 0.34, 0.20), _m_gear)
	_box(_torso, Vector3(0.22, 0.14, 0.05), Vector3(0.0, 0.28, 0.285), _m_gear)
	_box(_torso, Vector3(0.07, 0.16, 0.05), Vector3(-0.12, 0.47, 0.17), _m_weapon)
	_cylinder(_torso, 0.006, 0.38, Vector3(-0.12, 0.72, 0.17), _m_weapon)


func _build_head() -> void:
	_head = _pivot(_torso, Vector3(0.0, 0.57, 0.0), "Head")
	_cylinder(_head, 0.06, 0.10, Vector3(0.0, 0.03, 0.0), _m_gear)
	# Tête sous cagoule, bande des yeux.
	var head := _sphere(_head, 0.112, Vector3(0.0, 0.17, 0.0), _m_gear)
	head.scale = Vector3(1.0, 1.12, 1.05)
	_box(_head, Vector3(0.15, 0.04, 0.03), Vector3(0.0, 0.185, -0.105), _m_skin)
	# Casque balistique « high cut ».
	var dome := SphereMesh.new()
	dome.radius = 0.138
	dome.height = 0.138
	dome.is_hemisphere = true
	var helmet := _mesh(_head, dome, Vector3(0.0, 0.195, 0.005), _m_uniform)
	helmet.scale = Vector3(1.0, 1.0, 1.12)
	_box(_head, Vector3(0.27, 0.035, 0.30), Vector3(0.0, 0.20, 0.005), _m_uniform)
	for side: float in [-1.0, 1.0]:
		# Rails latéraux et coques du casque radio.
		_box(_head, Vector3(0.015, 0.03, 0.13), Vector3(0.137 * side, 0.225, 0.0), _m_weapon)
		_box(_head, Vector3(0.04, 0.09, 0.075), Vector3(0.125 * side, 0.15, 0.01), _m_gear)
		# Tubes des jumelles de vision nocturne, relevées.
		var tube := _cylinder(_head, 0.022, 0.10, Vector3(0.032 * side, 0.335, -0.135), _m_weapon)
		tube.rotation.x = deg_to_rad(-65.0)
		var lens := _cylinder(_head, 0.018, 0.012, Vector3(0.032 * side, 0.358, -0.183), _m_lens)
		lens.rotation.x = deg_to_rad(-65.0)
	# Support JVN, micro, marqueur d'identification.
	_box(_head, Vector3(0.05, 0.05, 0.035), Vector3(0.0, 0.285, -0.14), _m_weapon)
	_box(_head, Vector3(0.012, 0.012, 0.10), Vector3(-0.115, 0.115, -0.06), _m_weapon)
	_box(_head, Vector3(0.05, 0.012, 0.05), Vector3(0.0, 0.337, 0.06), _m_team)


func _build_rifle_and_arms() -> void:
	var rifle := _pivot(_torso, Vector3(0.07, 0.31, -0.24), "Rifle")
	rifle.rotation = Vector3(deg_to_rad(-22.0), deg_to_rad(16.0), 0.0)
	_rifle = rifle
	_rifle_hold = rifle.transform
	# En bandoulière : en travers de la poitrine, canon vers le bas.
	_rifle_slung = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-70.0), deg_to_rad(35.0), deg_to_rad(20.0))), Vector3(0.02, 0.27, -0.2))
	_box(rifle, Vector3(0.045, 0.08, 0.30), Vector3(0.0, 0.04, -0.05), _m_weapon)      # boîtier
	_box(rifle, Vector3(0.04, 0.065, 0.20), Vector3(0.0, 0.035, 0.19), _m_weapon)     # crosse
	_box(rifle, Vector3(0.045, 0.10, 0.03), Vector3(0.0, 0.02, 0.30), _m_gear)        # plaque de couche
	var grip := _box(rifle, Vector3(0.035, 0.10, 0.045), Vector3(0.0, -0.045, 0.04), _m_weapon)
	grip.rotation.x = deg_to_rad(18.0)
	var mag := _box(rifle, Vector3(0.03, 0.17, 0.06), Vector3(0.0, -0.08, -0.09), _m_weapon)
	mag.rotation.x = deg_to_rad(-12.0)
	_box(rifle, Vector3(0.05, 0.06, 0.27), Vector3(0.0, 0.045, -0.335), _m_gear)      # garde-main
	_box(rifle, Vector3(0.025, 0.07, 0.035), Vector3(0.0, -0.01, -0.36), _m_weapon)   # poignée avant
	var barrel := _cylinder(rifle, 0.012, 0.12, Vector3(0.0, 0.045, -0.52), _m_weapon)
	barrel.rotation.x = PI / 2.0
	var suppressor := _cylinder(rifle, 0.023, 0.19, Vector3(0.0, 0.045, -0.65), _m_weapon)
	suppressor.rotation.x = PI / 2.0
	# Viseur point rouge et lampe.
	_box(rifle, Vector3(0.04, 0.05, 0.08), Vector3(0.0, 0.115, -0.05), _m_weapon)
	_box(rifle, Vector3(0.03, 0.03, 0.005), Vector3(0.0, 0.118, -0.092), _m_lens)
	_box(rifle, Vector3(0.03, 0.03, 0.09), Vector3(0.042, 0.05, -0.40), _m_weapon)

	_build_arm(-1.0)
	_build_arm(1.0)
	# Poses des bras, résolues par IK deux os à partir de la position des mains
	# (repère du torse) : [main gauche, main droite].
	_arm_poses.resize(ArmPose.size())
	_arm_poses[ArmPose.RIFLE] = _solve_arms(rifle.transform * Vector3(0.0, -0.02, -0.33), rifle.transform * Vector3(0.0, -0.05, 0.05))
	_arm_poses[ArmPose.REACH] = _solve_arms(Vector3(-0.2, 0.5, -0.42), Vector3(0.2, 0.5, -0.42))
	_arm_poses[ArmPose.PUSH] = _solve_arms(Vector3(-0.22, 0.05, -0.25), Vector3(0.22, 0.05, -0.25))
	# Main gauche qui saisit la cible, main droite qui frappe vers l'avant.
	_arm_poses[ArmPose.STRIKE] = _solve_arms(Vector3(-0.1, 0.42, -0.38), Vector3(0.08, 0.45, -0.56))
	for i in _arm_joints.size():
		_arm_joints[i].quaternion = _arm_poses[ArmPose.RIFLE][i]


func _shoulder_position(side: float) -> Vector3:
	return Vector3(0.245 * side, 0.50, 0.0)


## Bras articulé : pivot d'épaule → bras → pivot de coude → avant-bras et main.
## Au repos (rotations nulles), le bras pend vers le bas.
func _build_arm(side: float) -> void:
	var shoulder := _pivot(_torso, _shoulder_position(side), "ShoulderL" if side < 0.0 else "ShoulderR")
	_sphere(shoulder, 0.078, Vector3.ZERO, _m_uniform)
	_box(shoulder, Vector3(0.115, UPPER_ARM_LENGTH, 0.125), Vector3(0.0, -UPPER_ARM_LENGTH * 0.5, 0.0), _m_uniform)
	# Écusson d'équipe sur l'épaule.
	_box(shoulder, Vector3(0.012, 0.075, 0.075), Vector3(0.064 * side, -0.09, 0.0), _m_team)
	var elbow := _pivot(shoulder, Vector3(0.0, -UPPER_ARM_LENGTH, 0.0), "Elbow")
	_sphere(elbow, 0.062, Vector3.ZERO, _m_gear)
	_box(elbow, Vector3(0.095, FOREARM_LENGTH, 0.105), Vector3(0.0, -FOREARM_LENGTH * 0.5, 0.0), _m_uniform)
	_sphere(elbow, 0.058, Vector3(0.0, -FOREARM_LENGTH, 0.0), _m_gear)
	_arm_joints.append(shoulder)
	_arm_joints.append(elbow)
	if side > 0.0:
		# Couteau de combat dans la main droite, sorti seulement pour frapper.
		_knife = _pivot(elbow, Vector3(0.0, -FOREARM_LENGTH - 0.03, 0.0), "Knife")
		_box(_knife, Vector3(0.028, 0.09, 0.032), Vector3.ZERO, _m_gear)
		_box(_knife, Vector3(0.012, 0.19, 0.03), Vector3(0.0, -0.13, 0.0), _m_steel)
		_knife.visible = false


## Rotations [épaule gauche, coude gauche, épaule droite, coude droit] qui
## amènent les mains aux positions données (repère du torse).
func _solve_arms(left_hand: Vector3, right_hand: Vector3) -> Array:
	var pose: Array = []
	for side: float in [-1.0, 1.0]:
		var shoulder := _shoulder_position(side)
		var to_hand := (left_hand if side < 0.0 else right_hand) - shoulder
		var reach := minf(to_hand.length(), UPPER_ARM_LENGTH + FOREARM_LENGTH - 0.01)
		var dir := to_hand.normalized()
		var hand := shoulder + dir * reach
		var along := (UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - FOREARM_LENGTH * FOREARM_LENGTH + reach * reach) / (2.0 * reach)
		var height := sqrt(maxf(UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - along * along, 0.0))
		var pole := Vector3(0.7 * side, -1.0, 0.2)
		pole = (pole - dir * pole.dot(dir)).normalized()
		var elbow := shoulder + dir * along + pole * height
		var upper := _basis_pointing_down(elbow - shoulder)
		var lower := _basis_pointing_down(hand - elbow)
		pose.append(upper.get_rotation_quaternion())
		pose.append((upper.inverse() * lower).get_rotation_quaternion())
	return pose


## Base orthonormée dont l'axe -Y suit `direction`.
func _basis_pointing_down(direction: Vector3) -> Basis:
	var y := -direction.normalized()
	var x := y.cross(Vector3.BACK)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, y, x.cross(y))


# --- Primitives -------------------------------------------------------------

func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _pivot(parent: Node3D, at: Vector3, node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = at
	parent.add_child(node)
	return node


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, at, material)


func _sphere(parent: Node3D, radius: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _mesh(parent, mesh, at, material)


func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return _mesh(parent, mesh, at, material)
