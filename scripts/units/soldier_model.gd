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
## Coup porté au corps à corps sans couteau.
## Défense au corps à corps : parade (avant-bras ou arme levés) ou esquive
## (pas de côté, buste baissé).
enum DefendMove { PARRY, DODGE }
enum StrikeMove { UPPERCUT, FRONT_KICK, ROUNDHOUSE, SIDE_KICK, BUTT_STRIKE, CHOKE, THROAT_CUT }
enum ArmPose { RIFLE, REACH, PUSH, STRIKE, LIMP, LIMP_PRONE, FREE }

# Images clés de l'escalade, par paires (instant 0..1, valeur), calculées pour
# une caisse de 1,2 m sans que les membres ne traversent la caisse ni le sol
# (cf. DECISIONS.md). Montée : accroupi, mains sur le rebord, traction, pied
# droit posé sur le dessus, jambe gauche ramenée, redressement.
const CLIMB_UP_HIPS: Array[float] = [0, 0.92, 0.12, 0.85, 0.26, 0.95, 0.45, 0.801, 0.54, 0.95, 0.62, 0.95, 0.72, 0.95, 0.84, 0.793, 1, 0.92]
const CLIMB_UP_THIGH_L: Array[float] = [0, 0, 0.12, 0.3, 0.26, 0.285, 0.45, 0.271, 0.54, 0.283, 0.62, 0.298, 0.72, 0.419, 0.84, 0.6, 1, 0]
const CLIMB_UP_KNEE_L: Array[float] = [0, 0, 0.12, -0.788, 0.26, -0.869, 0.45, -0.954, 0.54, -1.032, 0.62, -1.107, 0.72, -1.157, 0.84, -1.2, 1, 0]
const CLIMB_UP_THIGH_R: Array[float] = [0, 0, 0.12, 0.3, 0.26, 0.227, 0.45, 0.156, 0.54, 0.723, 0.62, 1.325, 0.72, 0.962, 0.84, 0.6, 1, 0]
const CLIMB_UP_KNEE_R: Array[float] = [0, 0, 0.12, -0.793, 0.26, -1.238, 0.45, -1.678, 0.54, -1.987, 0.62, -1.663, 0.72, -1.431, 0.84, -1.2, 1, 0]
const CLIMB_UP_LEAN: Array[float] = [0, 0, 0.12, -0.181, 0.26, -0.375, 0.45, -0.612, 0.54, -1.1, 0.62, -0.831, 0.72, -0.556, 0.84, -0.277, 1, 0]
const CLIMB_UP_SLING: Array[float] = [0.0, 0.0, 0.14, 1.0, 0.82, 1.0, 1.0, 0.0]
const CLIMB_UP_ARMS: Array[float] = [0.0, ArmPose.RIFLE, 0.2, ArmPose.REACH, 0.45, ArmPose.PUSH, 0.72, ArmPose.PUSH, 0.96, ArmPose.RIFLE]
# Descente (face au vide) : accroupi au bord, saut vers l'avant, réception
# accroupie, redressement.
const CLIMB_DOWN_HIPS: Array[float] = [0, 0.92, 0.25, 0.75, 0.35, 0.762, 0.45, 0.772, 0.6, 0.787, 0.74, 0.8, 1, 0.92]
const CLIMB_DOWN_THIGH: Array[float] = [0, 0, 0.25, 0.6, 0.35, 0.684, 0.45, 0.718, 0.6, 0.756, 0.74, 0.791, 1, 0]
const CLIMB_DOWN_KNEE: Array[float] = [0, 0, 0.25, -1.394, 0.35, -1.271, 0.45, -1.15, 0.6, -1.025, 0.74, -0.9, 1, 0]
const CLIMB_DOWN_LEAN: Array[float] = [0, 0, 0.25, -0.3, 0.35, -0.247, 0.45, -0.188, 0.6, -0.131, 0.74, -0.069, 1, 0]
const CLIMB_DOWN_SLING: Array[float] = [0.0, 0.0, 0.15, 1.0, 0.75, 1.0, 1.0, 0.0]
const CLIMB_DOWN_ARMS: Array[float] = [0.0, ArmPose.RIFLE, 0.22, ArmPose.PUSH, 0.5, ArmPose.REACH, 0.82, ArmPose.RIFLE]

# Mort (instants en secondes) : les genoux cèdent, le corps bascule en arrière,
# puis les jambes se relâchent.
const DEATH_HIPS: Array[float] = [0.0, 0.92, 0.3, 0.6, 0.75, 0.6, 1.1, 0.92]
const DEATH_THIGH_L: Array[float] = [0.0, 0.0, 0.3, 0.75, 0.75, 0.7, 1.1, 0.5]
const DEATH_KNEE_L: Array[float] = [0.0, 0.0, 0.3, -1.4, 0.75, -1.2, 1.1, -1.0]
const DEATH_THIGH_R: Array[float] = [0.0, 0.0, 0.3, 0.6, 0.75, 0.4, 1.1, 0.05]
const DEATH_KNEE_R: Array[float] = [0.0, 0.0, 0.3, -1.2, 0.75, -0.6, 1.1, -0.1]
const DEATH_LEAN: Array[float] = [0.0, 0.0, 0.3, -0.35, 0.75, 0.15, 1.1, 0.0]
const DEATH_PITCH: Array[float] = [0.0, 0.0, 0.3, 0.05, 0.8, PI / 2.0, 1.1, PI / 2.0]
const DEATH_POS_Y: Array[float] = [0.0, 0.0, 0.3, 0.0, 0.8, 0.24, 1.1, 0.24]
const DEATH_POS_Z: Array[float] = [0.0, 0.0, 0.3, 0.0, 0.8, -0.5, 1.1, -0.9]
const DEATH_HEAD: Array[float] = [0.0, 0.0, 0.3, 0.4, 0.8, -0.3, 1.1, -0.1]

# Rechargement (instants 0..1) : chemin de la main gauche entre la poignée
# avant, le puits de chargeur, le bas (chargeur vide lâché), la poche de
# gilet et retour ; bascule de l'arme pendant l'opération.
const RELOAD_HAND_TIMES: Array[float] = [0.0, 0.15, 0.27, 0.48, 0.65, 0.74, 1.0]
const RELOAD_TILT: Array[float] = [0.0, 0.0, 0.12, 1.0, 0.85, 1.0, 1.0, 0.0]
const RELOAD_MAG_OUT := 0.2
const RELOAD_MAG_DROP := 0.3
const RELOAD_MAG_TAKEN := 0.46
const RELOAD_MAG_IN := 0.72

## Prises des mains sur l'arme (repère de l'arme).
const LEFT_GRIP := Vector3(0.0, -0.02, -0.33)
const LEFT_GRIP_PRONE := Vector3(0.0, -0.06, -0.12)
const RIGHT_GRIP := Vector3(0.0, -0.05, 0.05)
const MAG_WELL := Vector3(0.0, -0.17, -0.1)
const MAG_DROP := Vector3(0.0, -0.32, -0.08)
const MAG_BELOW := Vector3(0.0, -0.28, -0.12)
## Poche à chargeurs gauche du gilet (repère du torse).
const MAG_POUCH := Vector3(-0.105, 0.36, -0.22)

## Visée épaulée : le buste pivote (épaule gauche en avant), l'arme et la tête
## compensent pour rester dans l'axe.
const AIM_TWIST := -0.4
## Direction des coudes par défaut (repère du torse, x vers l'extérieur).
const ARM_POLE := Vector3(0.7, -1.0, 0.2)
## Rampé : bassin au ras du sol, buste relevé sur les coudes.
const PRONE_BODY_POS := Vector3(0.0, 0.18, 0.9)
const PRONE_CHEST := 0.2
const PRONE_HEAD := 1.2
## Reptation : avance du cycle (rad) par unité de `move_ratio` et par seconde,
## soit environ 0,8 m par cycle complet (un appui de chaque côté).
const CRAWL_PHASE_RATE := 24.0
## Direction des coudes au sol (repère du torse, x vers l'extérieur).
const PRONE_ELBOW_POLE := Vector3(0.8, -0.4, -0.8)
const FLASH_DURATION := 0.05
const RECOIL_DECAY := 0.07
const HIT_DURATION := 0.4
## Durée pendant laquelle l'arme reste épaulée après un tir.
const AIM_HOLD := 1.5

