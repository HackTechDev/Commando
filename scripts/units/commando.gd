class_name Commando
extends Unit
## Unité contrôlable par le joueur : déplacement par navigation et postures.
## Ce qu'elle fait est décrit par deux actions (`CommandoAction`) : l'ordre
## en cours (`_order` : se déplacer, attaquer, s'approcher pour grimper,
## frapper ou lancer, tenir une caisse) et le geste en cours (`_gesture` :
## frappe, lancer, pose de charge, soins, ramassage, parade, recul), qui passe
## avant l'ordre. Voir `scripts/units/actions/`.

signal selected_changed(is_selected: bool)
signal sling_changed(slung: bool)
## Arme en main changée (secondaire ou principale).
signal weapon_changed(secondary: bool)
## Bouclier levé ou baissé (choix du joueur).
signal shield_changed(raised: bool)

## Corps à corps : couteau (tue), assommer, balayage (assomme moins
## longtemps), projection (au sol par-dessus la hanche, puis assommé).
enum MeleeKind { KNIFE, KNOCKOUT, SWEEP, THROW, DISARM, HOSTAGE, HATCHET }

const MASK_OCCLUDERS := 0b10
## Indicatif affiché au-dessus de la tête : couleur, couleur une fois
## sélectionné, et hauteur selon la posture (debout, accroupi, rampé).
const CALLSIGN_COLOR := Color(0.85, 0.92, 1.0, 0.85)
const CALLSIGN_SELECTED := Color(1.0, 0.85, 0.4, 1.0)
const CALLSIGN_HEIGHTS: Array[float] = [2.05, 1.55, 0.85]
## Raison pour laquelle l'opérateur ne tire pas ou ne lance pas, affichée
## sous son indicatif (`report_hint` pendant un ordre, `flash_hint` pour un
## ordre refusé).
enum Hint { NONE, OUT_OF_RANGE, OBSTACLE, NO_AMMO, NO_KNIFE, NO_GRENADE, NO_SMOKE, NO_GRAPNEL, MESSAGE }
const HINT_TEXTS: Dictionary = {
	Hint.OUT_OF_RANGE: "Hors de portée",
	Hint.OBSTACLE: "Obstacle : pas de ligne de tir",
	Hint.NO_AMMO: "À sec",
	Hint.NO_KNIFE: "Plus de couteau",
	Hint.NO_GRENADE: "Plus de grenade",
	Hint.NO_SMOKE: "Plus de fumigène",
	Hint.NO_GRAPNEL: "Pas de grappin (à équiper : écran Opérateurs)",
	# Texte libre (`flash_message`).
	Hint.MESSAGE: "",
}
const HINT_COLOR := Color(1.0, 0.62, 0.3)
## Durée d'affichage d'un refus.
const FLASH_TIME := 1.6
## Distance (entre centres) à partir de laquelle une attaque au corps à corps est possible.
const MELEE_RANGE := 1.3
## Instant de l'attaque (0 à 1) où le coup porte.
const STRIKE_HIT_TIME := 0.45
## Marge tolérée si la cible s'éloigne pendant l'élan.
const STRIKE_REACH_MARGIN := 0.4
## Évitement : en dessous de cette part de la vitesse voulue, l'unité est
## considérée comme bloquée et fait un pas de côté.
const BLOCKED_RATIO := 0.4
const SIDESTEP_RATIO := 0.7
## Part de la vitesse au sol utilisée pour marcher d'une caisse à l'autre.
const CRATE_WALK_RATIO := 0.6
# Avancée et élévation du corps pendant l'escalade, par paires (instant,
# fraction du trajet), calées sur les images clés de `SoldierModel`.
const CLIMB_UP_FORWARD: Array[float] = [0, 0, 0.12, 0.069, 0.26, 0.194, 0.45, 0.312, 0.54, 0.3, 0.62, 0.344, 0.72, 0.5, 0.84, 0.75, 1, 1]
const CLIMB_UP_HEIGHT: Array[float] = [0, 0, 0.12, 0, 0.26, 0.06, 0.45, 0.438, 0.54, 0.709, 0.62, 0.674, 0.72, 0.938, 0.84, 1, 1, 1]
const CLIMB_DOWN_FORWARD: Array[float] = [0, 0, 0.25, 0.3, 0.35, 0.529, 0.45, 0.688, 0.6, 0.85, 0.74, 1, 1, 1]
const CLIMB_DOWN_HEIGHT: Array[float] = [0, 0, 0.25, 0, 0.35, 0.006, 0.45, 0.338, 0.6, 0.668, 0.74, 1, 1, 1]
## Au-delà de ce dénivelé (m), on descend en sautant (`SoldierModel.JUMP_*`).
const JUMP_MIN_DROP := 1.5
## Saut : pas jusqu'au bord, impulsion (part du trajet horizontal, hauteur
## négative = au-dessus du départ), puis vol de JUMP_TAKEOFF à JUMP_LANDING,
## parabole en hauteur (chute accélérée), droite à l'horizontale.
const JUMP_PREP_FORWARD: Array[float] = [0, 0, 0.18, 0.26, 0.26, 0.35]
const JUMP_PREP_HEIGHT: Array[float] = [0, 0, 0.18, 0, 0.26, -0.04]
const JUMP_TAKEOFF := 0.26
const JUMP_LANDING := 0.62
## Vitesse verticale d'impulsion (en part du dénivelé, vers le haut).
const JUMP_LIFT := 0.1
## Bouclier levé : part de la vitesse de marche (on ne court pas avec).
const SHIELD_SPEED := 0.7
## Parade au choix du joueur (touche de parade) : un coup qui porte dans les
## `PARRY_WINDOW` secondes qui suivent l'appui est paré ; on ne peut
## rappuyer qu'après `PARRY_COOLDOWN` secondes (pas de parade permanente).
## Bouclier humain : part de la vitesse de marche, et message quand une
## action demande les deux mains.
const HOSTAGE_SPEED := 0.45
const HOSTAGE_BUSY := "Bouclier humain : relâchez d'abord l'otage"
## Porteur d'un corps : vitesse (part de la marche), message des actions
## refusées, hauteur (m) des épaules où repose le corps.
const CARRY_SPEED := 0.6
const CARRY_BUSY := "Mains prises : déposer d'abord le corps"
const CARRY_SHOULDER := 1.42
## Portée (m) d'un caillou lancé pour faire diversion.
const PEBBLE_RANGE := 14.0
## Corps à corps à plusieurs : un coéquipier inoccupé à moins de cette
## distance (m) d'un opérateur attaqué vient assommer l'assaillant.
const BACKUP_RANGE := 8.0
const PARRY_WINDOW := 0.45
const PARRY_COOLDOWN := 0.9

## Parade automatique (option) : tirage au sort selon `parry_chance` et
## `dodge_chance`, sans la touche. Posé par `Settings`.
static var auto_parry: bool = false

@export var stats: UnitStats
## Numéro de l'unité dans l'escouade (touches 1 à 6).
@export_range(1, 6) var unit_index: int = 1
@export var display_name: String = "Opérateur"
## Applique en mission la personnalisation de l'opérateur `unit_index` de
## l'équipe (`OperatorRoster`) : indicatif, arme, équipement, apparence.
@export var use_roster: bool = true

## Personnalisation appliquée (null : réglages de la scène).
var profile: OperatorProfile

var is_selected: bool = false
## Cartouches dans le chargeur engagé.
var ammo_in_magazine: int = 0
## Cartouches en réserve.
var ammo_reserve: int = 0
## Couteaux de lancer en main (à ramasser après chaque lancer).
var throwing_knives: int = 0
## Grenades, charges explosives et trousses de soins restantes.
var grenades: int = 0
var smoke_grenades: int = 0
var hatchets: int = 0
## Corps porté sur les épaules (`carry_body`), ou null.
var carried_body: Enemy
var explosives: int = 0
var medkits: int = 0
## Bouclier balistique emporté (0 ou 1).
var shields: int = 0:
	set(value):
		shields = value
		if _model:
			_model.carries_shield = value > 0
		if value > 0:
			add_to_group(&"shield_bearers")
		else:
			remove_from_group(&"shield_bearers")
			set_shield(false)
## Grappin emporté (0 ou 1) ; consommé au lancer (la corde reste en place).
var grapnels: int = 0:
	set(value):
		grapnels = value
		if _model:
			_model.carries_grapnel = value > 0
## Choix du joueur : bouclier levé (arme de poing en main). Il n'est
## effectivement tenu devant soi que pendant les déplacements et le tir
## (`is_shield_up`) ; les autres gestes le passent dans le dos un instant.
var shield_raised: bool = false
## Arme secondaire en main (`stats` est alors celui de l'arme secondaire).
var using_secondary: bool = false
## Obstacle sur lequel l'unité se tient, le cas échéant.
var perched_on: Climbable
## Ennemi tenu en bouclier humain, devant l'opérateur.
var hostage: Enemy

