# Cahier des charges — Jeu d'infiltration tactique en 3D isométrique

> Document destiné à Claude Code (CLI). À placer à la racine du projet (ou à référencer depuis `CLAUDE.md`).
> Travailler **jalon par jalon** (section 10), sans anticiper les jalons suivants.

---

## 1. Vision

Jeu d'infiltration tactique en temps réel, vue 3D isométrique, inspiré de *Commandos : Derrière les lignes ennemies*.
Le joueur dirige une petite escouade de spécialistes (2 à 6) aux compétences complémentaires, infiltrée derrière les lignes ennemies pour accomplir des objectifs (saboter, éliminer, libérer, voler des documents) sans déclencher l'alerte générale.

Piliers :
1. **Lisibilité** : le joueur voit ce que voient les ennemis (cônes de vision) et ce qu'ils entendent.
2. **Complémentarité** : aucun personnage ne peut finir une mission seul.
3. **Planification** : observer, planifier, exécuter, recharger la sauvegarde rapide, recommencer.
4. **Punition juste** : se faire repérer est toujours explicable.

Univers : fictif, **militaire contemporain**. Le joueur dirige des opérateurs des forces spéciales modernes (casque à rails, gilet porte-plaques, carabine, vision nocturne, radio). Leurs adversaires sont des soldats d'une armée irrégulière, à l'équipement plus ancien et dépareillé. Les cartes d'essai reprennent des cartes libres d'UFO:AI. **Aucun nom, personnage, logo ou asset repris de Commandos** (propriété intellectuelle) : archétypes génériques uniquement.

---

## 2. Contraintes techniques

