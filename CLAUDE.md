# CLAUDE.md

Jeu d'infiltration tactique en temps réel, vue 3D isométrique, Godot 4.7.2, GDScript typé.

## À lire

- `CAHIER_DES_CHARGES.md` : vision, architecture, couches de collision, jalons, consignes (§11).
- `IMPROVEMENTS.md` : liste numérotée des améliorations (« fais le point 4.1 »). Marquer un point fait : `**4.1 ~~Titre~~** (fait)`.
- `DECISIONS.md` : choix de conception, à compléter à chaque règle tranchée.
- `CHANGELOG.md` : une section par fonctionnalité livrée.
- `README.md` : lancement, contrôles (à tenir à jour avec l'InputMap), tests.

## Godot

L'exécutable n'est pas dans le PATH :

```sh
G=$HOME/JEUX/GODOT/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . --import          # après tout nouveau `class_name`
$G --headless --path . --quit-after 60   # vérification sans affichage
```

## Vérifications

```sh
./run_tests.sh                           # toute la suite GUT (environ 6 min)
./run_tests.sh -gselect=test_vip.gd      # un seul fichier
./run_tests.sh -gunit_test_name=push     # tests dont le nom contient « push »
```

Les tests de jeu héritent de `tests/helpers/level_test.gd` (`load_level`, `node`, `frames`, `frames_until`, `park`, `hide_from_enemies`).

## Conventions

- Textes, commentaires `##`, messages de commit : en français.
- GDScript typé partout ; `snake_case`, `PascalCase` pour `class_name` et nœuds, constantes en `UPPER_SNAKE_CASE`.
- Aucune touche en dur : tout passe par l'InputMap (`project.godot`), par position physique (AZERTY par défaut).
- Modèles 3D procéduraux (`SoldierModel`) : vérifier visuellement par un rendu hors écran quand on touche à la géométrie.
- Les textures et cartes UFO:AI sont hors du dépôt (`../CommandoAsset`), voir `assets/TEXTURES.md`.
- Un commit par étape logique, après une suite de tests au vert.
