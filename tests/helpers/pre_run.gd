extends GutHookScript
## Avant les tests : équipe par défaut et fichier de sauvegarde à part, pour
## ne dépendre ni toucher à la personnalisation du joueur.


func run() -> void:
	OperatorRoster.save_path = "user://test_operators.json"
	OperatorRoster.use(OperatorRoster.new())