# Changements de posture vers ou depuis la position couchée. Poses clés :
# [inclinaison du corps, hauteur du bassin, avance du bassin (-Z = avant),
#  cuisse G, cuisse D, genou G, genou D, buste, tête, écart des jambes,
#  main gauche au sol (0 à 1), arme en position couchée (0 à 1)].
const POSE_STAND: Array[float] = [0.0, 0.92, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const POSE_KNEEL: Array[float] = [0.0, 0.52, 0.0, 1.45, -0.1, -1.45, -1.47, -0.12, 0.12, 0.0, 0.0, 0.0]
const POSE_KNEES: Array[float] = [0.0, 0.52, 0.0, -0.05, -0.05, -1.5, -1.5, -0.45, 0.35, 0.05, 0.3, 0.3]
const POSE_ALL_FOURS: Array[float] = [-1.2, 0.5, 0.0, 1.2, 1.2, -1.5, -1.5, -0.15, 1.1, 0.08, 1.0, 1.0]
const POSE_PRONE: Array[float] = [-PI / 2.0, 0.18, -0.02, 0.0, 0.0, 0.0, 0.0, 0.2, 1.2, 0.12, 0.0, 1.0]
## Durées (s) : se coucher depuis debout / accroupi, se relever debout / accroupi.
const GO_PRONE_TIME := 1.1
const GO_PRONE_FROM_CROUCH_TIME := 0.9
const GET_UP_TIME := 1.1
const GET_UP_TO_CROUCH_TIME := 0.8

# Uppercut (assommer, instants 0..1 de la frappe) : armé (genoux fléchis,
# buste tourné à droite, poing droit à la hanche, main gauche qui saisit),
# impact (jambes et hanches qui se détendent, poing qui remonte en arc sous
# le menton), accompagnement vers le haut, retour.
const UPPERCUT_TIMES: Array[float] = [0.0, 0.3, 0.45, 0.6, 1.0]
const UPPERCUT_DIP: Array[float] = [0.0, 0.0, 0.3, 0.09, 0.45, 0.0, 0.6, 0.0, 1.0, 0.0]
const UPPERCUT_TWIST: Array[float] = [0.0, 0.0, 0.3, -0.4, 0.45, 0.25, 0.6, 0.3, 1.0, 0.0]
const UPPERCUT_LEAN: Array[float] = [0.0, 0.0, 0.3, -0.25, 0.45, -0.1, 0.6, 0.0, 1.0, 0.0]
## Fente vers la cible (m, -Z = avant) pour que le poing l'atteigne.
const UPPERCUT_LUNGE: Array[float] = [0.0, 0.0, 0.3, -0.1, 0.45, -0.38, 0.6, -0.38, 1.0, 0.0]
## Positions des poings (repère du torse) aux instants `UPPERCUT_TIMES`
## (la première est remplacée par la pose de départ).
const UPPERCUT_RIGHT: Array[Vector3] = [Vector3.ZERO, Vector3(0.24, 0.16, -0.06), Vector3(0.04, 0.6, -0.5), Vector3(0.02, 0.76, -0.36), Vector3.ZERO]
const UPPERCUT_LEFT: Array[Vector3] = [Vector3.ZERO, Vector3(-0.1, 0.5, -0.42), Vector3(-0.2, 0.5, -0.2), Vector3(-0.2, 0.52, -0.22), Vector3.ZERO]

# Coups de pied (jambe droite), instants 0..1 de la frappe : armé à 0,3,
# impact à 0,45, retour de jambe à 0,6, garde à 1. Pistes : rotation du
# bassin (vers la gauche), flexion de la jambe d'appui (m), buste (+ = en
# arrière), inclinaison latérale du buste, rotation du buste (compense le
# bassin), fente (m, - = en avant), cuisse droite (flexion, écart), genou
# droit, cheville droite.
const KICKS := {
	StrikeMove.FRONT_KICK: {
		"hip_yaw": [0.0, 0.0, 0.3, 0.15, 0.45, 0.2, 0.6, 0.15, 1.0, 0.0],
		"dip": [0.0, 0.0, 0.3, 0.04, 0.45, 0.03, 0.6, 0.04, 1.0, 0.0],
		"lean": [0.0, 0.0, 0.3, 0.12, 0.45, 0.3, 0.6, 0.15, 1.0, 0.0],
		"side_lean": [0.0, 0.0, 1.0, 0.0],
		"torso_yaw": [0.0, 0.0, 0.3, -0.15, 0.45, -0.2, 0.6, -0.15, 1.0, 0.0],
		"lunge": [0.0, 0.0, 0.3, -0.05, 0.45, -0.22, 0.6, -0.18, 1.0, 0.0],
		"thigh_x": [0.0, 0.0, 0.3, 1.6, 0.45, 1.35, 0.6, 1.5, 1.0, 0.0],
		"thigh_z": [0.0, 0.0, 1.0, 0.0],
		"knee": [0.0, 0.0, 0.3, -2.1, 0.45, -0.05, 0.6, -1.9, 1.0, 0.0],
		"ankle": [0.0, 0.0, 0.3, 0.3, 0.45, 0.9, 0.6, 0.3, 1.0, 0.0],
	},
	StrikeMove.ROUNDHOUSE: {
		"hip_yaw": [0.0, 0.0, 0.3, 0.6, 0.45, 1.3, 0.6, 1.1, 1.0, 0.0],
		"dip": [0.0, 0.0, 0.3, 0.05, 0.45, 0.03, 0.6, 0.04, 1.0, 0.0],
		"lean": [0.0, 0.0, 0.3, 0.1, 0.45, 0.15, 0.6, 0.1, 1.0, 0.0],
		"side_lean": [0.0, 0.0, 0.3, 0.25, 0.45, 0.5, 0.6, 0.4, 1.0, 0.0],
		"torso_yaw": [0.0, 0.0, 0.3, -0.3, 0.45, -0.8, 0.6, -0.7, 1.0, 0.0],
		"lunge": [0.0, 0.0, 0.3, -0.05, 0.45, -0.2, 0.6, -0.15, 1.0, 0.0],
		"thigh_x": [0.0, 0.0, 0.3, 0.9, 0.45, 0.3, 0.6, 0.5, 1.0, 0.0],
		"thigh_z": [0.0, 0.0, 0.3, 1.1, 0.45, 1.85, 0.6, 1.5, 1.0, 0.0],
		"knee": [0.0, 0.0, 0.3, -2.0, 0.45, -0.1, 0.6, -1.6, 1.0, 0.0],
		"ankle": [0.0, 0.0, 0.3, -0.5, 0.45, -0.9, 0.6, -0.5, 1.0, 0.0],
	},
	StrikeMove.SIDE_KICK: {
		"hip_yaw": [0.0, 0.0, 0.3, 1.35, 0.45, 1.45, 0.6, 1.4, 1.0, 0.0],
		"dip": [0.0, 0.0, 0.3, 0.05, 0.45, 0.03, 0.6, 0.04, 1.0, 0.0],
		"lean": [0.0, 0.0, 0.3, 0.05, 0.45, 0.1, 0.6, 0.05, 1.0, 0.0],
		"side_lean": [0.0, 0.0, 0.3, 0.3, 0.45, 0.75, 0.6, 0.5, 1.0, 0.0],
		"torso_yaw": [0.0, 0.0, 0.3, -0.9, 0.45, -1.0, 0.6, -1.0, 1.0, 0.0],
		"lunge": [0.0, 0.0, 0.3, -0.05, 0.45, -0.25, 0.6, -0.2, 1.0, 0.0],
		"thigh_x": [0.0, 0.0, 0.3, 1.5, 0.45, 0.15, 0.6, 1.2, 1.0, 0.0],
		"thigh_z": [0.0, 0.0, 0.3, 0.3, 0.45, 1.55, 0.6, 0.6, 1.0, 0.0],
		"knee": [0.0, 0.0, 0.3, -2.2, 0.45, -0.05, 0.6, -2.0, 1.0, 0.0],
		"ankle": [0.0, 0.0, 0.3, 0.5, 0.45, 1.0, 0.6, 0.5, 1.0, 0.0],
	},
}
# Coup de crosse (arme en main) : l'arme recule sur la hanche droite, crosse
# en avant, puis la crosse est projetée vers le visage avec rotation du buste
# et fente. Instants 0..1 de la frappe.
const BUTT_TIMES: Array[float] = [0.0, 0.3, 0.45, 0.6, 1.0]
const BUTT_DIP: Array[float] = [0.0, 0.0, 0.3, 0.06, 0.45, 0.02, 0.6, 0.02, 1.0, 0.0]
const BUTT_TWIST: Array[float] = [0.0, 0.0, 0.3, -0.45, 0.45, 0.3, 0.6, 0.3, 1.0, 0.0]
const BUTT_LEAN: Array[float] = [0.0, 0.0, 0.3, 0.05, 0.45, -0.15, 0.6, -0.1, 1.0, 0.0]
const BUTT_LUNGE: Array[float] = [0.0, 0.0, 0.3, 0.0, 0.45, -0.5, 0.6, -0.45, 1.0, 0.0]

# Prises par derrière, la victime à `GRAB_DISTANCE` devant l'opérateur.
# Étranglement : bras droit autour du cou, main gauche derrière la tête,
# buste tiré en arrière ; à la fin, il accompagne le corps vers le sol.
const CHOKE_TIMES: Array[float] = [0.0, 0.08, 0.8, 0.92, 1.0]
const CHOKE_RIGHT: Array[Vector3] = [Vector3.ZERO, Vector3(-0.12, 0.52, -0.42), Vector3(-0.12, 0.5, -0.42), Vector3(-0.1, 0.25, -0.42), Vector3.ZERO]
const CHOKE_LEFT: Array[Vector3] = [Vector3.ZERO, Vector3(0.0, 0.68, -0.34), Vector3(0.0, 0.66, -0.34), Vector3(0.08, 0.3, -0.4), Vector3.ZERO]
const CHOKE_LEAN: Array[float] = [0.0, 0.0, 0.08, 0.12, 0.8, 0.2, 0.92, -0.35, 1.0, 0.0]
const CHOKE_DIP: Array[float] = [0.0, 0.0, 0.08, 0.04, 0.8, 0.08, 0.92, 0.28, 1.0, 0.0]
# Égorgement : main gauche sur la bouche, lame de droite à gauche sous le menton.
const CUT_TIMES: Array[float] = [0.0, 0.2, 0.45, 0.62, 1.0]
const CUT_RIGHT: Array[Vector3] = [Vector3.ZERO, Vector3(0.28, 0.5, -0.4), Vector3(0.22, 0.54, -0.44), Vector3(-0.22, 0.5, -0.44), Vector3.ZERO]
const CUT_LEFT: Array[Vector3] = [Vector3.ZERO, Vector3(-0.04, 0.62, -0.48), Vector3(-0.04, 0.62, -0.46), Vector3(-0.02, 0.6, -0.44), Vector3.ZERO]
const CUT_LEAN: Array[float] = [0.0, 0.0, 0.2, 0.1, 0.45, 0.15, 0.62, 0.1, 1.0, 0.0]
const CUT_DIP: Array[float] = [0.0, 0.0, 0.2, 0.03, 0.62, 0.05, 1.0, 0.0]
## Distance entre l'opérateur et la victime d'une prise par derrière (m).
const GRAB_DISTANCE := 0.45
## Poussée d'un ennemi qui repousse l'opérateur (instants de 0 à 1) :
## arme ou mains ramenées contre la poitrine, puis projetées en avant.
const SHOVE_TIMES: Array[float] = [0.0, 0.3, 0.5, 1.0]
const SHOVE_LEFT: Array[Vector3] = [Vector3.ZERO, Vector3(-0.18, 0.48, -0.22), Vector3(-0.18, 0.52, -0.58), Vector3.ZERO]
const SHOVE_RIGHT: Array[Vector3] = [Vector3.ZERO, Vector3(0.18, 0.48, -0.22), Vector3(0.18, 0.52, -0.58), Vector3.ZERO]
const SHOVE_LEAN: Array[float] = [0.0, 0.0, 0.3, 0.08, 0.5, -0.3, 1.0, 0.0]
const SHOVE_LUNGE: Array[float] = [0.0, 0.0, 0.3, 0.05, 0.5, -0.35, 1.0, 0.0]
## Lancer de couteau (instants de 0 à 1) : main droite armée derrière la
## tête, bras gauche tendu vers la cible, lâcher, puis accompagnement.
const THROW_TIMES: Array[float] = [0.0, 0.35, 0.55, 0.75, 1.0]
const THROW_RELEASE := 0.55
const THROW_RIGHT: Array[Vector3] = [Vector3.ZERO, Vector3(0.26, 0.74, 0.1), Vector3(0.14, 0.66, -0.46), Vector3(0.02, 0.36, -0.38), Vector3.ZERO]
const THROW_LEFT: Array[Vector3] = [Vector3.ZERO, Vector3(-0.1, 0.56, -0.44), Vector3(-0.2, 0.44, -0.2), Vector3(-0.24, 0.34, -0.08), Vector3.ZERO]
const THROW_LEAN: Array[float] = [0.0, 0.0, 0.35, 0.12, 0.55, -0.2, 0.75, -0.25, 1.0, 0.0]
const THROW_TWIST: Array[float] = [0.0, 0.0, 0.35, -0.45, 0.55, 0.25, 0.75, 0.3, 1.0, 0.0]
const THROW_LUNGE: Array[float] = [0.0, 0.0, 0.35, 0.05, 0.55, -0.15, 0.75, -0.18, 1.0, 0.0]
## Mains sur une caisse (repère du modèle, main droite ; la gauche est
## symétrique) : à plat sur le flanc pour pousser, agrippées au rebord
## supérieur pour tirer. L'unité se tient à `CRATE_GRIP_GAP` du flanc.
const CRATE_PUSH_HAND := Vector3(0.2, 1.02, -0.42)
const CRATE_PULL_HAND := Vector3(0.22, 1.16, -0.42)
const CRATE_GRIP_GAP := 0.4
## Parade à mains nues : avant-bras croisés devant le visage.
const PARRY_LEFT := Vector3(-0.06, 0.74, -0.3)
const PARRY_RIGHT := Vector3(0.1, 0.7, -0.27)
## Ennemi déséquilibré : bras écartés pour se rattraper.
const STAGGER_LEFT := Vector3(-0.36, 0.3, -0.12)
const STAGGER_RIGHT := Vector3(0.36, 0.3, -0.12)

# Chute vers l'avant (attaqué par derrière) : à genoux, puis face contre terre.
const DEATH_FWD_HIPS: Array[float] = [0.0, 0.92, 0.35, 0.55, 0.8, 0.7, 1.1, 0.92]
const DEATH_FWD_THIGH: Array[float] = [0.0, 0.0, 0.35, -0.05, 0.8, 0.3, 1.1, 0.1]
const DEATH_FWD_KNEE: Array[float] = [0.0, 0.0, 0.35, -1.5, 0.8, -0.8, 1.1, -0.2]
const DEATH_FWD_LEAN: Array[float] = [0.0, 0.0, 0.35, -0.3, 0.8, 0.0, 1.1, 0.0]
const DEATH_FWD_PITCH: Array[float] = [0.0, 0.0, 0.35, 0.0, 0.85, -PI / 2.0, 1.1, -PI / 2.0]
const DEATH_FWD_POS_Y: Array[float] = [0.0, 0.0, 0.35, 0.0, 0.85, 0.15, 1.1, 0.15]
const DEATH_FWD_POS_Z: Array[float] = [0.0, 0.0, 0.35, 0.0, 0.85, 0.6, 1.1, 0.9]

## Garde des poings pendant un coup de pied (repère du torse).
const GUARD_LEFT := Vector3(-0.12, 0.62, -0.28)
const GUARD_RIGHT := Vector3(0.14, 0.58, -0.22)

## Durée (s) pour passer l'arme à la bretelle, ou pour la reprendre en main.
const SLING_TIME := 0.7
## Mains libres, arme à la bretelle (repère du torse).
const FREE_HAND := Vector3(0.27, 0.08, -0.12)

const HIP_HEIGHT := 0.92
const THIGH_LENGTH := 0.44
const UPPER_ARM_LENGTH := 0.29
const FOREARM_LENGTH := 0.29
const SHIN_LENGTH := 0.40
## Débattement de la cheville (rad) : négatif = pointe vers le bas.
const ANKLE_MIN := -0.9
const ANKLE_MAX := 1.0

@export var uniform_color := Color(0.30, 0.33, 0.24)
@export var gear_color := Color(0.16, 0.17, 0.14)
@export var boot_color := Color(0.12, 0.10, 0.08)
@export var weapon_color := Color(0.07, 0.07, 0.08)
@export var skin_color := Color(0.80, 0.62, 0.50)
## Couleur d'identification de l'équipe (écussons d'épaule, marqueur de casque).
@export var team_color := Color(0.15, 0.45, 0.95)
## Casque d'opérateur (balistique, rails, protection auditive) ; sinon,
## casque simple des soldats ennemis.
@export var operator_helmet := true
@export var helmet_color := Color(0.25, 0.27, 0.2)

## Posture affichée. Se coucher et se relever sont animés (voir
## `is_changing_posture`) ; entre debout et accroupi, la pose est interpolée.
var posture: Posture = Posture.STANDING:
	set(value):
		if value == posture:
			return
		if (value == Posture.PRONE or posture == Posture.PRONE) and _body != null and not is_dead and climb_progress < 0.0:
			_start_transition(posture, value)
		posture = value
## 0 = immobile, 1 = marche, 2 = course.
var move_ratio: float = 0.0
## Unité morte (ou inconsciente) : elle s'effondre puis reste étendue.
var is_dead: bool = false:
	set(value):
		if value and not is_dead:
			_death_time = 0.0
			_death_prone = posture == Posture.PRONE
			_death_forward = death_forward and not _death_prone
			death_forward = false
			_death_twist = randf_range(-0.4, 0.4)
		is_dead = value
## À régler avant `is_dead` : la chute se fait vers l'avant (face contre terre).
var death_forward: bool = false
## Saisi par derrière : il se débat, mains à la gorge, et faiblit.
var grabbed: bool = false:
	set(value):
		if value and not grabbed:
			_grab_time = 0.0
		grabbed = value
## Vrai quand l'unité vise une cible : arme épaulée.
var aiming: bool = false
## Vrai pour passer l'arme à la bretelle (mains libres pour grimper, frapper…),
## faux pour la reprendre en main. Le geste prend `SLING_TIME`.
var weapon_slung: bool = false
## Avancement du rechargement (0 à 1) ; négatif hors rechargement.
var reload_progress: float = -1.0
## Avancement de l'animation d'escalade (0 à 1), piloté par l'unité ;
## négatif quand aucune escalade n'est en cours.
var climb_progress: float = -1.0
## Vrai pour l'animation de descente, faux pour la montée.
var climb_descending: bool = false
## Vrai si le modèle porte sa carabine ; sans arme, les bras pendent le long du corps.
var is_armed: bool = true
## Avancement d'une attaque au corps à corps (0 à 1) ; négatif hors attaque.
var strike_progress: float = -1.0
## Vrai si l'attaque se fait au couteau (lame visible), faux pour un coup de poing.
var strike_with_knife: bool = false
## Coup porté quand la frappe se fait sans couteau. Les coups de pied ne se
## donnent que debout ; dans une autre posture, c'est un uppercut.
var strike_move: StrikeMove = StrikeMove.UPPERCUT
## Mains posées sur une caisse, pour la pousser ou (`crate_pull`) la tirer.
var crate_grip: bool = false
var crate_pull: bool = false
## Avancement (0 à 1) d'un lancer de couteau ; -1 hors lancer.
var throw_progress: float = -1.0
## Avancement (0 à 1) d'une poussée pour repousser un assaillant ; -1 hors poussée.
var shove_progress: float = -1.0
## Avancement (0 à 1) d'une défense (parade ou esquive) ; -1 hors défense.
var defend_progress: float = -1.0
var defend_move: DefendMove = DefendMove.PARRY
## Côté de l'esquive : 1 vers la droite, -1 vers la gauche.
var defend_side: float = 1.0
## Déséquilibré après une attaque parée ou esquivée.
var staggered: bool = false

var _body: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _ankle_l: Node3D
var _ankle_r: Node3D
var _phase: float = 0.0
var _rifle: Node3D
var _rifle_hold: Transform3D
var _rifle_slung: Transform3D
## Étape intermédiaire du geste : canon vers le bas devant la hanche droite.
var _rifle_sling_mid: Transform3D
## Positions de l'arme pendant le coup de crosse (armé, impact, accompagnement).
var _butt_keys: Array[Transform3D] = []
## 0 = arme en main, 1 = arme à la bretelle.
var _sling: float = 0.0
var _rifle_aim: Transform3D
var _rifle_prone: Transform3D
var _rifle_dropped: Transform3D
var _rifle_dropped_prone: Transform3D
## Position lissée de l'arme, avant le recul.
var _rifle_base: Transform3D
var _rifle_mag: Node3D
var _hand_mag: Node3D
var _flash: Node3D
var _knife: Node3D
var _lean: float = 0.0
var _torso_yaw: float = 0.0
var _aim_weight: float = 0.0
var _aim_hold: float = 0.0
var _kneel: float = 0.0
var _crawl: float = 0.0
## Changement de posture en cours : instants (0..1) et poses clés.
var _transition_times: Array[float] = []
var _transition_poses: Array = []
var _transition_time: float = 0.0
var _transition_duration: float = 0.0
var _shot_time: float = 10.0
var _hit_time: float = 10.0
## +1 si l'impact vient de face (le buste part en arrière), -1 de dos.
var _hit_push: float = 1.0
var _hit_side: float = 0.0
var _hit_strength: float = 1.0
var _stagger: float = 0.0
var _grip: float = 0.0
## Positions de l'arme pendant la poussée (contre la poitrine, puis en
## avant) et pendant la parade (horizontale devant le visage).
var _rifle_shove_chamber: Transform3D
var _rifle_shove_push: Transform3D
var _rifle_block: Transform3D
var _death_time: float = 0.0
var _death_prone: bool = false
var _death_twist: float = 0.0
var _death_forward: bool = false
var _grab_time: float = 0.0
var _mag_dropped: bool = false
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
var _m_helmet: StandardMaterial3D


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
	_m_helmet = _mat(helmet_color, 0.75)

	_body = _pivot(self, Vector3.ZERO, "Body")
	_hips = _pivot(_body, Vector3(0.0, HIP_HEIGHT, 0.0), "Hips")
	_build_legs()
	_build_torso()
	_build_head()
	_build_rifle_and_arms()


func _process(delta: float) -> void:
	_time += delta
	_shot_time += delta
	_hit_time += delta
	_aim_hold = maxf(_aim_hold - delta, 0.0)
	_flash.visible = _shot_time < FLASH_DURATION and is_armed and not is_dead
	if climb_progress >= 0.0 and not is_dead:
		_animate_climb(delta)
		return
	if is_dead:
		_transition_duration = 0.0
		_animate_death(delta)
		return
	if is_changing_posture():
		# Une frappe interrompt la transition (l'opérateur se met à genoux).
		if strike_progress < 0.0:
			_animate_transition(delta)
			return
		_transition_duration = 0.0
	_animate_alive(delta)


## Vrai si l'arme est en main, prête à tirer.
func is_weapon_ready() -> bool:
	return is_armed and _sling <= 0.0


## Vrai si les mains sont libres (arme à la bretelle, ou pas d'arme).
func is_weapon_slung() -> bool:
	return not is_armed or _sling >= 1.0


## Position de l'arme pendant le geste (0 = `base`, 1 = à la bretelle) :
## elle bascule canon vers le bas devant la hanche, puis passe sur le flanc.
func _sling_transform(base: Transform3D, amount: float) -> Transform3D:
	if amount <= 0.5:
		return base.interpolate_with(_rifle_sling_mid, smoothstep(0.0, 0.5, amount))
	return _rifle_sling_mid.interpolate_with(_rifle_slung, smoothstep(0.5, 0.8, amount))


## Position d'une main libre (repère du torse), avec balancement à la marche,
## ou en appui au sol quand l'opérateur est couché.
func _free_hand(side: float, prone: bool, s: float, c: float, moving: float, crawl: float) -> Vector3:
	if prone:
		var rest := Vector3(0.25 * side, 0.75, -0.15)
		var planted := Vector3(0.27 * side, 0.88 + 0.15 * s * -side, -0.16 + 0.07 * maxf(c * -side, 0.0))
		return rest.lerp(planted, crawl)
	return Vector3(FREE_HAND.x * side, FREE_HAND.y, FREE_HAND.z + 0.12 * s * moving * -side)


## Vrai pendant qu'il se couche ou se relève : l'unité ne doit ni bouger ni tirer.
func is_changing_posture() -> bool:
	return _transition_duration > 0.0


func _start_transition(from: Posture, to: Posture) -> void:
	_transition_time = 0.0
	_transition_poses = [_current_pose()]
	if to == Posture.PRONE:
		if from == Posture.CROUCHED:
			_transition_duration = GO_PRONE_FROM_CROUCH_TIME
			_transition_times = [0.0, 0.3, 0.65, 1.0]
		else:
			_transition_duration = GO_PRONE_TIME
			_transition_times = [0.0, 0.35, 0.7, 1.0]
		_transition_poses.append_array([POSE_KNEES, POSE_ALL_FOURS, POSE_PRONE])
	elif to == Posture.CROUCHED:
		_transition_duration = GET_UP_TO_CROUCH_TIME
		_transition_times = [0.0, 0.45, 1.0]
		_transition_poses.append_array([POSE_ALL_FOURS, POSE_KNEEL])
		_kneel = 1.0
	else:
		_transition_duration = GET_UP_TIME
		_transition_times = [0.0, 0.35, 0.7, 1.0]
		_transition_poses.append_array([POSE_ALL_FOURS, POSE_KNEEL, POSE_STAND])


## Pose actuelle du modèle, au format des poses clés de transition, pour
## partir de là où il en est (en marche, en pleine transition…).
func _current_pose() -> Array[float]:
	var hips := _body.transform * _hips.position
	var lying := clampf(-_body.rotation.x / (PI / 2.0), 0.0, 1.0)
	return [_body.rotation.x, hips.y, hips.z, _leg_l.rotation.x, _leg_r.rotation.x,
			_knee_l.rotation.x, _knee_r.rotation.x, _lean, _head.rotation.x,
			-_leg_l.rotation.z, 0.0, lying]


## Se coucher : à genoux, main gauche au sol, puis allongé ; se relever :
## l'inverse. Le bassin est placé dans le repère de l'unité, de sorte qu'il ne
## saute pas quand le corps bascule autour des pieds.
func _animate_transition(delta: float) -> void:
	_transition_time += delta
	var t := clampf(_transition_time / _transition_duration, 0.0, 1.0)
	var index := 1
	while index < _transition_times.size() - 1 and t > _transition_times[index]:
		index += 1
	var from_t := _transition_times[index - 1]
	var weight := smoothstep(0.0, 1.0, (t - from_t) / (_transition_times[index] - from_t))
	var from: Array = _transition_poses[index - 1]
	var to: Array = _transition_poses[index]
	var pose: Array[float] = []
	for i in from.size():
		pose.append(lerpf(from[i], to[i], weight))
	var pitch := pose[0]
	_body.rotation = Vector3(pitch, 0.0, 0.0)
	_hips.position.y = HIP_HEIGHT
	_hips.rotation.y = 0.0
	_body.position = Vector3(0.0, pose[1], pose[2]) - Basis(Vector3.RIGHT, pitch) * Vector3(0.0, HIP_HEIGHT, 0.0)
	_leg_l.rotation = Vector3(pose[3], 0.0, -pose[9])
	_leg_r.rotation = Vector3(pose[4], 0.0, pose[9])
	_knee_l.rotation.x = pose[5]
	_knee_r.rotation.x = pose[6]
	# Pieds à plat par rapport au sol, puis pointes tendues une fois allongé.
	var lying := clampf(-pitch / (PI / 2.0), 0.0, 1.0)
	_ankle_l.rotation.x = lerpf(clampf(-(pitch + pose[3] + pose[5]), ANKLE_MIN, ANKLE_MAX), ANKLE_MIN, lying)
	_ankle_r.rotation.x = lerpf(clampf(-(pitch + pose[4] + pose[6]), ANKLE_MIN, ANKLE_MAX), ANKLE_MIN, lying)
	_lean = pose[7]
	_torso_yaw = 0.0
	_torso.rotation = Vector3(_lean, 0.0, 0.0)
	_head.rotation = Vector3(pose[8], 0.0, 0.0)
	_crawl = 0.0
	_aim_weight = 0.0

	# Arme tenue de la main droite ; la main gauche se pose au sol sous l'épaule.
	var rifle_weight := pose[11]
	var rifle_target := _rifle_hold.interpolate_with(_rifle_prone, rifle_weight)
	_rifle_base = _rifle_base.interpolate_with(rifle_target, 1.0 - exp(-14.0 * delta))
	_rifle.transform = _rifle_base
	var shoulder := _arm_joints[0].global_position
	var ground := _torso.to_local(Vector3(shoulder.x, global_position.y + 0.05, shoulder.z) - global_basis.z * 0.05)
	var hand := pose[10]
	var left: Vector3
	var right: Vector3
	if is_armed:
		left = _rifle.transform * LEFT_GRIP.lerp(LEFT_GRIP_PRONE, rifle_weight)
		right = _rifle.transform * RIGHT_GRIP
	else:
		left = _arm_poses_hand(-1.0)
		right = _arm_poses_hand(1.0)
		var right_shoulder := _arm_joints[2].global_position
		right = right.lerp(_torso.to_local(Vector3(right_shoulder.x, global_position.y + 0.05, right_shoulder.z)), hand)
	left = left.lerp(ground, hand)
	var target := _solve_arms(left, right, ARM_POLE.lerp(PRONE_ELBOW_POLE, rifle_weight))
	var arm_blend := 1.0 - exp(-25.0 * delta)
	for i in _arm_joints.size():
		_arm_joints[i].quaternion = _arm_joints[i].quaternion.slerp(target[i], arm_blend)
	_knife.visible = false
	_update_magazines()
	if t >= 1.0:
		_transition_duration = 0.0


## Position de la main quand le bras pend le long du corps (repère du torse).
func _arm_poses_hand(side: float) -> Vector3:
	return Vector3(0.29 * side, 0.0, -0.03)


## Tir : recul de l'arme, flash de bouche, arme épaulée quelques instants.
func play_shot() -> void:
	_shot_time = 0.0
	_aim_hold = AIM_HOLD
	_flash.rotation.z = randf() * TAU
	_flash.scale = Vector3.ONE * randf_range(0.7, 1.2)


## Impact : le buste et la tête encaissent le choc. `from` (position dans le
## monde du tireur) oriente la réaction ; sans elle, le choc vient de face.
## `strength` amplifie la réaction (coup, poussée).
func play_hit(from: Vector3 = Vector3.INF, strength: float = 1.0) -> void:
	_hit_time = 0.0
	_hit_strength = strength
	_hit_push = 1.0
	_hit_side = randf_range(-1.0, 1.0)
	if from != Vector3.INF and is_inside_tree():
		var local := to_local(from)
		_hit_push = 1.0 if local.z < 0.0 else -1.0
		_hit_side = clampf(-local.x, -1.0, 1.0)


func _animate_alive(delta: float) -> void:
	var walk := clampf(move_ratio, 0.0, 2.0)
	var moving := minf(walk, 1.0)
	var prone := posture == Posture.PRONE
	if prone:
		_phase += delta * walk * CRAWL_PHASE_RATE
	else:
		_phase += delta * (5.0 + 3.5 * walk) * moving
	_crawl = move_toward(_crawl, 1.0 if prone and walk > 0.02 else 0.0, delta * 4.0)
	var crawl := smoothstep(0.0, 1.0, _crawl)
	var blend := 1.0 - exp(-10.0 * delta)
	var s := sin(_phase)
	var c := cos(_phase)
	var swing := 0.55 * moving + 0.25 * maxf(walk - 1.0, 0.0)
	_sling = move_toward(_sling, 1.0 if weapon_slung and is_armed else 0.0, delta / SLING_TIME)
	# Attaque au corps à corps : élan vers l'avant, puis retour.
	# Prise par derrière (étranglement, égorgement).
	var grapple := strike_progress >= 0.0 and (strike_move == StrikeMove.CHOKE or strike_move == StrikeMove.THROAT_CUT)
	var strike := 0.0
	if strike_progress >= 0.0 and not grapple:
		strike = sin(PI * clampf(strike_progress, 0.0, 1.0))
	# Sans couteau : coup de crosse (arme en main), uppercut ou coup de pied.
	var unarmed_strike := strike_progress >= 0.0 and not strike_with_knife and not grapple
	var butt := unarmed_strike and strike_move == StrikeMove.BUTT_STRIKE and is_armed
	var kick: Dictionary = {}
	if unarmed_strike and posture == Posture.STANDING:
		kick = KICKS.get(strike_move, {})
	var uppercut := unarmed_strike and kick.is_empty() and not butt
	var throwing := throw_progress >= 0.0 and strike_progress < 0.0
	var throw_t := clampf(throw_progress, 0.0, 1.0)
	var punch_t := clampf(strike_progress, 0.0, 1.0)
	var hip_yaw := 0.0
	var side_lean := 0.0
	var kick_torso_yaw := 0.0
	var reloading := reload_progress >= 0.0 and is_armed
	var wants_aim := is_armed and (aiming or _aim_hold > 0.0) and strike == 0.0 and not grapple and not grabbed and not throwing and not reloading and _sling <= 0.0
	_aim_weight = move_toward(_aim_weight, 1.0 if wants_aim else 0.0, delta * 5.0)
	var aim := 0.0 if prone else smoothstep(0.0, 1.0, _aim_weight)
	var hit := _hit_weight()

	# Cibles selon la posture (x = jambe gauche, y = jambe droite).
	var hips_y := HIP_HEIGHT + absf(s) * 0.03 * moving
	var thigh := Vector2(s * swing, -s * swing)
	var knee := Vector2(-maxf(-c, 0.0) * swing * 1.6, -maxf(c, 0.0) * swing * 1.6)
	var spread := Vector2.ZERO
	var twist := Vector2.ZERO
	var body_yaw := 0.0
	var chest_roll := s * 0.10 * moving
	var chest_turn := 0.0
	var lean := -0.12 * maxf(walk - 1.0, 0.0)
	var body_pitch := 0.0
	var body_pos := Vector3.ZERO
	var head_pitch := 0.0
	_kneel = move_toward(_kneel, 1.0 if posture == Posture.CROUCHED and walk < 0.05 else 0.0, delta * 4.0)
	match posture:
		Posture.CROUCHED:
			# En mouvement : marche accroupie ; à l'arrêt : un genou à terre.
			var k := smoothstep(0.0, 1.0, _kneel)
			var half := swing * 0.5
			var crouch_thigh := Vector2(1.0 + s * half, 1.0 - s * half)
			var crouch_knee := Vector2(-1.9 - maxf(-c, 0.0) * half * 1.6, -1.9 - maxf(c, 0.0) * half * 1.6)
			hips_y = lerpf(0.56 + absf(s) * 0.02 * moving, 0.52, k)
			thigh = crouch_thigh.lerp(Vector2(1.45, -0.1), k)
			knee = crouch_knee.lerp(Vector2(-1.45, -1.47), k)
			lean = lerpf(-0.4, -0.12, k)
			head_pitch = lerpf(0.3, 0.12, k)
		Posture.PRONE:
			# Sur les coudes, jambes écartées. Reptation en diagonale : le
			# coude gauche avance pendant que le genou droit remonte sur le
			# côté (la jambe pivote sur son axe pour rester à plat au sol),
			# puis l'inverse. Épaules et bassin ondulent, le corps avance par
			# poussées et se fait plus bas.
			var up_l := 0.5 * (1.0 - s)
			var up_r := 0.5 * (1.0 + s)
			body_pitch = -PI / 2.0
			body_pos = PRONE_BODY_POS + Vector3(0.0, 0.0, -0.04 * sin(2.0 * _phase) * crawl)
			lean = PRONE_CHEST - 0.08 * crawl
			head_pitch = PRONE_HEAD + 0.1 * crawl
			twist = Vector2(PI / 2.0, -PI / 2.0) * crawl
			thigh = Vector2(0.12 + 0.9 * up_l, 0.12 + 0.9 * up_r) * crawl
			knee = Vector2(-1.3 * up_l, -1.3 * up_r) * crawl
			spread = Vector2(-0.12, 0.12) * (1.0 - crawl)
			body_yaw = 0.05 * s * crawl
			chest_roll = 0.1 * s * crawl
			chest_turn = 0.12 * s * crawl
			hips_y = HIP_HEIGHT
	# Épauler redresse le buste.
	lean = lerpf(lean, -0.05, aim)
	if butt:
		lean += sample_keys(BUTT_LEAN, punch_t)
		if posture == Posture.STANDING:
			var dip := sample_keys(BUTT_DIP, punch_t)
			var bend := acos(clampf((THIGH_LENGTH + SHIN_LENGTH - dip) / (THIGH_LENGTH + SHIN_LENGTH), -1.0, 1.0))
			hips_y -= dip
			thigh += Vector2(bend, bend)
			knee -= Vector2(2.0 * bend, 2.0 * bend)
		body_pos.z += sample_keys(BUTT_LUNGE, punch_t)
	elif uppercut:
		lean += sample_keys(UPPERCUT_LEAN, punch_t)
		if posture == Posture.STANDING:
			# Flexion des genoux : le bassin descend, les pieds restent au sol.
			var dip := sample_keys(UPPERCUT_DIP, punch_t)
			var bend := acos(clampf((THIGH_LENGTH + SHIN_LENGTH - dip) / (THIGH_LENGTH + SHIN_LENGTH), -1.0, 1.0))
			hips_y -= dip
			thigh += Vector2(bend, bend)
			knee -= Vector2(2.0 * bend, 2.0 * bend)
		body_pos.z += sample_keys(UPPERCUT_LUNGE, punch_t)
	elif not kick.is_empty():
		# Jambe d'appui (gauche) fléchie, jambe droite qui frappe.
		var dip := sample_keys(kick["dip"], punch_t)
		var bend := acos(clampf((THIGH_LENGTH + SHIN_LENGTH - dip) / (THIGH_LENGTH + SHIN_LENGTH), -1.0, 1.0))
		hips_y -= dip
		thigh = Vector2(thigh.x + bend, sample_keys(kick["thigh_x"], punch_t))
		knee = Vector2(knee.x - 2.0 * bend, sample_keys(kick["knee"], punch_t))
		spread.y = sample_keys(kick["thigh_z"], punch_t)
		lean += sample_keys(kick["lean"], punch_t)
		body_pos.z += sample_keys(kick["lunge"], punch_t)
		hip_yaw = sample_keys(kick["hip_yaw"], punch_t)
		side_lean = sample_keys(kick["side_lean"], punch_t)
		kick_torso_yaw = sample_keys(kick["torso_yaw"], punch_t)
	elif grapple:
		var choke := strike_move == StrikeMove.CHOKE
		lean += sample_keys(CHOKE_LEAN if choke else CUT_LEAN, punch_t)
		var dip := sample_keys(CHOKE_DIP if choke else CUT_DIP, punch_t)
		hips_y -= dip
		thigh += Vector2.ONE * _knee_bend(dip)
		knee -= Vector2.ONE * 2.0 * _knee_bend(dip)
	elif throwing:
		lean += sample_keys(THROW_LEAN, throw_t)
		body_pos.z += sample_keys(THROW_LUNGE, throw_t)
	else:
		lean += -0.35 * strike
	var shake := 0.0
	if grabbed:
		# Tiré en arrière, il se débat de moins en moins et fléchit.
		_grab_time += delta
		var weak := clampf(_grab_time / 2.5, 0.0, 1.0)
		var dip := 0.03 + 0.1 * weak
		lean += 0.18
		head_pitch -= 0.45
		hips_y -= dip
		thigh += Vector2.ONE * _knee_bend(dip)
		knee -= Vector2.ONE * 2.0 * _knee_bend(dip)
		shake = sin(_grab_time * 23.0) * 0.07 * (1.0 - 0.6 * weak)
	# Poussée, parade, esquive, déséquilibre.
	var shove := shove_progress >= 0.0 and strike_progress < 0.0
	var shove_t := clampf(shove_progress, 0.0, 1.0)
	var defend := defend_progress >= 0.0 and strike_progress < 0.0
	var defend_w := 0.0
	if defend:
		defend_w = smoothstep(0.0, 1.0, minf(defend_progress / 0.2, 1.0)) * smoothstep(0.0, 1.0, minf((1.0 - defend_progress) / 0.35, 1.0))
	var parry := defend and defend_move == DefendMove.PARRY
	var dodge := defend and defend_move == DefendMove.DODGE
	var block := parry and is_armed and _sling < 0.5
	if shove:
		lean += sample_keys(SHOVE_LEAN, shove_t)
		body_pos.z += sample_keys(SHOVE_LUNGE, shove_t)
	if parry:
		lean += 0.12 * defend_w
		head_pitch += 0.15 * defend_w
	elif dodge:
		var duck := 0.14 * defend_w
		hips_y -= duck
		thigh += Vector2.ONE * _knee_bend(duck)
		knee -= Vector2.ONE * 2.0 * _knee_bend(duck)
		lean -= 0.25 * defend_w
		side_lean -= 0.3 * defend_side * defend_w
	_stagger = move_toward(_stagger, 1.0 if staggered else 0.0, delta * 5.0)
	var stagger := smoothstep(0.0, 1.0, _stagger)
	if stagger > 0.0:
		# Il recule d'un demi-pas, buste en arrière, et vacille.
		lean += 0.3 * stagger
		head_pitch -= 0.25 * stagger
		hips_y -= 0.06 * stagger
		thigh += Vector2.ONE * _knee_bend(0.06 * stagger)
		knee -= Vector2.ONE * 2.0 * _knee_bend(0.06 * stagger)
		body_pos.z += 0.12 * stagger
		shake += sin(_time * 7.0) * 0.1 * stagger
	# Caisse : buste penché en avant pour pousser, en arrière pour tirer,
	# genoux fléchis.
	_grip = move_toward(_grip, 1.0 if crate_grip else 0.0, delta * 4.0)
	var grip := smoothstep(0.0, 1.0, _grip)
	if grip > 0.0:
		var crouch := (0.1 if crate_pull else 0.06) * grip
		lean += (0.12 if crate_pull else -0.38) * grip
		head_pitch += (0.1 if crate_pull else -0.15) * grip
		hips_y -= crouch
		thigh += Vector2.ONE * _knee_bend(crouch)
		knee -= Vector2.ONE * 2.0 * _knee_bend(crouch)
	lean += 0.4 * hit * _hit_push * _hit_strength
	head_pitch += 0.12 * aim - 0.4 * hit * _hit_push * _hit_strength
	if not prone:
		hips_y -= 0.05 * hit

	_body.rotation.x = lerp_angle(_body.rotation.x, body_pitch, blend)
	# Couché, l'axe Z local du corps est vertical : sa rotation fait onduler
	# le bassin.
	_body.rotation.z = lerp_angle(_body.rotation.z, body_yaw, blend)
	# Les frappes sont rapides : le corps suit les clés presque sans retard.
	var limbs := 1.0 - exp(-30.0 * delta) if unarmed_strike or grapple or grabbed or shove or defend or throwing else blend
	_body.position = _body.position.lerp(body_pos, limbs)
	_hips.position.y = lerpf(_hips.position.y, hips_y, limbs)
	# Pivot sur le pied d'appui pendant un coup de pied.
	_hips.rotation.y = lerp_angle(_hips.rotation.y, hip_yaw, limbs)
	_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, thigh.x, limbs)
	_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, thigh.y, limbs)
	_leg_l.rotation.z = lerp_angle(_leg_l.rotation.z, spread.x, limbs)
	_leg_r.rotation.z = lerp_angle(_leg_r.rotation.z, spread.y, limbs)
	_leg_l.rotation.y = lerp_angle(_leg_l.rotation.y, twist.x, blend)
	_leg_r.rotation.y = lerp_angle(_leg_r.rotation.y, twist.y, blend)
	_knee_l.rotation.x = lerp_angle(_knee_l.rotation.x, knee.x, limbs)
	_knee_r.rotation.x = lerp_angle(_knee_r.rotation.x, knee.y, limbs)
	if prone:
		# Pointes de pied tendues vers l'arrière.
		_ankle_l.rotation.x = lerpf(_ankle_l.rotation.x, ANKLE_MIN, blend)
		_ankle_r.rotation.x = lerpf(_ankle_r.rotation.x, ANKLE_MIN, blend)
	else:
		_level_feet()
		if not kick.is_empty():
			_ankle_r.rotation.x = sample_keys(kick["ankle"], punch_t)
	# Respiration au repos, balancement en marche, choc des impacts.
	var breath := sin(_time * 1.8) * 0.012
	var fast := 1.0 - exp(-18.0 * delta)
	_lean = lerpf(_lean, lean + breath, fast)
	# Debout, `_torso_yaw` tourne le buste ; couché, il le fait rouler.
	var punch_twist := kick_torso_yaw
	if uppercut:
		punch_twist = sample_keys(UPPERCUT_TWIST, punch_t)
	elif butt:
		punch_twist = sample_keys(BUTT_TWIST, punch_t)
	elif throwing:
		punch_twist = sample_keys(THROW_TWIST, throw_t)
	_torso_yaw = lerp_angle(_torso_yaw, chest_roll * (1.0 - aim) + AIM_TWIST * aim + punch_twist, limbs)
	_torso.rotation = Vector3(_lean, _torso_yaw, 0.12 * hit * _hit_side + chest_turn + side_lean + shake)
	var head_yaw := sin(_time * 0.6) * 0.25 * (1.0 - moving) * (1.0 - aim) - AIM_TWIST * aim
	if prone:
		head_yaw = head_yaw * 0.4 * (1.0 - crawl) - chest_roll
	elif not kick.is_empty():
		# Les yeux restent sur la cible malgré la rotation du bassin.
		head_yaw = -0.8 * (hip_yaw + kick_torso_yaw)
	_head.rotation.x = lerp_angle(_head.rotation.x, head_pitch, fast)
	_head.rotation.y = lerp_angle(_head.rotation.y, head_yaw, blend)
	# La tête reste tournée vers l'avant malgré le balancement des épaules.
	_head.rotation.z = lerp_angle(_head.rotation.z, -0.8 * chest_turn, blend)

	# Arme : basse, épaulée ou en position couchée ; inclinée pendant le
	# rechargement ; à la bretelle sur le flanc pour libérer les mains.
	var rifle_target := _rifle_prone if prone else _rifle_hold.interpolate_with(_rifle_aim, aim)
	if prone:
		# Arme portée par la main droite, qui avance avec le coude droit.
		rifle_target.origin += Vector3(0.0, -0.1 * s, -0.04) * crawl
	if reloading:
		var tilt := sample_keys(RELOAD_TILT, reload_progress)
		rifle_target = rifle_target * Transform3D(Basis.from_euler(Vector3(0.25 * tilt, 0.0, -0.6 * tilt)), Vector3(-0.04 * tilt, 0.04 * tilt, 0.0))
	# Une frappe sans l'arme la met à la bretelle ; le coup de crosse la garde.
	var slung := _sling if butt else maxf(_sling, minf(strike * 1.5, 1.0))
	if grapple or grabbed or throwing or crate_grip:
		slung = 1.0
	if slung > 0.0:
		rifle_target = _sling_transform(rifle_target, slung)
	if butt:
		rifle_target = _butt_transform(rifle_target, punch_t)
	if shove and _sling < 0.5:
		rifle_target = _shove_transform(rifle_target, shove_t)
	if block:
		rifle_target = rifle_target.interpolate_with(_rifle_block, defend_w)
	_rifle_base = _rifle_base.interpolate_with(rifle_target, 1.0 - exp(-(40.0 if butt or shove or block else 14.0) * delta))
	var recoil := exp(-_shot_time / RECOIL_DECAY)
	_rifle.transform = _rifle_base * Transform3D(Basis(Vector3.RIGHT, 0.12 * recoil), Vector3(0.0, 0.0, 0.06 * recoil))

	# Bras : mains sur l'arme (IK), ou le long du corps sans arme.
	var target: Array
	if is_armed:
		var left := _rifle.transform * (LEFT_GRIP_PRONE if prone else LEFT_GRIP)
		var right := _rifle.transform * RIGHT_GRIP
		if reloading:
			left = _reload_hand(reload_progress)
		elif prone:
			# La main gauche lâche l'arme et prend appui au sol devant
			# l'épaule ; elle se soulève en avançant.
			var planted := Vector3(-0.27, 0.88 + 0.15 * s, -0.16 + 0.07 * maxf(c, 0.0))
			left = left.lerp(planted, crawl)
		# Geste de la bretelle : la main gauche lâche le garde-main dès que
		# le canon descend, la droite lâche la poignée une fois l'arme sur
		# le flanc.
		left = left.lerp(_free_hand(-1.0, prone, s, c, moving, crawl), smoothstep(0.35, 0.75, _sling))
		right = right.lerp(_free_hand(1.0, prone, s, c, moving, crawl), smoothstep(0.65, 1.0, _sling))
		target = _solve_arms(left, right, PRONE_ELBOW_POLE if prone else ARM_POLE)
	else:
		target = _arm_poses[ArmPose.RIFLE]
	if uppercut:
		var free_left := _free_hand(-1.0, false, s, c, moving, 0.0)
		var free_right := _free_hand(1.0, false, s, c, moving, 0.0)
		target = _solve_arms(_sample_points(UPPERCUT_LEFT, free_left, punch_t), _sample_points(UPPERCUT_RIGHT, free_right, punch_t))
	elif grapple:
		var choke := strike_move == StrikeMove.CHOKE
		var free_left := _free_hand(-1.0, false, s, c, moving, 0.0)
		var free_right := _free_hand(1.0, false, s, c, moving, 0.0)
		var times := CHOKE_TIMES if choke else CUT_TIMES
		target = _solve_arms(_path(times, CHOKE_LEFT if choke else CUT_LEFT, free_left, punch_t), _path(times, CHOKE_RIGHT if choke else CUT_RIGHT, free_right, punch_t))
	elif grabbed:
		# Mains à la gorge, sur le bras qui l'étrangle.
		target = _solve_arms(Vector3(-0.08, 0.56, -0.15), Vector3(0.08, 0.56, -0.15))
	elif throwing:
		var free_left := _free_hand(-1.0, posture == Posture.PRONE, s, c, moving, 0.0)
		var free_right := _free_hand(1.0, posture == Posture.PRONE, s, c, moving, 0.0)
		target = _solve_arms(_path(THROW_TIMES, THROW_LEFT, free_left, throw_t), _path(THROW_TIMES, THROW_RIGHT, free_right, throw_t))
	elif grip > 0.0:
		# Mains sur la caisse : cibles fixes dans le repère du modèle,
		# ramenées dans celui du torse (qui se penche).
		var hand := CRATE_PULL_HAND if crate_pull else CRATE_PUSH_HAND
		var to_torso := (_body.transform * _hips.transform * _torso.transform).affine_inverse()
		var left := to_torso * Vector3(-hand.x, hand.y, hand.z)
		var right := to_torso * hand
		target = _solve_arms(_free_hand(-1.0, false, s, c, moving, 0.0).lerp(left, grip), _free_hand(1.0, false, s, c, moving, 0.0).lerp(right, grip))
	elif shove and (not is_armed or _sling >= 0.5):
		# Poussée des deux mains.
		var free_left := _free_hand(-1.0, false, s, c, moving, 0.0)
		var free_right := _free_hand(1.0, false, s, c, moving, 0.0)
		target = _solve_arms(_path(SHOVE_TIMES, SHOVE_LEFT, free_left, shove_t), _path(SHOVE_TIMES, SHOVE_RIGHT, free_right, shove_t))
	elif parry and not block:
		var free_left := _free_hand(-1.0, false, s, c, moving, 0.0)
		var free_right := _free_hand(1.0, false, s, c, moving, 0.0)
		target = _solve_arms(free_left.lerp(PARRY_LEFT, defend_w), free_right.lerp(PARRY_RIGHT, defend_w))
	elif stagger > 0.0 and not is_armed:
		var free_left := _free_hand(-1.0, false, s, c, moving, 0.0)
		var free_right := _free_hand(1.0, false, s, c, moving, 0.0)
		target = _solve_arms(free_left.lerp(STAGGER_LEFT, stagger), free_right.lerp(STAGGER_RIGHT, stagger))
	elif not kick.is_empty():
		# Poings en garde devant le visage pendant le coup de pied.
		var guard := minf(punch_t / 0.2, 1.0) * minf((1.0 - punch_t) / 0.3, 1.0)
		target = _solve_arms(_free_hand(-1.0, false, s, c, moving, 0.0).lerp(GUARD_LEFT, guard), _free_hand(1.0, false, s, c, moving, 0.0).lerp(GUARD_RIGHT, guard))
	# Un coup de poing est rapide : les bras suivent sans retard.
	var arm_blend := 1.0 - exp(-(60.0 if unarmed_strike or grapple or shove or defend or throwing else 25.0) * delta)
	for i in _arm_joints.size():
		var goal: Quaternion = target[i]
		if strike > 0.0 and not unarmed_strike:
			goal = goal.slerp(_arm_poses[ArmPose.STRIKE][i], strike)
		_arm_joints[i].quaternion = _arm_joints[i].quaternion.slerp(goal, arm_blend)
	_knife.visible = (strike > 0.0 and strike_with_knife) or (throwing and throw_t < THROW_RELEASE) or (grapple and strike_move == StrikeMove.THROAT_CUT and punch_t > 0.1 and punch_t < 0.9)
	_update_magazines()


