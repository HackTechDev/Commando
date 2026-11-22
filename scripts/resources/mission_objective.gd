@tool
class_name MissionObjective
extends Resource
## Un objectif de mission (`MissionInfo.objectives`) : identifiant suivi en
## jeu (`Objectives`) et texte du journal.

## Identifiants connus, proposés par l'inspecteur. Un nœud de la carte
## remplit l'objectif (zone d'extraction, cible de sabotage, convertible…)
## en émettant son identifiant ; les conditions (`Objectives.CONDITIONS`)
## et `all_enemies_down` sont suivies par `Objectives` lui-même.
const KNOWN_IDS: Array[String] = [
	"all_enemies_down", "no_operator_lost", "no_alert", "vip_alive",
	"vip_extracted", "extracted", "documents", "sabotage", "depot",
	"aircraft_destroyed", "raid_in_time", "sabre_rally", "sabre_extracted",
	"heli_hover", "heli_rappel",
	"tuto_move", "tuto_run", "tuto_climb", "tuto_melee", "tuto_shoot",
	"tuto_sniper", "tuto_stealth", "tuto_end",
]

@export_custom(PROPERTY_HINT_ENUM_SUGGESTION, "all_enemies_down,no_operator_lost,no_alert,vip_alive,vip_extracted,extracted,documents,sabotage,depot,aircraft_destroyed,raid_in_time,sabre_rally,sabre_extracted,heli_hover,heli_rappel,tuto_move,tuto_run,tuto_climb,tuto_melee,tuto_shoot,tuto_sniper,tuto_stealth,tuto_end")
var id: String = ""
@export var text: String = ""


static func make(objective_id: String, objective_text: String) -> MissionObjective:
	var objective := MissionObjective.new()
	objective.id = objective_id
	objective.text = objective_text
	return objective


func to_dict() -> Dictionary:
	return {"id": id, "text": text}
