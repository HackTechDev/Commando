class_name LevelTest
extends GutTest
## Base des tests qui jouent une scène de niveau : chargement, attente en
## images de physique, mise à l'écart des ennemis qui gêneraient.

const SANDBOX := "res://scenes/levels/sandbox/sandbox.tscn"
const TRAINING_A := "res://scenes/levels/training_a/training_a.tscn"
const TRAINING_B := "res://scenes/levels/training_b/training_b.tscn"
const FIGHTER_CRASH := "res://scenes/levels/fighter_crash/fighter_crash.tscn"
## Endroit du sandbox où ranger un ennemi inutile au test.
const FAR_AWAY := Vector3(25, 0, -25)

var level: Node


func before_each() -> void:
	# Tirages (parade, coups, précision) reproductibles d'un test à l'autre.
	seed(1234)
	GameState.alert_level = GameState.AlertLevel.CALM
	Roof.view_level = -1


func after_each() -> void:
	_free_level()


## Charge et démarre la scène `path`, puis laisse la navigation se générer.
func load_level(path: String = SANDBOX) -> Node:
	_free_level()
	level = load(path).instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	# Navigation générée en arrière-plan derrière l'écran de chargement.
	if level is LevelRoot and not level.is_level_ready:
		await wait_for_signal(level.level_ready, 30.0)
	await wait_physics_frames(20)
	return level


func node(path: String) -> Node:
	return level.get_node(path)


## Attend que `condition` soit vraie, au plus `max_frames` images de physique.
## Renvoie le nombre d'images écoulées, ou -1 si elle ne l'est jamais devenue.
func frames_until(condition: Callable, max_frames: int) -> int:
	for i in max_frames:
		await get_tree().physics_frame
		if condition.call():
			return i
	return -1


## Attend `count` images de physique.
func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Met un ennemi hors jeu : loin, immobile et aveugle.
func park(enemy: Enemy, at: Vector3 = FAR_AWAY) -> void:
	enemy.global_position = at
	enemy.set_physics_process(false)


## Rend `unit` invisible aux ennemis (ils ne passent pas en alerte devant lui).
func hide_from_enemies(unit: Commando) -> void:
	unit.remove_from_group(&"commandos")


## Copie propre des réglages de l'unité, à modifier sans toucher à la
## ressource partagée par toutes les unités.
func own_stats(unit: Commando) -> UnitStats:
	unit.stats = unit.stats.duplicate() as UnitStats
	return unit.stats


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _free_level() -> void:
	if is_instance_valid(level):
		get_tree().root.remove_child(level)
		level.free()
	level = null