var _running: bool = false
var _fire_cooldown: float = 0.0
var _reload_left: float = 0.0
## Ordre en cours et geste en cours (null : aucun).
var _order: CommandoAction
var _gesture: CommandoAction
var _gear_noise_left: float = 0.0
## Réglages des deux armes, et munitions (chargeur, réserve) de celle rangée.
var _primary_stats: UnitStats
var _secondary_stats: UnitStats
var _holstered_ammo := Vector2i.ZERO
## Choix du joueur : arme à la bretelle (mains libres) plutôt qu'en main.
## Un ordre d'attaque ou de rechargement la fait reprendre en main.
var weapon_slung: bool = false:
	set(value):
		if value != weapon_slung:
			weapon_slung = value
			sling_changed.emit(value)
var _hopping: bool = false
## Vrai pendant une escalade (attente de la bretelle comprise).
var _climbing: bool = false
var _vertical_velocity: float = 0.0
var _last_health: float = INF
var _wants_to_move: bool = false
var _desired_velocity: Vector3
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Suivi de chemin sur terrain inégal (points bloqués, marches basses).
var _walker := PathWalker.new()
## Franchissement d'échelle ou de muret en cours.
var _traversal: LinkTraversal
## Raison affichée : signalée à chaque image par l'ordre en cours, ou
## brièvement après un refus.
var _hint: Hint = Hint.NONE
var _hint_frame: int = -100
var _flash: Hint = Hint.NONE
var _flash_text: String = ""
var _flash_left: float = 0.0
## Parade demandée : temps restant de la fenêtre, et avant de pouvoir rappuyer.
var _parry_left: float = 0.0
var _parry_cooldown: float = 0.0
var _hint_label: Label3D

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _ring: MeshInstance3D = $SelectionRing


func _ready() -> void:
	if use_roster:
		_apply_profile(OperatorRoster.current().profile(unit_index))
	health.reset(stats.max_health)
	_last_health = health.health
	ammo_in_magazine = stats.magazine_size
	ammo_reserve = stats.reserve_ammo
	throwing_knives = stats.throwing_knives
	grenades = stats.grenades
	smoke_grenades = stats.smoke_grenades
	hatchets = stats.hatchets
	explosives = stats.explosives
	medkits = stats.medkits
	shields = stats.shields
	grapnels = stats.grapnels
	_primary_stats = stats
	if _secondary_stats:
		_holstered_ammo = Vector2i(_secondary_stats.magazine_size, _secondary_stats.reserve_ammo)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_agent.velocity_computed.connect(_apply_velocity)
	_traversal = LinkTraversal.new(self, _model)
	_agent.link_reached.connect(_on_link_reached)
	_build_callsign()


## Petit texte de l'indicatif au-dessus de l'opérateur, toujours visible
## (même derrière un mur) et tourné vers la caméra.
func _build_callsign() -> void:
	var label := Label3D.new()
	label.name = "Callsign"
	label.text = display_name
	# Taille fixe à l'écran : lisible quel que soit le zoom.
	label.fixed_size = true
	label.font_size = 28
	label.outline_size = 8
	label.pixel_size = 0.0012
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	label.modulate = CALLSIGN_COLOR
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.render_priority = 1
	label.position.y = CALLSIGN_HEIGHTS[posture]
	add_child(label)
	_hint_label = label.duplicate() as Label3D
	_hint_label.name = "Hint"
	_hint_label.text = ""
	_hint_label.modulate = HINT_COLOR
	_hint_label.font_size = 24
	# Sous l'indicatif, à l'écran (taille fixe) : décalé vers le bas de la vue.
	_hint_label.offset = Vector2(0, -34)
	_hint_label.visible = false
	add_child(_hint_label)
	posture_changed.connect(func(new_posture: SoldierModel.Posture) -> void:
		var tween := label.create_tween().set_parallel(true)
		tween.tween_property(label, "position:y", CALLSIGN_HEIGHTS[new_posture], 0.25)
		tween.tween_property(_hint_label, "position:y", CALLSIGN_HEIGHTS[new_posture], 0.25))
	selected_changed.connect(func(value: bool) -> void:
		label.modulate = CALLSIGN_SELECTED if value else CALLSIGN_COLOR)


## Entrée d'un lien de navigation : échelle ou muret à franchir.
func _on_link_reached(details: Dictionary) -> void:
	var link := details.get("owner") as TraversalLink
	if link and not is_dead:
		_traversal.begin(link, details["link_entry_position"], details["link_exit_position"])


## Vrai pendant le franchissement d'une échelle ou d'un muret.
func is_traversing() -> bool:
	return _traversal != null and _traversal.active


## Indicatif, réglages des armes, équipement, charge portée, spécialité et
## apparence de `operator` (l'unité garde ses réglages si null).
func _apply_profile(operator: OperatorProfile) -> void:
	if operator == null:
		return
	profile = operator
	display_name = operator.callsign
	var base := stats
	stats = _equip(GearCatalog.apply_weapon(base, operator.primary), operator)
	var sidearm := GearCatalog.secondary_stats(base, operator.secondary)
	_secondary_stats = _equip(sidearm, operator) if sidearm else null
	_model.outfit = operator


## Complète les réglages d'une arme avec l'équipement, la charge et la
## spécialité de `operator`.
func _equip(weapon: UnitStats, operator: OperatorProfile) -> UnitStats:
	weapon.throwing_knives = operator.throwing_knives
	weapon.grenades = operator.grenades
	weapon.smoke_grenades = operator.smoke_grenades
	weapon.hatchets = operator.hatchet
	weapon.explosives = operator.explosives
	weapon.medkits = operator.medkit
	weapon.shields = operator.shield
	weapon.grapnels = operator.grapnel
	GearCatalog.apply_load_and_specialty(weapon, GearCatalog.load_of(operator), operator.specialty)
	return weapon


func _exit_tree() -> void:
	# Une unité retirée de la scène (changement de niveau…) quitte la sélection.
	SelectionManager.remove(self)


func _physics_process(delta: float) -> void:
	# Mains libres pour grimper, jouer du couteau, lancer, poser une charge,
	# soigner ou tenir une caisse : arme à la bretelle. Pour assommer, l'arme
	# reste comme le joueur l'a choisie (crosse ou mains nues).
	var hands_free := (_order != null and _order.hands_free()) or (_gesture != null and _gesture.hands_free())
	_model.weapon_slung = not is_dead and (weapon_slung or _climbing or hands_free or is_traversing())
	_update_reload(delta)
	_model.aiming = not is_dead and ((_order is AttackOrder and (_order as AttackOrder).is_aiming()) or (_order is FireAtOrder and (_order as FireAtOrder).is_aiming()))
	_model.look_target = _look_point()
	_model.shield_raised = is_shield_up()
	_model.hostage_hold = hostage != null
	_model.carrying = carried_body != null
	if carried_body:
		_model.weapon_slung = true
		if posture != SoldierModel.Posture.STANDING:
			posture = SoldierModel.Posture.STANDING
		_place_carried_body()
	if not is_dead and _traversal.update(delta):
		return
	if _hopping:
		return
	if is_handling_crate() and not is_dead:
		_run(_order, delta)
		return
	var horizontal := Vector3.ZERO
	if is_dead:
		pass
	elif _gesture:
		horizontal = _run(_gesture, delta)
	elif _order:
		horizontal = _run(_order, delta)

	# Se coucher ou se relever immobilise l'unité un instant.
	if _model.is_changing_posture():
		horizontal = Vector3.ZERO
	_vertical_velocity = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	_wants_to_move = horizontal != Vector3.ZERO
	_desired_velocity = horizontal
	_update_gear_noise(delta)
	_hold_hostage()
	# Une unité à l'arrêt est prioritaire : ce sont les autres qui la contournent.
	_agent.avoidance_priority = 0.5 if _wants_to_move else 1.0
	if _agent.avoidance_enabled:
		# L'évitement renvoie une vitesse corrigée via `velocity_computed`.
		_agent.velocity = horizontal
	else:
		_apply_velocity(horizontal)


## Avance `action` d'une image ; une fois terminée, elle laisse la place à
## sa suite éventuelle. Renvoie la vitesse horizontale voulue.
func _run(action: CommandoAction, delta: float) -> Vector3:
	var horizontal := action.update(delta)
	if action.done:
		if action == _gesture:
			_gesture = null
		elif action == _order:
			_order = null
		if action.next:
			_start(action.next)
	return horizontal


