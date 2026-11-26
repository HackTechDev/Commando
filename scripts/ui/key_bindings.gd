class_name KeyBindings
extends RefCounted
## Touches du clavier réglables par le joueur (écran « Touches du clavier »,
## `KeyBindingsPanel`). Chaque action de `GROUPS` a une touche principale :
## le premier événement clavier de l'action dans l'InputMap, défini par
## position physique. Les autres événements (flèches de la caméra, souris)
## ne changent pas. Les touches choisies sont enregistrées dans les réglages
## (`Settings`, section `SECTION` : action → code physique) et appliquées à
## l'InputMap au lancement et à chaque changement.
##
## Une touche déjà prise par une autre action réglable lui est échangée :
## l'autre action reçoit l'ancienne touche, aucune ne reste sans touche. Les
## touches fixes (modificateurs, Échap, flèches de la caméra…) sont refusées.

const SECTION := "keys"
## Actions réglables, par rubrique : [titre, [[action, libellé], …]].
const GROUPS: Array = [
	["Caméra", [
		[&"camera_forward", "Avancer"], [&"camera_back", "Reculer"],
		[&"camera_left", "Gauche"], [&"camera_right", "Droite"],
		[&"camera_rotate_left", "Tourner à gauche"], [&"camera_rotate_right", "Tourner à droite"],
		[&"camera_focus", "Centrer sur la sélection"],
		[&"view_level_up", "Étage supérieur"], [&"view_level_down", "Étage inférieur"],
	]],
	["Opérateurs", [
		[&"select_unit_1", "Opérateur 1"], [&"select_unit_2", "Opérateur 2"], [&"select_unit_3", "Opérateur 3"],
		[&"select_unit_4", "Opérateur 4"], [&"select_unit_5", "Opérateur 5"], [&"select_unit_6", "Opérateur 6"],
		[&"stop", "Stop"], [&"posture_crouch", "Accroupi"], [&"posture_prone", "Rampé"], [&"dive", "Roulade"],
		[&"reload", "Recharger"], [&"switch_weapon", "Arme secondaire (Maj : lampe)"], [&"action_sling", "Bretelle"],
		[&"parry", "Parer"],
	]],
	["Actions", [
		[&"action_knife", "Couteau"], [&"action_knockout", "Assommer"], [&"action_throw", "Lancer (couteau, caillou)"],
		[&"action_fire_at", "Tir libre"], [&"action_carry", "Porter un corps"], [&"action_crate", "Caisse (Maj : tourner)"],
		[&"action_grenade", "Grenades (appuis suivants : type suivant)"], [&"action_launcher", "Lance-grenades M320"],
		[&"action_plant", "Poser une charge (Maj : à retardement)"], [&"action_detonate", "Mise à feu"],
	]],
	["Équipement", [
		[&"action_medkit", "Soigner"], [&"action_grapple", "Grappin"], [&"action_taser", "Taser"],
		[&"action_shield", "Bouclier"], [&"toggle_nvg", "Jumelles, vue thermique"],
	]],
	["Partie", [
		[&"tactical_pause", "Pause tactique"], [&"plan_orders", "Préparer des ordres simultanés"],
		[&"execute_orders", "Exécuter les ordres simultanés"],
		[&"toggle_help", "Aide"], [&"toggle_objectives", "Journal des objectifs"], [&"toggle_minimap", "Minicarte"],
	]],
]
## Touches qu'on ne peut pas attribuer : modificateurs (variantes,
## sélection) et Échap (menu, annulation).
const RESERVED: Array[Key] = [KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

## Touches d'origine (celles de `project.godot`), relevées au premier
## `apply`.
static var _defaults: Dictionary = {}


## Actions réglables, dans l'ordre des rubriques.
static func actions() -> Array[StringName]:
	var list: Array[StringName] = []
	for group: Array in GROUPS:
		for entry: Array in group[1]:
			list.append(entry[0])
	return list


## Libellé de l'action `action` (son nom s'il n'est pas réglable).
static func label_of(action: StringName) -> String:
	for group: Array in GROUPS:
		for entry: Array in group[1]:
			if entry[0] == action:
				return entry[1]
	return String(action)


## Libellé complet, avec sa rubrique (« Caméra : Gauche »), pour les
## messages.
static func describe(action: StringName) -> String:
	for group: Array in GROUPS:
		for entry: Array in group[1]:
			if entry[0] == action:
				return "%s : %s" % [group[0], entry[1]]
	return String(action)


## Touche principale (code physique) de `action`, ou `KEY_NONE`.
static func key_of(action: StringName) -> Key:
	var event := _primary(action)
	if event == null:
		return KEY_NONE
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


## Touche d'origine de `action`.
static func default_of(action: StringName) -> Key:
	_capture_defaults()
	return _defaults.get(action, KEY_NONE)


## Applique à l'InputMap les touches enregistrées dans `settings` (les
## touches d'origine pour les autres).
static func apply(settings: Node) -> void:
	_capture_defaults()
	for action in actions():
		if not _defaults.has(action):
			continue
		var code: int = settings.call(&"value", SECTION, String(action), int(_defaults[action]))
		_set_key(action, code as Key)


## Donne la touche `code` à `action`, et l'enregistre dans `settings`. Une
## autre action réglable qui l'avait reçoit l'ancienne touche de `action`.
## Renvoie {ok, message, swapped (action échangée ou &"")}.
static func rebind(settings: Node, action: StringName, code: Key) -> Dictionary:
	var result := {"ok": false, "message": "", "swapped": &""}
	if code == KEY_NONE or code in RESERVED:
		result["message"] = "Touche réservée : choisissez-en une autre."
		return result
	var old := key_of(action)
	if code == old:
		result["ok"] = true
		return result
	var holder := owner_of(code, action)
	if not holder.is_empty():
		if not holder in actions() or key_of(holder) != code:
			result["message"] = "La touche %s est fixe (« %s »)." % [KeyNames.of_physical(code), describe(holder)]
			return result
		result["swapped"] = holder
	settings.call(&"set_value", SECTION, String(action), int(code))
	if not holder.is_empty():
		settings.call(&"set_value", SECTION, String(holder), int(old))
		result["message"] = "« %s » reçoit l'ancienne touche, %s." % [describe(holder), KeyNames.of_physical(old)]
	result["ok"] = true
	return result


## Action (autre que `except`) qui utilise la touche `code`, ou &"".
static func owner_of(code: Key, except: StringName = &"") -> StringName:
	for action: StringName in InputMap.get_actions():
		if action == except or String(action).begins_with("ui_"):
			continue
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key and (key.physical_keycode == code or (key.physical_keycode == KEY_NONE and key.keycode == code)):
				return action
	return &""


## Revient aux touches d'origine.
static func reset(settings: Node) -> void:
	settings.call(&"clear_section", SECTION)


static func _capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for action in actions():
		if InputMap.has_action(action):
			_defaults[action] = key_of(action)


## Premier événement clavier de `action`.
static func _primary(action: StringName) -> InputEventKey:
	if not InputMap.has_action(action):
		return null
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event as InputEventKey
	return null


## Remplace la touche principale de `action` par `code` (position
## physique), sans changer l'ordre des événements.
static func _set_key(action: StringName, code: Key) -> void:
	var primary := _primary(action)
	if primary == null or code == KEY_NONE or key_of(action) == code:
		return
	var events := InputMap.action_get_events(action)
	var replaced := primary.duplicate() as InputEventKey
	replaced.physical_keycode = code
	replaced.keycode = KEY_NONE
	replaced.key_label = KEY_NONE
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, replaced if event == primary else event)