## Angle de flexion des cuisses (genoux à deux fois cet angle) qui abaisse le
## bassin de `dip` sans décoller les pieds du sol.
func _knee_bend(dip: float) -> float:
	return acos(clampf((THIGH_LENGTH + SHIN_LENGTH - dip) / (THIGH_LENGTH + SHIN_LENGTH), -1.0, 1.0))


## Position d'une main le long d'une trajectoire `points` aux instants
## `times` ; la première et la dernière clé valent `rest`.
func _path(times: Array[float], points: Array[Vector3], rest: Vector3, t: float) -> Vector3:
	var last := times.size() - 1
	for i in range(1, times.size()):
		if t <= times[i]:
			var weight := smoothstep(0.0, 1.0, (t - times[i - 1]) / (times[i] - times[i - 1]))
			var from := rest if i - 1 == 0 else points[i - 1]
			var to := rest if i == last else points[i]
			return from.lerp(to, weight)
	return rest


## Position de l'arme pendant le coup de crosse ; `base` au début et à la fin.
func _butt_transform(base: Transform3D, t: float) -> Transform3D:
	var last := BUTT_TIMES.size() - 1
	for i in range(1, BUTT_TIMES.size()):
		if t <= BUTT_TIMES[i]:
			var from_t := BUTT_TIMES[i - 1]
			var weight := smoothstep(0.0, 1.0, (t - from_t) / (BUTT_TIMES[i] - from_t))
			var from := base if i - 1 == 0 else _butt_keys[i - 2]
			var to := base if i == last else _butt_keys[i - 1]
			return from.interpolate_with(to, weight)
	return base