## Fait de `action` l'ordre ou le geste en cours.
func _start(action: CommandoAction) -> void:
	if action.gesture:
		if _gesture:
			_gesture.cancel()
		_gesture = action
	else:
		_set_order(action)
		return
	action.start()


## Remplace l'ordre en cours par `order` (null : aucun). Un geste
## interruptible (pose de charge, soins) est annulé ; les autres vont à leur
## terme, puis l'ordre commence.
func _set_order(order: CommandoAction) -> void:
	if _order and _order != order:
		_order.cancel()
	_order = order
	if _gesture and _gesture.interruptible:
		_gesture.cancel()
		_gesture = null
	if order:
		order.start()


## Abandonne toutes les actions (mort de l'unité).
func _cancel_actions() -> void:
	if _gesture:
		_gesture.cancel()
		_gesture = null
	if _order:
		_order.cancel()
		_order = null


## Ce que l'opérateur regarde : la cible du geste en cours, sinon celle de
## l'ordre (ennemi visé ou attaqué, point d'un lancer de grenade), sinon rien
## (`Vector3.INF`).
func _look_point() -> Vector3:
	if _gesture and _gesture.look_point() != Vector3.INF:
		return _gesture.look_point()
	return _order.look_point() if _order else Vector3.INF


## Applique la vitesse horizontale (éventuellement corrigée par l'évitement).
func _apply_velocity(horizontal: Vector3) -> void:
	# Pendant une escalade, une traversée de caisses ou le déplacement d'une
	# caisse, le déplacement et l'animation sont scriptés : la physique (et
	# l'évitement, qui rappelle cette fonction) ne doit pas s'en mêler.
	if _hopping or is_handling_crate() or is_traversing():
		return
	# Une unité à l'arrêt ne se laisse pas pousser par l'évitement.
	if not _wants_to_move:
		horizontal = Vector3.ZERO
	elif horizontal.length() < BLOCKED_RATIO * _desired_velocity.length():
		# Freiné presque à l'arrêt par une unité pile en face : pas de côté.
		horizontal += _desired_velocity.cross(Vector3.UP) * SIDESTEP_RATIO
	velocity = Vector3(horizontal.x, _vertical_velocity, horizontal.z)
	var before := global_position
	move_and_slide()
	_hold_hostage()
	# Bloqué net (moins de la moitié du pas voulu) : peut-être une marche basse.
	var wanted := horizontal * get_physics_process_delta_time()
	var moved := global_position - before
	var climbed := 0.0
	if Vector2(moved.x, moved.z).length() < 0.5 * Vector2(wanted.x, wanted.z).length():
		climbed = PathWalker.step_up(self, wanted)
	PathWalker.smooth_model(_model, climbed, get_physics_process_delta_time())
	_model.posture = posture
	_model.move_ratio = Vector2(velocity.x, velocity.z).length() / stats.walk_speed


## Ordonne un déplacement vers `target`. `run` n'a d'effet que debout.
func move_to(target: Vector3, run: bool) -> void:
	if is_dead or _hopping:
		return
	if is_handling_crate():
		# Mains sur une caisse : l'ordre de déplacement la pousse ou la tire.
		(_order as CrateHoldOrder).set_goal(target)
		return
	if perched_on:
		_set_order(null)
		_descend(target, move_to.bind(target, run))
		return
	_set_order(MoveOrder.new(self, target, run))


## Ordonne d'attaquer `enemy` : l'unité s'approche jusqu'à avoir une ligne de
## tir, puis tire jusqu'à ce que la cible soit neutralisée.
func attack(enemy: Enemy, run: bool) -> void:
	if is_dead or _hopping or enemy == null or enemy.is_dead:
		return
	if carried_body:
		flash_message(CARRY_BUSY)
		return
	if not _ready_to_fire():
		flash_hint(Hint.NO_AMMO)
		return
	weapon_slung = false
	_set_order(AttackOrder.new(self, enemy, run))


## Ordonne de grimper sur `target`. Renvoie faux si c'est impossible
## (déjà occupé, inaccessible, unité morte). Une corniche, trop haute depuis
## le sol, se gagne par un objet voisin (caisse) : l'unité monte d'abord
## dessus, puis grimpe jusqu'à la corniche.
func climb(target: Climbable, run: bool) -> bool:
	if _hostage_busy():
		return false
	if is_dead or _hopping or target == null or not target.can_stand_on:
		return false
	if perched_on == target:
		return true
	if target.occupant != null and target.occupant != self:
		return false
	if target.handler != null:
		return false
	_set_order(null)
	if perched_on:
		var route := _route_across(perched_on, target)
		if not route.is_empty():
			_walk_across(route)
			return true
		if not _descend(target.global_position, climb.bind(target, run)):
			return false
		return true
	var then := Callable()
	if not target.climbable_from_ground:
		var entry := _nearest_entry(target)
		if entry == null:
			return false
		then = _continue_across.bind(target)
		target = entry
	var access := target.get_nearest_access(global_position)
	if not access["found"]:
		return false
	_set_order(ClimbOrder.new(self, target, access["point"], then, run))
	return true


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
	release_crate()
	weapon_slung = false
	_reload_left = stats.reload_time
	EventBus.unit_ammo_changed.emit(self)
	Sfx.play_at(&"reload", global_position + Vector3.UP, -8.0)


## Ordonne d'éliminer `enemy` au corps à corps : l'unité s'en approche (à la
## vitesse de sa posture), puis frappe. Au couteau, l'ennemi est tué ; sinon il
## est assommé. Renvoie faux si l'ordre est impossible.
func melee(enemy: Enemy, kind: MeleeKind, run: bool = false) -> bool:
	if is_dead or _hopping or enemy == null or enemy.is_dead:
		return false
	if hostage:
		# L'otage lui-même : on l'assomme sur place ; les autres attendront.
		if enemy == hostage and kind == MeleeKind.KNOCKOUT:
			release_hostage(true)
			return true
		_hostage_busy()
		return false
	if kind == MeleeKind.HOSTAGE and _secondary_stats == null:
		flash_message("Bouclier humain : il faut une arme de poing")
		return false
	if kind == MeleeKind.HATCHET and hatchets <= 0:
		flash_message("Pas de hachette (à équiper : écran Opérateurs)")
		return false
	if not finishes(kind) and enemy.is_stunned():
		return false
	if kind == MeleeKind.DISARM and not enemy.can_be_disarmed():
		return false
	if perched_on:
		return _descend(enemy.global_position, melee.bind(enemy, kind, run))
	_set_order(MeleeOrder.new(self, enemy, kind, run))
	return true


## Vrai si le coup `kind` achève un ennemi au sol (lames).
static func finishes(kind: MeleeKind) -> bool:
	return kind == MeleeKind.KNIFE or kind == MeleeKind.HATCHET


## Ordonne de lancer un couteau sur `enemy` : l'unité s'approche à portée,
## avec une ligne de vue dégagée, puis lance. Renvoie faux si c'est
## impossible (plus de couteau, cible morte…).
func throw_knife(enemy: Enemy, run: bool = false) -> bool:
	if _hostage_busy():
		return false
	if not is_dead and throwing_knives <= 0:
		flash_hint(Hint.NO_KNIFE)
	if is_dead or _hopping or enemy == null or enemy.is_dead or throwing_knives <= 0:
		return false
	if perched_on and not _can_throw_at(enemy):
		return _descend(enemy.global_position, throw_knife.bind(enemy, run))
	_set_order(KnifeThrowOrder.new(self, enemy, run))
	return true


## Ramasse un couteau de lancer au sol. Renvoie faux s'il en a déjà son compte.
func pick_up_knife() -> bool:
	if _hostage_busy():
		return false
	if is_dead or throwing_knives >= stats.throwing_knives:
		return false
	throwing_knives += 1
	EventBus.unit_ammo_changed.emit(self)
	Sfx.play_at(&"clink", global_position, -12.0)
	# Il se baisse s'il n'est pas déjà occupé ; son ordre reprend ensuite.
	if _gesture == null and not _hopping:
		_start(PickupGesture.new(self))
	return true


## Vrai si l'unité a une arme secondaire.
func has_secondary() -> bool:
	return _secondary_stats != null


