class_name EnemyChase
extends EnemyBehavior
## Alerte : cible en vue, il lui fait face et tire (`EnemyGunner`) jusqu'à
## sa distance de tir ; au contact, il frappe (`EnemyBrawler`). Sans arme ou
## garde levée, il vient au contact ; un camarade déjà au contact, il prend
## la cible de flanc. Cible perdue, il court au dernier point connu ; une
## fois arrivé (`arrived`), sa mémoire s'épuise, puis il fouille
## (`Enemy._update_detection`).

## Arrivé au dernier point connu sans revoir la cible.
var arrived: bool = false


## Passage en alerte : il vise avant le premier tir.
func enter() -> void:
	arrived = false
	enemy.gunner.cooldown = enemy.stats.aim_time


func update(delta: float) -> Vector3:
	var target := enemy._target
	var to_target := enemy._last_seen - enemy.global_position
	to_target.y = 0.0
	if target:
		arrived = false
		enemy._face(to_target, delta)
		# Cible perchée (caisse, mur, toit) : hors d'atteinte des coups.
		var perched := absf(enemy._last_seen.y - enemy.global_position.y) > Enemy.MELEE_MAX_HEIGHT
		if to_target.length() <= enemy.stats.melee_range and not perched:
			# Au contact : il frappe au lieu de tirer.
			enemy.brawler.try_strike(to_target)
			return Vector3.ZERO
		# Garde levée, il ne tire pas : il avance pour frapper.
		var guarding := enemy.is_guarding() and not perched
		if not guarding:
			enemy.gunner.try_fire(delta, to_target)
		# Sans arme (ou en garde), il vient au contact. Armé, face à une cible
		# perchée, il tire d'où il est plutôt que de chercher à passer dessous.
		var armed := enemy.can_fire()
		var hold := enemy.stats.hold_range if armed and not guarding else enemy.stats.melee_range * 0.8
		if armed and perched:
			hold = maxf(hold, enemy.stats.fire_range * 0.9)
		if to_target.length() <= hold:
			return Vector3.ZERO
	var goal := enemy._last_seen
	var flank := enemy.brawler.flank_point()
	if flank != Vector3.INF:
		goal = flank
	var agent := enemy._agent
	if agent.target_position.distance_to(goal) > 0.5:
		agent.target_position = goal
	if agent.is_navigation_finished():
		arrived = target == null
		return Vector3.ZERO
	return enemy._path_direction(delta, target == null) * enemy.stats.chase_speed
