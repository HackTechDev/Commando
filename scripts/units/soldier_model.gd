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
enum StrikeMove { UPPERCUT, FRONT_KICK, ROUNDHOUSE, SIDE_KICK, BUTT_STRIKE, CHOKE, THROAT_CUT, ELBOW, KNEE, JAB_HOOK, SWEEP }
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
# Saut depuis un mur (descente de plus de 1,5 m) : accroupi au bord (0,18),
# impulsion (0,26), vol jambes groupées, contact (0,62), amorti accroupi
# (0,72), redressement. Hauteurs de bassin calculées pour garder les pieds
# sous le bassin, au sol hors du vol (cuisse 0,44 m, tibia 0,40 m, pied 0,08 m).
const JUMP_HIPS: Array[float] = [0, 0.92, 0.18, 0.566, 0.26, 0.9, 0.36, 0.768, 0.62, 0.768, 0.72, 0.456, 0.95, 0.92, 1, 0.92]
const JUMP_THIGH: Array[float] = [0, 0, 0.18, 1.0, 0.26, 0.3, 0.36, 0.7, 0.62, 0.7, 0.72, 1.2, 0.95, 0, 1, 0]
const JUMP_KNEE: Array[float] = [0, 0, 0.18, -1.9, 0.26, -0.3, 0.36, -1.2, 0.62, -1.2, 0.72, -2.2, 0.95, 0, 1, 0]
const JUMP_LEAN: Array[float] = [0, 0, 0.18, -0.6, 0.26, -0.35, 0.36, -0.2, 0.62, -0.25, 0.72, -0.7, 0.95, 0, 1, 0]
const JUMP_SLING: Array[float] = [0.0, 0.0, 1.0, 0.0]
const JUMP_ARMS: Array[float] = [0.0, ArmPose.RIFLE, 0.16, ArmPose.REACH, 0.62, ArmPose.REACH, 0.72, ArmPose.PUSH, 0.95, ArmPose.RIFLE]

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
## Main gauche sous la droite, autour de la poignée du pistolet.
const PISTOL_LEFT_GRIP := Vector3(-0.03, -0.09, 0.02)
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
## Fusil à pompe : après le tir, le garde-main recule de `PUMP_TRAVEL` (m) puis
## revient, en `PUMP_TIME` secondes, `PUMP_DELAY` après le coup.
const PUMP_DELAY := 0.12
const PUMP_TIME := 0.45
const PUMP_TRAVEL := 0.1
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
# Coups à mains nues décrits par des pistes (instants 0..1 de la frappe) :
# pistes du corps, toutes facultatives, comme pour les coups de pied
# (`dip`, `lean`, `lunge`, `hip_yaw`, `side_lean`, `torso_yaw`, `head`
# s'ajoutent à la pose ; `thigh_r`, `knee_r`, `spread_r` remplacent celle de la
# jambe droite), et trajets des mains (`times`, `left`, `right`, repère du
# torse ; la première et la dernière position sont remplacées par la main
# au repos). `pole` oriente les coudes ; `open` : mains ouvertes (saisie).
const ELBOW_TIMES: Array[float] = [0.0, 0.3, 0.45, 0.6, 1.0]
const KNEE_TIMES: Array[float] = [0.0, 0.25, 0.45, 0.62, 1.0]
const JAB_HOOK_TIMES: Array[float] = [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 1.0]
const SWEEP_TIMES: Array[float] = [0.0, 0.25, 0.5, 0.7, 1.0]
const MOVES := {
	# Coup de coude horizontal du bras droit, en pivotant le buste.
	StrikeMove.ELBOW: {
		"times": ELBOW_TIMES,
		"right": [Vector3.ZERO, Vector3(0.3, 0.5, -0.1), Vector3(-0.14, 0.6, -0.3), Vector3(-0.12, 0.58, -0.28), Vector3.ZERO] as Array[Vector3],
		"left": [Vector3.ZERO, Vector3(-0.12, 0.62, -0.28), Vector3(-0.2, 0.55, -0.15), Vector3(-0.12, 0.62, -0.28), Vector3.ZERO] as Array[Vector3],
		"pole": Vector3(0.35, 0.15, -1.0),
		"torso_yaw": [0.0, 0.0, 0.3, -0.55, 0.45, 0.6, 0.6, 0.55, 1.0, 0.0],
		"lunge": [0.0, 0.0, 0.3, -0.05, 0.45, -0.3, 0.6, -0.28, 1.0, 0.0],
		"dip": [0.0, 0.0, 0.3, 0.06, 0.45, 0.04, 1.0, 0.0],
		"lean": [0.0, 0.0, 0.45, -0.1, 1.0, 0.0],
	},
	# Saisie par la nuque, deux mains derrière la tête de la cible, puis
	# genou droit remonté dans le ventre.
	StrikeMove.KNEE: {
		"times": KNEE_TIMES,
		"left": [Vector3.ZERO, Vector3(-0.1, 0.64, -0.44), Vector3(-0.08, 0.5, -0.42), Vector3(-0.08, 0.54, -0.42), Vector3.ZERO] as Array[Vector3],
		"right": [Vector3.ZERO, Vector3(0.1, 0.64, -0.44), Vector3(0.08, 0.5, -0.42), Vector3(0.08, 0.54, -0.42), Vector3.ZERO] as Array[Vector3],
		"open": true,
		"thigh_r": [0.0, 0.0, 0.25, 0.5, 0.45, 1.65, 0.62, 1.0, 1.0, 0.0],
		"knee_r": [0.0, 0.0, 0.25, -1.3, 0.45, -1.9, 0.62, -1.5, 1.0, 0.0],
		"lean": [0.0, 0.0, 0.25, -0.08, 0.45, 0.15, 0.62, 0.05, 1.0, 0.0],
		"lunge": [0.0, 0.0, 0.25, -0.12, 0.45, -0.3, 0.62, -0.25, 1.0, 0.0],
		"dip": [0.0, 0.0, 0.45, 0.03, 1.0, 0.0],
		"head": [0.0, 0.0, 0.45, 0.25, 1.0, 0.0],
	},
	# Enchaînement : direct du gauche (0,3), puis crochet du droit (0,75).
	StrikeMove.JAB_HOOK: {
		"times": JAB_HOOK_TIMES,
		"left": [Vector3.ZERO, GUARD_LEFT, Vector3(-0.05, 0.6, -0.62), GUARD_LEFT, GUARD_LEFT, Vector3(-0.14, 0.62, -0.26), Vector3.ZERO] as Array[Vector3],
		"right": [Vector3.ZERO, GUARD_RIGHT, GUARD_RIGHT, GUARD_RIGHT, Vector3(0.36, 0.55, -0.16), Vector3(-0.04, 0.6, -0.48), Vector3.ZERO] as Array[Vector3],
		"pole": Vector3(0.9, -0.3, 0.0),
		"torso_yaw": [0.0, 0.0, 0.15, -0.1, 0.3, -0.35, 0.45, -0.1, 0.6, -0.4, 0.75, 0.6, 1.0, 0.0],
		"lunge": [0.0, 0.0, 0.3, -0.22, 0.45, -0.12, 0.75, -0.3, 1.0, 0.0],
		"dip": [0.0, 0.0, 0.3, 0.04, 0.6, 0.06, 0.75, 0.03, 1.0, 0.0],
		"head": [0.0, 0.0, 0.15, 0.12, 0.9, 0.12, 1.0, 0.0],
	},
	# Balayage : accroupi d'un coup, main gauche au sol, la jambe droite
	# tendue au ras du sol balaie en arc en pivotant sur l'appui.
	StrikeMove.SWEEP: {
		"times": SWEEP_TIMES,
		"left": [Vector3.ZERO, Vector3(-0.3, 0.05, -0.32), Vector3(-0.32, -0.05, -0.28), Vector3(-0.3, 0.0, -0.3), Vector3.ZERO] as Array[Vector3],
		"right": [Vector3.ZERO, Vector3(0.14, 0.5, -0.24), Vector3(0.2, 0.4, -0.2), Vector3(0.16, 0.45, -0.22), Vector3.ZERO] as Array[Vector3],
		"dip": [0.0, 0.0, 0.25, 0.4, 0.5, 0.44, 0.7, 0.4, 1.0, 0.0],
		"lean": [0.0, 0.0, 0.25, -0.35, 0.5, -0.45, 0.7, -0.35, 1.0, 0.0],
		"hip_yaw": [0.0, 0.0, 0.25, 0.3, 0.5, 1.4, 0.7, 1.6, 1.0, 0.0],
		"torso_yaw": [0.0, 0.0, 0.25, -0.25, 0.5, -1.0, 0.7, -1.1, 1.0, 0.0],
		"thigh_r": [0.0, 0.0, 0.25, 0.7, 0.5, 0.35, 0.7, 0.45, 1.0, 0.0],
		"knee_r": [0.0, 0.0, 0.25, -1.3, 0.5, -0.1, 0.7, -0.3, 1.0, 0.0],
		"spread_r": [0.0, 0.0, 0.25, 0.4, 0.5, 1.2, 0.7, 1.0, 1.0, 0.0],
		"head": [0.0, 0.0, 0.5, 0.2, 1.0, 0.0],
	},
}

## Instant (0 à 1) où porte le coup décisif des mouvements de `MOVES` qui ne
## frappent pas à `Commando.STRIKE_HIT_TIME`, et premier coup d'un
## enchaînement.
const MOVE_HIT_TIMES := {StrikeMove.JAB_HOOK: 0.75, StrikeMove.SWEEP: 0.5}
const MOVE_FIRST_HIT := {StrikeMove.JAB_HOOK: 0.3}

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
## Démarche en poussant ou tirant : avance de phase par unité de
## `move_ratio` (un cycle de deux pas d'environ 0,45 m pour une vitesse de
## marche de 3 m/s), amplitude des cuisses (pas de 0,45 m), position moyenne
## des cuisses (pieds en arrière pour pousser, en avant pour tirer) et
## levée du genou de la jambe qui avance.
const CRATE_PHASE_RATE := 21.0
const CRATE_STRIDE := 0.27
const CRATE_PUSH_THIGH := -0.12
const CRATE_PULL_THIGH := 0.22
const CRATE_KNEE_LIFT := 0.9
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
## Durée pour sortir le pistolet de l'étui (ou l'y remettre).
const DRAW_TIME := 0.45
## Pistolet dans son étui de cuisse (repère du torse), canon vers le bas.
const HOLSTER := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0.2, -0.04, 0.03))
## Bouclier balistique : taille du panneau (m), poignée (repère du
## bouclier, derrière le panneau), temps pour le lever ou le passer dans le
## dos, et décalage de l'arme de poing (repère du torse), tenue à droite du
## bouclier.
const SHIELD_SIZE := Vector2(0.56, 0.92)
## Taille relative de la silhouette féminine.
const FEMALE_SCALE := 0.95
const SHIELD_HANDLE := Vector3(0.0, 0.0, 0.07)
const SHIELD_TIME := 0.35
const SHIELD_PISTOL_OFFSET := Vector3(0.2, 0.08, -0.06)
## Part de levée au-delà de laquelle le bouclier arrête les balles.
const SHIELD_GUARD := 0.8
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
const IRIS_REST := Vector3(0.036, 0.192, -0.098)
## Échelle verticale de la paupière, œil ouvert (1 : fermé).
const LID_OPEN := 0.08
const BLINK_DURATION := 0.16
const MOUTH_REST := Vector3(1.5, 0.32, 0.5)
## Durée du geste de ramassage (voir `play_pickup`).
const PICKUP_DURATION := 0.7
## Main au sol pendant le ramassage (repère du modèle, côté droit).
const PICKUP_HAND := Vector3(0.2, 0.15, -0.45)

@export var uniform_color := Color(0.30, 0.33, 0.24)
@export var gear_color := Color(0.16, 0.17, 0.14)
@export var boot_color := Color(0.12, 0.10, 0.08)
@export var weapon_color := Color(0.07, 0.07, 0.08)
@export var skin_color := Color(0.80, 0.62, 0.50)
## Couleur d'identification de l'équipe (écussons d'épaule, marqueur de casque).
@export var team_color := Color(0.15, 0.45, 0.95)
## Équipement d'opérateur (casque balistique, rails, cagoule, gilet
## porte-plaques) ; sinon, tenue des soldats ennemis (`_guard_look`) :
## casque ancien, casquette ou béret, visage découvert, gilet à chargeurs.
@export var operator_helmet := true
@export var helmet_color := Color(0.25, 0.27, 0.2)
## Civil (VIP, otage) : costume, chemise et cravate, mains nues, chaussures de
## ville, sans aucun équipement militaire (à combiner avec un `outfit` sans
## accessoires et `set_armed(false)`).
@export var civilian := false

## Personnalisation d'un opérateur (tenue, accessoires, visage, armes) ; null :
## apparence donnée par les réglages ci-dessus (ennemis). Changer de profil
## reconstruit le modèle.
## Pas de bruits de pas (aperçu de l'écran « Opérateurs »).
var silent: bool = false
var outfit: OperatorProfile:
	set(value):
		outfit = value
		if _body != null:
			_rebuild()

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
## Vrai si la descente est un saut (du haut d'un mur).
var climb_jump: bool = false
## Montée ou descente d'une échelle : avancement du cycle de barreaux (une
## unité par paire de barreaux, croissant en montant), piloté par l'unité ;
## négatif hors échelle.
var ladder_phase: float = -1.0
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
## Le lancer est celui d'une grenade (au lieu d'un couteau).
var throw_grenade: bool = false
## Arme secondaire en main ; l'arme principale pend alors à sa bretelle
## 3 points, sur le flanc droit. Le changement est animé (`_update_weapon_switch`) :
## l'arme principale descend à la bretelle, puis le pistolet sort de l'étui
## (et l'inverse pour le rengainer).
var sidearm_drawn: bool = false:
	set(value):
		sidearm_drawn = value
		if _body == null:
			_sidearm_built = value
## Porte un bouclier balistique (dans le dos, ou levé : `shield_raised`).
var carries_shield: bool = false:
	set(value):
		if value == carries_shield:
			return
		carries_shield = value
		if _body:
			_rebuild()
## Porte un grappin : corde lovée et grappin accrochés au flanc gauche.
var carries_grapnel: bool = false:
	set(value):
		if value == carries_grapnel:
			return
		carries_grapnel = value
		if _body:
			_rebuild()
## Bouclier tenu devant soi, de la main gauche.
var shield_raised: bool = false
## Avancement (0 à 1) d'une poussée pour repousser un assaillant ; -1 hors poussée.
var shove_progress: float = -1.0
## Avancement (0 à 1) d'une défense (parade ou esquive) ; -1 hors défense.
var defend_progress: float = -1.0
var defend_move: DefendMove = DefendMove.PARRY
## Côté de l'esquive : 1 vers la droite, -1 vers la gauche.
var defend_side: float = 1.0
## Déséquilibré après une attaque parée ou esquivée.
var staggered: bool = false
## Point regardé (repère du monde) : la tête et les yeux s'y tournent.
## `Vector3.INF` : rien de particulier.
var look_target: Vector3 = Vector3.INF
## Garde : poings levés (sans arme) ou arme en travers de la poitrine,
## genoux fléchis. Un ennemi en alerte la lève face à un assaillant proche.
var guard_up: bool = false

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
## Arme en main telle que construite (peut retarder sur `sidearm_drawn`
## pendant le changement d'arme), et sortie du pistolet (0 : dans l'étui,
## 1 : en main).
var _sidearm_built: bool = false
var _draw: float = 1.0
## Bouclier (null sans bouclier), sa position dans le dos (repère du torse) et
## sa levée (0 : dans le dos, 1 : devant).
var _shield: Node3D
## Silhouette et visage féminins (`OperatorProfile.body`).
var _female: bool = false
var _shield_back: Transform3D
var _shield_up: float = 0.0
var _rifle_aim: Transform3D
var _rifle_prone: Transform3D
var _rifle_dropped: Transform3D
var _rifle_dropped_prone: Transform3D
## Position lissée de l'arme, avant le recul.
var _rifle_base: Transform3D
var _rifle_mag: Node3D
## Garde-main mobile du fusil à pompe en main (null pour les autres armes),
## et sa position de repos.
var _pump: Node3D
var _pump_rest: Vector3
## Arme à magasin tubulaire : rechargée cartouche par cartouche, sans
## chargeur qui sort ni qui tombe.
var _tube_fed: bool = false
var _hand_mag: Node3D
var _flash: Node3D
var _knife: Node3D
var _hand_grenade: Node3D
## Prise de la main gauche dans le repère de l'arme (garde-main, ou poignée
## du pistolet tenu à deux mains).
var _left_grip: Vector3 = LEFT_GRIP
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
## Demi-cycle de marche du dernier bruit de pas.
var _last_step: int = 0
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
## Phalanges de chaque main (gauche, droite) : 4 doigts × 2, puis le pouce.
var _fingers: Array = []
## Apparence d'un soldat ennemi, tirée au hasard (graine : chemin du nœud) ;
## vide pour un opérateur.
var _guard_look: Dictionary = {}
## Déplacement mesuré dans le repère du modèle (x : vers la droite, y : vers
## l'avant), lissé : sert à marcher à reculons ou en pas chassés.
var _motion := Vector2.ZERO
var _last_position := Vector3.INF
var _pickup_time: float = 10.0
var _guard: float = 0.0
## Visage animé (absent sous un casque fermé : listes vides).
var _irises: Array[Node3D] = []
var _lids: Array[Node3D] = []
var _brows: Array[Node3D] = []
var _blink_wait: float = 2.0
var _blink_time: float = 10.0
var _gaze_wait: float = 0.0
var _gaze_idle := Vector2.ZERO
var _gaze := Vector2.ZERO
## Yeux mi-clos (douleur), de 0 à 1.
var _squint: float = 0.0
## Hasard purement visuel (clignements, regard), séparé du générateur global
## pour ne pas changer les tirages du jeu (parade, précision…).
var _cosmetic := RandomNumberGenerator.new()
var _mouth: MeshInstance3D
var _mouth_inner: MeshInstance3D
## Expression : effort (frappe, lancer, escalade, caisse) et douleur (coup
## encaissé, prise, déséquilibre), de 0 à 1, visées puis lissées.
var effort: float = 0.0
var pain: float = 0.0
var _effort: float = 0.0
var _pain: float = 0.0
var _curl := Vector2(0.4, 0.4)
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
var _m_top: StandardMaterial3D
var _m_pants: StandardMaterial3D
var _m_hair: StandardMaterial3D
var _m_dark: StandardMaterial3D
var _m_red: StandardMaterial3D
var _m_white: StandardMaterial3D
var _m_scrim: StandardMaterial3D
var _m_grenade: StandardMaterial3D
var _m_explosive: StandardMaterial3D
var _m_glove: StandardMaterial3D
var _m_sole: StandardMaterial3D
var _m_eye: StandardMaterial3D
var _m_iris: StandardMaterial3D
var _m_lip: StandardMaterial3D
var _m_stubble: StandardMaterial3D


