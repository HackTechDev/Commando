class_name HearingComponent
extends Node3D
## Ouïe d'un ennemi : écoute `EventBus.noise_emitted` et signale les bruits
## entendus (`heard`), avec la réaction qu'ils appellent.
##
## Un bruit s'entend dans son rayon (`noise_emitted`), multiplié par
## `acuity` ; un mur (couche des occultants) entre l'oreille et la source le
## réduit de moitié (`MUFFLE`). Les ennemis ne distinguent pas l'auteur d'un
## bruit : c'est son type qui décide de la réaction (`reaction_to`).

enum Reaction { IGNORE, INVESTIGATE, ALARM }

const MASK_OCCLUDERS := 0b10
## Part du rayon qui reste à travers un mur.
const MUFFLE := 0.5
const EAR_HEIGHT := 1.6
## Bruits qui donnent l'alerte : appel à l'aide, cri, coup de feu, explosion.
const ALARM_TYPES: Array[StringName] = [&"help", &"scream", &"gunshot", &"explosion"]
## Bruits qui intriguent : on va voir. Les autres types sont ignorés.
const INVESTIGATE_TYPES: Array[StringName] = [
	&"distraction", &"knife", &"melee", &"jump", &"run", &"gear", &"crate", &"smoke", &"impact",
]

## Bruit entendu en `at` : type, réaction, et force (1 à la source, 0 en
## limite d'audition).
signal heard(at: Vector3, type: StringName, reaction: Reaction, loudness: float)

## Finesse de l'ouïe : multiplie le rayon des bruits.
@export var acuity: float = 1.0
## Sourd (mannequin) : n'entend rien.
@export var deaf: bool = false

## Nombre de bruits entendus (tests, mise au point).
var heard_count: int = 0


func _ready() -> void:
	EventBus.noise_emitted.connect(_on_noise)


static func reaction_to(type: StringName) -> Reaction:
	if type in ALARM_TYPES:
		return Reaction.ALARM
	if type in INVESTIGATE_TYPES:
		return Reaction.INVESTIGATE
	return Reaction.IGNORE


## Force du bruit de rayon `radius` émis en `at`, entendu d'ici : 0 s'il
## n'est pas entendu.
func loudness(at: Vector3, radius: float) -> float:
	var reach := radius * acuity
	var ear := global_position + Vector3.UP * EAR_HEIGHT
	var distance := Vector2(at.x - ear.x, at.z - ear.z).length()
	if reach <= 0.0 or distance > reach:
		return 0.0
	if distance > 1.0 and _wall_between(ear, at + Vector3.UP * 0.5):
		reach *= MUFFLE
		if distance > reach:
			return 0.0
	return 1.0 - distance / reach


func _wall_between(from: Vector3, to: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_OCCLUDERS)
	var body := get_parent() as CollisionObject3D
	if body:
		query.exclude = [body.get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _on_noise(at: Vector3, radius: float, type: StringName) -> void:
	if deaf or not is_inside_tree():
		return
	var reaction := reaction_to(type)
	if reaction == Reaction.IGNORE:
		return
	var force := loudness(at, radius)
	if force <= 0.0:
		return
	heard_count += 1
	heard.emit(at, type, reaction, force)
