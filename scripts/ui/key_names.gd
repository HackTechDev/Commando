class_name KeyNames
extends RefCounted
## Noms des touches de l'InputMap, tels qu'imprimés sur le clavier du joueur
## (les actions sont définies par position physique : Z sur AZERTY, W sur
## QWERTY).

## Noms français des touches spéciales (`OS.get_keycode_string` les donne en
## anglais).
const FRENCH := {
	"Space": "Espace", "Enter": "Entrée", "Kp Enter": "Entrée", "Tab": "Tab",
	"Home": "Origine", "End": "Fin", "Shift": "Maj", "Ctrl": "Ctrl", "Escape": "Échap",
	"Up": "Haut", "Down": "Bas", "Left": "Gauche", "Right": "Droite",
	"Backspace": "Retour", "Delete": "Suppr", "Insert": "Inser",
	"PageUp": "Page préc.", "PageDown": "Page suiv.",
}


## Nom de la première touche du clavier de l'action `action`, ou « ? ».
static func label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		if key.physical_keycode != KEY_NONE:
			return of_physical(key.physical_keycode)
		if key.keycode != KEY_NONE:
			return of_code(key.keycode)
	return "?"


## Nom imprimé de la touche à la position physique `physical` (position
## QWERTY). La rangée des chiffres garde son chiffre, même en AZERTY (où
## l'on lit « & », « é »… sans Maj).
static func of_physical(physical: Key) -> String:
	if physical >= KEY_0 and physical <= KEY_9:
		return str(physical - KEY_0)
	var code := physical
	# Sans écran (tests), pas de disposition du clavier : position QWERTY.
	if DisplayServer.get_name() != "headless":
		var printed := DisplayServer.keyboard_get_label_from_physical(physical)
		if printed != KEY_NONE:
			code = printed
	return of_code(code)


## Nom de la touche `code` : le caractère pour un signe imprimable
## (« : » plutôt que « Colon »), le nom français sinon.
static func of_code(code: Key) -> String:
	if code > 32 and code < 256:
		return char(code).to_upper()
	var text := OS.get_keycode_string(code)
	return FRENCH.get(text, text)
