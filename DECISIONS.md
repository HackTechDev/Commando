# Décisions

- **Univers** : militaire moderne (forces spéciales), à la demande du porteur du projet. Remplace l'inspiration Seconde Guerre mondiale du §1 du cahier des charges, qui reste à mettre à jour.
- **Modèle du personnage** : construit par code à partir de primitives (`scripts/units/soldier_model.gd`) et animé de façon procédurale, en attendant des assets CC0 et un `AnimationTree` (M10).
- **Maj + clic** sur un commando ajoute à la sélection ; Maj + clic sur un ennemi restera réservé à l'affichage du cône de vision (§13).
- **Postures** : C et X sont des bascules vers accroupi / rampé ; réappuyer remet debout. La course n'est possible que debout.
- **Touches** : définies par position physique (ZQSD en AZERTY = WASD en QWERTY).
- **Navigation** : maillage généré au chargement du niveau à partir des collisions statiques (couches 1 et 2). Le maillage est produit 0,5 m au-dessus du sol ; l'agent compense avec `path_height_offset = 0.5`.
- **Collisions entre unités** : opérateurs et ennemis vivants se bloquent et se contournent ; les corps (morts) ne bloquent pas. Une unité à l'arrêt est prioritaire et ne bouge pas ; une unité freinée pile de face fait un pas de côté sur sa droite. Les ordres de groupe sont répartis en cercle autour de la destination.
- **Framework de tests** : pas encore choisi ni installé.
- **Affichage du cône** : toujours visible pour l'instant ; l'affichage à la demande (Maj + clic, survol) du §5.2 viendra plus tard.
- **État Alert** : l'ennemi s'arrête et fait face à la cible, sans tirer ni poursuivre (M4). Il reprend sa patrouille 4 s après avoir perdu la cible de vue.
- **Occlusion de la vue** : couche 2 seulement (murs, caisses). Les caisses (1,2 m) cachent une unité rampée ou accroupie juste derrière, pas une unité debout.
- **Machine à états ennemie** : simple `enum` + `match` dans `enemy.gd` pour trois états ; à restructurer en M4 quand tous les états du §5.3 arrivent.
- **Vision en alerte** : un ennemi en alerte voit aussi les cibles accroupies ou rampées en zone lointaine ; seuls les obstacles cachent encore.
- **Tir ennemi** : tirage aléatoire de réussite (85 % à bout portant, 35 % à 14 m, ×0,8 accroupi, ×0,6 rampé), 25 PV par balle sur 100. Pas de projectile physique ; les tirs ratés n'ont aucun effet.
- **Mort d'un commando** : message d'échec dans le HUD, mais la partie continue tant qu'il n'y a pas de système de mission (M7). Les commandos ne peuvent pas encore riposter (M5).
- **Tir des opérateurs** : arme à silencieux commune aux trois opérateurs (34 PV par balle, 95 % à bout portant, 60 % à 16 m, munitions illimitées pour l'instant). Un ennemi touché sans avoir vu le tireur passe en alerte et court vers la position du tir.
- **Corps ennemis** : ils restent au sol mais ne sont pas encore détectables ni transportables (M4/M5).
- **Munitions** : 10 cartouches par chargeur, 20 en réserve, comptées à l'unité (un rechargement partiel ne perd rien). Pas encore de ramassage de munitions (§5.5). Les ennemis gardent des munitions illimitées.