## Change d'arme (principale ↔ secondaire). Un rechargement en cours est
## interrompu. Renvoie faux sans arme secondaire.
func switch_weapon() -> bool:
	if is_dead or _secondary_stats == null or carried_body:
		return false
	_reload_left = 0.0
	_model.reload_progress = -1.0
	var in_hand := Vector2i(ammo_in_magazine, ammo_reserve)
	ammo_in_magazine = _holstered_ammo.x
	ammo_reserve = _holstered_ammo.y
	_holstered_ammo = in_hand
	using_secondary = not using_secondary
	stats = _secondary_stats if using_secondary else _primary_stats
	# L'arme principale se tient à deux mains : le bouclier passe dans le dos.
	if not using_secondary:
		set_shield(false)
	_model.sidearm_drawn = using_secondary
	_fire_cooldown = stats.aim_time
	weapon_slung = false
	Sfx.play_at(&"reload", global_position + Vector3.UP, -12.0)
	EventBus.unit_ammo_changed.emit(self)
	weapon_changed.emit(using_secondary)
	return true


## Vrai si l'unité peut tirer : munitions dans l'arme en main, sinon elle
## dégaine l'autre arme s'il lui en reste.
func _ready_to_fire() -> bool:
	if has_ammo():
		return true
	if _secondary_stats and _holstered_ammo.x + _holstered_ammo.y > 0:
		return switch_weapon()
	return false


## Ordonne de lancer une grenade vers `target` (au sol) : l'unité s'approche
## à portée, puis lance. Renvoie faux sans grenade.
func throw_grenade(target: Vector3, run: bool = false) -> bool:
	if _hostage_busy():
		return false
	if not is_dead and grenades <= 0:
		flash_hint(Hint.NO_GRENADE)
	if is_dead or _hopping or grenades <= 0:
		return false
	if perched_on and not _in_grenade_range(target):
		return _descend(target, throw_grenade.bind(target, run))
	_set_order(GrenadeOrder.new(self, target, run))
	return true


## Ordonne de lancer un caillou vers `target` pour faire diversion : les
## ennemis qui l'entendent tomber vont voir. Sans limite de cailloux.
func throw_pebble(target: Vector3, run: bool = false) -> bool:
	if _hostage_busy():
		return false
	if is_dead or _hopping:
		return false
	if perched_on and not _in_grenade_range(target, PEBBLE_RANGE):
		return _descend(target, throw_pebble.bind(target, run))
	_set_order(GrenadeOrder.new(self, target, run, SoldierModel.ThrowObject.PEBBLE))
	return true


## Ordonne de lancer une grenade fumigène vers `target` : un nuage qui coupe
## la vue des ennemis (`SmokeCloud`). Renvoie faux sans fumigène.
func throw_smoke(target: Vector3, run: bool = false) -> bool:
	if _hostage_busy():
		return false
	if not is_dead and smoke_grenades <= 0:
		flash_hint(Hint.NO_SMOKE)
	if is_dead or _hopping or smoke_grenades <= 0:
		return false
	if perched_on and not _in_grenade_range(target):
		return _descend(target, throw_smoke.bind(target, run))
	_set_order(GrenadeOrder.new(self, target, run, SoldierModel.ThrowObject.SMOKE))
	return true


## Nombre d'objets `object` qu'il peut encore lancer (cailloux sans limite).
func throwables(object: SoldierModel.ThrowObject) -> int:
	match object:
		SoldierModel.ThrowObject.GRENADE:
			return grenades
		SoldierModel.ThrowObject.SMOKE:
			return smoke_grenades
	return 1


## Lâche `object` vers `target` (instant du lancer de `ThrowGesture`).
func _release_throwable(object: SoldierModel.ThrowObject, target: Vector3) -> void:
	match object:
		SoldierModel.ThrowObject.GRENADE:
			_release_grenade(target)
		SoldierModel.ThrowObject.SMOKE:
			_release_grenade(target, true)
		SoldierModel.ThrowObject.PEBBLE:
			_release_pebble(target)


## Vrai si `target` est à portée de lancer (`reach`, ou celle d'une grenade).
func _in_grenade_range(target: Vector3, reach: float = -1.0) -> bool:
	var offset := target - global_position
	offset.y = 0.0
	return offset.length() <= (stats.grenade_range if reach < 0.0 else reach)


## Ordonne de lancer le grappin vers `target` (un point en hauteur) puis d'y
## monter à la corde. Renvoie faux si c'est impossible (pas de grappin,
## point hors de portée, pas de paroi à gravir : voir `grapple_route`).
func grapple(target: Vector3, run: bool = false) -> bool:
	if _hostage_busy():
		return false
	if not is_dead and grapnels <= 0:
		flash_hint(Hint.NO_GRAPNEL)
	if is_dead or _hopping or grapnels <= 0 or perched_on:
		return false
	var route := grapple_route(target)
	if not route["ok"]:
		flash_message("Grappin : %s" % route["reason"])
		return false
	_set_order(GrappleOrder.new(self, route, run))
	return true


## Trajet de la corde d'un grappin lancé vers `target` (`GrapnelRope.plan`).
func grapple_route(target: Vector3) -> Dictionary:
	return GrapnelRope.plan(get_world_3d(), global_position, target)


## Lâche le grappin (instant du lancer de `ThrowGesture`) ; accroché, il
## monte à la corde jusqu'au point visé, sauf si un autre ordre a été donné.
func _release_grapnel(route: Dictionary) -> void:
	if grapnels <= 0:
		return
	grapnels -= 1
	EventBus.unit_ammo_changed.emit(self)
	var hand := global_position + Vector3.UP * (_weapon_height() + 0.3) + global_basis.x * 0.15
	var rope := GrapnelRope.launch(get_tree().current_scene, hand, route)
	Sfx.play_at(&"whoosh", hand, -6.0)
	await rope.anchored
	# La corde rejoint la navigation à la synchronisation suivante.
	for i in 3:
		await get_tree().physics_frame
	if is_dead or _order != null or _gesture != null:
		return
	move_to(route["anchor"], false)


## Lâche une grenade vers `target` (instant du lancer de `ThrowGesture`).
func _release_grenade(target: Vector3, smoke: bool = false) -> void:
	if (smoke_grenades if smoke else grenades) <= 0:
		return
	if smoke:
		smoke_grenades -= 1
	else:
		grenades -= 1
	EventBus.unit_ammo_changed.emit(self)
	var hand := global_position + Vector3.UP * (_weapon_height() + 0.3) + global_basis.x * 0.15
	Grenade.spawn(get_tree().current_scene, hand, target + Vector3.UP * 0.05, stats, smoke)
	Sfx.play_at(&"whoosh", hand, -8.0)


func _release_pebble(target: Vector3) -> void:
	var hand := global_position + Vector3.UP * (_weapon_height() + 0.3) + global_basis.x * 0.15
	Pebble.spawn(get_tree().current_scene, hand, target + Vector3.UP * 0.03)
	Sfx.play_at(&"whoosh", hand, -12.0)


## Pose une charge explosive aux pieds de l'unité (elle s'accroupit le temps
## de l'armer). Renvoie faux s'il ne lui en reste pas ou qu'elle est occupée.
func plant_explosive() -> bool:
	if _hostage_busy():
		return false
	if is_dead or _hopping or explosives <= 0 or _gesture != null or is_handling_crate():
		return false
	stop()
	_start(PlantGesture.new(self))
	return true


## Vrai pendant la pose d'une charge.
func is_planting() -> bool:
	return _gesture is PlantGesture


## Fait sauter les charges posées par l'unité. Renvoie leur nombre.
func detonate_explosives() -> int:
	if is_dead:
		return 0
	var charges := ExplosiveCharge.planted_by(get_tree(), self)
	for charge in charges:
		charge.detonate()
	if not charges.is_empty():
		EventBus.unit_ammo_changed.emit(self)
	return charges.size()


## Soigne l'opérateur le plus blessé à portée (l'unité elle-même comprise)
## avec une trousse. Renvoie faux sans trousse ou sans blessé à portée.
func use_medkit() -> bool:
	if _hostage_busy():
		return false
	if is_dead or _hopping or medkits <= 0 or _gesture != null:
		return false
	var patient := _most_wounded_nearby()
	if patient == null:
		return false
	stop()
	_start(HealGesture.new(self, patient))
	return true


## Vrai pendant des soins.
func is_healing() -> bool:
	return _gesture is HealGesture


func _most_wounded_nearby() -> Commando:
	var best: Commando = null
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var unit := node as Commando
		if unit == null or unit.is_dead or unit.health.health >= unit.health.max_health:
			continue
		if unit.global_position.distance_to(global_position) > stats.heal_range:
			continue
		if best == null or unit.health.health < best.health.health:
			best = unit
	return best


## Charge lourde : l'équipement s'entrechoque quand l'opérateur court.
func _update_gear_noise(delta: float) -> void:
	if stats.gear_noise_radius <= 0.0 or not _wants_to_move or not _running or posture != SoldierModel.Posture.STANDING:
		return
	_gear_noise_left -= delta
	if _gear_noise_left <= 0.0:
		_gear_noise_left = stats.gear_noise_interval
		EventBus.noise_emitted.emit(global_position, stats.gear_noise_radius, &"gear")


