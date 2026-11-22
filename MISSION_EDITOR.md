# Éditeur de mission

Plan de travail. Avancement : étapes 1 à 4 faites.

## Choix arrêtés

- **Un greffon dans l'éditeur Godot** (`addons/mission_editor/`), pas un éditeur dans le jeu. Il sert au développement : les joueurs ne créent pas de missions.
- **Première version : étapes 1 à 5** ci-dessous.
- **Les missions de série s'ouvrent aussi dans l'éditeur.**

## 1. Principe

Avec un greffon, une mission reste ce qu'elle est aujourd'hui : une scène `.tscn` dont la racine est un `LevelRoot`. Le greffon édite cette scène directement. Il n'y a ni format JSON, ni reconstruction au chargement, ni conversion des missions de série : elles s'ouvrent comme n'importe quelle scène.

Le greffon apporte ce que l'éditeur Godot ne sait pas faire seul :
- une palette des éléments du jeu, posés d'un clic dans la vue 3D ;
- l'affichage des décors et des unités procédurales ;
- des repères visuels : cônes de vue, trajets des rondes, portée du bruit ;
- un panneau pour les informations de la mission (titre, objectifs…) ;
- une vérification de la carte et un bouton pour l'essayer.

L'annulation et le rétablissement viennent de Godot (`EditorUndoRedoManager`), de même que l'inspecteur pour les réglages fins.

### Trois obstacles à lever

1. **Les données des missions sont dans le code.** Titre, description, camouflage conseillé et objectifs sont écrits dans `scripts/levels/level_catalog.gd` (24 entrées). Pour que le greffon les modifie, ils doivent devenir une ressource éditable, `MissionInfo` (fichier `.tres`), rangée à côté de la scène. `LevelCatalog` lit ces ressources au lieu de son tableau.
2. **Les décors procéduraux sont invisibles dans l'éditeur.** Les bâtiments, gardes (`SoldierModel`), invités, passants, voitures, Sabre, convertible, etc. sont construits par leur script au lancement. Seuls `ladder.gd` et `low_wall.gd` sont `@tool`. Il faut les rendre `@tool` un par un, en ne gardant dans l'éditeur que la construction du modèle : pas de déplacement, d'IA, de bruit ni de groupes (garde `Engine.is_editor_hint()`).
   - Les cartes UFO:AI (`UfoMapLevel`) sont aussi construites au chargement : il faut un aperçu, construit dans l'éditeur sans être enregistré dans la scène.
   - Les textures externes (`TextureLibrary`) : même chose. C'est le point 101 a) d'`IMPROVEMENTS.md`.
3. **18 cartes sont générées** par `tools/gen_*.py` (`MapBuilder`). Une carte modifiée dans l'éditeur, puis régénérée, perdrait ses modifications. Voir § 6.

## 2. Le greffon

- **Dock « Mission »**, quand la scène ouverte est un `LevelRoot` :
  - **palette par catégories** : décor (bâtiment, mur, muret, caisse, haie, lampadaire, échelle, route, trottoir), équipe, ennemis (garde posté, ronde, pick-up armé), civils (invité, passant, boucle de voitures), objectifs (documents, groupe électrogène…), extraction et véhicules (convertible, Sabre) ;
  - **réglages de la carte** : nuit ou jour, tenue de rigueur ;
  - **informations de la mission** (`MissionInfo`) : titre, description, camouflage conseillé, objectifs.
- **Pose dans la vue 3D** : le greffon capte les clics (`_forward_3d_gui_input`), vise le sol (couche 1) et pose l'élément sous le bon nœud parent (`Decor`, `Units`, `Enemies`…, comme `MapBuilder`).
  - Grille magnétique de 0,5 m, qu'on peut désactiver ; rotation par pas de 15°.
  - Raccourcis du greffon : des `Shortcut` de l'éditeur Godot, que l'utilisateur peut changer. La règle de l'InputMap concerne le jeu, pas l'éditeur.