## Arme pendant la poussée : ramenée en travers de la poitrine, puis
## projetée en avant à deux mains, et retour.
func _shove_transform(base: Transform3D, t: float) -> Transform3D:
	if t <= SHOVE_TIMES[1]:
		return base.interpolate_with(_rifle_shove_chamber, smoothstep(0.0, 1.0, t / SHOVE_TIMES[1]))
	if t <= SHOVE_TIMES[2]:
		return _rifle_shove_chamber.interpolate_with(_rifle_shove_push, smoothstep(0.0, 1.0, (t - SHOVE_TIMES[1]) / (SHOVE_TIMES[2] - SHOVE_TIMES[1])))
	return _rifle_shove_push.interpolate_with(base, smoothstep(0.0, 1.0, (t - SHOVE_TIMES[2]) / (1.0 - SHOVE_TIMES[2])))


## Position interpolée le long d'une trajectoire de main aux instants
## `UPPERCUT_TIMES` ; la première et la dernière clé valent `rest`.
func _sample_points(points: Array[Vector3], rest: Vector3, t: float) -> Vector3:
	var last := UPPERCUT_TIMES.size() - 1
	for i in range(1, UPPERCUT_TIMES.size()):
		if t <= UPPERCUT_TIMES[i]:
			var from_t := UPPERCUT_TIMES[i - 1]
			var weight := smoothstep(0.0, 1.0, (t - from_t) / (UPPERCUT_TIMES[i] - from_t))
			var from := rest if i - 1 == 0 else points[i - 1]
			var to := rest if i == last else points[i]
			return from.lerp(to, weight)
	return rest


