class_name ConfirmDialog
extends ConfirmationDialog
## Fenêtre de confirmation avant une action qui interrompt la partie (boutons
## « Quitter » et « Menu »). Le jeu est en pause tant qu'elle est ouverte.

## Ce que fait la confirmation.
var action: Callable
var _was_paused: bool = false


## Fenêtre « Quitter le jeu ? ».
static func for_quit(tree_owner: Node) -> ConfirmDialog:
	return ConfirmDialog.new("Quitter", "Quitter le jeu ?", "Quitter", func() -> void: tree_owner.get_tree().quit())


## Fenêtre « Revenir au menu ? ».
static func for_menu(tree_owner: Node) -> ConfirmDialog:
	return ConfirmDialog.new("Menu", "Revenir au menu ?\nLa partie en cours sera perdue.", "Menu",
			func() -> void: tree_owner.get_tree().change_scene_to_file(LevelCatalog.MENU_SCENE))


func _init(window_title: String = "", text: String = "", ok_text: String = "OK", on_confirm: Callable = Callable()) -> void:
	title = window_title
	dialog_text = text
	ok_button_text = ok_text
	cancel_button_text = "Annuler"
	action = on_confirm
	exclusive = true
	min_size = Vector2i(320, 120)
	get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	process_mode = Node.PROCESS_MODE_ALWAYS
	confirmed.connect(_on_confirmed)
	canceled.connect(_resume)


## Ouvre la fenêtre, centrée, avec « Annuler » sélectionné (Entrée ne
## confirme pas par erreur ; Échap annule).
func ask() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	popup_centered()
	get_cancel_button().grab_focus()


func _on_confirmed() -> void:
	# Pause levée avant l'action : la scène suivante (menu) ne doit pas
	# démarrer en pause.
	_resume()
	if action.is_valid():
		action.call()


func _resume() -> void:
	get_tree().paused = _was_paused
