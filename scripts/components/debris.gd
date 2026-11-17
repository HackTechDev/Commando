class_name Debris
extends Node3D
## Éclats projetés par un objet détruit (caisse, bidon, pan de mur) : des
## morceaux qui volent, retombent et restent un moment au sol, puis
## disparaissent. Purement visuel (aucune collision).

## Durée (s) avant disparition.
const LIFETIME := 6.0
const GRAVITY := 9.8

var _pieces: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _spins: Array[Vector3] = []
var _time: float = 0.0
var _ground: float = 0.0


## Projette `count` éclats de couleur `color` depuis la boîte `box` (repère
## monde), éloignés de `from` (centre de l'explosion).
static func burst(parent: Node, box: AABB, from: Vector3, color: Color, count: int = 14) -> Debris:
	var debris := Debris.new()
	parent.add_child(debris)
	debris.global_position = Vector3.ZERO
	debris._ground = box.position.y
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(box.position)
	for i in count:
		var piece := MeshInstance3D.new()
		var cube := BoxMesh.new()
		var size := box.size.length() * rng.randf_range(0.05, 0.12)
		cube.size = Vector3(size, size * rng.randf_range(0.3, 0.8), size * rng.randf_range(0.5, 1.2))
		piece.mesh = cube
		piece.material_override = material
		debris.add_child(piece)
		var start := box.position + Vector3(rng.randf() * box.size.x, rng.randf() * box.size.y, rng.randf() * box.size.z)
		piece.global_position = start
		var away := start - from
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		debris._pieces.append(piece)
		debris._velocities.append(away * rng.randf_range(2.0, 6.0) + Vector3.UP * rng.randf_range(2.0, 5.0))
		debris._spins.append(Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9)))
	return debris


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= LIFETIME:
		queue_free()
		return
	for i in _pieces.size():
		var piece := _pieces[i]
		if _velocities[i] == Vector3.ZERO:
			continue
		_velocities[i].y -= GRAVITY * delta
		piece.global_position += _velocities[i] * delta
		piece.rotation += _spins[i] * delta
		if piece.global_position.y <= _ground + 0.03:
			piece.global_position.y = _ground + 0.03
			_velocities[i] = Vector3.ZERO