## Poids (0 à 1) de la réaction à l'impact en cours : montée brève, retour lent.
func _hit_weight() -> float:
	if _hit_time >= HIT_DURATION:
		return 0.0
	var t := _hit_time / HIT_DURATION
	return minf(t * 6.0, 1.0) * (1.0 - t) * (1.0 - t)


## Position de la main gauche pendant le rechargement (repère du torse).
func _reload_hand(t: float) -> Vector3:
	var rifle := _rifle.transform
	var points: Array[Vector3] = [rifle * LEFT_GRIP, rifle * MAG_WELL, rifle * MAG_DROP, MAG_POUCH, rifle * MAG_BELOW, rifle * MAG_WELL, rifle * LEFT_GRIP]
	for i in range(1, RELOAD_HAND_TIMES.size()):
		if t <= RELOAD_HAND_TIMES[i]:
			var from_t := RELOAD_HAND_TIMES[i - 1]
			var weight := smoothstep(0.0, 1.0, (t - from_t) / (RELOAD_HAND_TIMES[i] - from_t))
			return points[i - 1].lerp(points[i], weight)
	return points[points.size() - 1]


## Chargeur sur l'arme ou dans la main gauche selon l'avancement du
## rechargement ; le chargeur vide tombe au sol.
func _update_magazines() -> void:
	var t := reload_progress if is_armed and not is_dead else -1.0
	var out := t >= RELOAD_MAG_OUT and t < RELOAD_MAG_IN
	_rifle_mag.visible = not out
	_hand_mag.visible = out and (t < RELOAD_MAG_DROP or t >= RELOAD_MAG_TAKEN)
	if t < 0.0 or t < RELOAD_MAG_OUT:
		_mag_dropped = false
	elif t >= RELOAD_MAG_DROP and not _mag_dropped:
		_mag_dropped = true
		_drop_magazine()