func _ready() -> void:
	_build()


## Remplace le modèle construit par un nouveau, d'après `outfit`.
func _rebuild() -> void:
	var old := _body
	remove_child(old)
	old.free()
	_arm_joints.clear()
	_arm_poses.clear()
	_fingers.clear()
	_irises.clear()
	_lids.clear()
	_brows.clear()
	_mouth = null
	_mouth_inner = null
	_shield = null
	_butt_keys.clear()
	_build()


func _build() -> void:
	_m_uniform = _cloth(uniform_color)
	_m_gear = _webbing(gear_color)
	_m_boot = _mat(boot_color, 0.7)
	_m_weapon = _mat(weapon_color, 0.45, 0.6)
	_m_skin = _mat(skin_color, 0.8)
	_m_helmet = _mat(helmet_color, 0.75)
	_m_top = _m_uniform
	_m_pants = _m_uniform
	_m_hair = _mat(GearCatalog.HAIR_COLORS[0], 0.9)
	if outfit:
		_m_top = _cloth(outfit.top_color)
		_m_pants = _cloth(outfit.pants_color)
		_m_uniform = _m_top
		_m_gear = _webbing(outfit.vest_color)
		_m_helmet = _mat(outfit.headwear_color, 0.75)
		_m_skin = _mat(GearCatalog.SKINS[outfit.skin], 0.8)
		_m_hair = _mat(GearCatalog.HAIR_COLORS[outfit.hair_color], 0.9)
	if civilian:
		_m_gear = _mat(Color(0.09, 0.06, 0.04), 0.45)
		_m_boot = _mat(Color(0.05, 0.04, 0.035), 0.35)
	_guard_look = _pick_guard_look() if outfit == null and not operator_helmet and not civilian else {}
	_female = outfit != null and outfit.body == &"female"
	if not _guard_look.is_empty():
		_m_skin = _mat(GearCatalog.SKINS[_guard_look["skin"]], 0.8)
		_m_hair = _mat(GearCatalog.HAIR_COLORS[_guard_look["hair_color"]], 0.9)
		_m_helmet = _cloth((uniform_color as Color).darkened(0.1)) if _guard_look["headwear"] == &"helmet" else _mat(_guard_look["headwear_color"], 0.85)
	_m_dark = _mat(Color(0.05, 0.05, 0.05), 0.4)
	_m_glove = _m_skin if civilian else _mat(Color(0.13, 0.13, 0.12), 0.8)
	_m_sole = _mat(Color(0.06, 0.06, 0.06), 0.9)
	_m_eye = _mat(Color(0.9, 0.9, 0.86), 0.3)
	_m_iris = _mat(Color(0.12, 0.08, 0.05), 0.2)
	_m_lip = _mat((_m_skin.albedo_color as Color).darkened(0.25).lerp(Color(0.6, 0.25, 0.22), 0.45 if _female else 0.25), 0.6)
	_m_stubble = _mat((_m_skin.albedo_color as Color).lerp(_m_hair.albedo_color, 0.55), 0.95)
	_m_red = _mat(Color(0.75, 0.1, 0.08), 0.6)
	_m_white = _mat(Color(0.88, 0.88, 0.85), 0.8)
	# Toile de camouflage du tireur d'élite (filet, écharpe).
	_m_scrim = _cloth((_m_top.albedo_color as Color).lerp(Color(0.45, 0.42, 0.3), 0.5))
	_m_grenade = _mat(Color(0.2, 0.24, 0.16), 0.6, 0.2)
	_m_explosive = _mat(Color(0.62, 0.55, 0.38), 0.85)
	_m_team = _mat(team_color, 0.6)
	_m_team.emission_enabled = true
	_m_team.emission = team_color
	_m_team.emission_energy_multiplier = 0.4
	if civilian:
		# Pas d'écusson : il se fond dans l'étoffe.
		_m_team = _m_top
	_m_lens = _mat(Color(0.1, 0.5, 0.3), 0.15, 0.8)
	_m_steel = _mat(Color(0.72, 0.74, 0.78), 0.25, 0.9)

	_body = _pivot(self, Vector3.ZERO, "Body")
	# Un peu plus petite ; les articulations restent les mêmes (animations).
	_body.scale = Vector3.ONE * (FEMALE_SCALE if _female else 1.0)
	_hips = _pivot(_body, Vector3(0.0, HIP_HEIGHT, 0.0), "Hips")
	_build_legs()
	_build_torso()
	_build_head()
	_build_rifle_and_arms()
	_build_shield()
	_build_grapnel()


func _process(delta: float) -> void:
	_time += delta
	_shot_time += delta
	_update_weapon_switch(delta)
	_hit_time += delta
	_pickup_time += delta
	_aim_hold = maxf(_aim_hold - delta, 0.0)
	_animate_face(delta)
	_flash.visible = _shot_time < FLASH_DURATION and is_armed and not is_dead
	if climb_progress >= 0.0 and not is_dead:
		_animate_climb(delta)
		return
	if ladder_phase >= 0.0 and not is_dead:
		_animate_ladder(delta)
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
	return is_armed and _sling <= 0.0 and not is_switching_weapon()


## Vrai pendant un changement d'arme (principale ↔ secondaire).
func is_switching_weapon() -> bool:
	return sidearm_drawn != _sidearm_built or (_sidearm_built and _draw < 1.0)


## Position de la bretelle visée : un changement d'arme vers le pistolet
## laisse d'abord pendre l'arme principale.
func _sling_goal() -> float:
	if not is_armed:
		return 0.0
	if sidearm_drawn and not _sidearm_built:
		return 1.0
	return 1.0 if weapon_slung else 0.0


## Enchaîne le changement d'arme : l'arme principale descend à la bretelle,
## le modèle passe au pistolet (l'arme principale reste pendue au même
## endroit), qui sort de l'étui ; à l'inverse, le pistolet rentre dans l'étui
## puis l'arme principale remonte de la bretelle.
func _update_weapon_switch(delta: float) -> void:
	if is_dead:
		return
	if sidearm_drawn == _sidearm_built:
		if _sidearm_built:
			_draw = move_toward(_draw, 1.0, delta / DRAW_TIME)
		return
	if sidearm_drawn:
		if _sling < 1.0 and is_armed:
			return
		_sidearm_built = true
		_rebuild()
		_draw = 0.0
		_sling = 1.0 if weapon_slung else 0.0
		_rifle_base = HOLSTER
		_rifle.transform = HOLSTER
		return
	_draw = move_toward(_draw, 0.0, delta / DRAW_TIME)
	if _draw > 0.0:
		return
	_sidearm_built = false
	_rebuild()
	_draw = 1.0
	_sling = 1.0
	_rifle_base = _rifle_slung
	_rifle.transform = _rifle_slung


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
		left = _rifle.transform * _left_grip.lerp(LEFT_GRIP_PRONE, rifle_weight)
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
	_hand_grenade.visible = false
	_update_magazines()
	_animate_fingers(Vector2(lerpf(0.95, 0.1, hand), 1.0) if is_armed else Vector2(lerpf(0.35, 0.1, hand), lerpf(0.35, 0.1, hand)), delta)
	if t >= 1.0:
		_transition_duration = 0.0


## Position de la main quand le bras pend le long du corps (repère du torse).
func _arm_poses_hand(side: float) -> Vector3:
	return Vector3(0.29 * side, 0.0, -0.03)


## Ramassage d'un objet au sol : genoux fléchis, buste penché, une main
## (la gauche si l'arme est en main) descend jusqu'au sol puis remonte.
func play_pickup() -> void:
	_pickup_time = 0.0


## Vrai pendant le geste de ramassage.
func is_picking_up() -> bool:
	return _pickup_time < PICKUP_DURATION


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
	_measure_motion(delta)
	var walk := clampf(move_ratio, 0.0, 2.0)
	var moving := minf(walk, 1.0)
	var prone := posture == Posture.PRONE
	if prone:
		_phase += delta * walk * CRAWL_PHASE_RATE
	elif crate_grip:
		# Cadence liée à la distance parcourue ; à reculons pour tirer.
		_phase += delta * walk * CRATE_PHASE_RATE * (-1.0 if crate_pull else 1.0)
	else:
		_phase += delta * (5.0 + 3.5 * walk) * moving * (-1.0 if _backward() > 0.5 else 1.0)
	_play_steps(walk, moving, prone)
	_crawl = move_toward(_crawl, 1.0 if prone and walk > 0.02 else 0.0, delta * 4.0)
	var crawl := smoothstep(0.0, 1.0, _crawl)
	var blend := 1.0 - exp(-10.0 * delta)
	var s := sin(_phase)
	var c := cos(_phase)
	var swing := 0.55 * moving + 0.25 * maxf(walk - 1.0, 0.0)
	_sling = move_toward(_sling, _sling_goal(), delta / SLING_TIME)
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
	var move: Dictionary = {}
	if unarmed_strike and posture == Posture.STANDING:
		kick = KICKS.get(strike_move, {})
		move = MOVES.get(strike_move, {})
	var uppercut := unarmed_strike and kick.is_empty() and move.is_empty() and not butt
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
	# Ramassage : flexion des genoux et buste penché, au plus bas à mi-geste.
	var pickup := 0.0
	if is_picking_up() and not prone:
		pickup = sin(PI * _pickup_time / PICKUP_DURATION)
		var dip := (0.42 if posture == Posture.STANDING else 0.1) * pickup
		hips_y -= dip
		thigh += Vector2.ONE * _knee_bend(dip)
		knee -= Vector2.ONE * 2.0 * _knee_bend(dip)
		lean -= 0.85 * pickup
		head_pitch += 0.35 * pickup
	# Garde : poids sur l'avant des pieds, genoux souples, léger rebond ;
	# poings levés sans arme, arme en travers de la poitrine avec.
	_guard = move_toward(_guard, 1.0 if guard_up and not prone and (not is_armed or _sling < 0.5) else 0.0, delta * 4.0)
	var guard := smoothstep(0.0, 1.0, _guard)
	if guard > 0.0:
		var bounce := (0.05 + 0.015 * sin(_time * 6.0) * (1.0 - moving)) * guard
		hips_y -= bounce
		thigh += Vector2.ONE * _knee_bend(bounce)
		knee -= Vector2.ONE * 2.0 * _knee_bend(bounce)
		lean -= 0.12 * guard
		head_pitch += 0.12 * guard
	# Pas chassés quand il est déplacé de côté (esquive, poussée) : la jambe
	# du côté du mouvement s'ouvre, l'autre la rejoint.
	var strafe := _sideways()
	if strafe > 0.0 and not prone and posture == Posture.STANDING:
		var lead := signf(_motion.x)
		var open := 0.22 * maxf(s, 0.0) * strafe
		var close := 0.08 * maxf(-s, 0.0) * strafe
		thigh = thigh.lerp(Vector2(0.08, 0.08), strafe)
		knee = knee.lerp(Vector2(-0.45 * maxf(c, 0.0), -0.45 * maxf(-c, 0.0)), strafe)
		if lead > 0.0:
			spread = Vector2(-close, open)
		else:
			spread = Vector2(-open, close)
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
	elif not move.is_empty():
		var dip := _track(move, "dip", punch_t)
		hips_y -= dip
		thigh += Vector2.ONE * _knee_bend(dip)
		knee -= Vector2.ONE * 2.0 * _knee_bend(dip)
		if move.has("thigh_r"):
			thigh.y = sample_keys(move["thigh_r"], punch_t)
			knee.y = sample_keys(move["knee_r"], punch_t)
		if move.has("spread_r"):
			spread.y = sample_keys(move["spread_r"], punch_t)
		lean += _track(move, "lean", punch_t)
		head_pitch += _track(move, "head", punch_t)
		body_pos.z += _track(move, "lunge", punch_t)
		hip_yaw = _track(move, "hip_yaw", punch_t)
		side_lean = _track(move, "side_lean", punch_t)
		kick_torso_yaw = _track(move, "torso_yaw", punch_t)
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
		# Le pied droit recule pour rattraper l'équilibre.
		thigh.y -= 0.35 * stagger
		knee.y -= 0.25 * stagger
		shake += sin(_time * 7.0) * 0.1 * stagger
	# Caisse : buste penché en avant pour pousser, en arrière pour tirer,
	# genoux fléchis.
	_grip = move_toward(_grip, 1.0 if crate_grip else 0.0, delta * 4.0)
	var grip := smoothstep(0.0, 1.0, _grip)
	if grip > 0.0:
		# Pas courts et appuyés : la jambe qui avance dans le sens du
		# déplacement (en avant pour pousser, en arrière pour tirer) lève le
		# genou, l'autre pousse au sol.
		var stride := minf(walk * 6.0, 1.0)
		var base := CRATE_PULL_THIGH if crate_pull else CRATE_PUSH_THIGH
		var crate_thigh := Vector2(base + s * CRATE_STRIDE * stride, base - s * CRATE_STRIDE * stride)
		var crate_knee := Vector2(-maxf(c, 0.0), -maxf(-c, 0.0)) * CRATE_KNEE_LIFT * stride
		thigh = thigh.lerp(crate_thigh, grip)
		knee = knee.lerp(crate_knee, grip)
		hips_y += absf(s) * 0.02 * stride * grip
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
	elif not kick.is_empty() or not move.is_empty():
		# Les yeux restent sur la cible malgré la rotation du bassin.
		head_yaw = -0.8 * (hip_yaw + kick_torso_yaw)
	else:
		# La tête se tourne vers ce qu'il regarde (l'épaulement vise déjà).
		var look := _look_yaw(1.0)
		if not is_nan(look):
			head_yaw = lerpf(look, head_yaw, aim)
	_head.rotation.x = lerp_angle(_head.rotation.x, head_pitch, fast)
	_head.rotation.y = lerp_angle(_head.rotation.y, head_yaw, blend)
	# La tête reste tournée vers l'avant malgré le balancement des épaules.
	_head.rotation.z = lerp_angle(_head.rotation.z, -0.8 * chest_turn, blend)

	# Arme : basse, épaulée ou en position couchée ; inclinée pendant le
	# rechargement ; à la bretelle sur le flanc pour libérer les mains.
	var rifle_target := _rifle_prone if prone else _rifle_hold.interpolate_with(_rifle_aim, aim)
	var shield := _update_shield(delta, prone)
	# Bouclier levé : l'arme de poing passe à droite du bouclier.
	rifle_target.origin += SHIELD_PISTOL_OFFSET * shield
	# Pistolet qui sort de l'étui (ou y rentre).
	var draw := smoothstep(0.0, 1.0, _draw) if _sidearm_built else 1.0
	if draw < 1.0:
		rifle_target = HOLSTER.interpolate_with(rifle_target, draw)
		_rifle_base = rifle_target
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
	if is_armed and guard > 0.0 and not butt and not shove:
		rifle_target = rifle_target.interpolate_with(_rifle_block, guard)
	if block:
		rifle_target = rifle_target.interpolate_with(_rifle_block, defend_w)
	_rifle_base = _rifle_base.interpolate_with(rifle_target, 1.0 - exp(-(40.0 if butt or shove or block else 14.0) * delta))
	var recoil := exp(-_shot_time / RECOIL_DECAY)
	_rifle.transform = _rifle_base * Transform3D(Basis(Vector3.RIGHT, 0.12 * recoil), Vector3(0.0, 0.0, 0.06 * recoil))
	var pump := pump_offset(_shot_time) if _pump else 0.0
	if _pump:
		_pump.position = _pump_rest + Vector3(0.0, 0.0, pump)

	# Bras : mains sur l'arme (IK), ou le long du corps sans arme.
	var target: Array
	if is_armed:
		var left := _rifle.transform * ((LEFT_GRIP_PRONE if prone else _left_grip) + Vector3(0.0, 0.0, pump))
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
		# La main gauche ne vient sur le pistolet qu'une fois sorti de l'étui.
		if draw < 1.0:
			left = left.lerp(_free_hand(-1.0, prone, s, c, moving, crawl), 1.0 - smoothstep(0.6, 1.0, draw))
		if shield > 0.0:
			left = left.lerp(_shield.transform * SHIELD_HANDLE, shield)
		target = _solve_arms(left, right, PRONE_ELBOW_POLE if prone else ARM_POLE)
	else:
		target = _arm_poses[ArmPose.RIFLE]
	if uppercut:
		var free_left := _free_hand(-1.0, false, s, c, moving, 0.0)
		var free_right := _free_hand(1.0, false, s, c, moving, 0.0)
		target = _solve_arms(_sample_points(UPPERCUT_LEFT, free_left, punch_t), _sample_points(UPPERCUT_RIGHT, free_right, punch_t))
	elif not move.is_empty():
		var free_left := _free_hand(-1.0, false, s, c, moving, 0.0)
		var free_right := _free_hand(1.0, false, s, c, moving, 0.0)
		if move.has("right"):
			var times: Array[float] = move["times"]
			target = _solve_arms(_path(times, move["left"], free_left, punch_t), _path(times, move["right"], free_right, punch_t), move.get("pole", ARM_POLE))
		else:
			var fists := minf(punch_t / 0.2, 1.0) * minf((1.0 - punch_t) / 0.3, 1.0)
			target = _solve_arms(free_left.lerp(GUARD_LEFT, fists), free_right.lerp(GUARD_RIGHT, fists))
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
	elif guard > 0.0 and not is_armed and strike_progress < 0.0:
		var free_left := _free_hand(-1.0, false, s, c, moving, 0.0)
		var free_right := _free_hand(1.0, false, s, c, moving, 0.0)
		var sway := Vector3(0.0, 0.015 * sin(_time * 6.0), 0.0)
		target = _solve_arms(free_left.lerp(GUARD_LEFT + Vector3(0.0, 0.0, -0.06) + sway, guard), free_right.lerp(GUARD_RIGHT + sway, guard))
	elif not kick.is_empty():
		# Poings en garde devant le visage pendant le coup de pied.
		var fists := minf(punch_t / 0.2, 1.0) * minf((1.0 - punch_t) / 0.3, 1.0)
		target = _solve_arms(_free_hand(-1.0, false, s, c, moving, 0.0).lerp(GUARD_LEFT, fists), _free_hand(1.0, false, s, c, moving, 0.0).lerp(GUARD_RIGHT, fists))
	if pickup > 0.0:
		var to_torso := (_body.transform * _hips.transform * _torso.transform).affine_inverse()
		var left_hand := is_armed and _sling < 0.5
		var ground := to_torso * Vector3(PICKUP_HAND.x * (-1.0 if left_hand else 1.0), PICKUP_HAND.y, PICKUP_HAND.z)
		var reach := _solve_arms(ground, ground) if not left_hand else _solve_arms(ground, _rifle.transform * RIGHT_GRIP)
		# Copie : `target` peut être une pose de référence partagée.
		target = target.duplicate()
		for i in target.size():
			if (i < 2) == left_hand:
				target[i] = (target[i] as Quaternion).slerp(reach[i], pickup)
	# Un coup de poing est rapide : les bras suivent sans retard.
	var arm_blend := 1.0 - exp(-(60.0 if unarmed_strike or grapple or shove or defend or throwing else 25.0) * delta)
	for i in _arm_joints.size():
		var goal: Quaternion = target[i]
		if strike > 0.0 and not unarmed_strike:
			goal = goal.slerp(_arm_poses[ArmPose.STRIKE][i], strike)
		_arm_joints[i].quaternion = _arm_joints[i].quaternion.slerp(goal, arm_blend)
	_hand_grenade.visible = throwing and throw_grenade and throw_t < THROW_RELEASE
	_knife.visible = (strike > 0.0 and strike_with_knife) or (throwing and not throw_grenade and throw_t < THROW_RELEASE) or (grapple and strike_move == StrikeMove.THROAT_CUT and punch_t > 0.1 and punch_t < 0.9)
	_update_magazines()

	# Doigts : serrés sur l'arme, le couteau, la grenade ou en poing ; ouverts
	# pour pousser, parer, prendre appui ; détendus sinon.
	var curl := Vector2(0.35, 0.35)
	if is_armed:
		var held := 1.0 - smoothstep(0.35, 0.75, _sling)
		curl = curl.lerp(Vector2(0.95, 1.0), held)
		if prone:
			curl.x = lerpf(curl.x, 0.15, crawl)
	if not move.is_empty() and move.get("open", false):
		curl = Vector2(0.55, 0.55)
	elif uppercut or not kick.is_empty() or butt or not move.is_empty():
		curl = Vector2(1.0, 1.0)
	elif grapple:
		curl = Vector2(0.55, 1.0 if strike_move == StrikeMove.THROAT_CUT else 0.6)
	elif grabbed:
		curl = Vector2(0.7, 0.7)
	elif throwing:
		curl = Vector2(0.3, 1.0 if throw_t < THROW_RELEASE else 0.15)
	elif grip > 0.0 or (shove and not is_armed) or (parry and not block):
		curl = curl.lerp(Vector2(0.12, 0.12), maxf(grip, 1.0 if shove or parry else 0.0))
	elif strike > 0.0:
		curl.y = 1.0
	elif guard > 0.0:
		curl = curl.lerp(Vector2.ONE, guard)
	if reloading:
		curl.x = 0.85
	if pickup > 0.0:
		# Main ouverte en descendant, refermée sur l'objet en remontant.
		var grab := 0.1 if _pickup_time < PICKUP_DURATION * 0.5 else 0.9
		if is_armed and _sling < 0.5:
			curl.x = grab
		else:
			curl.y = grab
	_animate_fingers(curl, delta)

	effort = 1.0 if unarmed_strike or grapple or throwing or shove or strike > 0.0 or (grip > 0.0 and walk > 0.05) else 0.0
	pain = maxf(maxf(hit * _hit_strength, stagger), 1.0 if grabbed else 0.0)


