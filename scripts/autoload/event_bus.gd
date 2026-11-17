extends Node
## Bus de signaux globaux, réservé aux événements transverses.

@warning_ignore_start("unused_signal")
signal unit_spotted(unit: Node3D, by: Node3D)
signal unit_damaged(unit: Node3D, amount: float)
signal unit_ammo_changed(unit: Node3D)
signal unit_died(unit: Node3D)
signal enemy_killed(enemy: Node3D)
## Un ennemi (`by`) a découvert le corps d'un camarade (`body`).
signal body_discovered(body: Node3D, by: Node3D)
signal alarm_raised(position: Vector3)
signal objective_completed(objective_id: StringName)
## Fin de mission : objectif atteint (`success`) ou manqué, et message affiché.
signal mission_ended(success: bool, message: String)
signal noise_emitted(position: Vector3, radius: float, type: StringName)
## Un obstacle (caisse) a été déplacé : la navigation doit être recalculée.
signal navigation_obstacle_moved
@warning_ignore_restore("unused_signal")