func _drop_magazine() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var mag := MeshInstance3D.new()
	mag.mesh = (_hand_mag as MeshInstance3D).mesh
	mag.material_override = _m_weapon
	get_tree().current_scene.add_child(mag)
	mag.global_transform = _hand_mag.global_transform
	var ground := Vector3(mag.global_position.x, global_position.y + 0.03, mag.global_position.z)
	var tween := mag.create_tween()
	tween.tween_property(mag, "global_position", ground, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(mag, "rotation", Vector3(PI / 2.0, randf() * TAU, 0.0), 0.25)
	tween.tween_interval(4.0)
	tween.tween_callback(mag.queue_free)


## Chute (mort ou perte de connaissance) : les genoux cèdent, le corps bascule
## sur le dos et l'arme tombe à côté. Couché, il s'affaisse simplement.
func _animate_death(delta: float) -> void:
	_death_time += delta
	var t := _death_time
	var blend := 1.0 - exp(-14.0 * delta)
	var hips_y := HIP_HEIGHT
	var thigh := Vector2.ZERO
	var knee := Vector2.ZERO
	var spread := Vector2(-0.1, 0.1)
	var lean := 0.0
	var pitch := 0.0
	var roll := 0.0
	var pos := Vector3.ZERO
	var head := Vector3.ZERO
	var limp: Array = _arm_poses[ArmPose.LIMP]
	var dropped := _rifle_dropped
	if _death_forward and t >= 1.1:
		# Fin de la chute vers l'avant : même pose qu'une mort à plat ventre.
		_death_prone = true
		_death_forward = false
	if _death_forward:
		hips_y = sample_keys(DEATH_FWD_HIPS, t)
		thigh = Vector2.ONE * sample_keys(DEATH_FWD_THIGH, t)
		knee = Vector2.ONE * sample_keys(DEATH_FWD_KNEE, t)
		lean = sample_keys(DEATH_FWD_LEAN, t)
		pitch = sample_keys(DEATH_FWD_PITCH, t)
		pos = Vector3(0.0, sample_keys(DEATH_FWD_POS_Y, t), sample_keys(DEATH_FWD_POS_Z, t))
		head = Vector3(0.3 * smoothstep(0.5, 1.1, t), signf(_death_twist + 0.001) * 1.1 * smoothstep(0.6, 1.1, t), 0.0)
		limp = _arm_poses[ArmPose.LIMP_PRONE]
		dropped = _rifle_dropped_prone
	elif _death_prone:
		pitch = -PI / 2.0
		pos = PRONE_BODY_POS - Vector3(0.0, 0.03, 0.0)
		thigh = Vector2(0.1, 0.1)
		knee = Vector2(-0.2, -0.2)
		spread = Vector2(-0.15, 0.15)
		head = Vector3(0.3, signf(_death_twist + 0.001) * 1.1, 0.0)
		limp = _arm_poses[ArmPose.LIMP_PRONE]
		dropped = _rifle_dropped_prone
	else:
		hips_y = sample_keys(DEATH_HIPS, t)
		thigh = Vector2(sample_keys(DEATH_THIGH_L, t), sample_keys(DEATH_THIGH_R, t))
		knee = Vector2(sample_keys(DEATH_KNEE_L, t), sample_keys(DEATH_KNEE_R, t))
		lean = sample_keys(DEATH_LEAN, t)
		pitch = sample_keys(DEATH_PITCH, t)
		roll = _death_twist * smoothstep(0.3, 1.0, t)
		pos = Vector3(0.0, sample_keys(DEATH_POS_Y, t), sample_keys(DEATH_POS_Z, t))
		head = Vector3(sample_keys(DEATH_HEAD, t), _death_twist * 1.5 * smoothstep(0.6, 1.1, t), 0.0)
	_body.rotation.x = lerp_angle(_body.rotation.x, pitch, blend)
	_body.rotation.z = lerp_angle(_body.rotation.z, roll, blend)
	_body.position = _body.position.lerp(pos, blend)
	_hips.position.y = lerpf(_hips.position.y, hips_y, blend)
	_hips.rotation.y = lerp_angle(_hips.rotation.y, 0.0, blend)
	_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, thigh.x, blend)
	_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, thigh.y, blend)
	_leg_l.rotation.z = lerp_angle(_leg_l.rotation.z, spread.x, blend)
	_leg_r.rotation.z = lerp_angle(_leg_r.rotation.z, spread.y, blend)
	_leg_l.rotation.y = lerp_angle(_leg_l.rotation.y, 0.0, blend)
	_leg_r.rotation.y = lerp_angle(_leg_r.rotation.y, 0.0, blend)
	_knee_l.rotation.x = lerp_angle(_knee_l.rotation.x, knee.x, blend)
	_knee_r.rotation.x = lerp_angle(_knee_r.rotation.x, knee.y, blend)
	if _death_prone:
		_ankle_l.rotation.x = lerpf(_ankle_l.rotation.x, ANKLE_MIN, blend)
		_ankle_r.rotation.x = lerpf(_ankle_r.rotation.x, ANKLE_MIN, blend)
	else:
		_level_feet()
	_lean = lerpf(_lean, lean, blend)
	_torso_yaw = lerp_angle(_torso_yaw, 0.0, blend)
	_torso.rotation = Vector3(_lean, _torso_yaw, 0.0)
	_head.rotation = _head.rotation.lerp(head, blend)
	# Les bras suivent la chute avec retard, puis retombent au sol.
	var slow := 1.0 - exp(-(1.5 if t < 0.6 else 6.0) * delta)
	for i in _arm_joints.size():
		_arm_joints[i].quaternion = _arm_joints[i].quaternion.slerp(limp[i], slow)
	_rifle_base = _rifle_base.interpolate_with(dropped, slow)
	_rifle.transform = _rifle_base
	_knife.visible = false
	_update_magazines()