## Mesure le déplacement réel du modèle depuis l'image précédente (le
## modèle ne connaît pas la vitesse de son unité, seulement `move_ratio`).
func _measure_motion(delta: float) -> void:
	if not is_inside_tree() or delta <= 0.0:
		return
	var position_now := global_position
	var moved := Vector3.ZERO if _last_position == Vector3.INF else position_now - _last_position
	_last_position = position_now
	# Téléportation (placement, escalade scriptée) : on l'ignore.
	if moved.length() > 0.5:
		moved = Vector3.ZERO
	var local := global_basis.inverse() * (moved / delta)
	_motion = _motion.lerp(Vector2(local.x, -local.z), 1.0 - exp(-12.0 * delta))


## Part du déplacement vers l'arrière (0 à 1).
func _backward() -> float:
	var speed := _motion.length()
	return 0.0 if speed < 0.3 else clampf(-_motion.y / speed, 0.0, 1.0)


## Part du déplacement sur le côté (0 à 1), au-delà de la marche en crabe.
func _sideways() -> float:
	var speed := _motion.length()
	return 0.0 if speed < 0.3 else smoothstep(0.55, 0.85, absf(_motion.x) / speed)


## Bruit de pas à chaque pied posé (deux par cycle), plus fort en courant,
## plus discret accroupi ; bruissement en rampant.
func _play_steps(walk: float, moving: float, prone: bool) -> void:
	var step := floori(_phase / PI)
	if step == _last_step:
		return
	_last_step = step
	if moving < 0.15 or not is_inside_tree() or silent:
		return
	if prone:
		Sfx.play_at(&"crawl", global_position, -16.0, 0.15)
		return
	var volume := -14.0
	if walk > 1.3:
		volume = -8.0
	elif posture == Posture.CROUCHED or crate_grip:
		volume = -18.0
	Sfx.play_at(&"step", global_position, volume, 0.12)


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
	var points: Array[Vector3] = [rifle * _left_grip, rifle * MAG_WELL, rifle * MAG_DROP, MAG_POUCH, rifle * MAG_BELOW, rifle * MAG_WELL, rifle * _left_grip]
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
	if _tube_fed:
		# Cartouche par cartouche : rien ne sort de l'arme, rien ne tombe.
		_rifle_mag.visible = true
		_hand_mag.visible = false
		return
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
	_hand_grenade.visible = false
	_update_magazines()
	_animate_fingers(Vector2(0.3, 0.3), delta)
	# Grimace pendant la chute, puis visage détendu.
	effort = 0.0
	pain = 1.0 - smoothstep(0.6, 1.4, t)


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
## Piste `name` du mouvement `move` à l'instant `t` (0 si elle manque).
static func _track(move: Dictionary, name: String, t: float) -> float:
	return sample_keys(move[name], t) if move.has(name) else 0.0


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
	if down and climb_jump:
		_animate_jump(delta, t)
		return
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
	_sling = move_toward(_sling, _sling_goal(), delta / SLING_TIME)
	var sling := maxf(_sling, sample_keys(CLIMB_DOWN_SLING if down else CLIMB_UP_SLING, t))
	_rifle.transform = _sling_transform(_rifle_hold, sling)
	_rifle_base = _rifle.transform
	_apply_arm_keys(CLIMB_DOWN_ARMS if down else CLIMB_UP_ARMS, t)
	effort = 0.0 if down else 1.0
	pain = 0.0
	_animate_fingers(_climb_curl(CLIMB_DOWN_ARMS if down else CLIMB_UP_ARMS, t), delta)


## Pose du saut depuis un mur à l'instant `t` (même squelette que l'escalade).
func _animate_jump(delta: float, t: float) -> void:
	_hips.position.y = sample_keys(JUMP_HIPS, t)
	var thigh := sample_keys(JUMP_THIGH, t)
	var knee := sample_keys(JUMP_KNEE, t)
	# Jambes légèrement décalées : on pose un pied après l'autre.
	_leg_l.rotation.x = thigh
	_knee_l.rotation.x = knee
	_leg_r.rotation.x = thigh * 0.9
	_knee_r.rotation.x = knee * 0.95
	_level_feet()
	_torso.rotation.x = sample_keys(JUMP_LEAN, t)
	_torso.rotation.y = 0.0
	_torso.rotation.z = 0.0
	_lean = _torso.rotation.x
	_torso_yaw = 0.0
	_head.rotation = Vector3(-0.6 * _torso.rotation.x, 0.0, 0.0)
	_sling = move_toward(_sling, _sling_goal(), delta / SLING_TIME)
	var sling := maxf(_sling, sample_keys(JUMP_SLING, t))
	_rifle.transform = _sling_transform(_rifle_hold, sling)
	_rifle_base = _rifle.transform
	_apply_arm_keys(JUMP_ARMS, t)
	_animate_fingers(_climb_curl(JUMP_ARMS, t), delta)


## Pose sur une échelle, face aux barreaux : mains sur les montants, qui
## montent l'une après l'autre ; chaque genou se lève avec la main opposée.
func _animate_ladder(delta: float) -> void:
	_transition_duration = 0.0
	var cycle := sin(fposmod(ladder_phase, 1.0) * TAU)
	var blend := 1.0 - exp(-25.0 * delta)
	_body.rotation.x = lerp_angle(_body.rotation.x, 0.0, blend)
	_body.rotation.z = lerp_angle(_body.rotation.z, 0.0, blend)
	_body.position = _body.position.lerp(Vector3.ZERO, blend)
	_hips.rotation.y = 0.0
	_hips.position.y = HIP_HEIGHT - 0.03
	_leg_l.rotation = Vector3(0.55 + 0.45 * cycle, 0.0, 0.0)
	_knee_l.rotation.x = -(0.85 + 0.75 * cycle)
	_leg_r.rotation = Vector3(0.55 - 0.45 * cycle, 0.0, 0.0)
	_knee_r.rotation.x = -(0.85 - 0.75 * cycle)
	_level_feet()
	_torso.rotation = Vector3(-0.1, 0.0, 0.0)
	_lean = _torso.rotation.x
	_torso_yaw = 0.0
	_head.rotation = Vector3(0.25, 0.0, 0.0)
	_sling = move_toward(_sling, 1.0 if is_armed else 0.0, delta / SLING_TIME)
	_rifle.transform = _sling_transform(_rifle_hold, _sling)
	_rifle_base = _rifle.transform
	var pose := _solve_arms(Vector3(-0.2, 0.52 - 0.16 * cycle, -0.3), Vector3(0.2, 0.52 + 0.16 * cycle, -0.3))
	for i in _arm_joints.size():
		_arm_joints[i].quaternion = pose[i]
	effort = 0.6
	pain = 0.0
	_animate_fingers(Vector2(0.9, 0.95), delta)


## Doigts pendant l'escalade : ouverts pour attraper et prendre appui,
## serrés sur l'arme sinon.
func _climb_curl(keys: Array[float], t: float) -> Vector2:
	var count := keys.size() / 2
	var index := 0
	while index < count - 1 and t > keys[(index + 1) * 2]:
		index += 1
	var pose := int(keys[index * 2 + 1])
	if pose == ArmPose.REACH or pose == ArmPose.PUSH:
		return Vector2(0.1, 0.1)
	return Vector2(0.95, 1.0) if is_armed and _sling < 0.5 else Vector2(0.35, 0.35)


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
		# Haut de cuisse (fessier) et cuisse effilée vers le genou.
		_ellipsoid(leg, 0.094 if _female else 0.088, Vector3(1.0, 0.9, 1.08), Vector3(0.012 * side if _female else 0.0, -0.03, 0.005), _m_pants)
		_tapered(leg, 0.084, 0.063, THIGH_LENGTH, Vector3(0.0, -0.22, 0.0), _m_pants).scale.z = 1.08
		if not civilian:
			# Poche cargo et son rabat.
			_box(leg, Vector3(0.035, 0.13, 0.115), Vector3(0.078 * side, -0.25, 0.0), _m_pants)
			_box(leg, Vector3(0.042, 0.03, 0.122), Vector3(0.08 * side, -0.175, 0.0), _m_pants)
		var knee := _pivot(leg, Vector3(0.0, -THIGH_LENGTH, 0.0), "Knee")
		_sphere(knee, 0.064, Vector3.ZERO, _m_pants)
		# Jambe et mollet, bas du pantalon bouffant sur la botte.
		_tapered(knee, 0.062, 0.05, 0.34, Vector3(0.0, -0.18, 0.0), _m_pants).scale.z = 1.08
		_ellipsoid(knee, 0.056, Vector3(0.95, 1.7, 0.9), Vector3(0.0, -0.13, 0.016), _m_pants)
		_tapered(knee, 0.056, 0.064, 0.05, Vector3(0.0, -0.335, 0.0), _m_pants)
		if _wears(&"knee_pads"):
			var pad := _ellipsoid(knee, 0.072, Vector3(1.0, 1.15, 0.55), Vector3(0.0, -0.02, -0.05), _m_gear)
			pad.name = "KneePad"
			_tapered(knee, 0.066, 0.066, 0.016, Vector3(0.0, -0.07, 0.0), _m_weapon)
		# Botte : tige, empeigne arrondie, lacets, semelle crantée.
		var ankle := _pivot(knee, Vector3(0.0, -SHIN_LENGTH, 0.0), "Ankle")
		_tapered(ankle, 0.058, 0.064, 0.15, Vector3(0.0, 0.035, 0.002), _m_boot)
		var foot := _capsule(ankle, 0.056, 0.27, Vector3(0.0, -0.026, -0.05), _m_boot)
		foot.rotation.x = PI / 2.0
		foot.scale = Vector3(1.0, 1.0, 0.72)
		_box(ankle, Vector3(0.04, 0.008, 0.11), Vector3(0.0, 0.016, -0.085), _m_weapon).rotation.x = -0.25
		_box(ankle, Vector3(0.118, 0.026, 0.285), Vector3(0.0, -0.067, -0.05), _m_sole)
		if side < 0.0:
			_leg_l = leg
			_knee_l = knee
			_ankle_l = ankle
		else:
			_leg_r = leg
			_knee_r = knee
			_ankle_r = ankle
			_build_sidearm(leg)