## Vrai pendant une attaque au corps à corps (élan et coup).
func is_striking() -> bool:
	return _gesture is StrikeGesture


## Vrai pendant une prise par derrière (étranglement, égorgement).
func is_grappling() -> bool:
	return _gesture is StrikeGesture and (_gesture as StrikeGesture).grapple


## Vrai pendant une parade ou une esquive.
func is_defending() -> bool:
	return _gesture is DefendGesture


## Vrai pendant un lancer (couteau ou grenade).
func is_throwing() -> bool:
	return _gesture is ThrowGesture


## Ennemi que l'unité a ordre de neutraliser au corps à corps (null : aucun).
func melee_target() -> Enemy:
	return (_order as MeleeOrder).enemy if _order is MeleeOrder else null


## Prend `enemy` en bouclier humain (fin de la saisie par derrière) : il
## reste debout devant l'opérateur, qui dégaine son arme de poing.
func take_hostage(enemy: Enemy) -> void:
	if is_dead or enemy == null or enemy.is_dead:
		return
	enemy.grab()
	hostage = enemy
	enemy.captor = self
	add_collision_exception_with(enemy)
	posture = SoldierModel.Posture.STANDING
	set_shield(false)
	release_crate()
	_running = false
	if not using_secondary:
		switch_weapon()
	weapon_slung = false
	_hold_hostage()


## Lâche l'otage : il se dégage et donne l'alerte, sauf s'il est assommé
## (`knock_out`, d'un coup de crosse sur la tempe).
func release_hostage(knock_out: bool = false) -> void:
	var enemy := hostage
	if enemy == null:
		return
	_drop_hostage()
	if not is_instance_valid(enemy) or enemy.is_dead:
		return
	if knock_out:
		enemy.knock_out(true)
		Sfx.play_at(&"punch", enemy.global_position + Vector3.UP * 1.5)
		EventBus.noise_emitted.emit(global_position, stats.melee_noise_radius, &"melee")
	else:
		enemy.release()


## Oublie l'otage, sans rien lui faire.
func _drop_hostage() -> void:
	var enemy := hostage
	hostage = null
	_model.hostage_hold = false
	if is_instance_valid(enemy):
		enemy.captor = null
		remove_collision_exception_with(enemy)


## Maintient l'otage devant soi, tourné comme l'opérateur.
func _hold_hostage() -> void:
	if hostage == null:
		return
	if not is_instance_valid(hostage) or hostage.is_dead or hostage.state != Enemy.State.GRABBED:
		_drop_hostage()
		return
	var spot := global_position - global_basis.z * SoldierModel.GRAB_DISTANCE
	hostage.global_position = Vector3(spot.x, hostage.global_position.y, spot.z)
	hostage.rotation.y = rotation.y
	hostage.velocity = Vector3.ZERO


## Vrai (et l'opérateur le signale) si l'otage lui occupe les mains.
func _hostage_busy() -> bool:
	if carried_body != null:
		flash_message(CARRY_BUSY)
		return true
	if hostage == null:
		return false
	flash_message(HOSTAGE_BUSY)
	return true


## Ordonne d'aller prendre le corps `body` (mort ou assommé) sur l'épaule.
## Renvoie faux si c'est impossible.
func carry_body(body: Enemy, run: bool = false) -> bool:
	if _hostage_busy():
		return false
	if is_dead or _hopping or body == null or not body.is_body() or body.carrier != null:
		return false
	if perched_on:
		return _descend(body.body_center(), carry_body.bind(body, run))
	_set_order(CarryOrder.new(self, body, run))
	return true


## Va à la porte `door` et l'ouvre ou la ferme ; verrouillée, la crochète.
## Renvoie faux si l'unité ne peut pas y aller.
func use_door(door: Door, run: bool = false) -> bool:
	if _hostage_busy():
		return false
	if is_dead or _hopping or door == null or door.is_broken or carried_body != null and door.is_locked and not door.is_open:
		return false
	if perched_on:
		return _descend(door.near_side(global_position), use_door.bind(door, run))
	_set_order(DoorOrder.new(self, door, run))
	return true


## Vrai pendant un crochetage de porte.
func is_picking_lock() -> bool:
	return _order is DoorOrder and (_order as DoorOrder).picking


## Prend `body` sur les épaules (instant du geste de `CarryOrder`).
func _lift_body(body: Enemy) -> void:
	if not is_instance_valid(body) or not body.is_body() or body.carrier != null or carried_body != null:
		return
	carried_body = body
	body.carry(self)
	weapon_slung = true
	_place_carried_body()


## Reprend sur les épaules le corps d'une sauvegarde, dans sa pose relevée.
func _relift_body(path: NodePath) -> void:
	var body := get_node_or_null(path) as Enemy
	if body == null or is_dead or not body.is_body():
		return
	carried_body = body
	body.carry(self, false)
	weapon_slung = true
	_place_carried_body()


## Dépose le corps porté au sol, le long de son flanc droit. Renvoie faux
## s'il ne porte rien.
func drop_body() -> bool:
	if carried_body == null:
		return false
	var body := carried_body
	carried_body = null
	# Couché le long du flanc droit, la tête vers l'avant du porteur.
	var hips := global_position + global_basis.x * 0.9
	body.put_down(hips, -global_basis.z, body.carried_hips, body.carried_axis)
	if not is_dead:
		_model.play_pickup()
	Sfx.play_at(&"fall", hips, -8.0)
	return true


## Corps porté en travers des épaules : la tête vers la gauche du
## porteur, ventre contre l'épaule, le bassin dessus.
func _place_carried_body() -> void:
	if not is_instance_valid(carried_body):
		carried_body = null
		return
	var body := carried_body
	var axis := body.carried_axis
	# Le dos (face contre terre) ou le ventre reste en haut ou passe en bas
	# pour que le ventre repose sur l'épaule.
	var up := Vector3.UP if body._model.is_face_down() else Vector3.DOWN
	var head := -global_basis.x
	var lying := Basis(Vector3.UP.cross(axis), Vector3.UP, axis)
	var carried := Basis(up.cross(head), up, head)
	var basis := carried * lying.inverse()
	var shoulder := global_position + Vector3.UP * CARRY_SHOULDER + global_basis.z * 0.05
	body.global_transform = Transform3D(basis, shoulder - basis * body.carried_hips)
	body._model.position.y = 0.0


## Arrête l'ordre en cours (déplacement, attaque, caisse…) et une pose de
## charge ou des soins ; un coup ou un lancer déjà commencé va à son terme.
func stop() -> void:
	_set_order(null)


## Ordonne de pousser ou tirer `crate` : l'unité rejoint le côté le plus
## proche de `near`, passe son arme à la bretelle et pose les mains dessus.
## Ensuite, un ordre de déplacement fait glisser la caisse dans l'axe de ce
## côté. Renvoie faux si c'est impossible (caisse occupée, aucun côté libre).
func handle_crate(crate: Climbable, near: Vector3) -> bool:
	if _hostage_busy():
		return false
	if is_dead or _hopping or crate == null or not crate.movable or crate.occupant != null:
		return false
	if crate.handler != null and crate.handler != self:
		return false
	if perched_on:
		return _descend(near, handle_crate.bind(crate, near))
	var side := crate.get_side_toward(near)
	if side == Vector3.ZERO:
		return false
	_set_order(CrateApproachOrder.new(self, crate, side))
	return true


## Lâche la caisse tenue (ou abandonne l'approche).
func release_crate() -> void:
	if _order is CrateHoldOrder or _order is CrateApproachOrder:
		_set_order(null)


## Vrai pendant qu'il tient une caisse.
func is_handling_crate() -> bool:
	return _order is CrateHoldOrder


## Passe l'arme à la bretelle, ou la reprend en main.
func toggle_sling() -> void:
	if is_dead:
		return
	weapon_slung = not weapon_slung
	# Reprendre son arme oblige à lâcher la caisse.
	if not weapon_slung:
		release_crate()


## Roulade vers `toward` : l'opérateur plonge et finit couché. Refusée
## couché, perché, en plein geste ou un otage dans les bras. Renvoie vrai si
## elle commence.
func dive(toward: Vector3) -> bool:
	if _hostage_busy():
		return false
	if is_dead or _hopping or _climbing or perched_on or is_traversing() or _gesture != null:
		return false
	if posture == SoldierModel.Posture.PRONE or _model.is_changing_posture():
		return false
	release_crate()
	set_shield(false)
	_set_order(null)
	_start(DiveGesture.new(self, toward))
	return true


## Vrai pendant une roulade.
func is_diving() -> bool:
	return _gesture is DiveGesture