| Élément | Choix |
|---|---|
| Moteur | **Godot 4.7** (ne pas utiliser d'API dépréciées de Godot 3.x / 4.0-4.2) |
| Langage | **GDScript typé statiquement** (`var x: int`, fonctions typées, `class_name`) |
| Rendu | Forward+ (fallback Compatibility testé) |
| Caméra | `Camera3D` en projection **orthographique**, angle isométrique (≈ -35° pitch / 45° yaw) |
| Navigation | `NavigationRegion3D` + `NavigationAgent3D` (évitement activé) |
| Physique | Jolt (par défaut en 4.x récent) |
| Tests | **GUT** ou **gdUnit4** (choisir un seul, l'installer dans `addons/`) |
| Plateforme cible | Linux (prioritaire), Windows |
| Résolution de référence | 1920×1080, mise à l'échelle `canvas_items` + `expand` |
| Entrées | Souris + clavier, tout passe par l'**InputMap** (aucune touche en dur) |

---

## 3. Architecture du projet

```
res://
├── addons/                 # GUT ou gdUnit4
├── assets/
│   ├── models/  textures/  audio/  fonts/
├── data/                   # Ressources .tres (personnages, armes, ennemis, missions)
├── scenes/
│   ├── main/               # Main.tscn, menus
│   ├── camera/             # RigCamera iso
│   ├── units/              # Commando de base + spécialisations
│   ├── enemies/            # Soldat, officier, chien, véhicule
│   ├── props/              # Caisses, portes, barils, interrupteurs
│   ├── levels/             # Un dossier par mission
│   └── ui/                 # HUD, portraits, inventaire, menus
├── scripts/
│   ├── autoload/           # Singletons
│   ├── components/         # Composants réutilisables
│   ├── ai/                 # Machine à états ennemie
│   └── resources/          # Classes Resource personnalisées
└── tests/
```

### Autoloads
- `GameState` : mission courante, état d'alerte global, objectifs.
- `EventBus` : signaux globaux (`unit_spotted`, `alarm_raised`, `objective_completed`, `noise_emitted`…).
- `SaveManager` : sauvegarde rapide / chargement (F5 / F9).
- `SelectionManager` : unités sélectionnées, ordres.
- `AudioManager` : bus, musique dynamique selon le niveau d'alerte.

### Principes
- **Composition plutôt qu'héritage** : composants enfants (`HealthComponent`, `VisionComponent`, `HearingComponent`, `InteractableComponent`, `CarryableComponent`, `InventoryComponent`).
- **Données dans des `Resource`** (`.tres`) : stats, compétences, armes, paramètres de vision. Aucune valeur d'équilibrage en dur dans le code.
- Communication : signaux vers le haut, appels de méthodes vers le bas. `EventBus` seulement pour les événements transverses.
- Les scènes `.tscn` restent **petites et modulaires** (éditables à la main par Claude CLI sans risque).
- Groupes Godot : `commandos`, `enemies`, `interactables`, `bodies`, `hiding_spots`.
- Couches de collision documentées dans `project.godot` et ici :

| Couche | Usage |
|---|---|
| 1 | Sol / terrain |
| 2 | Murs / obstacles bloquant la vue |
| 3 | Commandos |
| 4 | Ennemis |
| 5 | Interactables |
| 6 | Végétation (bloque la vue partiellement, pas le passage) |
| 7 | Eau |

---

## 4. Caméra et vue

- Rig : `Node3D` pivot → `Camera3D` orthographique.
- Déplacement : bord d'écran, touches ZQSD/flèches, clic molette maintenu (drag).
- Zoom : molette, en jouant sur `size` (bornes min/max).
- **Rotation libre** autour du point visé, tant que les touches dédiées (A / E) sont maintenues, avec un lissage. L'inclinaison reste fixe (≈ -35°).
- Suivi de l'unité sélectionnée (double-clic sur portrait ou touche dédiée).
- Limites de déplacement définies par niveau (`AABB`).
- **Occlusion** : les toits/étages d'un bâtiment deviennent transparents ou masqués quand une unité est à l'intérieur ; les murs entre caméra et unité sélectionnée passent en transparence (shader de dithering).

---

## 5. Gameplay

### 5.1 Contrôle des unités
- Sélection : clic gauche, sélection rectangulaire, touches 1-6, portraits du HUD.
- Déplacement : clic droit sur le sol ; double-clic droit = courir.
- Indicateur de destination + chemin prévisualisé.
- **Postures** : debout / accroupi / rampé (touche bascule). Impact : vitesse, bruit, visibilité.
- Action contextuelle selon le curseur (curseur change selon la cible : porte, ennemi, cadavre, échelle…).
- **Mode ordres simultanés** : enregistrer une action par unité puis les déclencher toutes ensemble (touche dédiée).
- Pause tactique (Espace) avec possibilité de donner des ordres en pause (option de difficulté).

### 5.2 Détection ennemie (cœur du jeu)
- **Cône de vision** (`VisionComponent`) :
  - deux zones : proche (détection immédiate) et lointaine (détection uniquement debout ; accroupi/rampé invisible) ;
  - angle et portée paramétrables par type d'ennemi ;
  - occlusion par raycasts (couches 2 et 6) ;
  - rendu au sol par mesh généré ou shader décal, couleurs : vert (calme), jaune (suspicion), rouge (alerte).
- Affichage du cône : **Maj + clic** sur un ennemi (persistant), ou survol.
- **Jauge de détection** progressive (pas de repérage instantané sauf zone proche).
- **Ouïe** (`HearingComponent`) : réagit aux événements `noise_emitted(position, rayon, type)`. Course, tir, explosion, chute de corps, appât sonore.
- Découverte d'un **cadavre** ou d'un **ennemi assommé** → alerte.
- Traces de pas dans la neige/boue (bonus, jalon tardif).

### 5.3 IA ennemie
Machine à états (classes de nœuds ou `Resource`s, au choix, mais documentée) :

| État | Comportement |
|---|---|
| `Patrol` | Suit un `Path3D` ou des points, avec pauses et rotations de tête |
| `Idle/Guard` | Poste fixe, balayage de regard |
| `Suspicious` | S'arrête, regarde vers la source, s'approche prudemment |
| `Investigate` | Se rend au dernier point de bruit/vision, fouille autour |
| `Alert` | Tire, appelle des renforts, déclenche l'alarme si proche d'une sirène |
| `Search` | Après perte de contact, fouille la zone pendant N secondes |
| `Return` | Retour au poste/patrouille, vigilance accrue (cônes plus longs temporairement) |
| `Stunned` / `Tied` / `Dead` | Neutralisé |

- Niveaux d'alerte globaux : 0 calme, 1 suspicion locale, 2 alarme (renforts depuis des points de spawn, patrouilles accrues).
- Types : soldat, sentinelle, officier (déclenche l'alarme plus vite), chien (odorat, ignore la posture), véhicule de patrouille.

### 5.4 Escouade (archétypes génériques)

| Archétype | Compétences |
|---|---|
| **Commando de choc** | Couteau silencieux, escalade de poteaux/murs, porter 1 corps rapidement, leurre sonore |
| **Tireur d'élite** | Fusil de précision (munitions limitées), longue portée, silencieux relatif |
| **Sapeur** | Pièges, explosifs à retardement/télécommandés, désamorçage, pince coupante (barbelés) |
| **Plongeur** | Nage, harpon, canot pneumatique, détection de mines |
| **Conducteur** | Pilote véhicules, peut ligoter, mitrailleuse fixe |
| **Infiltré** | Déguisement en uniforme ennemi, distrait les soldats, injection soporifique |

Compétences communes : pistolet bruyant, assommer, porter/déposer un corps, ligoter, se cacher (buissons, bâtiments), grimper aux échelles, ouvrir les portes, fouiller.

### 5.5 Interactions et objets
- Corps : porter, déposer, cacher (dans buissons/bâtiments/eau). Un corps visible est un risque.
- Portes (ouvertes/verrouillées), échelles, fenêtres, bâtiments enterables (intérieur affiché en coupe).
- Inventaire par personnage (grille simple), échange entre unités adjacentes.
- Objets ramassables : munitions, trousses de soins, explosifs, documents, uniforme.

### 5.6 Missions
- Définies par une `MissionData` (`Resource`) : briefing, objectifs principaux/secondaires, unités disponibles, conditions d'échec.
- Objectifs typés : détruire, éliminer cible, récupérer objet, libérer prisonnier, atteindre zone d'extraction avec toute l'escouade.
- Échec : un commando meurt (par défaut), alarme générale (option selon mission), temps écoulé.
- Écran de fin : temps, alarmes déclenchées, ennemis tués/neutralisés, note.

---

## 6. Interface

- **HUD** : portraits des commandos (vie, posture, sélection), barre d'actions/compétences de l'unité sélectionnée, munitions.
- Indicateur d'alerte global.
- Minimap optionnelle (jalon tardif).
- Journal d'objectifs (touche dédiée).
- Infobulles sur les compétences.
- Menus : principal, pause, options (audio, vidéo, remappage des touches), sélection de mission, briefing.
- Toute l'UI en `Control` avec un **Theme** unique (`res://assets/ui/theme.tres`).
- Textes via le système de traduction de Godot (`tr()`), langues : français (par défaut), anglais.

---

## 7. Niveaux

- Construction modulaire : `GridMap` avec `MeshLibrary` pour le terrain/bâtiments + props placés à la main.
- Navigation régénérée à partir de la géométrie (bake au chargement ou pré-baké).
- Chaque niveau contient : `LevelRoot` avec `SpawnPoints`, `PatrolPaths`, `Objectives`, `CameraBounds`, `ExtractionZone`.
- **Niveau de test** (`levels/sandbox/`) : terrain plat, quelques murs, 3 ennemis, toutes les interactions, utilisé pour développer chaque mécanique.
- Mission 1 (tutoriel) puis mission 2 complète comme démonstration.

---

## 8. Assets

- Phase prototype : **primitives** (CSG/MeshInstance3D), couleurs codées (bleu = commandos, rouge = ennemis, jaune = interactables).
- Ensuite : assets libres **CC0** (ex. Kenney, Quaternius) ; consigner chaque source et licence dans `assets/CREDITS.md`.
- Animations : `AnimationTree` avec state machine (idle, marche, course, accroupi, rampé, attaque, mort, porter).
- Style visuel cible : low-poly stylisé, éclairage chaud, ombres nettes.

---

## 9. Audio

- Bus : Master, Musique, SFX, Voix, UI.
- Musique dynamique selon niveau d'alerte (crossfade).
- Sons positionnels 3D (`AudioStreamPlayer3D`) pour pas, tirs, explosions.
- Courtes répliques des personnages à la sélection/ordre (placeholders texte/bips au début).

---

## 10. Jalons (à réaliser dans l'ordre)

Chaque jalon doit être **jouable**, testé, et faire l'objet d'un commit.

| # | Jalon | Critères d'acceptation |
|---|---|---|
| **M0** | Squelette du projet | Arborescence, autoloads vides, InputMap, framework de tests installé, scène sandbox qui se lance |
| **M1** | Caméra iso | Pan, zoom, rotation libre lissée, limites |
| **M2** | Unité contrôlable | Sélection (clic, rectangle, touches), déplacement NavigationAgent3D, marche/course, postures |
| **M3** | Ennemi + vision | Patrouille sur Path3D, cône de vision affiché et occlus par les murs, deux zones, jauge de détection, état Alert |
| **M4** | IA complète | Tous les états de 5.3, ouïe, bruit, découverte de corps, alarme globale |
| **M5** | Actions de base | Couteau, assommer, porter/cacher un corps, ligoter, portes, échelles |
| **M6** | Escouade | 3 archétypes (choc, tireur d'élite, sapeur) avec compétences, HUD portraits + barre d'actions |
| **M7** | Mission jouable | MissionData, objectifs, conditions de victoire/échec, briefing, écran de fin, sauvegarde rapide |
| **M8** | Occlusion & bâtiments | Transparence des murs, toits masqués, intérieurs |
| **M9** | Archétypes restants | Plongeur (eau), conducteur (véhicule), infiltré (déguisement) |
| **M10** | Habillage | Assets CC0, animations, audio, menus, options, traduction FR/EN |
| **M11** | Contenu | Mission tutoriel + mission 2, équilibrage |

---

## 11. Consignes pour Claude Code

1. Lire ce document en entier avant de commencer ; travailler **uniquement sur le jalon demandé**.
2. Avant de coder un jalon : proposer un court plan (fichiers créés/modifiés), puis l'exécuter.
3. Vérifier après chaque modification :
   - `godot --headless --path . --quit` sans erreur de parsing ;
   - lancer les tests en headless (commande GUT/gdUnit4 documentée dans `README.md`).
4. Écrire des **tests unitaires** pour la logique pure (détection, états d'IA, inventaire, objectifs, sauvegarde).
5. Ne jamais générer de gros `.tscn` monolithiques : préférer des sous-scènes instanciées.
6. Ne pas modifier les fichiers `.import` ni le dossier `.godot/`.
7. Conventions :
   - `snake_case` pour fichiers, variables, fonctions ; `PascalCase` pour `class_name` et nœuds ;
   - signaux au passé (`unit_selected`, `alarm_raised`) ;
   - constantes en `UPPER_SNAKE_CASE` ;
   - `@export` pour tout paramètre réglable ;
   - commentaires `##` (doc Godot) sur classes et méthodes publiques.
8. Tenir à jour `README.md` (lancement, contrôles, tests) et `CHANGELOG.md` (une entrée par jalon).
9. Un commit Git par étape logique, message clair en français.
10. En cas de doute sur une règle de gameplay : choisir la solution la plus simple, la noter dans `DECISIONS.md`, et continuer.

---

## 12. Hors périmètre (pour l'instant)

- Multijoueur / coopération.
- Éditeur de niveaux intégré.
- Génération procédurale.
- Consoles et mobile.
- Campagne scénarisée complète (au-delà de 2 missions).

---

## 13. Contrôles par défaut (proposition)

| Action | Touche |
|---|---|
| Sélection | Clic gauche / rectangle |
| Déplacer / courir | Clic droit / double clic droit |
| Sélection directe | 1 à 6 |
| Posture | C (accroupi), X (rampé) |
| Afficher cône ennemi | Maj + clic gauche |
| Caméra | ZQSD / flèches, bord d'écran, clic molette (glisser), molette (zoom), A/E maintenus (rotation libre) |
| Centrer sur l'unité | Espace double-pression ou Origine |
| Pause tactique | Espace |
| Ordres simultanés | Tab (enregistrer), Entrée (exécuter) |
| Inventaire | I |
| Objectifs | O |
| Sauvegarde / chargement rapide | F5 / F9 |
| Menu | Échap |