## Retire ou rend la carabine. Sans arme, la pose de repos des bras devient
## « bras le long du corps ».
func set_armed(value: bool) -> void:
	is_armed = value
	_rifle.visible = value
	if value:
		_arm_poses[ArmPose.RIFLE] = _solve_arms(_rifle_hold * Vector3(0.0, -0.02, -0.33), _rifle_hold * Vector3(0.0, -0.05, 0.05))
	else:
		_arm_poses[ArmPose.RIFLE] = _solve_arms(Vector3(-0.29, 0.0, -0.03), Vector3(0.29, 0.0, -0.03))
	for i in _arm_joints.size():
		_arm_joints[i].quaternion = _arm_poses[ArmPose.RIFLE][i]


## Valeur interpolée (avec adoucissement) d'une piste d'images clés donnée
## par paires (instant, valeur).
static func sample_keys(keys: Array, t: float) -> float:
	var count := keys.size() / 2
	if t <= keys[0]:
		return keys[1]
	for i in range(1, count):
		if t <= keys[i * 2]:
			var from_t: float = keys[(i - 1) * 2]
			var weight := smoothstep(0.0, 1.0, (t - from_t) / (keys[i * 2] - from_t))
			return lerpf(keys[(i - 1) * 2 + 1], keys[i * 2 + 1], weight)
	return keys[count * 2 - 1]


## Pose d'escalade à l'instant `climb_progress` (le déplacement du corps dans
## le monde est géré par l'unité).
func _animate_climb(delta: float) -> void:
	_transition_duration = 0.0
	_hips.rotation.y = 0.0
	var t := clampf(climb_progress, 0.0, 1.0)
	var down := climb_descending
	var blend := 1.0 - exp(-25.0 * delta)
	_body.rotation.x = lerp_angle(_body.rotation.x, 0.0, blend)
	_body.rotation.z = lerp_angle(_body.rotation.z, 0.0, blend)
	_body.position = _body.position.lerp(Vector3.ZERO, blend)
	_leg_l.rotation.z = 0.0
	_leg_r.rotation.z = 0.0
	_leg_l.rotation.y = 0.0
	_leg_r.rotation.y = 0.0
	_hips.position.y = sample_keys(CLIMB_DOWN_HIPS if down else CLIMB_UP_HIPS, t)
	_leg_l.rotation.x = sample_keys(CLIMB_DOWN_THIGH if down else CLIMB_UP_THIGH_L, t)
	_knee_l.rotation.x = sample_keys(CLIMB_DOWN_KNEE if down else CLIMB_UP_KNEE_L, t)
	_leg_r.rotation.x = sample_keys(CLIMB_DOWN_THIGH if down else CLIMB_UP_THIGH_R, t)
	_knee_r.rotation.x = sample_keys(CLIMB_DOWN_KNEE if down else CLIMB_UP_KNEE_R, t)
	_level_feet()
	_torso.rotation.x = sample_keys(CLIMB_DOWN_LEAN if down else CLIMB_UP_LEAN, t)
	_torso.rotation.y = 0.0
	_torso.rotation.z = 0.0
	_lean = _torso.rotation.x
	_torso_yaw = 0.0
	_head.rotation = Vector3(-0.5 * _torso.rotation.x, 0.0, 0.0)
	_sling = move_toward(_sling, 1.0 if weapon_slung and is_armed else 0.0, delta / SLING_TIME)
	var sling := maxf(_sling, sample_keys(CLIMB_DOWN_SLING if down else CLIMB_UP_SLING, t))
	_rifle.transform = _sling_transform(_rifle_hold, sling)
	_rifle_base = _rifle.transform
	_apply_arm_keys(CLIMB_DOWN_ARMS if down else CLIMB_UP_ARMS, t)


## IK des pieds : la cheville compense la flexion de la hanche et du genou
## pour garder la semelle parallèle au bassin (donc au sol quand le corps est
## droit), dans la limite du débattement de la cheville.
func _level_feet() -> void:
	_ankle_l.rotation.x = clampf(-(_leg_l.rotation.x + _knee_l.rotation.x), ANKLE_MIN, ANKLE_MAX)
	_ankle_r.rotation.x = clampf(-(_leg_r.rotation.x + _knee_r.rotation.x), ANKLE_MIN, ANKLE_MAX)


## Interpole les bras entre les poses d'une piste (instant, `ArmPose`).
func _apply_arm_keys(keys: Array[float], t: float) -> void:
	var count := keys.size() / 2
	var from_index := 0
	while from_index < count - 2 and t > keys[(from_index + 1) * 2]:
		from_index += 1
	var from_t := keys[from_index * 2]
	var to_t := keys[(from_index + 1) * 2]
	var weight := smoothstep(0.0, 1.0, clampf((t - from_t) / (to_t - from_t), 0.0, 1.0))
	# Arme à la bretelle : les mains ne reviennent pas sur l'arme.
	var rest := ArmPose.FREE if _sling >= 0.5 else ArmPose.RIFLE
	var from_key := int(keys[from_index * 2 + 1])
	var to_key := int(keys[(from_index + 1) * 2 + 1])
	var from_pose: Array = _arm_poses[rest if from_key == ArmPose.RIFLE else from_key]
	var to_pose: Array = _arm_poses[rest if to_key == ArmPose.RIFLE else to_key]
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
		# Botte (tige + semelle) articulée à la cheville.
		var ankle := _pivot(knee, Vector3(0.0, -SHIN_LENGTH, 0.0), "Ankle")
		_box(ankle, Vector3(0.15, 0.16, 0.18), Vector3(0.0, 0.04, 0.0), _m_boot)
		_box(ankle, Vector3(0.15, 0.09, 0.30), Vector3(0.0, -0.035, -0.05), _m_boot)
		if side < 0.0:
			_leg_l = leg
			_knee_l = knee
			_ankle_l = ankle
		else:
			_leg_r = leg
			_knee_r = knee
			_ankle_r = ankle
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
	if operator_helmet:
		_build_operator_helmet()
		return
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


