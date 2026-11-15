class_name Unit
extends CharacterBody3D
## Personnage du camp des joueurs (opérateur, VIP) : les ennemis le cherchent
## du regard (`targets`), lui tirent dessus et le frappent. La scène fournit un
## `SoldierModel` et un `HealthComponent`.

signal posture_changed(posture: SoldierModel.Posture)

## Groupes des unités que les ennemis repèrent et prennent pour cible.
const TARGET_GROUPS: Array[StringName] = [&"commandos", &"vips"]

var is_dead: bool = false
var posture: SoldierModel.Posture = SoldierModel.Posture.STANDING:
	set(value):
		if value != posture:
			posture = value
			if _model:
				_model.posture = value
			posture_changed.emit(posture)

@onready var _model: SoldierModel = $SoldierModel
@onready var health: HealthComponent = $HealthComponent


## Unités vivantes que les ennemis peuvent prendre pour cible.
static func targets(tree: SceneTree) -> Array[Unit]:
	var result: Array[Unit] = []
	for group in TARGET_GROUPS:
		for node in tree.get_nodes_in_group(group):
			var unit := node as Unit
			if unit and not unit.is_dead:
				result.append(unit)
	return result


## Coup au corps à corps porté par `enemy` : l'unité l'encaisse. Renvoie vrai
## s'il est évité (voir `Commando.defend_against`).
func defend_against(enemy: Enemy) -> bool:
	if is_dead:
		return false
	Sfx.play_at(&"punch", global_position + Vector3.UP * 1.4)
	health.take_damage(enemy.stats.melee_damage)
	if not is_dead:
		_model.play_hit(enemy.global_position, PushGesture.HIT_STRENGTH)
	return false
