extends Node
## Bus de signaux globaux, réservé aux événements transverses.

@warning_ignore_start("unused_signal")
signal unit_spotted(unit: Node3D, by: Node3D)
signal unit_damaged(unit: Node3D, amount: float)
signal unit_died(unit: Node3D)
signal alarm_raised(position: Vector3)
signal objective_completed(objective_id: StringName)
signal noise_emitted(position: Vector3, radius: float, type: StringName)
@warning_ignore_restore("unused_signal")
