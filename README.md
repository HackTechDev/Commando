# Commando

Jeu d'infiltration tactique en temps réel, vue 3D isométrique (Godot 4.7, GDScript typé).
Voir `CAHIER_DES_CHARGES.md` pour la vision, l'architecture et les jalons.

## Lancement

```sh
godot --path .            # menu de démarrage : choix de la carte
godot --path . scenes/levels/sandbox/sandbox.tscn          # lance directement le terrain d'essai
godot --path . scenes/levels/training_a/training_a.tscn   # lance directement la carte UFO:AI « training_a »
godot --headless --path . --quit-after 60   # vérification sans affichage
```

(`godot` = exécutable Godot 4.7.x.) Dans l'éditeur, F5 ouvre le menu ; F6 lance directement la scène ouverte. Le bouton « Menu » du HUD ramène au choix de la carte. Pour proposer un nouveau niveau dans le menu, l'ajouter à `LevelCatalog.LEVELS` (`scripts/levels/level_catalog.gd`).

Les textures et les cartes ne sont pas dans le dépôt : elles sont lues au chargement de chaque niveau dans `../CommandoAsset/textures` et `../CommandoAsset/maps` (réglages de projet `commando/assets/texture_dir` et `commando/assets/map_dir`, ou variables d'environnement `COMMANDO_TEXTURES` et `COMMANDO_MAPS`). Voir `assets/TEXTURES.md`.

## Export Web (HTML)

```sh
./export_web.sh            # exporte dans build/web/
./export_web.sh --serve    # exporte puis sert le jeu sur http://localhost:8000
./export_web.sh --debug    # export en mode débogage
```

Le script cherche Godot dans la variable `GODOT`, puis dans le PATH, puis à son emplacement par défaut.

Le dossier `build/` n'est pas versionné. La page doit être servie en HTTP : l'ouvrir directement depuis le disque (`file://`) ne fonctionne pas. Les modèles d'export Web de Godot 4.7.2 doivent être installés. Le jeu Web n'a pas accès au disque : il tourne sans les textures ni les cartes externes (sandbox sans textures).

## Contrôles

| Action | Touche (AZERTY) |
|---|---|
| Sélectionner | Clic gauche, rectangle, touches 1 à 3 (Maj : ajouter) |
| Marcher / courir | Clic droit / double clic droit |
| Tirer sur un ennemi | Clic droit sur l'ennemi |
| Couteau (élimination silencieuse) | V, puis clic gauche sur l'ennemi |
| Assommer | B, puis clic gauche sur l'ennemi |
| Lancer le couteau (jusqu'à 7 m) | T, puis clic gauche sur l'ennemi ; passer sur le couteau pour le ramasser |
| Pousser / tirer une caisse | P, puis clic gauche sur le côté de la caisse ; clic droit au sol pour la déplacer dans l'axe ; F pour lâcher |
| Grimper sur une caisse | Clic droit sur la caisse (un ordre au sol fait redescendre) |
| Grappin (équipement) | W, puis clic gauche sur un point en hauteur : l'opérateur lance le grappin et monte à la corde |
| Échelle, muret | Clic droit sur le toit ou de l'autre côté : le chemin passe par l'échelle ou enjambe le muret |
| Arme à la bretelle / en main | G (bascule) |
| Arme secondaire / principale | Y |
| Recharger | R |
| Annuler l'ordre en cours | F (clic droit pour annuler une action V / B / T / P armée) |
| Accroupi / rampé | C / X (bascule) |
| Déplacer la caméra | ZQSD, flèches, bord d'écran, clic molette maintenu |
| Zoom | Molette |
| Rotation de la caméra | A / E (maintenir) |
| Centrer sur l'unité | Origine |
| Pause tactique (ordres possibles) | Espace |
| Ordres simultanés | Tab (préparer / abandonner), Entrée (exécuter) |
| Étage affiché (cartes à bâtiments) | Page suiv. (descendre), Page préc. (monter ; au-dessus du dernier étage, tout s'affiche) |
| Aide (toutes les commandes, jeu en pause) | H (Échap ou clic pour fermer) |
| Journal des objectifs / minicarte | O / M (clic sur la minicarte : centrer la caméra) |
| Menu pause (reprendre, recommencer, aide, options, menu, quitter) | Échap (annule d'abord une action V / B / T… armée) |
| Quitter | Bouton « Quitter » en haut à droite |

Les touches sont définies par position physique dans l'InputMap : sur un clavier QWERTY, ZQSD devient WASD et A/E devient Q/E.

## Tests

Les tests utilisent [GUT](https://github.com/bitwes/Gut) 9.7.1 (licence MIT), installé dans `addons/gut`.

```sh
./run_tests.sh                                   # toute la suite (environ 3 min)
./run_tests.sh -gdir=res://tests/unit            # tests unitaires seuls (quelques secondes)
./run_tests.sh -gselect=test_crate.gd            # un fichier
./run_tests.sh -gselect=test_crate.gd -gunit_test_name=push   # un test
```

Le script renvoie un code non nul si un test échoue. Dans l'éditeur, le panneau « GUT » (en bas) lance les mêmes tests.

- `tests/unit/` : logique pure, sans scène (cône de vision, points de vie, lecture des cartes UFO:AI, textures et dossiers externes, sons).
- `tests/gameplay/` : parties jouées dans le terrain d'essai (escalade, fusillade, postures, corps à corps, prises par derrière, lutte, parade, lancer de couteau, caisses, sons).
- `tests/levels/` : cartes `training_a`, `training_b` et `fighter_crash` (ignorées si le fichier de carte est absent) et menu de démarrage.
- `tests/helpers/level_test.gd` : classe de base `LevelTest` (chargement d'un niveau, attente en images de physique, mise à l'écart des ennemis).

Les tests de jeu tournent en temps réel simulé : ils sont lents (quelques secondes chacun) mais vérifient le comportement réel. Les tirages au sort sont rendus reproductibles par `seed()` ; un test qui dépend d'une probabilité la fixe sur une copie des réglages de l'unité (`own_stats`).