func _build_torso() -> void:
	_torso = _pivot(_hips, Vector3.ZERO, "Torso")
	# Bassin, ceinturon (boucle, poche).
	_ellipsoid(_torso, 0.19, Vector3(1.08 if _female else 1.0, 0.58 if _female else 0.55, 0.68 if _female else 0.66), Vector3(0.0, 0.03, 0.0), _m_pants)
	_tapered(_torso, 0.2, 0.2, 0.055, Vector3(0.0, 0.085, 0.0), _m_gear).scale.z = 0.68
	_box(_torso, Vector3(0.06, 0.045, 0.02), Vector3(0.0, 0.085, -0.137), _m_weapon)
	if not civilian:
		_box(_torso, Vector3(0.07, 0.09, 0.06), Vector3(-0.2, 0.05, 0.0), _m_gear)
	# Buste : taille, poitrine plus large, épaules arrondies, col.
	# Silhouette féminine : taille plus marquée, buste et épaules plus étroits.
	var waist := 0.85 if _female else 1.0
	var chest := 0.92 if _female else 1.0
	_tapered(_torso, 0.165 * waist, 0.172, 0.2, Vector3(0.0, 0.2, 0.0), _m_top).scale.z = 0.62
	_tapered(_torso, 0.2 * chest, 0.168 * waist, 0.24, Vector3(0.0, 0.4, 0.0), _m_top).scale.z = 0.6
	if _female:
		for side: float in [-1.0, 1.0]:
			_ellipsoid(_torso, 0.058, Vector3(1.0, 0.85, 0.75), Vector3(0.062 * side, 0.385, -0.085), _m_top).name = "BustL" if side < 0.0 else "BustR"
	var shoulders := _capsule(_torso, 0.065 if _female else 0.07, 0.47 if _female else 0.52, Vector3(0.0, 0.5, 0.0), _m_top)
	shoulders.rotation.z = PI / 2.0
	shoulders.scale = Vector3(1.0, 1.0, 0.95)
	_tapered(_torso, 0.068 * (0.88 if _female else 1.0), 0.08, 0.04, Vector3(0.0, 0.565, 0.005), _m_top)
	var front := -0.12
	if _wears(&"vest") and not _guard_look.is_empty():
		front = -0.16
		_build_chest_rig()
	elif _wears(&"vest"):
		front = -0.155
		var vest := _pivot(_torso, Vector3.ZERO, "Vest")
		# Porte-plaques : ceinture élastique, plaques avant et arrière, bretelles.
		_tapered(vest, 0.205, 0.2, 0.15, Vector3(0.0, 0.22, 0.0), _m_gear).scale.z = 0.7
		_box(vest, Vector3(0.3, 0.29, 0.035), Vector3(0.0, 0.4, -0.137), _m_gear)
		_box(vest, Vector3(0.31, 0.33, 0.035), Vector3(0.0, 0.38, 0.135), _m_gear)
		for side: float in [-1.0, 1.0]:
			_box(vest, Vector3(0.075, 0.028, 0.29), Vector3(0.12 * side, 0.556, 0.0), _m_gear)
		# Trois porte-chargeurs à rabat.
		for i in 3:
			var x := (float(i) - 1.0) * 0.1
			_box(vest, Vector3(0.088, 0.16, 0.05), Vector3(x, 0.27, -0.177), _m_gear)
			_box(vest, Vector3(0.06, 0.035, 0.035), Vector3(x, 0.365, -0.17), _m_weapon)
			_box(vest, Vector3(0.09, 0.012, 0.054), Vector3(x, 0.35, -0.178), _m_gear)
		# Poche utilitaire et écusson de poitrine.
		_box(vest, Vector3(0.14, 0.07, 0.03), Vector3(0.0, 0.46, -0.168), _m_gear)
		_box(vest, Vector3(0.08, 0.035, 0.01), Vector3(0.0, 0.465, -0.186), _m_team)
	elif civilian:
		_build_suit()
	else:
		# Sans gilet : poche de poitrine et écusson sur la veste, chargeurs au
		# ceinturon.
		_box(_torso, Vector3(0.1, 0.09, 0.02), Vector3(0.09, 0.4, -0.122), _m_top)
		_box(_torso, Vector3(0.07, 0.03, 0.01), Vector3(0.09, 0.465, -0.122), _m_team)
		for x: float in [-0.07, 0.07]:
			_box(_torso, Vector3(0.07, 0.12, 0.05), Vector3(x, 0.03, -0.145), _m_gear)
			_box(_torso, Vector3(0.05, 0.03, 0.03), Vector3(x, 0.1, -0.145), _m_weapon)
	var back := 0.15 if _wears(&"vest") else 0.12
	if _wears(&"backpack"):
		# Sac d'assaut.
		var pack := _pivot(_torso, Vector3.ZERO, "Backpack")
		_box(pack, Vector3(0.30, 0.36, 0.14), Vector3(0.0, 0.34, back + 0.06), _m_gear)
		_box(pack, Vector3(0.22, 0.14, 0.05), Vector3(0.0, 0.28, back + 0.145), _m_gear)
		back += 0.03
	if _wears(&"radio"):
		# Radio et antenne, sur le sac ou à l'épaule.
		var radio := _pivot(_torso, Vector3.ZERO, "Radio")
		_box(radio, Vector3(0.07, 0.16, 0.05), Vector3(-0.12, 0.47, back), _m_weapon)
		_cylinder(radio, 0.006, 0.38, Vector3(-0.12, 0.72, back), _m_weapon)
	_build_equipment(front)
	_build_specialty(front, back)


## Grappin emporté : rouleau de corde au flanc gauche, griffes repliées
## au-dessus.
func _build_grapnel() -> void:
	if not (carries_grapnel or (outfit != null and outfit.grapnel > 0)):
		return
	var kit := _pivot(_torso, Vector3.ZERO, "Grapnel")
	var back := 0.14 if _wears(&"vest") else 0.11
	var coil := MeshInstance3D.new()
	coil.name = "Coil"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.075
	torus.outer_radius = 0.125
	coil.mesh = torus
	coil.material_override = _mat(Color(0.55, 0.47, 0.3), 1.0)
	coil.position = Vector3(-0.2, 0.12, back)
	coil.rotation = Vector3(0.0, 0.0, PI / 2.0)
	kit.add_child(coil)
	var steel := _mat(Color(0.3, 0.32, 0.34), 0.4, 0.8)
	_cylinder(kit, 0.015, 0.16, Vector3(-0.2, 0.27, back), steel)


## Bouclier balistique : panneau, rebord, hublot de visée, bande
## réfléchissante et poignée à l'arrière ; dans le dos au départ.
func _build_shield() -> void:
	if not (carries_shield or (outfit != null and outfit.shield > 0)):
		return
	var back := 0.15 if _wears(&"vest") else 0.12
	if _wears(&"backpack"):
		back += 0.17
	_shield_back = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.32, back + 0.03))
	_shield = _pivot(_torso, Vector3.ZERO, "Shield")
	_shield.transform = _shield_back
	var panel := _mat(Color(0.11, 0.11, 0.12), 0.55, 0.25)
	var rim := _mat(Color(0.05, 0.05, 0.05), 0.9)
	var glass := _mat(Color(0.12, 0.2, 0.26), 0.08, 0.7)
	var w := SHIELD_SIZE.x
	var h := SHIELD_SIZE.y
	_box(_shield, Vector3(w, h, 0.025), Vector3.ZERO, panel).name = "Panel"
	for side: float in [-1.0, 1.0]:
		_box(_shield, Vector3(0.02, h + 0.02, 0.035), Vector3((w * 0.5) * side, 0.0, 0.0), rim)
		_box(_shield, Vector3(w, 0.02, 0.035), Vector3(0.0, (h * 0.5) * side, 0.0), rim)
	# Hublot à hauteur des yeux, bande d'identification.
	_box(_shield, Vector3(0.26, 0.075, 0.03), Vector3(0.0, 0.31, 0.0), glass).name = "Viewport"
	_box(_shield, Vector3(0.42, 0.035, 0.006), Vector3(0.0, -0.05, -0.016), _m_team)
	# Poignée verticale et brassière, à l'arrière.
	_box(_shield, Vector3(0.03, 0.14, 0.03), SHIELD_HANDLE, rim)
	for y: float in [-0.07, 0.07]:
		_box(_shield, Vector3(0.025, 0.02, 0.06), Vector3(0.0, y, 0.035), rim)
	_box(_shield, Vector3(0.12, 0.03, 0.04), Vector3(0.0, -0.2, 0.04), rim)


## Fait passer le bouclier du dos à l'avant (par le flanc gauche) selon
## `shield_raised`. Devant, il est tenu dans l'axe du corps, quels que
## soient l'inclinaison et l'épaulement du buste. Renvoie sa levée (0 à 1).
func _update_shield(delta: float, prone: bool) -> float:
	if _shield == null:
		return 0.0
	# Le bouclier attend que l'arme principale ait quitté les mains.
	var hands_free := _sidearm_built or _sling >= 0.95 or not is_armed
	_shield_up = move_toward(_shield_up, 1.0 if shield_raised and not prone and not is_dead and hands_free else 0.0, delta / SHIELD_TIME)
	var up := smoothstep(0.0, 1.0, _shield_up)
	var to_torso := (_body.transform * _hips.transform * _torso.transform).affine_inverse()
	var front := to_torso * Transform3D(Basis.IDENTITY, Vector3(-0.04, _hips.position.y + 0.36, -0.44))
	var side := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-0.34, 0.3, 0.0))
	if up < 0.5:
		_shield.transform = _shield_back.interpolate_with(side, up * 2.0)
	else:
		_shield.transform = side.interpolate_with(front, up * 2.0 - 1.0)
	return up


## Vrai si le bouclier est levé.
func is_shield_up() -> bool:
	return _shield != null and _shield_up >= SHIELD_GUARD


## Point où le tir `from` → `to` frappe le bouclier levé (tireur devant,
## cible derrière), ou `Vector3.INF`.
func shield_blocks(from: Vector3, to: Vector3) -> Vector3:
	if not is_shield_up() or not _shield.is_inside_tree():
		return Vector3.INF
	var frame := _shield.global_transform
	var a := frame.affine_inverse() * from
	var b := frame.affine_inverse() * to
	if a.z >= 0.0 or b.z < 0.0:
		return Vector3.INF
	var hit := a.lerp(b, a.z / (a.z - b.z))
	if absf(hit.x) > SHIELD_SIZE.x * 0.5 or absf(hit.y) > SHIELD_SIZE.y * 0.5:
		return Vector3.INF
	return frame * hit


## Costume d'un civil : plastron et col de chemise, cravate, revers de la
## veste, boutons et pochette.
func _build_suit() -> void:
	var suit := _pivot(_torso, Vector3.ZERO, "Suit")
	var lapel_material := _mat((_m_top.albedo_color as Color).darkened(0.25), 0.7)
	var tie_material := _mat(Color(0.45, 0.08, 0.1), 0.5)
	_box(suit, Vector3(0.1, 0.17, 0.012), Vector3(0.0, 0.47, -0.107), _m_white).rotation.x = -0.1
	_tapered(suit, 0.074, 0.084, 0.035, Vector3(0.0, 0.555, 0.004), _m_white)
	_box(suit, Vector3(0.034, 0.03, 0.02), Vector3(0.0, 0.535, -0.106), tie_material)
	var tie := _box(suit, Vector3(0.036, 0.17, 0.01), Vector3(0.0, 0.44, -0.114), tie_material)
	tie.rotation.x = -0.1
	for side: float in [-1.0, 1.0]:
		var lapel := _box(suit, Vector3(0.05, 0.19, 0.012), Vector3(0.062 * side, 0.45, -0.112), lapel_material)
		lapel.rotation = Vector3(-0.1, 0.0, 0.32 * side)
	for y: float in [0.33, 0.25]:
		_sphere(suit, 0.009, Vector3(0.0, y, -0.108), _m_weapon)
	_box(suit, Vector3(0.05, 0.018, 0.008), Vector3(-0.1, 0.43, -0.11), _m_white)


## Apparence d'un soldat ennemi : visage, cheveux, barbe et couvre-chef,
## toujours la même pour un même nœud.
func _pick_guard_look() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(get_path())) if is_inside_tree() else 0
	var headwear: StringName = [&"helmet", &"helmet", &"cap", &"beret"][rng.randi() % 4]
	return {
		"skin": rng.randi() % GearCatalog.SKINS.size(),
		"hair_color": rng.randi() % GearCatalog.HAIR_COLORS.size(),
		"hair_style": [&"short", &"short", &"shaved"][rng.randi() % 3],
		"beard": [&"none", &"stubble", &"full"][rng.randi() % 3],
		"headwear": headwear,
		"headwear_color": [Color(0.42, 0.1, 0.1), Color(0.15, 0.15, 0.13), Color(0.3, 0.32, 0.2)][rng.randi() % 3],
		"radio": rng.randf() < 0.4,
	}


## Équipement qui distingue la spécialité au premier coup d'œil.
func _build_specialty(front: float, back: float) -> void:
	var specialty := &"none" if outfit == null else outfit.specialty
	if specialty == &"none":
		return
	var gear := _pivot(_torso, Vector3.ZERO, "Specialty")
	match specialty:
		&"marksman":
			# Écharpe de camouflage au cou, télémètre, tapis de tir roulé
			# en travers du haut du dos.
			var scarf := _tapered(gear, 0.088, 0.105, 0.06, Vector3(0.0, 0.565, 0.008), _m_scrim)
			scarf.scale.z = 0.9
			for side: float in [-1.0, 1.0]:
				var tail := _box(gear, Vector3(0.05, 0.16, 0.012), Vector3(0.035 * side, 0.47, back + 0.005), _m_scrim)
				tail.rotation.z = 0.15 * side
			_box(gear, Vector3(0.05, 0.09, 0.04), Vector3(0.11, 0.45, front - 0.02), _m_gear)
			_box(gear, Vector3(0.035, 0.03, 0.05), Vector3(0.11, 0.51, front - 0.02), _m_weapon)
			var mat := _cylinder(gear, 0.055, 0.46, Vector3(0.0, 0.6, back + 0.05), _m_scrim)
			mat.rotation.z = PI / 2.0
			for side: float in [-1.0, 1.0]:
				var band := _cylinder(gear, 0.058, 0.02, Vector3(0.15 * side, 0.6, back + 0.05), _m_weapon)
				band.rotation.z = PI / 2.0
		&"scout":
			# Jumelles sur la poitrine, poche à eau plate dans le dos.
			for side: float in [-1.0, 1.0]:
				var tube := _cylinder(gear, 0.026, 0.1, Vector3(0.032 * side, 0.48, front - 0.04), _m_weapon)
				tube.rotation.x = 0.15
				_cylinder(gear, 0.021, 0.006, Vector3(0.032 * side, 0.428, front - 0.033), _m_lens)
			_box(gear, Vector3(0.03, 0.03, 0.02), Vector3(0.0, 0.5, front - 0.04), _m_weapon)
			if not _wears(&"backpack"):
				_box(gear, Vector3(0.2, 0.3, 0.05), Vector3(0.0, 0.36, back + 0.025), _m_gear)
				var hose := _cylinder(gear, 0.008, 0.3, Vector3(0.1, 0.45, front + 0.07), _m_weapon)
				hose.rotation.x = 0.25
		&"sapper":
			# Pied-de-biche d'effraction en travers du dos, bobine de
			# cordeau détonant sur la hanche.
			var bar := _box(gear, Vector3(0.026, 0.72, 0.026), Vector3(0.0, 0.38, back + (0.12 if _wears(&"backpack") else 0.03)), _m_steel)
			bar.rotation.z = 0.75
			var fork := _box(bar, Vector3(0.07, 0.03, 0.02), Vector3(0.0, 0.37, 0.0), _m_steel)
			fork.rotation.x = 0.4
			var spool := _cylinder(gear, 0.05, 0.05, Vector3(-0.22, 0.02, 0.06), _m_red)
			spool.rotation.z = PI / 2.0
			_cylinder(gear, 0.025, 0.055, Vector3(-0.22, 0.02, 0.06), _m_weapon).rotation.z = PI / 2.0
		&"medic":
			# Grand sac de soins à la hanche droite, croix rouge sur fond blanc.
			var bag := _box(gear, Vector3(0.09, 0.16, 0.2), Vector3(0.23, 0.0, 0.03), _m_gear)
			_box(bag, Vector3(0.004, 0.08, 0.08), Vector3(0.047, 0.0, 0.0), _m_white)
			_box(bag, Vector3(0.006, 0.06, 0.018), Vector3(0.048, 0.0, 0.0), _m_red)
			_box(bag, Vector3(0.006, 0.018, 0.06), Vector3(0.048, 0.0, 0.0), _m_red)


## Gilet des ennemis : panneau ventral de quatre porte-chargeurs ouverts,
## bretelles croisées dans le dos, pas de plaques.
func _build_chest_rig() -> void:
	var rig := _pivot(_torso, Vector3.ZERO, "Vest")
	_box(rig, Vector3(0.3, 0.17, 0.03), Vector3(0.0, 0.3, -0.135), _m_gear)
	for i in 4:
		var x := (float(i) - 1.5) * 0.072
		_box(rig, Vector3(0.062, 0.12, 0.045), Vector3(x, 0.29, -0.165), _m_gear)
		_box(rig, Vector3(0.04, 0.05, 0.03), Vector3(x, 0.36, -0.163), _m_weapon)
	_tapered(rig, 0.2, 0.2, 0.05, Vector3(0.0, 0.24, 0.0), _m_gear).scale.z = 0.66
	for side: float in [-1.0, 1.0]:
		_box(rig, Vector3(0.05, 0.02, 0.28), Vector3(0.1 * side, 0.556, 0.0), _m_gear)
		_strap(Vector3(0.12 * side, 0.54, 0.125), Vector3(-0.12 * side, 0.26, 0.125), 0.045, 0.012, _m_gear, rig)
		_strap(Vector3(0.1 * side, 0.54, -0.13), Vector3(0.11 * side, 0.36, -0.15), 0.045, 0.012, _m_gear, rig)


