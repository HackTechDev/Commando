@tool
class_name CrowdModel
extends SoldierModel
## Modèle d'un figurant (invité, passant) : la même silhouette, animée à
## moindre coût. Hors de l'écran il ne s'anime pas du tout ; à l'écran,
## seulement une image sur `every` (le temps écoulé est cumulé, la pose reste
## juste). Une foule de cinquante figurants coûte ainsi quelques
## millisecondes au lieu de plusieurs dizaines.

## Une image animée sur `every` (2 pour un passant qui marche, 3 immobile).
var every: int = 3

var _notifier: VisibleOnScreenNotifier3D
var _elapsed: float = 0.0
var _skipped: int = 0


func _ready() -> void:
	super._ready()
	_notifier = VisibleOnScreenNotifier3D.new()
	_notifier.aabb = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.9, 1.0))
	add_child(_notifier)
	# Décale les figurants entre eux : ils ne s'animent pas tous à la même image.
	_skipped = absi(hash(get_instance_id())) % maxi(every, 1)


## Vrai si le figurant est à l'écran.
func is_seen() -> bool:
	return _notifier != null and _notifier.is_on_screen()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		super._process(delta)
		return
	_elapsed += delta
	_skipped += 1
	if _skipped < every or not _notifier.is_on_screen():
		return
	_skipped = 0
	super._process(_elapsed)
	_elapsed = 0.0
