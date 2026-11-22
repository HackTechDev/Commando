class_name Cover
extends RefCounted
## Couverture : part du corps d'une cible visible depuis la bouche d'une
## arme. Des rayons visent plusieurs points du corps (hauteurs selon la
## posture, de part et d'autre de l'axe du tir) ; ceux qu'arrête un
## obstacle (caisse, muret, angle de mur, rebord de toit) sont couverts.
## Le tireur touche d'autant moins (`hit_factor`) ; une balle manquée à
## cause de l'abri y finit sa course (`hidden_point`).

const MASK_OBSTACLES := 0b10
## Hauteurs visées (m au-dessus des pieds), selon la posture.
const HEIGHTS := {
	SoldierModel.Posture.STANDING: [0.35, 0.8, 1.2, 1.6],
	SoldierModel.Posture.CROUCHED: [0.3, 0.6, 0.95],
	SoldierModel.Posture.PRONE: [0.15, 0.3],
}
## Demi-largeur du corps visée de part et d'autre (m).
const HALF_WIDTH := 0.22
## Courbe de la chance de toucher selon la part visible (1 : à découvert).
const FACTOR_EXPONENT := 0.7

## Part visible (0 à 1) et un point couvert (Vector3.INF s'il n'y en a pas).
var exposure: float = 1.0
var hidden_point: Vector3 = Vector3.INF


## Couverture de la cible dont les pieds sont en `feet`, dans la posture
## `posture`, vue depuis `muzzle`. `exclude` : corps à ignorer (tireur,
## cible, véhicule).
static func measure(world: World3D, muzzle: Vector3, feet: Vector3, posture: SoldierModel.Posture, exclude: Array[RID] = []) -> Cover:
	var cover := Cover.new()
	var across := Vector3(feet.x - muzzle.x, 0.0, feet.z - muzzle.z).cross(Vector3.UP)
	across = across.normalized() * HALF_WIDTH if across.length_squared() > 0.0001 else Vector3.RIGHT * HALF_WIDTH
	var space := world.direct_space_state
	var total := 0
	var seen := 0
	for height: float in HEIGHTS.get(posture, HEIGHTS[SoldierModel.Posture.STANDING]):
		for side: float in [0.0, -1.0, 1.0]:
			var point: Vector3 = feet + Vector3.UP * height + across * side
			var query := PhysicsRayQueryParameters3D.create(muzzle, point, MASK_OBSTACLES, exclude)
			total += 1
			if space.intersect_ray(query).is_empty():
				seen += 1
			elif cover.hidden_point == Vector3.INF or side == 0.0:
				cover.hidden_point = point
	cover.exposure = float(seen) / float(total)
	return cover


## Multiplicateur de la chance de toucher : 1 à découvert, 0 tout couvert.
func hit_factor() -> float:
	return pow(exposure, FACTOR_EXPONENT)


## Vrai si une balle manquée doit finir dans l'abri (d'autant plus souvent
## que la cible est couverte).
func miss_hits_cover() -> bool:
	return hidden_point != Vector3.INF and randf() < 1.0 - exposure