## Bascule entre `new_posture` et debout.
func toggle_posture(new_posture: SoldierModel.Posture) -> void:
	if is_dead:
		return
	if hostage or carried_body:
		# Debout, l'otage devant soi ou le corps sur les épaules.
		_hostage_busy()
		return
	posture = SoldierModel.Posture.STANDING if posture == new_posture else new_posture
	# On ne rampe pas derrière un bouclier.
	if posture == SoldierModel.Posture.PRONE:
		set_shield(false)
	# On ne déplace une caisse que debout.
	if posture != SoldierModel.Posture.STANDING:
		release_crate()


## Lève (`raised`) ou baisse le bouclier. Le lever fait dégainer l'arme de
## poing (le bouclier occupe la main gauche) et relever un opérateur couché ;
## il est refusé sans bouclier ni arme secondaire. Renvoie vrai si le
## bouclier est dans l'état demandé.
func set_shield(raised: bool) -> bool:
	if raised == shield_raised:
		return true
	if raised and _hostage_busy():
		return false
	if raised:
		if is_dead or shields <= 0 or _secondary_stats == null:
			return false
		if not using_secondary:
			switch_weapon()
		if posture == SoldierModel.Posture.PRONE:
			posture = SoldierModel.Posture.CROUCHED
		weapon_slung = false
		release_crate()
	shield_raised = raised
	Sfx.play_at(&"reload", global_position + Vector3.UP, -10.0)
	shield_changed.emit(raised)
	return true


## Vrai si le bouclier est tenu devant l'opérateur : levé, et pas occupé à un
## geste, une escalade, une caisse ou une poussée.
func is_shield_up() -> bool:
	return shield_raised and not is_dead and _gesture == null and not _climbing and not _hopping \
			and not is_handling_crate() and posture != SoldierModel.Posture.PRONE and perched_on == null


## Point où le segment de tir `from` → `to` est arrêté par un bouclier levé
## (le plus proche du tireur), ou `Vector3.INF` si aucun ne le coupe. Protège
## le porteur et ceux qui s'abritent derrière lui.
static func shield_in_the_way(tree: SceneTree, from: Vector3, to: Vector3) -> Vector3:
	var best := Vector3.INF
	for node in tree.get_nodes_in_group(&"shield_bearers"):
		var unit := node as Commando
		if unit == null or not unit.is_shield_up():
			continue
		var stop := unit._model.shield_blocks(from, to)
		if stop != Vector3.INF and from.distance_to(stop) < from.distance_to(best):
			best = stop
	return best


## Met à jour l'état de sélection et l'anneau au sol.
func set_selected(value: bool) -> void:
	if is_selected == value or (value and is_dead):
		return
	is_selected = value
	_ring.visible = value
	selected_changed.emit(value)


## Redescend de l'obstacle du côté le plus proche de `toward`, puis appelle
## `then`. Renvoie faux s'il n'y a aucun côté praticable. D'une corniche, on
## repasse par un objet accessible depuis le sol s'il y en a un ; sinon, on
## saute.
func _descend(toward: Vector3, then: Callable) -> bool:
	if not perched_on.climbable_from_ground:
		var route := _route_to_ground(toward)
		if not route.is_empty():
			_walk_across(route, _descend.bind(toward, then))
			return true
	var access := perched_on.get_nearest_access(toward)
	if not access["found"]:
		return false
	var obstacle := perched_on
	perched_on = null
	_hop(access["point"], func() -> void:
		obstacle.occupant = null
		then.call())
	return true


## Obstacles qu'on peut atteindre depuis `from` sans toucher le sol, en
## passant par des obstacles libres : {obstacle: obstacle précédent}.
func _perch_graph(from: Climbable) -> Dictionary:
	var previous: Dictionary = {from: null}
	var queue: Array[Climbable] = [from]
	var all := get_tree().get_nodes_in_group(&"climbables")
	while not queue.is_empty():
		var current: Climbable = queue.pop_front()
		for node in all:
			var next := node as Climbable
			if next == null or previous.has(next) or not current.can_reach(next):
				continue
			if (next.occupant != null and next.occupant != self) or next.handler != null:
				continue
			previous[next] = current
			queue.append(next)
	return previous


## Chemin de `from` (exclu) à `to` (inclus) dans un graphe de `_perch_graph`.
static func _path_in(previous: Dictionary, from: Climbable, to: Climbable) -> Array[Climbable]:
	var route: Array[Climbable] = []
	var current := to
	while current != from:
		route.push_front(current)
		current = previous[current]
	return route


## Suite d'obstacles libres menant de `from` à `to` sans toucher le sol
## (`from` exclu, `to` inclus) ; vide s'il n'y en a pas.
func _route_across(from: Climbable, to: Climbable) -> Array[Climbable]:
	var previous := _perch_graph(from)
	if not previous.has(to) or to == from:
		return []
	return _path_in(previous, from, to)


## Depuis l'obstacle occupé, chemin vers l'obstacle accessible depuis le sol
## dont la descente est la plus proche de `toward` ; vide s'il n'y en a pas.
func _route_to_ground(toward: Vector3) -> Array[Climbable]:
	var previous := _perch_graph(perched_on)
	var best: Climbable = null
	var best_distance := INF
	for node: Climbable in previous:
		if node == perched_on or not node.climbable_from_ground:
			continue
		var access := node.get_nearest_access(toward)
		if not access["found"]:
			continue
		var distance := (access["point"] as Vector3).distance_squared_to(toward)
		if distance < best_distance:
			best_distance = distance
			best = node
	return [] as Array[Climbable] if best == null else _path_in(previous, perched_on, best)


## Obstacle accessible depuis le sol, le plus proche de l'unité, d'où l'on
## peut rejoindre `target` sans toucher le sol ; null s'il n'y en a pas.
func _nearest_entry(target: Climbable) -> Climbable:
	var best: Climbable = null
	var best_distance := INF
	for node: Climbable in _perch_graph(target):
		if node == target or not node.climbable_from_ground or node.occupant != null or node.handler != null:
			continue
		var access := node.get_nearest_access(global_position)
		if not access["found"]:
			continue
		var distance := (access["point"] as Vector3).distance_squared_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


## Suite d'une escalade en deux temps : de l'obstacle atteint jusqu'à `target`.
func _continue_across(target: Climbable) -> void:
	if perched_on == null or is_dead:
		return
	var route := _route_across(perched_on, target)
	if not route.is_empty():
		_walk_across(route)


## Passe de l'obstacle occupé aux obstacles de `route`, l'un après l'autre,
## sans toucher le sol : à pied entre voisins de même hauteur, en grimpant ou
## en redescendant sinon. Appelle `then` au bout du chemin.
func _walk_across(route: Array[Climbable], then: Callable = Callable()) -> void:
	var target: Climbable = route[0]
	_set_order(null)
	var origin := perched_on
	perched_on = null
	target.occupant = self
	var arrived := func() -> void:
		origin.occupant = null
		if is_dead:
			return
		perched_on = target
		# Étape suivante, si elle est toujours libre.
		var rest := route.slice(1)
		if rest.is_empty():
			if then.is_valid():
				then.call()
		elif rest[0].occupant == null or rest[0].occupant == self:
			_walk_across(rest, then)
	if not origin.is_adjacent_to(target):
		_hop(target.get_top_position(), arrived)
		return
	_hopping = true
	velocity = Vector3.ZERO
	var from := global_position
	var to := target.get_top_position()
	var flat := to - from
	flat.y = 0.0
	if flat.length_squared() > 0.0001:
		rotation.y = atan2(-flat.x, -flat.z)
	_running = false
	# Pas prudents sur les caisses : plus lent qu'au sol, à cadence de marche.
	var speed := _current_speed() * CRATE_WALK_RATIO
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		global_position = from.lerp(to, t)
		_model.posture = posture
		_model.move_ratio = 1.0
	, 0.0, 1.0, from.distance_to(to) / speed)
	tween.tween_callback(func() -> void:
		_hopping = false
		_model.move_ratio = 0.0
		arrived.call())


