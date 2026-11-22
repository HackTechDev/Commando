class_name GameRng
extends RefCounted
## Hasard rejouable : chaque nœud qui tire au sort une issue de jeu (parade,
## esquive, précision d'un tir ou d'un lancer, couverture, regard et fouille
## d'un ennemi…) a son propre générateur (`of`), dont la graine dérive de la
## graine de la mission et du chemin du nœud. Une même graine rejoue donc
## les mêmes tirages, et les tirages d'une unité ne dépendent pas de ceux
## des autres (ni de l'ordre dans lequel elles agissent).
##
## La graine de la mission est tirée au chargement du niveau
## (`begin_mission`, appelé par `LevelRoot`), sauf si elle est imposée :
## `forced_seed` (tests), ou l'argument `--seed=N` après `--` sur la ligne
## de commande. Les effets purement visuels (débris, gerbes, sons) gardent
## le hasard global de Godot : ils ne décalent pas les tirages de jeu.

const META := &"game_rng"
## Graine imposée (négative : aucune).
static var forced_seed: int = -1
## Graine de la mission en cours.
static var mission_seed: int = 0


## Nouvelle mission : graine imposée, ou tirée au hasard. Les générateurs
## des nœuds sont recréés à leur premier tirage.
static func begin_mission() -> int:
	mission_seed = forced_seed if forced_seed >= 0 else _seed_from_command_line()
	if mission_seed < 0:
		var source := RandomNumberGenerator.new()
		source.randomize()
		mission_seed = source.randi() & 0x7fffffff
	return mission_seed


static func _seed_from_command_line() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return int(arg.trim_prefix("--seed="))
	return -1


## Générateur du nœud `node` (créé au premier appel).
static func of(node: Node) -> RandomNumberGenerator:
	if node.has_meta(META):
		return node.get_meta(META)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([mission_seed, String(node.get_path()) if node.is_inside_tree() else String(node.name)])
	node.set_meta(META, rng)
	return rng


## État du générateur de `node` (sauvegarde rapide).
static func save(node: Node) -> int:
	return of(node).state


## Rend l'état `state` (sauvegarde rapide) au générateur de `node`.
static func load(node: Node, state: Variant) -> void:
	if state is int:
		of(node).state = state


## Vrai avec la probabilité `chance`, tiré par `node`.
static func chance(node: Node, probability: float) -> bool:
	return of(node).randf() < probability


## Signe au hasard (1 ou -1), tiré par `node`.
static func side(node: Node) -> float:
	return 1.0 if of(node).randf() < 0.5 else -1.0