## Casque balistique « high cut » d'opérateur : coque découpée au-dessus des
## oreilles, rails RIS latéraux (avec lampe et adaptateurs), protection
## auditive électronique à micro, support et JVN relevées, contrepoids.
func _build_operator_helmet() -> void:
	var dome := SphereMesh.new()
	dome.radius = 0.142
	dome.height = 0.145
	dome.is_hemisphere = true
	var shell := _mesh(_head, dome, Vector3(0.0, 0.19, 0.005), _m_helmet)
	shell.scale = Vector3(1.0, 1.0, 1.1)
	# Bord de la coque (garniture caoutchouc).
	var rim := _cylinder(_head, 0.144, 0.014, Vector3(0.0, 0.192, 0.005), _m_gear)
	rim.scale = Vector3(1.0, 1.0, 1.1)
	# Visière avant courte.
	_box(_head, Vector3(0.17, 0.02, 0.03), Vector3(0.0, 0.2, -0.148), _m_helmet)
	for side: float in [-1.0, 1.0]:
		# Rail RIS épousant le flanc de la coque, avec ses crans.
		var rail := _pivot(_head, Vector3(0.142 * side, 0.232, 0.0), "Rail")
		rail.rotation.z = -0.32 * side
		_box(rail, Vector3(0.016, 0.034, 0.16), Vector3.ZERO, _m_weapon)
		for i in 6:
			_box(rail, Vector3(0.022, 0.026, 0.01), Vector3(0.0, 0.0, -0.065 + 0.026 * i), _m_weapon)
		# Adaptateur qui relie la coquille auditive au rail.
		_box(_head, Vector3(0.014, 0.06, 0.022), Vector3(0.143 * side, 0.2, 0.0), _m_weapon)
		# Protection auditive : coquille, couvercle, coussinet.
		var cup := _cylinder(_head, 0.052, 0.04, Vector3(0.133 * side, 0.15, 0.005), _m_gear)
		cup.rotation.z = PI / 2.0
		var cap := _cylinder(_head, 0.036, 0.014, Vector3(0.158 * side, 0.15, 0.005), _m_weapon)
		cap.rotation.z = PI / 2.0
		var cushion := _cylinder(_head, 0.048, 0.012, Vector3(0.108 * side, 0.15, 0.005), _m_weapon)
		cushion.rotation.z = PI / 2.0
		# Tubes des jumelles de vision nocturne, relevées.
		var tube := _cylinder(_head, 0.022, 0.10, Vector3(0.032 * side, 0.335, -0.14), _m_weapon)
		tube.rotation.x = deg_to_rad(-65.0)
		var lens := _cylinder(_head, 0.018, 0.012, Vector3(0.032 * side, 0.358, -0.188), _m_lens)
		lens.rotation.x = deg_to_rad(-65.0)
	# Lampe tactique sur le rail droit.
	var lamp := _cylinder(_head, 0.016, 0.07, Vector3(0.168, 0.25, -0.03), _m_weapon)
	lamp.rotation.x = PI / 2.0
	_box(_head, Vector3(0.02, 0.02, 0.02), Vector3(0.158, 0.245, -0.03), _m_weapon)
	# Micro sur perche, devant la bouche.
	var boom := _box(_head, Vector3(0.01, 0.01, 0.11), Vector3(-0.12, 0.13, -0.07), _m_weapon)
	boom.rotation.y = -0.45
	_sphere(_head, 0.014, Vector3(-0.085, 0.125, -0.12), _m_gear)
	# Support de JVN (plaque frontale), contrepoids à l'arrière, marqueur IR.
	_box(_head, Vector3(0.06, 0.06, 0.03), Vector3(0.0, 0.27, -0.14), _m_weapon)
	_box(_head, Vector3(0.05, 0.05, 0.035), Vector3(0.0, 0.29, -0.155), _m_weapon)
	_box(_head, Vector3(0.11, 0.06, 0.035), Vector3(0.0, 0.235, 0.16), _m_gear)
	_box(_head, Vector3(0.05, 0.012, 0.05), Vector3(0.0, 0.337, 0.06), _m_team)


func _build_rifle_and_arms() -> void:
	var rifle := _pivot(_torso, Vector3(0.07, 0.31, -0.24), "Rifle")
	rifle.rotation = Vector3(deg_to_rad(-22.0), deg_to_rad(16.0), 0.0)
	_rifle = rifle
	_rifle_hold = rifle.transform
	# À la bretelle : pendue sur le flanc droit, canon vers le bas et un peu
	# vers l'avant, crosse sous l'aisselle.
	_rifle_slung = Transform3D(Basis.from_euler(Vector3(-PI / 2.0 + 0.25, 0.0, 0.1)), Vector3(0.28, 0.2, 0.08))
	_butt_keys = [
		Transform3D(Basis.from_euler(Vector3(0.6, PI - 0.5, 0.0)), Vector3(0.22, 0.32, 0.05)),
		Transform3D(Basis.from_euler(Vector3(-0.25, PI, 0.0)), Vector3(0.08, 0.6, -0.25)),
		Transform3D(Basis.from_euler(Vector3(-0.5, PI, 0.0)), Vector3(0.06, 0.66, -0.2)),
	]
	# Canon vers la gauche, légèrement relevé : l'arme barre la poitrine.
	_rifle_shove_chamber = Transform3D(Basis.from_euler(Vector3(0.3, PI / 2.0, 0.0)), Vector3(0.14, 0.4, -0.2))
	_rifle_shove_push = Transform3D(Basis.from_euler(Vector3(0.3, PI / 2.0, 0.0)), Vector3(0.14, 0.48, -0.5))
	_rifle_block = Transform3D(Basis.from_euler(Vector3(0.15, PI / 2.0, 0.0)), Vector3(0.16, 0.66, -0.34))
	_rifle_sling_mid = Transform3D(Basis.from_euler(Vector3(-PI / 2.0 + 0.45, 0.35, 0.0)), Vector3(0.16, 0.24, -0.24))
	_box(rifle, Vector3(0.045, 0.08, 0.30), Vector3(0.0, 0.04, -0.05), _m_weapon)      # boîtier
	_box(rifle, Vector3(0.04, 0.065, 0.20), Vector3(0.0, 0.035, 0.19), _m_weapon)     # crosse
	_box(rifle, Vector3(0.045, 0.10, 0.03), Vector3(0.0, 0.02, 0.30), _m_gear)        # plaque de couche
	var grip := _box(rifle, Vector3(0.035, 0.10, 0.045), Vector3(0.0, -0.045, 0.04), _m_weapon)
	grip.rotation.x = deg_to_rad(18.0)
	var mag := _box(rifle, Vector3(0.03, 0.17, 0.06), Vector3(0.0, -0.08, -0.09), _m_weapon)
	mag.rotation.x = deg_to_rad(-12.0)
	_rifle_mag = mag
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
	# Flash de bouche (discret : arme à silencieux).
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.8, 0.35)
	_flash = _pivot(rifle, Vector3(0.0, 0.045, -0.77), "MuzzleFlash")
	var flash := _sphere(_flash, 0.045, Vector3.ZERO, flash_material)
	flash.scale = Vector3(1.0, 1.0, 1.8)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false

	# Positions de l'arme (repère du torse). Épaulée : crosse à l'épaule,
	# viseur à hauteur d'œil, dans l'axe malgré la rotation du buste.
	_rifle_aim = Transform3D(Basis.from_euler(Vector3(0.0, -AIM_TWIST, 0.0)), Vector3(0.1, 0.52, -0.2))
	# Couché : définie dans le repère de l'unité puis ramenée dans celui du torse.
	var prone_torso := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), PRONE_BODY_POS) \
			* Transform3D(Basis(Vector3.RIGHT, PRONE_CHEST), Vector3(0.0, HIP_HEIGHT, 0.0))
	_rifle_prone = prone_torso.affine_inverse() * Transform3D(Basis.from_euler(Vector3(0.03, 0.15, 0.0)), Vector3(0.12, 0.3, -0.82))
	# Au sol après une chute, sur le côté droit (sur le dos, puis à plat ventre).
	_rifle_dropped = Transform3D(Basis.from_euler(Vector3(PI / 2.0, 0.2, PI / 2.0)), Vector3(0.5, 0.3, 0.2))
	_rifle_dropped_prone = Transform3D(Basis.from_euler(Vector3(PI / 2.0, -0.2, -PI / 2.0)), Vector3(0.5, 0.6, -0.12))
	_rifle_base = _rifle_hold

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
	# Bras relâchés au sol, sur le dos (le sol est vers +Z du torse) ou à plat
	# ventre (vers -Z).
	_arm_poses[ArmPose.FREE] = _solve_arms(Vector3(-FREE_HAND.x, FREE_HAND.y, FREE_HAND.z), FREE_HAND)
	_arm_poses[ArmPose.LIMP] = _solve_arms(Vector3(-0.6, 0.62, 0.2), Vector3(0.58, 0.2, 0.2))
	_arm_poses[ArmPose.LIMP_PRONE] = _solve_arms(Vector3(-0.55, 0.75, -0.12), Vector3(0.55, 0.3, -0.12))
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
	if side < 0.0:
		# Chargeur tenu en main pendant le rechargement.
		var held := _box(elbow, Vector3(0.03, 0.06, 0.17), Vector3(0.0, -FOREARM_LENGTH - 0.05, -0.04), _m_weapon)
		held.visible = false
		_hand_mag = held
	if side > 0.0:
		# Couteau de combat dans la main droite, sorti seulement pour frapper.
		_knife = _pivot(elbow, Vector3(0.0, -FOREARM_LENGTH - 0.03, 0.0), "Knife")
		_box(_knife, Vector3(0.028, 0.09, 0.032), Vector3.ZERO, _m_gear)
		_box(_knife, Vector3(0.012, 0.19, 0.03), Vector3(0.0, -0.13, 0.0), _m_steel)
		_knife.visible = false


## Rotations [épaule gauche, coude gauche, épaule droite, coude droit] qui
## amènent les mains aux positions données (repère du torse).
func _solve_arms(left_hand: Vector3, right_hand: Vector3, pole_hint: Vector3 = ARM_POLE) -> Array:
	var pose: Array = []
	for side: float in [-1.0, 1.0]:
		var shoulder := _shoulder_position(side)
		var to_hand := (left_hand if side < 0.0 else right_hand) - shoulder
		var reach := minf(to_hand.length(), UPPER_ARM_LENGTH + FOREARM_LENGTH - 0.01)
		var dir := to_hand.normalized()
		var hand := shoulder + dir * reach
		var along := (UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - FOREARM_LENGTH * FOREARM_LENGTH + reach * reach) / (2.0 * reach)
		var height := sqrt(maxf(UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - along * along, 0.0))
		var pole := Vector3(pole_hint.x * side, pole_hint.y, pole_hint.z)
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