## Équipement visible : grenades et charges au ceinturon, trousse de soins
## dans le dos, fourreaux des couteaux de lancer sur la poitrine (`front` :
## devant du buste).
func _build_equipment(front: float) -> void:
	if outfit == null:
		return
	var grenade_spots: Array[Vector3] = [Vector3(0.17, 0.03, -0.1), Vector3(-0.165, 0.03, -0.1), Vector3(0.21, 0.03, 0.0), Vector3(-0.2, 0.03, 0.08)]
	for i in outfit.grenades:
		var grenade := _pivot(_torso, grenade_spots[i], "Grenade%d" % (i + 1))
		_sphere(grenade, 0.034, Vector3.ZERO, _m_grenade)
		_box(grenade, Vector3(0.012, 0.035, 0.014), Vector3(0.0, 0.035, -0.02), _m_steel)
	for i in outfit.explosives:
		var charge := _box(_torso, Vector3(0.09, 0.06, 0.045), Vector3(0.125 * (1.0 if i == 0 else -1.0), 0.05, 0.14), _m_explosive)
		charge.name = "Explosive%d" % (i + 1)
		_box(charge, Vector3(0.012, 0.012, 0.05), Vector3(0.025, 0.035, 0.0), _m_red)
	if outfit.medkit > 0:
		var kit := _box(_torso, Vector3(0.08, 0.08, 0.05), Vector3(0.0, 0.05, 0.145), _m_gear)
		kit.name = "Medkit"
		_box(kit, Vector3(0.05, 0.014, 0.004), Vector3(0.0, 0.0, 0.026), _m_red)
		_box(kit, Vector3(0.014, 0.05, 0.004), Vector3(0.0, 0.0, 0.026), _m_red)
	for i in outfit.throwing_knives:
		var sheath := _pivot(_torso, Vector3(-0.115 - 0.035 * i, 0.36, front - 0.02), "ThrowingKnife%d" % (i + 1))
		_box(sheath, Vector3(0.026, 0.13, 0.016), Vector3.ZERO, _m_gear)
		_box(sheath, Vector3(0.02, 0.05, 0.014), Vector3(0.0, 0.09, 0.0), _m_weapon)


## Arme secondaire dans son holster, sur la cuisse droite.
func _build_sidearm(leg: Node3D) -> void:
	var kind := &"pistol" if outfit == null else outfit.secondary
	if kind == &"none":
		return
	var holster := _pivot(leg, Vector3.ZERO, "Sidearm")
	if _sidearm_built:
		# Arme en main : holster vide.
		_box(holster, Vector3(0.05, 0.20, 0.12), Vector3(0.115, -0.20, 0.0), _m_gear)
		return
	if kind == &"machine_pistol":
		_box(holster, Vector3(0.06, 0.24, 0.13), Vector3(0.12, -0.21, 0.0), _m_gear)
		_box(holster, Vector3(0.04, 0.09, 0.13), Vector3(0.125, -0.06, 0.02), _m_weapon)
		_box(holster, Vector3(0.025, 0.07, 0.03), Vector3(0.125, -0.02, 0.05), _m_weapon)
		return
	_box(holster, Vector3(0.05, 0.20, 0.12), Vector3(0.115, -0.20, 0.0), _m_gear)
	_box(holster, Vector3(0.035, 0.07, 0.10), Vector3(0.12, -0.07, 0.02), _m_weapon)


## Vrai si l'opérateur porte l'accessoire `accessory` (toujours, sans profil).
func _wears(accessory: StringName) -> bool:
	if not _guard_look.is_empty():
		return accessory == &"vest" or (accessory == &"radio" and _guard_look["radio"])
	return outfit == null or bool(outfit.get(accessory))


## Tissu de couleur `color`, ou du camouflage de `outfit` s'il y en a un
## (texture plaquée en triplanaire dans le repère de chaque pièce), avec
## plis et coutures en relief (`fabric_normal_map`).
func _cloth(color: Color) -> StandardMaterial3D:
	var material := _mat(color, 0.95)
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 2.5
	material.normal_enabled = true
	material.normal_texture = fabric_normal_map()
	material.normal_scale = 0.8
	if outfit and not outfit.camo.is_empty():
		material.albedo_color = Color.WHITE
		material.albedo_texture = GearCatalog.camo_texture(outfit.camo)
	return material


## Toile du gilet et des poches : même relief, plus serré et plus discret.
func _webbing(color: Color) -> StandardMaterial3D:
	var material := _mat(color, 0.85)
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 6.0
	material.normal_enabled = true
	material.normal_texture = fabric_normal_map()
	material.normal_scale = 0.35
	return material


const FABRIC_SIZE := 256
## Écart (pixels) entre deux coutures de la texture de tissu.
const FABRIC_SEAM := 128
static var _fabric_cache: Texture2D


## Carte normale répétable du tissu, générée une fois : plis (crêtes d'un
## bruit doux), trame fine et coutures piquées.
static func fabric_normal_map() -> Texture2D:
	if _fabric_cache:
		return _fabric_cache
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.012
	noise.fractal_octaves = 2
	var folds := noise.get_seamless_image(FABRIC_SIZE, FABRIC_SIZE)
	var image := Image.create(FABRIC_SIZE, FABRIC_SIZE, false, Image.FORMAT_RGBA8)
	for y in FABRIC_SIZE:
		for x in FABRIC_SIZE:
			var n := folds.get_pixel(x, y).r
			# Pli : crête étroite là où le bruit passe par sa valeur médiane.
			var height := 0.55 * (1.0 - absf(2.0 * n - 1.0)) ** 3
			height += 0.04 * sin(x * PI * 0.5) * sin(y * PI * 0.5)
			var seam := y % FABRIC_SEAM
			if seam < 3:
				height -= 0.25
			elif seam < 6 and x % 8 < 4:
				height += 0.12
			image.set_pixel(x, y, Color(height, height, height))
	image.bump_map_to_normal_map(6.0)
	image.generate_mipmaps()
	_fabric_cache = ImageTexture.create_from_image(image)
	return _fabric_cache


func _build_head() -> void:
	_head = _pivot(_torso, Vector3(0.0, 0.57, 0.0), "Head")
	var masked := _wears(&"balaclava")
	var neck := 0.86 if _female else 1.0
	_tapered(_head, 0.05 * neck, 0.057 * neck, 0.12, Vector3(0.0, 0.035, 0.008), _m_gear if masked else _m_skin)
	if masked:
		# Tête sous cagoule : seuls les yeux et l'arête du nez se voient.
		_head_shape(_m_gear).name = "Balaclava"
		var opening := _ellipsoid(_head, 0.06, Vector3(1.05, 0.36, 0.5), Vector3(0.0, 0.192, -0.078), _m_skin)
		opening.name = "EyeOpening"
		_build_eyes()
	else:
		_build_face()
	if outfit:
		match outfit.headwear:
			&"helmet":
				_build_operator_helmet(outfit.wears_nvg(), outfit.headset)
			&"none":
				if outfit.headset:
					_build_ear_cups(0.12)
					_box(_head, Vector3(0.25, 0.015, 0.03), Vector3(0.0, 0.3, 0.0), _m_weapon)
			_:
				_build_soft_headwear(outfit.headwear)
				if outfit.headset:
					_build_ear_cups(0.12)
		return
	if _guard_look.is_empty():
		_build_operator_helmet(true, true)
		return
	match _guard_look["headwear"]:
		&"helmet":
			_build_guard_helmet()
		var kind:
			_build_soft_headwear(kind)


## Casque ancien des soldats ennemis : bombe arrondie sous un couvre-casque
## en toile, bord évasé tout autour, bande élastique et jugulaire.
func _build_guard_helmet() -> void:
	var dome := SphereMesh.new()
	dome.radius = 0.142
	dome.height = 0.142
	dome.is_hemisphere = true
	var helmet := _mesh(_head, dome, Vector3(0.0, 0.18, 0.008), _m_helmet)
	helmet.name = "Helmet"
	helmet.scale = Vector3(1.0, 1.02, 1.1)
	var rim := _tapered(_head, 0.142, 0.158, 0.028, Vector3(0.0, 0.17, 0.008), _m_helmet)
	rim.scale.z = 1.1
	var band := _tapered(_head, 0.137, 0.14, 0.02, Vector3(0.0, 0.225, 0.008), _m_dark)
	band.scale.z = 1.1
	for side: float in [-1.0, 1.0]:
		_strap(Vector3(0.135 * side, 0.17, 0.02), Vector3(0.07 * side, 0.06, -0.06), 0.012, 0.004, _m_dark)


## Visage découvert : tête, yeux, sourcils, nez, cheveux et barbe d'`outfit`.
func _build_face() -> void:
	_head_shape(_m_skin).name = "Face"
	for side: float in [-1.0, 1.0]:
		# Oreille.
		_ellipsoid(_head, 0.024, Vector3(0.45, 1.0, 0.75), Vector3(0.1 * side, 0.18, 0.014), _m_skin)
	_build_eyes()
	var nose := MeshInstance3D.new()
	nose.name = "Nose"
	nose.mesh = _nose_mesh(_female)
	nose.material_override = _m_skin
	_head.add_child(nose)
	var beard: StringName = _guard_look.get("beard", &"none") if outfit == null else outfit.beard
	if _female:
		beard = &"none"
	# Lèvres posées sur la peau, ou sur la barbe qui la recouvre ; à moitié
	# enfoncées pour rester collées au visage malgré sa courbure.
	var lips_depth := face_depth(0.0, MOUTH_HEIGHT, _female)
	match beard:
		&"stubble", &"full":
			lips_depth = _beard_point(MOUTH_HEIGHT, 0.0, beard == &"full").z
	lips_depth += 0.003
	_mouth = _ellipsoid(_head, 0.023 if _female else 0.02, MOUTH_REST, Vector3(0.0, MOUTH_HEIGHT, lips_depth), _m_lip)
	_mouth.name = "Mouth"
	# Intérieur de la bouche, visible quand elle s'ouvre (douleur).
	_mouth_inner = _ellipsoid(_head, 0.016, Vector3(1.2, 0.01, 0.4), Vector3(0.0, MOUTH_HEIGHT - 0.001, lips_depth - 0.004), _m_dark)
	_mouth_inner.visible = false
	var style: StringName = _guard_look.get("hair_style", &"short") if outfit == null else outfit.hair_style
	# Sous un couvre-chef, seuls l'arrière du crâne et la queue de cheval
	# dépassent.
	var covered := (outfit != null and outfit.headwear != &"none") or not _guard_look.is_empty()
	if style != &"shaved":
		# Arrière et côtés du crâne.
		_ellipsoid(_head, 0.1, Vector3(0.96, 0.72, 0.92), Vector3(0.0, 0.2, 0.042), _m_hair)
		if not covered:
			var cap := SphereMesh.new()
			cap.radius = 0.11
			cap.height = 0.11
			cap.is_hemisphere = true
			var hair := _mesh(_head, cap, Vector3(0.0, 0.212, 0.012), _m_hair)
			hair.name = "Hair"
			hair.scale = Vector3(0.96, 0.92, 1.05)
			hair.rotation.x = 0.3
	match style:
		&"ponytail":
			var tail := _capsule(_head, 0.024, 0.15, Vector3(0.0, 0.15, 0.135), _m_hair)
			tail.rotation.x = 0.45
			_sphere(_head, 0.018, Vector3(0.0, 0.195, 0.12), _m_gear)
		&"bun":
			_sphere(_head, 0.045, Vector3(0.0, 0.2, 0.125), _m_hair).name = "Bun"
		&"long":
			# Mèches qui encadrent le visage et tombent sur la nuque et les
			# épaules (visibles sous un casque).
			var back := _ellipsoid(_head, 0.1, Vector3(1.0, 1.45, 0.5), Vector3(0.0, 0.07, 0.075), _m_hair)
			back.name = "LongHair"
			back.rotation.x = -0.15
			for side: float in [-1.0, 1.0]:
				_ellipsoid(_head, 0.06, Vector3(0.38, 1.6, 0.9), Vector3(0.092 * side, 0.115, 0.01), _m_hair)
		&"mohawk":
			if not covered:
				_box(_head, Vector3(0.032, 0.05, 0.22), Vector3(0.0, 0.31, 0.005), _m_hair)
	match beard:
		&"stubble":
			_mesh(_head, _beard_mesh(false), Vector3.ZERO, _m_stubble).name = "Beard"
		&"full":
			_mesh(_head, _beard_mesh(true), Vector3.ZERO, _m_hair).name = "Beard"
			# Moustache, entre le nez et la lèvre.
			_ellipsoid(_head, 0.022, Vector3(1.7, 0.4, 0.55), Vector3(0.0, 0.131, face_depth(0.0, 0.131) - 0.004), _m_hair)


## Volume de la tête : un seul maillage lissé, crâne arrondi et mâchoire
## plus étroite jusqu'au menton (partagé par tous les modèles).
func _head_shape(material: Material) -> MeshInstance3D:
	var head := MeshInstance3D.new()
	head.mesh = _head_mesh(_female)
	head.material_override = material
	_head.add_child(head)
	return head


## Hauteur de la bouche (repère de la tête).
const MOUTH_HEIGHT := 0.119
## Barbe : coque qui épouse la mâchoire, sous le nez, remontant en favoris
## jusqu'aux oreilles ; épaisseur (m) en haut et au menton.
const BEARD_TOP := 0.136
const BEARD_SIDEBURN := 0.04
const BEARD_SPREAD := 1.75
const STUBBLE_THICKNESS := Vector2(0.0025, 0.004)
const FULL_BEARD_THICKNESS := Vector2(0.007, 0.024)

static var _beard_cache: Array[ArrayMesh] = [null, null]


## Point de la barbe à la hauteur `y` et à l'angle `phi` (0 : devant) autour
## de la tête masculine.
static func _beard_point(y: float, phi: float, full: bool) -> Vector3:
	var dy := clampf((y - HEAD_CENTER.y) / HEAD_RADII.z, -1.0, 0.0)
	var ring := sqrt(1.0 - dy * dy)
	var t := -dy
	var skin := Vector3(
		ring * sin(phi) * HEAD_RADII.x * (1.0 - 0.2 * t * t),
		dy * HEAD_RADII.z,
		-ring * cos(phi) * HEAD_RADII.w * (1.0 - 0.12 * t * t))
	if skin.z < 0.0:
		skin.z *= 1.0 + 0.08 * t
	var thickness := STUBBLE_THICKNESS if not full else FULL_BEARD_THICKNESS
	var depth := lerpf(thickness.x, thickness.y, smoothstep(0.5, 1.0, t))
	return HEAD_CENTER + skin * (1.0 + depth / maxf(skin.length(), 0.001))


static func _beard_mesh(full: bool) -> ArrayMesh:
	var variant := 1 if full else 0
	if _beard_cache[variant]:
		return _beard_cache[variant]
	var rows := 12
	var columns := 20
	var bottom := HEAD_CENTER.y - HEAD_RADII.z
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows + 1:
		for j in columns + 1:
			var phi := lerpf(-BEARD_SPREAD, BEARD_SPREAD, float(j) / columns)
			var top := BEARD_TOP + BEARD_SIDEBURN * absf(sin(phi))
			tool.add_vertex(_beard_point(lerpf(top, bottom, float(i) / rows), phi, full))
	for i in rows:
		for j in columns:
			var a := i * (columns + 1) + j
			var b := a + columns + 1
			for index: int in [a, b, a + 1, a + 1, b, b + 1]:
				tool.add_index(index)
	tool.generate_normals()
	_beard_cache[variant] = tool.commit()
	return _beard_cache[variant]

const HEAD_CENTER := Vector3(0.0, 0.195, 0.008)
## Demi-largeur, demi-hauteurs (au-dessus et au-dessous du centre) et
## demi-profondeur de la tête.
const HEAD_RADII := Vector4(0.0998, 0.1134, 0.141, 0.11)

## Profondeur (z, vers l'avant négatif) de la surface du visage au point
## (`x`, `y`) du repère de la tête : même calcul que `_head_mesh`.
static func face_depth(x: float, y: float, female: bool = false) -> float:
	var size := 0.96 if female else 1.0
	var jaw := 0.3 if female else 0.2
	var chin := 0.04 if female else 0.08
	var dy := (y - HEAD_CENTER.y) / (size * (HEAD_RADII.y if y > HEAD_CENTER.y else HEAD_RADII.z))
	dy = clampf(dy, -1.0, 1.0)
	var ring := sqrt(1.0 - dy * dy)
	var t := maxf(-dy, 0.0)
	var half_width := size * HEAD_RADII.x * (1.0 - jaw * t * t) * ring
	var side := clampf(x / maxf(half_width, 0.0001), -1.0, 1.0)
	var depth := ring * sqrt(1.0 - side * side) * HEAD_RADII.w * (1.0 - 0.12 * t * t) * (1.0 + chin * t)
	return HEAD_CENTER.z - size * depth


## Nez : arête qui part d'entre les yeux, bout arrondi, ailes et narines,
## ancré dans la surface du visage (`face_depth`).
static var _nose_cache: Array[ArrayMesh] = [null, null]


