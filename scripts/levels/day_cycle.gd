class_name DayCycle
extends Node
## Heure qui avance (`LevelRoot.time_flow` > 0) : l'heure de la mission
## (`OperationClock`, `MissionInfo.time`) avance de `time_flow` minutes par
## seconde de jeu. L'obscurité (`darkness`, 0 de jour, 1 en pleine nuit) en
## découle : pleine nuit de `DUSK_END` à `DAWN_START`, transitions à l'aube
## et au crépuscule. Elle règle :
## - la lumière : le soleil (premier `DirectionalLight3D` de la carte) et
##   le ciel passent des teintes de nuit à celles du jour, orangées à
##   l'aube et au crépuscule ;
## - la vue des gardes (`Enemy._refresh_sight`, par `LevelRoot.darkness_of`),
##   les lampes (`StreetLamp`), les jumelles (abaissées la nuit, relevées
##   le jour) ;
## - l'objectif bonus `before_dawn` (repartir avant l'aube), manqué quand
##   le jour se lève, et des annonces radio avant l'aube.

## Heures (décimales) : début et fin de l'aube, du crépuscule.
const DAWN_START := 5.0
const DAWN_END := 6.5
const DUSK_START := 18.5
const DUSK_END := 20.0
## Intervalle (s) entre deux mises à jour de la lumière.
const REFRESH_INTERVAL := 0.25
## Annonces avant l'aube (minutes avant `DAWN_START`).
const WARNINGS: Array[int] = [30, 10]

const NIGHT_SUN := Color(0.6, 0.7, 1.0)
const NIGHT_SUN_ENERGY := 0.16
const NIGHT_AMBIENT := Color(0.2, 0.25, 0.4)
const NIGHT_AMBIENT_ENERGY := 0.22
const NIGHT_SKY := Color(0.01, 0.015, 0.03)
const DAY_SUN := Color(1.0, 0.95, 0.86)
const DAY_SUN_ENERGY := 1.25
const DAY_AMBIENT := Color(0.75, 0.74, 0.7)
const DAY_AMBIENT_ENERGY := 0.6
const DAY_SKY := Color(0.55, 0.66, 0.8)
## Teintes du lever et du coucher (au milieu de la transition).
const GLOW_SUN := Color(1.0, 0.62, 0.4)
const GLOW_SKY := Color(0.62, 0.42, 0.38)

var level: LevelRoot
## Obscurité actuelle (0 jour, 1 nuit).
var darkness: float = 1.0
var _sun: DirectionalLight3D
var _environment: Environment
var _refresh_left: float = 0.0
var _warned: Array[int] = []
var _was_night: bool = true


func _init(root: LevelRoot) -> void:
	level = root
	name = "DayCycle"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for child in level.get_children():
		if child is DirectionalLight3D and _sun == null:
			_sun = child
		elif child is WorldEnvironment and (child as WorldEnvironment).environment:
			# Copie propre à la partie : la ressource de la scène ne change pas.
			_environment = (child as WorldEnvironment).environment.duplicate()
			(child as WorldEnvironment).environment = _environment
	darkness = darkness_at(hour())
	_was_night = darkness >= 0.5
	# Jumelles : d'après l'heure de départ, pas la case « nuit » de la carte.
	var vision := level.get_node_or_null(^"NightVision") as NightVision
	if vision and vision.night != _was_night:
		vision.set_night.call_deferred(_was_night)
	# Annonces déjà passées au lancement : pas de rattrapage.
	for minutes in WARNINGS:
		if _minutes_to_dawn() < minutes:
			_warned.append(minutes)
	_apply()


## Heure de la mission (décimale, de 0 à 24).
func hour() -> float:
	var clock := OperationClock.of(level.get_tree()) if level.is_inside_tree() else null
	if clock == null:
		return 0.0
	return clock.current_hour()


## Obscurité à l'heure `at` (décimale).
static func darkness_at(at: float) -> float:
	var h := fposmod(at, 24.0)
	if h >= DAWN_END and h <= DUSK_START:
		return 0.0
	if h > DAWN_START and h < DAWN_END:
		return 1.0 - smoothstep(DAWN_START, DAWN_END, h)
	if h > DUSK_START and h < DUSK_END:
		return smoothstep(DUSK_START, DUSK_END, h)
	return 1.0


func _minutes_to_dawn() -> float:
	return fposmod(DAWN_START - hour(), 24.0) * 60.0


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = REFRESH_INTERVAL
	darkness = darkness_at(hour())
	_apply()
	var night := darkness >= 0.5
	if night != _was_night:
		_was_night = night
		_on_night_changed(night)
	if night:
		var left := _minutes_to_dawn()
		for minutes in WARNINGS:
			if left <= minutes and not _warned.has(minutes):
				_warned.append(minutes)
				EventBus.radio_message.emit("Aube dans %d minutes : les gardes verront bientôt plus loin." % minutes)


## Le jour se lève ou la nuit tombe.
func _on_night_changed(night: bool) -> void:
	var vision := level.get_node_or_null(^"NightVision") as NightVision
	if vision:
		vision.set_night(night)
	if night:
		EventBus.radio_message.emit("La nuit tombe.")
		return
	EventBus.radio_message.emit("Le jour se lève : les gardes voient loin.")
	var objectives := level.get_tree().get_first_node_in_group(Objectives.GROUP) as Objectives
	if objectives and not objectives.is_over:
		objectives.fail("before_dawn")


## Lumière du soleil et du ciel selon l'obscurité, orangée aux transitions.
func _apply() -> void:
	var glow := 1.0 - absf(darkness * 2.0 - 1.0)
	if _sun:
		_sun.light_color = DAY_SUN.lerp(NIGHT_SUN, darkness).lerp(GLOW_SUN, glow * 0.7)
		_sun.light_energy = lerpf(DAY_SUN_ENERGY, NIGHT_SUN_ENERGY, darkness)
	if _environment:
		_environment.ambient_light_color = DAY_AMBIENT.lerp(NIGHT_AMBIENT, darkness)
		_environment.ambient_light_energy = lerpf(DAY_AMBIENT_ENERGY, NIGHT_AMBIENT_ENERGY, darkness)
		_environment.background_color = DAY_SKY.lerp(NIGHT_SKY, darkness).lerp(GLOW_SKY, glow * 0.6)
