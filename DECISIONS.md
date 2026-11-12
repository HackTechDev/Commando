# Décisions

- **Univers** : militaire moderne (forces spéciales), à la demande du porteur du projet. Remplace l'inspiration Seconde Guerre mondiale du §1 du cahier des charges, qui reste à mettre à jour.
- **Modèle du personnage** : construit par code à partir de primitives (`scripts/units/soldier_model.gd`) et animé de façon procédurale, en attendant des assets CC0 et un `AnimationTree` (M10).
- **Maj + clic** sur un commando ajoute à la sélection ; Maj + clic sur un ennemi restera réservé à l'affichage du cône de vision (§13).
- **Postures** : C et X sont des bascules vers accroupi / rampé ; réappuyer remet debout. La course n'est possible que debout.
- **Touches** : définies par position physique (ZQSD en AZERTY = WASD en QWERTY).
- **Navigation** : maillage généré au chargement du niveau à partir des collisions statiques (couches 1 et 2). Le maillage est produit 0,5 m au-dessus du sol ; l'agent compense avec `path_height_offset = 0.5`.
- **Évitement entre unités** : pas encore activé ; les commandos se traversent. Les ordres de groupe sont répartis en cercle autour de la destination.
- **Framework de tests** : pas encore choisi ni installé.
