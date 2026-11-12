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