- **Repères visuels** (`EditorNode3DGizmoPlugin`) :
  - cône de vision de chaque garde, selon son `VisionConfig` (zones proche et lointaine, de jour et de nuit) ;
  - trajets des rondes, des passants et des boucles de voitures, avec des poignées pour déplacer, insérer ou retirer un point ;
  - zone d'extraction ;
  - portée des bruits (klaxon, moteur du Sabre).

## 3. Vérification et essai

- **Bouton « Vérifier »** : il calcule le maillage de navigation dans l'éditeur et contrôle :
  - l'équipe a un point de départ ;
  - chaque objectif a sa cible sur la carte (porteur des documents, groupe électrogène, VIP…) ;
  - les objectifs et la zone d'extraction sont atteignables à pied depuis le départ, comme `build/shots/check_map.sh` ;
  - au-delà d'environ 40 gardes, un avertissement de performance (avec 72 gardes, on est tombé à 10 images/s).

  Chaque problème est listé ; un clic sélectionne le nœud en cause.
- **Bouton « Essayer »** : lance la scène ouverte (`EditorInterface.play_custom_scene`). À vérifier : lancée seule, une scène de niveau doit monter les objectifs, l'équipe et son équipement comme depuis le menu.
- **Catalogue** : une mission créée avec le greffon apparaît dans le choix des missions dès que sa `MissionInfo` existe (le catalogue lit les ressources du dossier `scenes/levels`).

## 4. Étapes, chacune avec son commit

1. ✓ **`MissionInfo`** : ressource des informations de mission, migration des 24 entrées de `level_catalog.gd` par un script, `LevelCatalog` qui lit les ressources. Le jeu doit se comporter exactement comme avant.
2. ✓ **Affichage dans l'éditeur** : décors et unités `@tool` (construction seule) ; aperçu des cartes UFO:AI et des textures externes, non enregistré. Vérifié en ouvrant chaque mission de série dans l'éditeur.
3. ✓ **Base du greffon** : dock, palette de décor, pose au clic, grille, rotation, annulation ; réglages de la carte ; avertissement sur les cartes générées et protection contre l'écrasement (§ 6).
4. ✓ **Unités, trajets et mission** : équipe, gardes et rondes, civils, voitures, avec leurs repères visuels et poignées de trajet ; panneau `MissionInfo` avec les objectifs et leurs cibles ; extraction.
5. **Vérification et essai** : bouton « Vérifier », bouton « Essayer », nouvelle mission visible dans le catalogue.

Après la première version : copier-coller entre missions, dessin des routes au pinceau, partir d'une carte UFO:AI comme fond.

## 5. Hors de la première version

- **Relief** : le sol reste plat.
- **Bâtiments** : seulement les bâtiments réglables qui existent déjà, pas de dessin libre de pièces ni d'étages.
- **Événements scriptés** : renforts déclenchés, pick-ups qui arrivent, ateliers du didacticiel. Les missions de série qui en ont s'ouvrent et se modifient, mais ces scripts ne s'éditent pas dans le greffon.
- **Missions créées par les joueurs** : le greffon ne sert pas dans le jeu exporté.

## 6. Cartes générées

18 cartes de série sont produites par `tools/gen_*.py` (`MapBuilder`). Une carte modifiée dans l'éditeur, puis régénérée, perdrait ses modifications. Règle retenue :

- **Avertissement** : quand la scène ouverte vient d'un générateur, le dock « Mission » l'affiche et nomme le script.
- **Pas d'écrasement** : `MapBuilder` note dans la scène une empreinte de son contenu au moment de la génération. Avant d'écrire, il compare la scène existante à cette empreinte. Si elle a été modifiée depuis, il refuse d'écrire et le signale.
- **Retrait au cas par cas** : une carte reprise dans l'éditeur devient la source ; son générateur est ensuite retiré du dépôt.

Fait à l'étape 3 : la scène porte le nom de son générateur et son empreinte (`metadata/generator`, `metadata/generated_hash` sur la racine). Une scène sans empreinte n'est pas écrasée non plus : c'est le cas du didacticiel, retouché à la main après sa génération. `MAPKIT_FORCE=1` force l'écriture.
