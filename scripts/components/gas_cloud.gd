class_name GasCloud
extends SmokeCloud
## Nuage de gaz lacrymogène (obus de 40 mm du M320) : plus clair et
## jaunâtre que la fumée, il ne coupe pas la vue, mais les gardes qui s'y
## trouvent suffoquent : ils sont sonnés (`Enemy.daze` : ni vue, ni tir, ni
## défense) tant qu'ils y restent et un peu après, et toussent assez fort
## pour intriguer leurs voisins. Les chiens aussi. Les opérateurs portent un
## masque : le gaz ne les gêne pas.

const GAS_GROUP := &"gas_clouds"
## Durée de l'effet après chaque bouffée respirée (s), et intervalle entre
## deux bouffées.
const CHOKE_TIME := 2.5
const CHOKE_INTERVAL := 0.5
## Épaisseur à partir de laquelle le gaz suffoque.
const CHOKE_FROM := 0.3
## Hauteur (m) sous laquelle on respire le gaz (au-dessus du sol du nuage).
const BREATH_HEIGHT := 2.6
## Toux : rayon du bruit (m) et intervalle (s) par garde.
const COUGH_NOISE := 9.0
const COUGH_INTERVAL := 1.6

var _choke_left: float = 0.0
## Par garde (id d'instance) : temps avant sa prochaine toux.
var _coughs: Dictionary = {}


## Fait naître un nuage de gaz au point `at` (au sol).
static func spawn(parent: Node, at: Vector3) -> SmokeCloud:
	var cloud := GasCloud.new()
	parent.add_child(cloud)
	cloud.global_position = at
	return cloud


## Ennemis en vie que le nuage suffoque en ce moment.
func choking() -> Array[Enemy]:
	var found: Array[Enemy] = []
	if density() < CHOKE_FROM:
		return found
	var reach := radius()
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		var offset := enemy.global_position - global_position
		var height := offset.y
		offset.y = 0.0
		if offset.length() <= reach and height > -1.0 and height < BREATH_HEIGHT:
			found.append(enemy)
	return found


func _ready() -> void:
	super()
	remove_from_group(GROUP)
	add_to_group(GAS_GROUP)
	# Plus clair et moins opaque que la fumée, teinté de jaune.
	_material.albedo_color = Color(0.86, 0.85, 0.62, 0.4)


func _physics_process(delta: float) -> void:
	super(delta)
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_material.albedo_color.a = 0.4 * density()
	_choke_left -= delta
	if _choke_left > 0.0:
		return
	_choke_left = CHOKE_INTERVAL
	for enemy in choking():
		enemy.daze(CHOKE_TIME, global_position)
		var key := enemy.get_instance_id()
		var wait: float = _coughs.get(key, 0.0) - CHOKE_INTERVAL
		if wait <= 0.0:
			wait = COUGH_INTERVAL
			EventBus.noise_emitted.emit(enemy.global_position, COUGH_NOISE, &"distraction")
			Sfx.play_at(&"cough", enemy.global_position + Vector3.UP * 1.5, -6.0)
		_coughs[key] = wait
