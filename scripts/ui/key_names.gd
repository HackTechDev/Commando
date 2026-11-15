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
		var code := key.keycode
		if key.physical_keycode != KEY_NONE:
			code = key.physical_keycode
			# Sans écran (tests), pas de disposition du clavier : position QWERTY.
			if DisplayServer.get_name() != "headless":
				var printed := DisplayServer.keyboard_get_label_from_physical(key.physical_keycode)
				if printed != KEY_NONE:
					code = printed
		if code != KEY_NONE:
			var text := OS.get_keycode_string(code)
			return FRENCH.get(text, text)
	return "?"