static func _nose_mesh(female: bool) -> ArrayMesh:
	var variant := 1 if female else 0
	if _nose_cache[variant]:
		return _nose_cache[variant]
	var k := 0.85 if female else 1.0
	# Points : x, y, avancée devant la surface du visage (négatif : enfoncé).
	var spec := {
		"root": Vector3(0.0, 0.19, 0.002),
		"bridge_l": Vector3(-0.009, 0.175, 0.004), "bridge_r": Vector3(0.009, 0.175, 0.004),
		"ridge": Vector3(0.0, 0.168, 0.016),
		"tip": Vector3(0.0, 0.148, 0.028),
		"tip_l": Vector3(-0.01, 0.147, 0.021), "tip_r": Vector3(0.01, 0.147, 0.021),
		"wing_l": Vector3(-0.017, 0.141, 0.008), "wing_r": Vector3(0.017, 0.141, 0.008),
		"base": Vector3(0.0, 0.137, 0.011),
		"nostril_l": Vector3(-0.009, 0.138, 0.009), "nostril_r": Vector3(0.009, 0.138, 0.009),
		# Ancrages sous la peau.
		"in_root": Vector3(0.0, 0.195, -0.006),
		"in_l": Vector3(-0.016, 0.168, -0.004), "in_r": Vector3(0.016, 0.168, -0.004),
		"in_wing_l": Vector3(-0.022, 0.139, -0.004), "in_wing_r": Vector3(0.022, 0.139, -0.004),
		"in_base": Vector3(0.0, 0.132, -0.004),
	}
	var points := {}
	for key: String in spec:
		var p: Vector3 = spec[key]
		var x := p.x * k
		var y := 0.142 + (p.y - 0.142) * k
		points[key] = Vector3(x, y, face_depth(x, y, female) - p.z * k)
	var triangles := [
		["in_root", "root", "bridge_l"], ["in_root", "bridge_r", "root"],
		["root", "ridge", "bridge_l"], ["root", "bridge_r", "ridge"],
		["in_root", "bridge_l", "in_l"], ["in_root", "in_r", "bridge_r"],
		["bridge_l", "ridge", "tip_l"], ["ridge", "bridge_r", "tip_r"],
		["ridge", "tip", "tip_l"], ["ridge", "tip_r", "tip"],
		["in_l", "bridge_l", "wing_l"], ["bridge_l", "tip_l", "wing_l"],
		["in_r", "wing_r", "bridge_r"], ["bridge_r", "wing_r", "tip_r"],
		["in_l", "wing_l", "in_wing_l"], ["in_r", "in_wing_r", "wing_r"],
		["tip_l", "tip", "nostril_l"], ["tip", "tip_r", "nostril_r"],
		["tip", "base", "nostril_l"], ["tip", "nostril_r", "base"],
		["tip_l", "nostril_l", "wing_l"], ["tip_r", "wing_r", "nostril_r"],
		["wing_l", "nostril_l", "in_wing_l"], ["wing_r", "in_wing_r", "nostril_r"],
		["nostril_l", "base", "in_base"], ["base", "nostril_r", "in_base"],
		["nostril_l", "in_base", "in_wing_l"], ["nostril_r", "in_wing_r", "in_base"],
	]
	# Orientation de chaque face : vers l'extérieur du volume du nez.
	var inside: Vector3 = (points["in_root"] + points["in_base"]) * 0.5 + Vector3(0.0, 0.0, -0.004)
	var keys := spec.keys()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	for key: String in keys:
		tool.add_vertex(points[key])
	for tri: Array in triangles:
		var a: Vector3 = points[tri[0]]
		var b: Vector3 = points[tri[1]]
		var c: Vector3 = points[tri[2]]
		var ia := keys.find(tri[0])
		var ib := keys.find(tri[1])
		var ic := keys.find(tri[2])
		# Sens horaire vu de l'extérieur (faces avant de Godot).
		if (b - a).cross(c - a).dot((a + b + c) / 3.0 - inside) > 0.0:
			var swap := ib
			ib = ic
			ic = swap
		for index: int in [ia, ib, ic]:
			tool.add_index(index)
	tool.generate_normals()
	_nose_cache[variant] = tool.commit()
	return _nose_cache[variant]


## Têtes générées : [masculine, féminine].
static var _head_cache: Array[ArrayMesh] = [null, null]


## Volume de la tête ; `female` : un peu plus petite, mâchoire plus fine et
## menton moins avancé.
static func _head_mesh(female: bool = false) -> ArrayMesh:
	var variant := 1 if female else 0
	if _head_cache[variant]:
		return _head_cache[variant]
	var jaw := 0.3 if female else 0.2
	var chin := 0.04 if female else 0.08
	var size := 0.96 if female else 1.0
	var rings := 18
	var segments := 28
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings + 1:
		var theta := PI * i / rings
		for j in segments + 1:
			var phi := TAU * j / segments
			var d := Vector3(sin(theta) * sin(phi), cos(theta), -sin(theta) * cos(phi))
			# Sous le centre, la tête se resserre (mâchoire) et le menton avance.
			var t := maxf(-d.y, 0.0)
			var x := d.x * HEAD_RADII.x * (1.0 - jaw * t * t)
			var y := d.y * (HEAD_RADII.y if d.y > 0.0 else HEAD_RADII.z)
			var z := d.z * HEAD_RADII.w * (1.0 - 0.12 * t * t)
			if d.z < 0.0:
				z *= 1.0 + chin * t
			tool.set_uv(Vector2(float(j) / segments, float(i) / rings))
			tool.add_vertex(HEAD_CENTER + Vector3(x, y, z) * size)
	for i in rings:
		for j in segments:
			var a := i * (segments + 1) + j
			var b := a + segments + 1
			# Faces avant dans le sens horaire, vues de l'extérieur.
			for index: int in [a, b, a + 1, a + 1, b, b + 1]:
				tool.add_index(index)
	tool.generate_normals()
	_head_cache[variant] = tool.commit()
	return _head_cache[variant]


## Yeux (blanc et iris) et sourcils.
## Les iris et les paupières sont animés par `_animate_face`.
func _build_eyes() -> void:
	for side: float in [-1.0, 1.0]:
		_ellipsoid(_head, 0.013, Vector3(1.1, 0.6, 0.5), Vector3(0.037 * side, 0.192, -0.094), _m_eye)
		var iris := _pivot(_head, IRIS_REST * Vector3(side, 1.0, 1.0), "Iris")
		_sphere(iris, 0.0062, Vector3.ZERO, _m_iris)
		_irises.append(iris)
		# Paupière : pivot au bord supérieur de l'œil, aplati quand l'œil est
		# ouvert, étiré vers le bas pour le fermer.
		var lid := _pivot(_head, Vector3(0.037 * side, 0.2, -0.094), "Eyelid")
		_ellipsoid(lid, 0.0145, Vector3(1.15, 0.7, 0.75), Vector3(0.0, -0.008, -0.001), _m_skin)
		lid.scale.y = LID_OPEN
		_lids.append(lid)
		var brow := _box(_head, Vector3(0.034, 0.005, 0.01) if _female else Vector3(0.036, 0.008, 0.012), Vector3(0.038 * side, 0.211, -0.097), _m_hair)
		brow.rotation.z = -0.12 * side
		_brows.append(brow)


## Paupières (clignements, yeux mi-clos de douleur, fermés une fois mort ou
## inconscient) et regard : les iris visent `look_target`, sinon errent.
func _animate_face(delta: float) -> void:
	if _lids.is_empty():
		return
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_blink_wait = _cosmetic.randf_range(2.0, 5.0)
		_blink_time = 0.0
	_blink_time += delta
	var blink := 1.0 - absf(_blink_time / BLINK_DURATION * 2.0 - 1.0) if _blink_time < BLINK_DURATION else 0.0
	_effort = lerpf(_effort, effort, 1.0 - exp(-10.0 * delta))
	_pain = lerpf(_pain, pain, 1.0 - exp(-(16.0 if pain > _pain else 4.0) * delta))
	_squint = 0.55 * _pain + 0.3 * _effort
	_animate_expression()
	var closed := maxf(blink, _squint)
	if is_dead:
		closed = 1.0
	for lid in _lids:
		lid.scale.y = lerpf(LID_OPEN, 1.0, closed)
	# Regard : vers la cible, ou petits mouvements au hasard.
	_gaze_wait -= delta
	if _gaze_wait <= 0.0:
		_gaze_wait = _cosmetic.randf_range(0.8, 2.5)
		_gaze_idle = Vector2(_cosmetic.randf_range(-1.0, 1.0), _cosmetic.randf_range(-0.6, 0.4))
	var gaze := _gaze_idle * 0.6
	if look_target != Vector3.INF and is_inside_tree():
		var local := _head.global_transform.affine_inverse() * look_target - HEAD_CENTER
		if local.length_squared() > 0.0001:
			local = local.normalized()
			gaze = Vector2(clampf(local.x * 3.0, -1.0, 1.0), clampf(local.y * 3.0, -1.0, 1.0))
	_gaze = _gaze.lerp(gaze, 1.0 - exp(-20.0 * delta))
	for i in _irises.size():
		var side := -1.0 if i == 0 else 1.0
		_irises[i].position = IRIS_REST * Vector3(side, 1.0, 1.0) + Vector3(_gaze.x * 0.0045, _gaze.y * 0.0022, 0.0)


## Sourcils froncés (effort) ou relevés au milieu (douleur), lèvres serrées
## ou bouche ouverte.
func _animate_expression() -> void:
	for i in _brows.size():
		var side := -1.0 if i == 0 else 1.0
		_brows[i].position.y = 0.211 - 0.004 * _effort + 0.003 * _pain
		_brows[i].rotation.z = side * (-0.12 + 0.42 * _effort - 0.35 * _pain)
	if _mouth:
		_mouth.scale = MOUTH_REST + Vector3(0.25 * _effort - 0.2 * _pain, -0.12 * _effort + 0.4 * _pain, 0.05 * _pain)
		_mouth_inner.visible = _pain > 0.1
		_mouth_inner.scale.y = maxf(0.75 * _pain, 0.01)


## Lacet de la tête vers `look_target` (repère du modèle), borné à ±`limit`.
func _look_yaw(limit: float) -> float:
	if look_target == Vector3.INF or not is_inside_tree():
		return NAN
	var local := to_local(look_target)
	if Vector2(local.x, local.z).length_squared() < 0.01:
		return NAN
	return clampf(atan2(-local.x, -local.z) - _torso_yaw, -limit, limit)


## Casquette, chapeau de brousse ou bonnet, dans la couleur du couvre-chef.
func _build_soft_headwear(kind: StringName) -> void:
	var dome := SphereMesh.new()
	dome.radius = 0.121
	dome.height = 0.121
	dome.is_hemisphere = true
	var hat := _mesh(_head, dome, Vector3(0.0, 0.2, 0.005), _m_helmet)
	hat.name = "Headwear"
	match kind:
		&"cap":
			hat.scale = Vector3(1.0, 0.9, 1.06)
			var brim := _box(_head, Vector3(0.15, 0.012, 0.1), Vector3(0.0, 0.205, -0.16), _m_helmet)
			brim.rotation.x = 0.12
		&"boonie":
			hat.scale = Vector3(1.03, 1.05, 1.08)
			_cylinder(_head, 0.2, 0.01, Vector3(0.0, 0.205, 0.005), _m_helmet)
		&"beret":
			# Béret penché sur le côté droit.
			hat.scale = Vector3(1.12, 0.55, 1.08)
			hat.position = Vector3(-0.012, 0.255, 0.0)
			hat.rotation.z = -0.25
			_tapered(_head, 0.112, 0.114, 0.022, Vector3(0.0, 0.25, 0.006), _m_dark).scale.z = 1.08
			_box(_head, Vector3(0.025, 0.03, 0.006), Vector3(0.05, 0.27, -0.118), _m_steel)
		&"beanie":
			hat.scale = Vector3(1.02, 1.2, 1.07)
			hat.position.y = 0.19
			_cylinder(_head, 0.124, 0.04, Vector3(0.0, 0.2, 0.005), _m_helmet).scale = Vector3(1.0, 1.0, 1.07)


## Protection auditive : coquilles, couvercles, coussinets et micro
## (`offset` : écart des coquilles au centre de la tête).
func _build_ear_cups(offset: float) -> void:
	for side: float in [-1.0, 1.0]:
		var cup := _cylinder(_head, 0.052, 0.04, Vector3((offset + 0.013) * side, 0.15, 0.005), _m_gear)
		cup.name = "EarCup"
		cup.rotation.z = PI / 2.0
		var cap := _cylinder(_head, 0.036, 0.014, Vector3((offset + 0.038) * side, 0.15, 0.005), _m_weapon)
		cap.rotation.z = PI / 2.0
		var cushion := _cylinder(_head, 0.048, 0.012, Vector3((offset - 0.012) * side, 0.15, 0.005), _m_weapon)
		cushion.rotation.z = PI / 2.0
	# Micro sur perche, devant la bouche.
	var boom := _box(_head, Vector3(0.01, 0.01, 0.11), Vector3(-0.12, 0.13, -0.07), _m_weapon)
	boom.rotation.y = -0.45
	_sphere(_head, 0.014, Vector3(-0.085, 0.125, -0.12), _m_gear)


## Casque balistique « high cut » d'opérateur : coque découpée au-dessus des
## oreilles et descendant sur la nuque, bordure caoutchouc et doublure,
## rails latéraux courbes (lampe, adaptateurs du casque audio), support de
## JVN, scratchs, contrepoids et jugulaire. Les accessoires sont
## posés sur la coque (`_shell_frame`) pour en épouser la forme.
func _build_operator_helmet(nvg: bool, headset: bool) -> void:
	var shell := MeshInstance3D.new()
	shell.name = "Helmet"
	shell.mesh = _helmet_mesh()
	shell.set_surface_override_material(0, _m_helmet)
	shell.set_surface_override_material(1, _m_weapon)
	shell.set_surface_override_material(2, _m_dark)
	_head.add_child(shell)
	# Scratchs du dessus (avec le marqueur d'équipe) et de l'arrière.
	_shell_box(Vector3(0.085, 0.005, 0.07), 0.42, 0.0, 0.002, _m_gear)
	_shell_box(Vector3(0.03, 0.012, 0.03), 0.42, 0.0, 0.01, _m_team)
	_shell_box(Vector3(0.1, 0.005, 0.05), 1.05, PI, 0.002, _m_gear, false)
	for side: float in [-1.0, 1.0]:
		# Rail latéral courbe, crénelé, au-dessus de la découpe.
		_shell_band(1.08, side * 0.95, side * 2.05, 0.026, 0.012, 0.006, _m_weapon, 9, true)
		if headset:
			# Bras qui relie la coquille auditive au rail.
			var top := _helmet_point(1.12, side * PI / 2.0) + _helmet_normal(1.12, side * PI / 2.0) * 0.012
			_strap(top, Vector3((0.133 + 0.01) * side, 0.185, 0.005), 0.016, 0.01, _m_weapon)
		# Jugulaire : sangles devant et derrière l'oreille, jusqu'au menton.
		var chin := Vector3(0.05 * side, 0.072, -0.075)
		for phi: float in [side * 1.15, side * 2.05]:
			var anchor := _helmet_point(_helmet_edge(phi) - 0.04, phi)
			_strap(anchor, chin, 0.012, 0.004, _m_weapon)
	_box(_head, Vector3(0.1, 0.012, 0.03), Vector3(0.0, 0.066, -0.076), _m_weapon).name = "ChinCup"
	if headset:
		_build_ear_cups(0.12)
	# Lampe tactique sur l'avant du rail droit.
	var lamp := _pivot(_head, Vector3.ZERO, "Lamp")
	lamp.transform = _shell_frame(1.08, 1.12, 0.03, false)
	var body := _cylinder(lamp, 0.015, 0.075, Vector3.ZERO, _m_weapon)
	body.rotation.x = PI / 2.0
	var glass := _cylinder(lamp, 0.013, 0.004, Vector3(0.0, 0.0, -0.039), _m_steel)
	glass.rotation.x = PI / 2.0
	_box(lamp, Vector3(0.016, 0.02, 0.02), Vector3(0.0, -0.016, 0.0), _m_weapon)
	# Support de JVN : platine épousant le front, réceptacle.
	var shroud := _pivot(_head, Vector3.ZERO, "Shroud")
	shroud.transform = _shell_frame(1.2, 0.0, 0.004)
	_box(shroud, Vector3(0.075, 0.008, 0.06), Vector3.ZERO, _m_weapon)
	_box(shroud, Vector3(0.042, 0.02, 0.03), Vector3(0.0, 0.012, 0.0), _m_weapon)
	if nvg:
		# Bras articulé, boîtier et tubes des jumelles relevées.
		_strap(shroud.transform * Vector3(0.0, 0.02, 0.0), Vector3(0.0, 0.3, -0.13), 0.026, 0.018, _m_weapon)
		var housing := _box(_head, Vector3(0.105, 0.03, 0.04), Vector3(0.0, 0.314, -0.125), _m_weapon)
		housing.rotation.x = deg_to_rad(-65.0)
		for side: float in [-1.0, 1.0]:
			var tube := _cylinder(_head, 0.021, 0.10, Vector3(0.033 * side, 0.335, -0.145), _m_weapon)
			tube.name = "NvgTube"
			tube.rotation.x = deg_to_rad(-65.0)
			var ring := _cylinder(_head, 0.023, 0.014, Vector3(0.033 * side, 0.352, -0.181), _m_gear)
			ring.rotation.x = deg_to_rad(-65.0)
			var lens := _cylinder(_head, 0.017, 0.006, Vector3(0.033 * side, 0.36, -0.198), _m_lens)
			lens.rotation.x = deg_to_rad(-65.0)
		# Contrepoids (pochette) sur la nuque.
		_shell_box(Vector3(0.11, 0.035, 0.055), 1.42, PI, 0.016, _m_gear, false)
		_shell_box(Vector3(0.112, 0.008, 0.02), 1.32, PI, 0.032, _m_gear, false)


