# Changelog

## Première ébauche (M0 partiel, aperçu de M1 et M2)

- Arborescence du projet, autoloads `EventBus`, `GameState`, `SelectionManager`, InputMap, noms des couches de collision.
- Caméra isométrique orthographique : déplacement, zoom, rotation par pas de 90°, limites.
- Unité `Commando` : sélection (clic, rectangle, touches), déplacement par `NavigationAgent3D`, marche/course, postures debout/accroupi/rampé.
- Modèle 3D procédural d'opérateur des forces spéciales modernes (`SoldierModel`), animé par code.
- Niveau `sandbox` : sol, murs, caisses, navigation générée au chargement, trois opérateurs.

## Ennemi et cône de vision (M3)

- `Enemy` : patrouille en boucle sur les points d'un `Path3D`, avec pause à chaque point.
- `VisionComponent` : cône affiché au sol, occulté par les murs et les caisses, zone proche (détection immédiate) et zone lointaine (cibles debout uniquement).
- Jauge de détection progressive au-dessus de l'ennemi, états `PATROL` / `SUSPICIOUS` / `ALERT`, cône vert / jaune / rouge.
- Indicateur d'alerte global dans le HUD.

## Poursuite et tir en alerte

- En alerte, l'ennemi court vers la cible jusqu'à portée, vise puis tire (traceur, bruit `gunshot`) ; précision décroissante avec la distance et la posture de la cible.
- Cible perdue de vue : il court à sa dernière position connue, y attend, puis reprend sa patrouille.
- `HealthComponent` : points de vie des commandos, affichés dans le HUD ; mort d'un opérateur (corps au sol, retiré de la sélection, message d'échec).

## Tir des opérateurs

- Clic droit sur un ennemi : les unités sélectionnées s'approchent jusqu'à avoir une ligne de tir, puis tirent jusqu'à sa mort.
- Les ennemis ont des points de vie ; un ennemi touché passe en alerte vers le tireur ; mort, il reste au sol et son cône disparaît.

## Munitions limitées

- Chargeur de 10 cartouches et 20 en réserve par opérateur ; rechargement automatique à chargeur vide ou manuel (R), 2 s.
- À sec, l'opérateur cesse d'attaquer et refuse les ordres d'attaque ; le HUD affiche chargeur / réserve.

## Collisions entre unités

- Opérateurs et ennemis se bloquent physiquement et se contournent (évitement de `NavigationAgent3D`).
- Une unité à l'arrêt ne se fait pas pousser ; une destination occupée par une autre unité met fin à l'ordre à proximité.

## Rotation fluide de la caméra

- La caméra tourne en continu tant que A / E est maintenue, avec accélération et arrêt progressifs.

## HUD

- Portraits des opérateurs en bas à gauche : numéro, nom, barre de vie, posture, munitions, surbrillance de sélection ; clic pour sélectionner, double clic pour centrer la caméra.
- Barre d'actions en bas à droite : accroupi, rampé, recharger, stop (nouvelle touche F), avec infobulles.
- Indicateur d'alerte en haut à droite ; thème unique `res://assets/ui/theme.tres`.

## Grimper sur les caisses

- Clic droit sur une caisse : un opérateur sélectionné la rejoint et grimpe dessus ; un ordre au sol le fait redescendre du côté le plus proche de sa destination.
- Une seule unité par caisse ; depuis la caisse, l'opérateur tire par-dessus les obstacles bas et ne redescend que s'il n'a pas de ligne de tir.

## Animation d'escalade

- Montée en plusieurs temps : arme en bandoulière, élan, mains sur le rebord, traction, passage d'une jambe, redressement (1,4 s).
- Descente : accroupi au bord, appui des mains, chute, réception fléchie, redressement (1 s).
- Les bras du modèle sont désormais articulés (épaule et coude) et posés par IK.

## Bouton « Quitter »

- Bouton « Quitter » en haut à droite du HUD, à côté de l'indicateur d'alerte ; il ferme le jeu immédiatement.

## Passage direct entre caisses voisines

- Un opérateur perché qui reçoit l'ordre d'aller sur une caisse collée à la sienne y passe à pied, sans redescendre ; pour une caisse en diagonale, il passe par la caisse intermédiaire.
- Si la caisse visée est occupée, un opérateur déjà perché reste où il est au lieu de redescendre.

## Export Web

- Préréglage d'export « Web » (`export_presets.cfg`), sans threads pour être hébergeable partout ; sortie dans `build/web/`.