## Escalade scriptée (montée ou descente) : pendant sa durée, l'unité ne
## reçoit aucun ordre et n'est pas déplacée par la physique. Le corps suit des
## courbes calées sur l'animation du modèle (`SoldierModel.climb_progress`).
func _hop(to: Vector3, done: Callable) -> void:
	_hopping = true
	_climbing = true
	if _order is MoveOrder:
		_set_order(null)
	velocity = Vector3.ZERO
	posture = SoldierModel.Posture.STANDING
	var from := global_position
	var flat := to - from
	flat.y = 0.0
	if flat.length_squared() > 0.0001:
		rotation.y = atan2(-flat.x, -flat.z)
	# Se relever et passer l'arme à la bretelle avant de grimper.
	_model.weapon_slung = true
	_model.move_ratio = 0.0
	while not is_dead and (_model.is_changing_posture() or not _model.is_weapon_slung()):
		await get_tree().physics_frame
	if is_dead:
		_hopping = false
		_climbing = false
		return
	var going_up := to.y > from.y
	var jumping := not going_up and from.y - to.y > JUMP_MIN_DROP
	var forward_keys := CLIMB_UP_FORWARD if going_up else CLIMB_DOWN_FORWARD
	var height_keys := CLIMB_UP_HEIGHT if going_up else CLIMB_DOWN_HEIGHT
	_model.climb_descending = not going_up
	_model.climb_jump = jumping
	_model.climb_progress = 0.0
	var landed := [false]
	var duration := stats.climb_time if going_up else (stats.jump_time if jumping else stats.descend_time)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var progress := _jump_progress(t) if jumping else Vector2(SoldierModel.sample_keys(forward_keys, t), SoldierModel.sample_keys(height_keys, t))
		global_position = Vector3(lerpf(from.x, to.x, progress.x), lerpf(from.y, to.y, progress.y), lerpf(from.z, to.z, progress.x))
		_model.climb_progress = t
		if jumping and t >= JUMP_LANDING and not landed[0]:
			landed[0] = true
			_on_jump_landed()
	, 0.0, 1.0, duration)
	tween.tween_callback(func() -> void:
		_hopping = false
		_climbing = false
		_model.climb_progress = -1.0
		if not is_dead:
			done.call())


## Avancement d'un saut à l'instant `t` : (part du trajet horizontal, part
## du dénivelé descendue).
static func _jump_progress(t: float) -> Vector2:
	if t < JUMP_TAKEOFF:
		return Vector2(SoldierModel.sample_keys(JUMP_PREP_FORWARD, t), SoldierModel.sample_keys(JUMP_PREP_HEIGHT, t))
	if t >= JUMP_LANDING:
		return Vector2.ONE
	var u := (t - JUMP_TAKEOFF) / (JUMP_LANDING - JUMP_TAKEOFF)
	var start_forward: float = JUMP_PREP_FORWARD[JUMP_PREP_FORWARD.size() - 1]
	var start_height: float = JUMP_PREP_HEIGHT[JUMP_PREP_HEIGHT.size() - 1]
	# Chute libre : hauteur du second degré, de la vitesse d'impulsion (vers
	# le haut) jusqu'au sol.
	var height := start_height - JUMP_LIFT * u + (1.0 - start_height + JUMP_LIFT) * u * u
	return Vector2(lerpf(start_forward, 1.0, u), height)


## Réception d'un saut : bruit sourd (son et bruit signalé aux alentours).
func _on_jump_landed() -> void:
	Sfx.play_at(&"fall", global_position, -8.0)
	EventBus.noise_emitted.emit(global_position, stats.jump_noise_radius, &"jump")


## Vrai si `enemy` est à portée de lancer, avec une ligne de vue dégagée.
func _can_throw_at(enemy: Enemy) -> bool:
	var offset := enemy.global_position - global_position
	offset.y = 0.0
	return offset.length() <= stats.throw_range and _has_line_of_fire(enemy)


func _release_knife(enemy: Enemy) -> void:
	throwing_knives -= 1
	EventBus.unit_ammo_changed.emit(self)
	var offset := enemy.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var chance := 1.0
	if distance > stats.throw_sure_range:
		chance = lerpf(1.0, stats.throw_hit_chance_far, inverse_lerp(stats.throw_sure_range, stats.throw_range, minf(distance, stats.throw_range)))
	var hand := global_position + Vector3.UP * (_weapon_height() + 0.25) + global_basis.x * 0.15 - global_basis.z * 0.3
	ThrownKnife.spawn(get_tree().current_scene, hand, enemy, randf() < chance, global_position)
	Sfx.play_at(&"whoosh", hand, -6.0)


## Coup porté par `enemy` au corps à corps : l'opérateur pare si le joueur
## a pressé la touche de parade juste avant (`ready_parry`) ; avec la parade
## automatique (option), il pare ou esquive si le tirage le permet ; sinon il
## encaisse. Occupé (geste, escalade, caisse, couché), il encaisse toujours.
## Renvoie vrai si le coup est évité. Une pose de charge ou des soins sont
## abandonnés pour se défendre.
func defend_against(enemy: Enemy) -> bool:
	if is_dead:
		return false
	_call_backup(enemy)
	var busy := (_gesture != null and not _gesture.interruptible) or _hopping or perched_on != null \
			or is_handling_crate() or posture == SoldierModel.Posture.PRONE or _model.is_changing_posture()
	if busy:
		return super(enemy)
	if _parry_left > 0.0:
		# Touche pressée au bon moment : paré à coup sûr.
		_parry_left = 0.0
		_start(DefendGesture.new(self, enemy, false))
		return true
	if not auto_parry:
		return super(enemy)
	var roll := randf()
	if roll >= stats.parry_chance + stats.dodge_chance:
		return super(enemy)
	_start(DefendGesture.new(self, enemy, roll >= stats.parry_chance))
	return true


## Coéquipiers inoccupés (sans ordre ni geste) à moins de `BACKUP_RANGE` :
## ils accourent pour assommer `enemy`, qui frappe cet opérateur.
func _call_backup(enemy: Enemy) -> void:
	for node in get_tree().get_nodes_in_group(&"commandos"):
		var mate := node as Commando
		if mate == null or mate == self or mate.is_dead or mate._order != null or mate._gesture != null:
			continue
		if mate.hostage or mate.perched_on or mate.is_handling_crate():
			continue
		if mate.global_position.distance_to(global_position) > BACKUP_RANGE:
			continue
		mate.melee(enemy, MeleeKind.KNOCKOUT, true)


## Touche de parade : le prochain coup reçu dans `PARRY_WINDOW` secondes est
## paré. Renvoie faux si c'est trop tôt depuis le dernier appui.
func ready_parry() -> bool:
	if is_dead or _parry_cooldown > 0.0:
		return false
	_parry_left = PARRY_WINDOW
	_parry_cooldown = PARRY_COOLDOWN
	return true


## Vrai pendant la fenêtre de parade ouverte par la touche.
func is_ready_to_parry() -> bool:
	return _parry_left > 0.0


func _update_reload(delta: float) -> void:
	if not is_reloading() or is_dead:
		return
	# On ne recharge qu'arme en main.
	if not _model.is_weapon_ready():
		return
	_reload_left -= delta
	_model.reload_progress = 1.0 - _reload_left / stats.reload_time
	if _reload_left <= 0.0:
		_reload_left = 0.0
		_model.reload_progress = -1.0
		var loaded := mini(stats.magazine_size - ammo_in_magazine, ammo_reserve)
		ammo_in_magazine += loaded
		ammo_reserve -= loaded
		EventBus.unit_ammo_changed.emit(self)


func _follow_path(delta: float) -> Vector3:
	var to_next := _walker.next_point(_agent, self, get_physics_process_delta_time()) - global_position
	to_next.y = 0.0
	if to_next.length_squared() < 0.0001:
		return Vector3.ZERO
	_face(to_next, delta)
	return to_next.normalized() * _current_speed()


func _face(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-stats.turn_speed * delta))


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
	var scene := get_tree().current_scene as Node3D
	if not hit:
		var side := global_basis.x * (0.5 + randf() * 0.5) * (1.0 if randf() < 0.5 else -1.0)
		# La balle manquée file jusqu'au premier obstacle derrière la cible.
		var ignored: Array[RID] = [get_rid(), enemy.get_rid()]
		if hostage:
			ignored.append(hostage.get_rid())
		aim = ShotImpact.land(scene, muzzle, aim + side, ignored)
	else:
		ShotImpact.hit(scene, enemy, aim, muzzle, stats.damage_at(distance), false)
	Tracer.spawn(scene, muzzle, aim, Color(0.6, 0.9, 1.0))
	_model.play_shot()
	if _model.has_pump():
		# Bruit de la pompe, manœuvrée juste après le coup.
		get_tree().create_timer(SoldierModel.PUMP_DELAY, false).timeout.connect(func() -> void:
			if is_instance_valid(self) and not is_dead:
				Sfx.play_at(&"reload", global_position + Vector3.UP, -6.0))
	if stats.suppressed:
		Sfx.play_at(&"shot_suppressed", muzzle, -4.0)
	else:
		Sfx.play_at(&"shot", muzzle)
	EventBus.noise_emitted.emit(global_position, stats.gunshot_noise_radius, &"gunshot")
	if hit:
		enemy.take_hit(stats.damage_at(distance), global_position)