## Coque du casque : ellipsoïde de centre et rayons donnés, épaisseur de la
## doublure (part du rayon), et nombre d'anneaux et de secteurs du maillage.
const HELMET_CENTER := Vector3(0.0, 0.19, 0.005)
const HELMET_RADII := Vector3(0.145, 0.148, 0.158)
const HELMET_INNER := 0.9
const HELMET_RINGS := 14
const HELMET_SEGMENTS := 56

static var _helmet_cache: ArrayMesh


## Angle (depuis le sommet) du bord de la coque dans la direction `phi`
## (0 : avant, ±π/2 : côtés, π : arrière) : au ras des sourcils devant,
## découpé au-dessus des oreilles, plus bas sur la nuque.
static func _helmet_edge(phi: float) -> float:
	return 1.67 - 0.17 * cos(phi) - 0.38 * exp(-pow((absf(wrapf(phi, -PI, PI)) - PI / 2.0) / 0.5, 2.0))


static func _helmet_point(theta: float, phi: float, factor: float = 1.0) -> Vector3:
	var direction := Vector3(sin(theta) * sin(phi), cos(theta), -sin(theta) * cos(phi))
	return HELMET_CENTER + HELMET_RADII * factor * direction


static func _helmet_normal(theta: float, phi: float) -> Vector3:
	var direction := Vector3(sin(theta) * sin(phi), cos(theta), -sin(theta) * cos(phi))
	return (direction / HELMET_RADII).normalized()


## Maillage de la coque (partagé par tous les modèles) : surface extérieure,
## bordure (épaisseur au bord) et doublure intérieure.
static func _helmet_mesh() -> ArrayMesh:
	if _helmet_cache:
		return _helmet_cache
	var outer := SurfaceTool.new()
	var trim := SurfaceTool.new()
	var liner := SurfaceTool.new()
	for tool: SurfaceTool in [outer, trim, liner]:
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in HELMET_SEGMENTS:
		var phis: Array[float] = [-PI + TAU * j / HELMET_SEGMENTS, -PI + TAU * (j + 1) / HELMET_SEGMENTS]
		var edges: Array[float] = [_helmet_edge(phis[0]), _helmet_edge(phis[1])]
		for i in HELMET_RINGS:
			var t0 := float(i) / HELMET_RINGS
			var t1 := float(i + 1) / HELMET_RINGS
			var angles := [[t0 * edges[0], phis[0]], [t1 * edges[0], phis[0]], [t1 * edges[1], phis[1]], [t0 * edges[1], phis[1]]]
			var points: Array[Vector3] = []
			var inner: Array[Vector3] = []
			var normals: Array[Vector3] = []
			var inward: Array[Vector3] = []
			for a: Array in angles:
				points.append(_helmet_point(a[0], a[1]))
				inner.append(_helmet_point(a[0], a[1], HELMET_INNER))
				normals.append(_helmet_normal(a[0], a[1]))
				inward.append(-_helmet_normal(a[0], a[1]))
			_add_quad(outer, points, normals)
			_add_quad(liner, inner, inward)
		# Bordure : du bord extérieur au bord intérieur, tournée vers le bas.
		var rim: Array[Vector3] = [_helmet_point(edges[0], phis[0]), _helmet_point(edges[0], phis[0], HELMET_INNER),
				_helmet_point(edges[1], phis[1], HELMET_INNER), _helmet_point(edges[1], phis[1])]
		var down: Array[Vector3] = []
		for k in 2:
			var along := (_helmet_point(edges[k] + 0.02, phis[k]) - _helmet_point(edges[k], phis[k])).normalized()
			down.append(along)
		_add_quad(trim, rim, [down[0], down[0], down[1], down[1]] as Array[Vector3])
	var mesh := ArrayMesh.new()
	for tool: SurfaceTool in [outer, trim, liner]:
		tool.commit(mesh)
	_helmet_cache = mesh
	return mesh


## Quadrilatère (deux triangles) dont les faces avant regardent du côté des
## normales données (Godot : faces avant dans le sens horaire).
static func _add_quad(tool: SurfaceTool, points: Array[Vector3], normals: Array[Vector3]) -> void:
	for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
		var a := points[triangle[0]]
		var face := (points[triangle[1]] - a).cross(points[triangle[2]] - a)
		if face.length_squared() < 1e-14:
			continue
		var reference := normals[triangle[0]] + normals[triangle[1]] + normals[triangle[2]]
		var order: Array = triangle if face.dot(reference) < 0.0 else [triangle[0], triangle[2], triangle[1]]
		for k: int in order:
			tool.set_normal(normals[k])
			tool.add_vertex(points[k])


## Repère posé sur la coque en (`theta`, `phi`), décollé de `lift` : Y selon
## la normale, -Z vers le bas de la coque (`along_meridian`) ou dans le sens
## de `phi` croissant.
static func _shell_frame(theta: float, phi: float, lift: float, along_meridian: bool = true) -> Transform3D:
	var normal := _helmet_normal(theta, phi)
	var next := _helmet_point(theta + 0.01, phi) if along_meridian else _helmet_point(theta, phi + 0.01)
	var tangent := next - _helmet_point(theta, phi)
	tangent = (tangent - normal * tangent.dot(normal)).normalized()
	return Transform3D(Basis.looking_at(tangent, normal), _helmet_point(theta, phi) + normal * lift)


## Pièce plate posée sur la coque.
func _shell_box(size: Vector3, theta: float, phi: float, lift: float, material: Material, along_meridian: bool = true) -> MeshInstance3D:
	var piece := _box(_head, size, Vector3.ZERO, material)
	piece.transform = _shell_frame(theta, phi, lift + size.y * 0.5, along_meridian)
	return piece


## Bande qui suit la coque à hauteur `theta`, de `from` à `to` (en `phi`), en
## `segments` morceaux ; `notched` : crans d'un rail.
func _shell_band(theta: float, from: float, to: float, width: float, thickness: float, lift: float, material: Material, segments: int, notched: bool = false) -> void:
	for i in segments:
		var a := lerpf(from, to, float(i) / segments)
		var b := lerpf(from, to, float(i + 1) / segments)
		var length := _helmet_point(theta, a).distance_to(_helmet_point(theta, b))
		_shell_box(Vector3(width, thickness, length * 1.08), theta, (a + b) * 0.5, lift, material, false)
		if notched:
			_shell_box(Vector3(width * 1.1, thickness * 0.4, length * 0.3), theta, (a + b) * 0.5, lift + thickness * 0.8, material, false)


## Sangle plate de `from` à `to` (repère de la tête).
func _strap(from: Vector3, to: Vector3, width: float, thickness: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var strap := _box(parent if parent else _head, Vector3(width, thickness, from.distance_to(to)), Vector3.ZERO, material)
	var direction := (to - from).normalized()
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	strap.transform = Transform3D(Basis.looking_at(direction, up), (from + to) * 0.5)
	return strap


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
	var primary := (&"carbine" if _guard_look.is_empty() else &"rifle") if outfit == null else outfit.primary
	var drawn := _sidearm_built and outfit != null and outfit.secondary != &"none"
	_pump = null
	_tube_fed = false
	var muzzle := _build_weapon(rifle, outfit.secondary if drawn else primary)
	var pump := _pump
	var tube_fed := _tube_fed
	_left_grip = PISTOL_LEFT_GRIP if drawn else LEFT_GRIP
	if drawn:
		# Arme principale pendue à sa bretelle 3 points, sur le flanc droit,
		# canon vers le bas : là où l'a laissée le geste de la bretelle.
		var back := _pivot(_torso, Vector3.ZERO, "SlungPrimary")
		back.transform = _rifle_slung
		var magazine := _rifle_mag
		_build_weapon(back, primary)
		back.name = "SlungPrimary"
		_rifle_mag = magazine
		_pump = pump
		_tube_fed = tube_fed
	# Flash de bouche (discret : arme à silencieux).
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.8, 0.35)
	_flash = _pivot(rifle, Vector3(0.0, 0.045, muzzle), "MuzzleFlash")
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
	_arm_poses[ArmPose.RIFLE] = _solve_arms(rifle.transform * _left_grip, rifle.transform * RIGHT_GRIP)
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


## Géométrie de l'arme principale `kind` (`GearCatalog.PRIMARY`) dans le
## repère `rifle` : poignée et garde-main aux mêmes endroits pour toutes, pour
## les mains. Renvoie la position (z) de la bouche du canon.
func _build_weapon(rifle: Node3D, kind: StringName) -> float:
	rifle.name = "Rifle"
	var grip := _box(rifle, Vector3(0.035, 0.10, 0.045), Vector3(0.0, -0.045, 0.04), _m_weapon)
	grip.rotation.x = deg_to_rad(18.0)
	match kind:
		&"pistol", &"machine_pistol":
			# Tenue à deux mains : la poignée sert de repère, comme pour les fusils.
			var long := kind == &"machine_pistol"
			_box(rifle, Vector3(0.032, 0.05, 0.2 if long else 0.17), Vector3(0.0, 0.03, -0.05), _m_weapon)
			_rifle_mag = _box(rifle, Vector3(0.024, 0.2 if long else 0.08, 0.035), Vector3(0.0, -0.08 if long else -0.05, 0.04), _m_weapon)
			_rifle_mag.rotation.x = deg_to_rad(18.0)
			if long:
				return -0.17
			var can := _cylinder(rifle, 0.017, 0.14, Vector3(0.0, 0.035, -0.21), _m_weapon)
			can.rotation.x = PI / 2.0
			return -0.28
		&"smg":
			_box(rifle, Vector3(0.045, 0.085, 0.26), Vector3(0.0, 0.04, -0.04), _m_weapon)
			for side: float in [-1.0, 1.0]:
				_box(rifle, Vector3(0.012, 0.012, 0.18), Vector3(0.015 * side, 0.05, 0.16), _m_weapon)
			_box(rifle, Vector3(0.045, 0.08, 0.02), Vector3(0.0, 0.03, 0.25), _m_gear)
			_rifle_mag = _box(rifle, Vector3(0.028, 0.15, 0.045), Vector3(0.0, -0.07, -0.12), _m_weapon)
			_rifle_mag.rotation.x = -0.25
			# Silencieux intégré, qui sert de garde-main.
			var body := _cylinder(rifle, 0.027, 0.34, Vector3(0.0, 0.045, -0.33), _m_weapon)
			body.rotation.x = PI / 2.0
			_box(rifle, Vector3(0.035, 0.04, 0.06), Vector3(0.0, 0.11, -0.04), _m_weapon)
			_box(rifle, Vector3(0.025, 0.025, 0.005), Vector3(0.0, 0.112, -0.072), _m_lens)
			return -0.52
		&"dmr":
			_box(rifle, Vector3(0.048, 0.085, 0.32), Vector3(0.0, 0.04, -0.05), _m_weapon)
			_box(rifle, Vector3(0.045, 0.09, 0.24), Vector3(0.0, 0.03, 0.2), _m_weapon)
			_box(rifle, Vector3(0.04, 0.03, 0.12), Vector3(0.0, 0.085, 0.17), _m_weapon)
			_box(rifle, Vector3(0.05, 0.11, 0.03), Vector3(0.0, 0.02, 0.33), _m_gear)
			_rifle_mag = _box(rifle, Vector3(0.03, 0.1, 0.065), Vector3(0.0, -0.055, -0.09), _m_weapon)
			_rifle_mag.rotation.x = deg_to_rad(-8.0)
			_box(rifle, Vector3(0.052, 0.065, 0.42), Vector3(0.0, 0.045, -0.41), _m_gear)
			var barrel := _cylinder(rifle, 0.011, 0.24, Vector3(0.0, 0.045, -0.74), _m_weapon)
			barrel.rotation.x = PI / 2.0
			var brake := _cylinder(rifle, 0.017, 0.06, Vector3(0.0, 0.045, -0.86), _m_weapon)
			brake.rotation.x = PI / 2.0
			# Lunette et ses colliers.
			var scope := _cylinder(rifle, 0.024, 0.26, Vector3(0.0, 0.13, -0.07), _m_weapon)
			scope.name = "Scope"
			scope.rotation.x = PI / 2.0
			var bell := _cylinder(rifle, 0.032, 0.05, Vector3(0.0, 0.13, -0.21), _m_weapon)
			bell.rotation.x = PI / 2.0
			var lens := _cylinder(rifle, 0.027, 0.005, Vector3(0.0, 0.13, -0.237), _m_lens)
			lens.rotation.x = PI / 2.0
			for z: float in [-0.13, 0.0]:
				_box(rifle, Vector3(0.03, 0.05, 0.02), Vector3(0.0, 0.095, z), _m_weapon)
			# Bipied replié.
			for side: float in [-1.0, 1.0]:
				_box(rifle, Vector3(0.01, 0.01, 0.18), Vector3(0.016 * side, 0.0, -0.5), _m_weapon)
			return -0.89
		&"shotgun":
			_box(rifle, Vector3(0.05, 0.09, 0.26), Vector3(0.0, 0.04, -0.03), _m_weapon)
			_box(rifle, Vector3(0.04, 0.08, 0.22), Vector3(0.0, 0.03, 0.19), _m_weapon)
			_box(rifle, Vector3(0.05, 0.11, 0.03), Vector3(0.0, 0.02, 0.31), _m_gear)
			_rifle_mag = _box(rifle, Vector3(0.035, 0.13, 0.07), Vector3(0.0, -0.07, -0.08), _m_weapon)
			var barrel := _cylinder(rifle, 0.018, 0.45, Vector3(0.0, 0.06, -0.38), _m_weapon)
			barrel.rotation.x = PI / 2.0
			_box(rifle, Vector3(0.055, 0.06, 0.18), Vector3(0.0, 0.025, -0.34), _m_gear)
			_box(rifle, Vector3(0.012, 0.02, 0.012), Vector3(0.0, 0.085, -0.58), _m_weapon)
			_box(rifle, Vector3(0.03, 0.025, 0.015), Vector3(0.0, 0.1, 0.0), _m_weapon)
			return -0.61
	match kind:
		&"pump_shotgun":
			return _build_pump_shotgun(rifle)
		&"famas":
			return _build_famas(rifle)
		&"scar_l", &"scar_h":
			return _build_scar(rifle, kind == &"scar_h")
		&"hk417":
			return _build_hk417(rifle)
		&"m249":
			return _build_m249(rifle)
	if kind == &"rifle":
		# Fusil d'assaut des ennemis : crosse et garde-main en bois, chargeur
		# courbe, frein de bouche, sans optique.
		var wood := _mat(Color(0.36, 0.2, 0.1), 0.7)
		_box(rifle, Vector3(0.045, 0.075, 0.3), Vector3(0.0, 0.04, -0.05), _m_weapon)
		var stock := _box(rifle, Vector3(0.038, 0.08, 0.24), Vector3(0.0, 0.0, 0.2), wood)
		stock.rotation.x = deg_to_rad(-6.0)
		_box(rifle, Vector3(0.05, 0.065, 0.24), Vector3(0.0, 0.035, -0.33), wood)
		var curved := _pivot(rifle, Vector3(0.0, -0.01, -0.09), "Magazine")
		for i in 3:
			var piece := _box(curved, Vector3(0.028, 0.065, 0.055), Vector3(0.0, -0.03 - 0.055 * i, -0.012 * i * i), _m_weapon)
			piece.rotation.x = -0.2 * i
		_rifle_mag = curved
		var gas := _cylinder(rifle, 0.012, 0.22, Vector3(0.0, 0.075, -0.36), _m_weapon)
		gas.rotation.x = PI / 2.0
		var muzzle := _cylinder(rifle, 0.012, 0.22, Vector3(0.0, 0.04, -0.56), _m_weapon)
		muzzle.rotation.x = PI / 2.0
		var brake := _cylinder(rifle, 0.017, 0.05, Vector3(0.0, 0.04, -0.68), _m_weapon)
		brake.rotation.x = PI / 2.0
		_box(rifle, Vector3(0.01, 0.04, 0.012), Vector3(0.0, 0.07, -0.64), _m_weapon)
		return -0.71
	# Carabine à silencieux.
	_box(rifle, Vector3(0.045, 0.08, 0.30), Vector3(0.0, 0.04, -0.05), _m_weapon)      # boîtier
	_box(rifle, Vector3(0.04, 0.065, 0.20), Vector3(0.0, 0.035, 0.19), _m_weapon)     # crosse
	_box(rifle, Vector3(0.045, 0.10, 0.03), Vector3(0.0, 0.02, 0.30), _m_gear)        # plaque de couche
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
	return -0.77


## Cylindre couché le long du canon (axe Z de l'arme).
func _barrel(rifle: Node3D, radius: float, length: float, at: Vector3, material: Material) -> MeshInstance3D:
	var tube := _cylinder(rifle, radius, length, at, material)
	tube.rotation.x = PI / 2.0
	return tube


