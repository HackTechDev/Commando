class_name QuitDialog
extends ConfirmationDialog
## Fenêtre de confirmation avant de quitter le jeu (boutons « Quitter » du
## menu et du HUD). Le jeu est en pause tant qu'elle est ouverte.

## Ce que fait la confirmation (remplaçable pour les tests).
var quit_action: Callable
var _was_paused: bool = false


func _init() -> void:
	title = "Quitter"
	dialog_text = "Quitter le jeu ?"
	ok_button_text = "Quitter"
	cancel_button_text = "Annuler"
	exclusive = true
	min_size = Vector2i(320, 120)
	get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	process_mode = Node.PROCESS_MODE_ALWAYS
	confirmed.connect(_on_confirmed)
	canceled.connect(_resume)


## Ouvre la fenêtre, centrée, avec « Annuler » sélectionné (Entrée ne quitte
## pas par erreur ; Échap annule).
func ask() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	popup_centered()
	get_cancel_button().grab_focus()


func _on_confirmed() -> void:
	if quit_action.is_valid():
		quit_action.call()
	else:
		get_tree().quit()


func _resume() -> void:
	get_tree().paused = _was_paused