## Ordonne une rafale de tir libre sur `target` (mur, objet, sol) : l'unité
## s'approche à portée, puis tire `FireAtOrder.BURST` coups. Renvoie faux si
## elle ne peut pas tirer.
func fire_at(target: Vector3, run: bool = false) -> bool:
	if is_dead or _hopping:
		return false
	if carried_body:
		flash_message(CARRY_BUSY)
		return false
	if not _ready_to_fire():
		flash_hint(Hint.NO_AMMO)
		return false
	weapon_slung = false
	_set_order(FireAtOrder.new(self, target, run))
	return true


## Obstacles et cibles qu'une balle tirée librement peut frapper : sol, murs
## et caisses, ennemis debout ou au sol.
const MASK_FREE_FIRE := 0b11011
## Écart (m, à 10 m) d'une balle tirée librement, selon la précision.
const FREE_FIRE_SPREAD := 0.35


## Un coup de tir libre vers `point` : la balle file jusqu'au premier
## obstacle ; un ennemi est blessé, un objet destructible (`take_shot`)
## encaisse les dégâts.
func _fire_at_point(point: Vector3) -> void:
	_fire_cooldown = stats.fire_interval
	ammo_in_magazine -= 1
	EventBus.unit_ammo_changed.emit(self)
	var forward := -global_basis.z
	var muzzle := global_position + Vector3.UP * _weapon_height() + forward * 0.7
	var aim := point
	if aim.distance_to(muzzle) < 1.0:
		aim = muzzle + forward * 2.0
	var distance := Vector2(aim.x - muzzle.x, aim.z - muzzle.z).length()
	# Écart aléatoire, plus grand de loin et avec une arme peu précise.
	var sloppiness := 1.0 - lerpf(stats.hit_chance_near, stats.hit_chance_far, clampf(distance / stats.fire_range, 0.0, 1.0))
	var spread := FREE_FIRE_SPREAD * (0.3 + sloppiness) * distance / 10.0
	aim += Vector3(randf_range(-spread, spread), randf_range(-spread, spread) * 0.6, randf_range(-spread, spread))
	var direction := (aim - muzzle).normalized()
	var excluded: Array[RID] = [get_rid()]
	if hostage:
		excluded.append(hostage.get_rid())
	var query := PhysicsRayQueryParameters3D.create(muzzle, aim + direction * ShotImpact.MISS_RANGE, MASK_FREE_FIRE, excluded)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var scene := get_tree().current_scene as Node3D
	var end := aim + direction * 4.0
	if not hit.is_empty():
		end = hit["position"]
		var damage := stats.damage_at(distance)
		var target := hit["collider"] as Node
		if target is Enemy and not (target as Enemy).is_dead:
			ShotImpact.hit(scene, target as Node3D, end, muzzle, damage, false)
			(target as Enemy).take_hit(damage, global_position)
		else:
			ShotImpact.burst(scene, end, hit["normal"], ShotImpact.DUST, 10, 2.2)
			if target and target.has_method(&"take_shot"):
				target.call(&"take_shot", damage, end, muzzle)
	Tracer.spawn(scene, muzzle, end, Color(0.6, 0.9, 1.0))
	_model.play_shot()
	if stats.suppressed:
		Sfx.play_at(&"shot_suppressed", muzzle, -4.0)
	else:
		Sfx.play_at(&"shot", muzzle)
	EventBus.noise_emitted.emit(global_position, stats.gunshot_noise_radius, &"gunshot")


func _current_speed() -> float:
	if carried_body:
		return stats.walk_speed * CARRY_SPEED
	if hostage:
		return stats.walk_speed * HOSTAGE_SPEED
	var shield := SHIELD_SPEED if shield_raised else 1.0
	match posture:
		SoldierModel.Posture.CROUCHED:
			return stats.crouch_speed * shield
		SoldierModel.Posture.PRONE:
			return stats.crawl_speed
	if shield_raised:
		return stats.walk_speed * shield
	return stats.run_speed if _running else stats.walk_speed


func _on_health_changed(current: float, _maximum: float) -> void:
	if current < _last_health and current > 0.0:
		_model.play_hit()
		Sfx.play_at(&"hit", global_position + Vector3.UP, -4.0)
	_last_health = current
	EventBus.unit_damaged.emit(self, health.max_health - health.health)


func _on_died() -> void:
	is_dead = true
	_traversal.cancel()
	Sfx.play_at(&"fall", global_position, -2.0)
	_cancel_actions()
	release_hostage()
	drop_body()
	_reload_left = 0.0
	_model.reload_progress = -1.0
	remove_from_group(&"commandos")
	collision_layer = 0
	_agent.avoidance_enabled = false
	_model.is_dead = true
	var callsign := get_node_or_null(^"Callsign") as Label3D
	if callsign:
		callsign.visible = false
	_flash_left = 0.0
	SelectionManager.remove(self)
	EventBus.unit_died.emit(self)


## Sauvegarde rapide (`QuickSave`) : en plus de l'état d'`Unit`, armes,
## munitions, équipement et bouclier.
func save_state() -> Dictionary:
	var data := super()
	data.merge({
		"using_secondary": using_secondary, "ammo": Vector2i(ammo_in_magazine, ammo_reserve),
		"holstered_ammo": _holstered_ammo, "weapon_slung": weapon_slung, "shield_raised": shield_raised,
		"throwing_knives": throwing_knives, "grenades": grenades, "smoke_grenades": smoke_grenades, "hatchets": hatchets, "explosives": explosives,
		"medkits": medkits, "shields": shields, "grapnels": grapnels,
		"carried_body": String(carried_body.get_path()) if carried_body else "",
	})
	return data


func load_state(data: Dictionary) -> void:
	stop()
	release_crate()
	# L'otage reprend l'état sauvegardé (le sien) : on le lâche sans plus.
	_drop_hostage()
	# Le corps porté aussi ; on reprend celui de la sauvegarde une fois tous
	# les états rendus.
	carried_body = null
	var carried_path: String = data.get("carried_body", "")
	if not carried_path.is_empty():
		_relift_body.call_deferred(NodePath(carried_path))
	super(data)
	if is_dead:
		return
	if data.get("using_secondary", using_secondary) != using_secondary:
		switch_weapon()
	var ammo: Vector2i = data.get("ammo", Vector2i(ammo_in_magazine, ammo_reserve))
	ammo_in_magazine = ammo.x
	ammo_reserve = ammo.y
	_holstered_ammo = data.get("holstered_ammo", _holstered_ammo)
	throwing_knives = data.get("throwing_knives", throwing_knives)
	grenades = data.get("grenades", grenades)
	smoke_grenades = data.get("smoke_grenades", smoke_grenades)
	hatchets = data.get("hatchets", hatchets)
	explosives = data.get("explosives", explosives)
	medkits = data.get("medkits", medkits)
	shields = data.get("shields", shields)
	grapnels = data.get("grapnels", grapnels)
	weapon_slung = data.get("weapon_slung", weapon_slung)
	set_shield(data.get("shield_raised", false))
	EventBus.unit_ammo_changed.emit(self)


## Signale, pendant un ordre, pourquoi l'opérateur ne tire pas ou ne lance
## pas encore (à rappeler à chaque image tant que cela dure).
func report_hint(hint: Hint) -> void:
	_hint = hint
	_hint_frame = Engine.get_physics_frames()


## Affiche un instant pourquoi un ordre est refusé.
func flash_hint(hint: Hint) -> void:
	_flash = hint
	_flash_left = FLASH_TIME


## Affiche un instant un message libre (raison d'un refus détaillée).
func flash_message(text: String) -> void:
	flash_hint(Hint.MESSAGE)
	_flash_text = text


## Texte affiché en ce moment sous l'indicatif (vide si aucun).
func hint_text() -> String:
	var hint := current_hint()
	if hint == Hint.MESSAGE:
		return _flash_text
	return HINT_TEXTS[hint] if hint != Hint.NONE else ""


## Raison affichée en ce moment (`Hint.NONE` si aucune).
func current_hint() -> Hint:
	if _hint != Hint.NONE and Engine.get_physics_frames() - _hint_frame <= 2:
		return _hint
	return _flash if _flash_left > 0.0 else Hint.NONE


func _process(delta: float) -> void:
	_flash_left = maxf(_flash_left - delta, 0.0)
	_parry_left = maxf(_parry_left - delta, 0.0)
	_parry_cooldown = maxf(_parry_cooldown - delta, 0.0)
	if _hint_label == null:
		return
	var hint := Hint.NONE if is_dead else current_hint()
	_hint_label.visible = hint != Hint.NONE
	if hint != Hint.NONE:
		_hint_label.text = hint_text()