## Fusil à pompe : crosse et garde-main noirs, long canon, magasin tubulaire
## dessous, garde-main mobile (`_pump`) que la main gauche manœuvre après
## chaque tir.
func _build_pump_shotgun(rifle: Node3D) -> float:
	var furniture := _mat(Color(0.12, 0.12, 0.11), 0.85)
	_box(rifle, Vector3(0.048, 0.085, 0.22), Vector3(0.0, 0.045, -0.06), _m_weapon)
	var stock := _box(rifle, Vector3(0.04, 0.085, 0.26), Vector3(0.0, 0.015, 0.18), furniture)
	stock.rotation.x = deg_to_rad(-7.0)
	_box(rifle, Vector3(0.045, 0.1, 0.03), Vector3(0.0, 0.0, 0.32), _m_gear)
	# Pontet et fenêtre d'éjection.
	_box(rifle, Vector3(0.012, 0.03, 0.07), Vector3(0.0, -0.01, 0.0), _m_weapon)
	_box(rifle, Vector3(0.002, 0.025, 0.06), Vector3(0.025, 0.06, -0.08), _m_lens)
	_barrel(rifle, 0.016, 0.56, Vector3(0.0, 0.065, -0.45), _m_weapon)
	var tube := _barrel(rifle, 0.014, 0.44, Vector3(0.0, 0.028, -0.39), _m_weapon)
	tube.name = "TubeMagazine"
	_box(rifle, Vector3(0.03, 0.05, 0.02), Vector3(0.0, 0.045, -0.62), _m_weapon)
	# Guidon.
	_box(rifle, Vector3(0.006, 0.014, 0.006), Vector3(0.0, 0.086, -0.71), _m_lens)
	# Garde-main mobile, sur le magasin, sous la main gauche.
	_pump = _pivot(rifle, Vector3(0.0, 0.03, LEFT_GRIP.z), "Pump")
	_pump_rest = _pump.position
	var grip := _box(_pump, Vector3(0.05, 0.05, 0.17), Vector3.ZERO, furniture)
	grip.name = "PumpGrip"
	for i in 4:
		_box(_pump, Vector3(0.052, 0.006, 0.012), Vector3(0.0, -0.012, -0.06 + 0.04 * i), _m_weapon)
	# Porte de chargement sous le boîtier : c'est là que glissent les cartouches.
	_rifle_mag = _box(rifle, Vector3(0.026, 0.012, 0.07), Vector3(0.0, 0.0, -0.08), _m_weapon)
	_tube_fed = true
	return -0.73


## Recul (m) du garde-main du fusil à pompe, `since` secondes après le tir.
static func pump_offset(since: float) -> float:
	var t := (since - PUMP_DELAY) / PUMP_TIME
	if t <= 0.0 or t >= 1.0:
		return 0.0
	return PUMP_TRAVEL * sin(PI * t)


## Vrai si l'arme en main est un fusil à pompe.
func has_pump() -> bool:
	return _pump != null


## Vrai pendant qu'il manœuvre la pompe.
func is_pumping() -> bool:
	return _pump != null and pump_offset(_shot_time) > 0.0


## FAMAS : bullpup, chargeur derrière la poignée, longue poignée de
## transport sur le dessus, bipied replié, canon court.
func _build_famas(rifle: Node3D) -> float:
	_box(rifle, Vector3(0.05, 0.09, 0.62), Vector3(0.0, 0.035, -0.02), _m_weapon)
	_box(rifle, Vector3(0.052, 0.12, 0.05), Vector3(0.0, 0.02, 0.3), _m_gear)
	_box(rifle, Vector3(0.046, 0.06, 0.12), Vector3(0.0, -0.03, 0.24), _m_weapon)
	_box(rifle, Vector3(0.048, 0.03, 0.26), Vector3(0.0, -0.025, -0.2), _m_weapon)
	# Poignée de transport : deux montants et la barre.
	_box(rifle, Vector3(0.02, 0.02, 0.44), Vector3(0.0, 0.135, -0.06), _m_weapon)
	_box(rifle, Vector3(0.02, 0.06, 0.03), Vector3(0.0, 0.1, -0.27), _m_weapon)
	_box(rifle, Vector3(0.02, 0.06, 0.03), Vector3(0.0, 0.1, 0.14), _m_weapon)
	_rifle_mag = _box(rifle, Vector3(0.026, 0.14, 0.05), Vector3(0.0, -0.06, 0.13), _m_weapon)
	_rifle_mag.rotation.x = deg_to_rad(-6.0)
	_barrel(rifle, 0.011, 0.16, Vector3(0.0, 0.045, -0.41), _m_weapon)
	_barrel(rifle, 0.016, 0.05, Vector3(0.0, 0.045, -0.5), _m_weapon)
	for side: float in [-1.0, 1.0]:
		var leg := _box(rifle, Vector3(0.008, 0.008, 0.2), Vector3(0.03 * side, 0.03, -0.3), _m_weapon)
		leg.rotation.y = 0.05 * side
	return -0.53


## FN SCAR : boîtier supérieur à long rail, crosse repliable réglable,
## garde-main à rails, silencieux, couleur sable. Le SCAR-H (7,62 mm) a un
## chargeur droit plus gros et un canon plus long.
func _build_scar(rifle: Node3D, heavy: bool) -> float:
	var tan := _mat(Color(0.55, 0.47, 0.33), 0.75)
	var front := -0.44 if heavy else -0.4
	_box(rifle, Vector3(0.05, 0.07, 0.62 + (0.04 if heavy else 0.0)), Vector3(0.0, 0.055, -0.13 - (0.02 if heavy else 0.0)), tan)
	_box(rifle, Vector3(0.024, 0.012, 0.56), Vector3(0.0, 0.096, -0.12), _m_weapon)
	_box(rifle, Vector3(0.044, 0.05, 0.16), Vector3(0.0, 0.0, -0.06), _m_weapon)
	_box(rifle, Vector3(0.04, 0.05, 0.2), Vector3(0.0, 0.0, front + 0.12), tan)
	# Crosse : armature, appui-joue et plaque de couche.
	_box(rifle, Vector3(0.036, 0.04, 0.24), Vector3(0.0, 0.04, 0.17), tan)
	_box(rifle, Vector3(0.036, 0.035, 0.1), Vector3(0.0, 0.08, 0.22), tan)
	_box(rifle, Vector3(0.04, 0.11, 0.03), Vector3(0.0, 0.03, 0.3), _m_weapon)
	if heavy:
		_rifle_mag = _box(rifle, Vector3(0.032, 0.13, 0.075), Vector3(0.0, -0.08, -0.08), _m_weapon)
		_rifle_mag.rotation.x = deg_to_rad(-4.0)
	else:
		_rifle_mag = _box(rifle, Vector3(0.028, 0.15, 0.06), Vector3(0.0, -0.08, -0.08), _m_weapon)
		_rifle_mag.rotation.x = deg_to_rad(-14.0)
	_box(rifle, Vector3(0.025, 0.07, 0.035), Vector3(0.0, -0.05, front + 0.06), _m_weapon)
	# Viseur holographique.
	_box(rifle, Vector3(0.04, 0.045, 0.07), Vector3(0.0, 0.124, -0.05), _m_weapon)
	_box(rifle, Vector3(0.032, 0.03, 0.005), Vector3(0.0, 0.128, -0.087), _m_lens)
	_barrel(rifle, 0.012, 0.08, Vector3(0.0, 0.05, front - 0.04), _m_weapon)
	var length := 0.2 if heavy else 0.17
	_barrel(rifle, 0.024 if heavy else 0.021, length, Vector3(0.0, 0.05, front - 0.08 - length * 0.5), _m_weapon)
	return front - 0.1 - length


## HK417 : grand AR en 7,62 mm, chargeur droit, garde-main long à rails,
## lunette à faible grossissement, silencieux, crosse réglable.
func _build_hk417(rifle: Node3D) -> float:
	_box(rifle, Vector3(0.05, 0.085, 0.3), Vector3(0.0, 0.04, -0.05), _m_weapon)
	_box(rifle, Vector3(0.042, 0.07, 0.22), Vector3(0.0, 0.035, 0.2), _m_weapon)
	_box(rifle, Vector3(0.04, 0.035, 0.12), Vector3(0.0, 0.085, 0.2), _m_weapon)
	_box(rifle, Vector3(0.046, 0.1, 0.03), Vector3(0.0, 0.02, 0.31), _m_gear)
	_rifle_mag = _box(rifle, Vector3(0.032, 0.13, 0.07), Vector3(0.0, -0.075, -0.09), _m_weapon)
	_rifle_mag.rotation.x = deg_to_rad(-6.0)
	_box(rifle, Vector3(0.056, 0.066, 0.38), Vector3(0.0, 0.045, -0.39), _m_gear)
	_box(rifle, Vector3(0.022, 0.012, 0.64), Vector3(0.0, 0.085, -0.27), _m_weapon)
	_box(rifle, Vector3(0.025, 0.07, 0.035), Vector3(0.0, -0.01, -0.38), _m_weapon)
	var scope := _barrel(rifle, 0.02, 0.2, Vector3(0.0, 0.125, -0.07), _m_weapon)
	scope.name = "Scope"
	_barrel(rifle, 0.027, 0.04, Vector3(0.0, 0.125, -0.18), _m_weapon)
	_barrel(rifle, 0.022, 0.004, Vector3(0.0, 0.125, -0.2), _m_lens)
	for z: float in [-0.12, -0.02]:
		_box(rifle, Vector3(0.028, 0.04, 0.02), Vector3(0.0, 0.1, z), _m_weapon)
	_barrel(rifle, 0.012, 0.08, Vector3(0.0, 0.045, -0.62), _m_weapon)
	_barrel(rifle, 0.024, 0.2, Vector3(0.0, 0.045, -0.76), _m_weapon)
	return -0.86


## M249 : boîtier carré à couvercle d'alimentation, boîte de bande sous le
## flanc gauche, poignée de transport, cache-canon ajouré, bipied replié,
## crosse squelette.
func _build_m249(rifle: Node3D) -> float:
	_box(rifle, Vector3(0.06, 0.1, 0.36), Vector3(0.0, 0.04, -0.06), _m_weapon)
	_box(rifle, Vector3(0.064, 0.025, 0.2), Vector3(0.0, 0.1, -0.08), _m_weapon)
	# Crosse squelette.
	_box(rifle, Vector3(0.04, 0.025, 0.26), Vector3(0.0, 0.07, 0.24), _m_weapon)
	_box(rifle, Vector3(0.04, 0.025, 0.26), Vector3(0.0, -0.01, 0.24), _m_weapon)
	_box(rifle, Vector3(0.045, 0.12, 0.03), Vector3(0.0, 0.03, 0.37), _m_gear)
	# Boîte de bande et bande engagée dans le boîtier.
	_rifle_mag = _box(rifle, Vector3(0.07, 0.11, 0.1), Vector3(-0.035, -0.07, -0.1), _m_gear)
	_box(rifle, Vector3(0.04, 0.02, 0.05), Vector3(-0.04, 0.0, -0.1), _m_steel)
	# Garde-main, cache-canon, canon et poignée de transport.
	_box(rifle, Vector3(0.058, 0.055, 0.16), Vector3(0.0, 0.0, -0.32), _m_weapon)
	_barrel(rifle, 0.016, 0.42, Vector3(0.0, 0.05, -0.48), _m_weapon)
	_box(rifle, Vector3(0.04, 0.03, 0.22), Vector3(0.0, 0.08, -0.38), _m_gear)
	_box(rifle, Vector3(0.03, 0.03, 0.03), Vector3(0.0, 0.105, -0.25), _m_weapon)
	var handle := _box(rifle, Vector3(0.016, 0.022, 0.12), Vector3(0.0, 0.125, -0.3), _m_weapon)
	handle.rotation.x = -0.25
	_barrel(rifle, 0.021, 0.05, Vector3(0.0, 0.05, -0.71), _m_weapon)
	for side: float in [-1.0, 1.0]:
		var leg := _box(rifle, Vector3(0.01, 0.01, 0.26), Vector3(0.022 * side, 0.02, -0.5), _m_weapon)
		leg.rotation.y = 0.04 * side
	return -0.74


func _shoulder_position(side: float) -> Vector3:
	return Vector3(0.245 * side, 0.50, 0.0)


## Bras articulé : pivot d'épaule → bras → pivot de coude → avant-bras et main.
## Au repos (rotations nulles), le bras pend vers le bas.
func _build_arm(side: float) -> void:
	var shoulder := _pivot(_torso, _shoulder_position(side), "ShoulderL" if side < 0.0 else "ShoulderR")
	# Épaule, bras effilé, écusson d'équipe.
	var arm := 0.88 if _female else 1.0
	_sphere(shoulder, 0.072 * arm, Vector3.ZERO, _m_top)
	_tapered(shoulder, 0.064 * arm, 0.052 * arm, UPPER_ARM_LENGTH, Vector3(0.0, -UPPER_ARM_LENGTH * 0.5, 0.0), _m_top)
	_box(shoulder, Vector3(0.012, 0.07, 0.07), Vector3(0.063 * side, -0.085, 0.0), _m_team)
	if outfit and outfit.specialty == &"medic":
		# Brassard blanc à croix rouge.
		var band := _tapered(shoulder, 0.0625, 0.061, 0.06, Vector3(0.0, -0.17, 0.0), _m_white)
		band.name = "Armband"
		_box(band, Vector3(0.006, 0.04, 0.012), Vector3(0.062 * side, 0.0, 0.0), _m_red)
		_box(band, Vector3(0.006, 0.012, 0.04), Vector3(0.062 * side, 0.0, 0.0), _m_red)
	# Coude, avant-bras, manchette et main gantée (pouce vers l'avant).
	var elbow := _pivot(shoulder, Vector3(0.0, -UPPER_ARM_LENGTH, 0.0), "Elbow")
	_sphere(elbow, 0.053 * arm, Vector3.ZERO, _m_top)
	_tapered(elbow, 0.052 * arm, 0.043 * arm, FOREARM_LENGTH - 0.04, Vector3(0.0, -(FOREARM_LENGTH - 0.04) * 0.5, 0.0), _m_top)
	_tapered(elbow, 0.047, 0.045, 0.04, Vector3(0.0, -FOREARM_LENGTH + 0.03, 0.0), _m_glove)
	_build_hand(elbow, side)
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
		# Grenade tenue pendant le lancer.
		_hand_grenade = _pivot(elbow, Vector3(0.0, -FOREARM_LENGTH - 0.04, -0.02), "HandGrenade")
		_sphere(_hand_grenade, 0.036, Vector3.ZERO, _m_grenade)
		_hand_grenade.visible = false


## Main gantée articulée : paume, quatre doigts de deux phalanges et pouce,
## qui se referment vers la paume (côté intérieur, vers le corps) selon
## `_curl` (`_animate_fingers`).
func _build_hand(elbow: Node3D, side: float) -> void:
	var wrist := -FOREARM_LENGTH
	_ellipsoid(elbow, 0.036, Vector3(0.62, 1.05, 1.0), Vector3(0.0, wrist - 0.022, 0.0), _m_glove).name = "Hand"
	var joints: Array[Node3D] = []
	for i in 4:
		var z := -0.024 + 0.016 * i
		var length := 0.03 - 0.004 * absf(i - 1.4)
		var knuckle := _pivot(elbow, Vector3(0.0, wrist - 0.052, z), "Finger%d" % i)
		_capsule(knuckle, 0.0085, length + 0.012, Vector3(0.0, -length * 0.5, 0.0), _m_glove)
		var middle := _pivot(knuckle, Vector3(0.0, -length, 0.0), "Phalanx")
		_capsule(middle, 0.0078, length, Vector3(0.0, -length * 0.4, 0.0), _m_glove)
		joints.append_array([knuckle, middle])
	var thumb := _pivot(elbow, Vector3(-0.008 * side, wrist - 0.018, -0.026), "Thumb")
	_capsule(thumb, 0.0105, 0.05, Vector3(0.0, -0.02, 0.0), _m_glove)
	thumb.rotation.x = 0.55
	joints.append(thumb)
	_fingers.append(joints)


## Doigts : 0 = main ouverte, 1 = poing serré (sur une arme, un objet).
## `curl` : fermeture visée pour la main gauche (x) et droite (y).
func _animate_fingers(curl: Vector2, delta: float) -> void:
	_curl = _curl.lerp(curl, 1.0 - exp(-14.0 * delta))
	for hand in _fingers.size():
		var side := -1.0 if hand == 0 else 1.0
		var amount: float = _curl.x if hand == 0 else _curl.y
		var joints: Array = _fingers[hand]
		for i in 8:
			# Phalanges vers la paume : rotation autour de l'axe avant-arrière.
			(joints[i] as Node3D).rotation.z = -side * amount * (1.45 if i % 2 == 0 else 1.6)
		var thumb: Node3D = joints[8]
		thumb.rotation = Vector3(0.55 + 0.35 * amount, 0.0, -side * 0.9 * amount)


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


## Tronc de cône (membres, buste) : rayons du haut et du bas.
func _tapered(parent: Node3D, top: float, bottom: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	return _mesh(parent, mesh, at, material)


func _capsule(parent: Node3D, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 6
	return _mesh(parent, mesh, at, material)


## Sphère déformée (`proportions` : facteurs par axe).
func _ellipsoid(parent: Node3D, radius: float, proportions: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var piece := _sphere(parent, radius, at, material)
	piece.scale = proportions
	return piece


func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return _mesh(parent, mesh, at, material)
