# Éditeur de mission

Le greffon « Éditeur de mission » (`addons/mission_editor`) sert à créer et modifier les missions dans l'éditeur Godot. Ce fichier comprend :

- un **didacticiel** : une mission construite pas à pas, de la création à l'essai ;
- une **référence** : palette, objectifs, vérification, raccourcis, limites ;
- le **plan de travail** qui a guidé la première version (terminée : étapes 1 à 5).

## Didacticiel : une première mission

Exemple suivi : « Raid sur le dépôt ». De nuit, l'équipe s'infiltre dans une cour gardée, incendie un dépôt de carburant, prend les documents d'un officier et rejoint l'extraction.

### 1. Préparer l'éditeur

1. Ouvrez le projet dans Godot 4.7. Le greffon est déjà activé (Projet > Paramètres du projet > Greffons : « Éditeur de mission »).
2. Pour voir les textures des cartes UFO:AI et des bâtiments, le dossier `../CommandoAsset` doit exister à côté du projet (voir `assets/TEXTURES.md`). Sans lui, tout fonctionne, mais les murs et le sol restent unis.
3. Ouvrez une scène de mission, par exemple `scenes/levels/sandbox/sandbox.tscn` (Terrain d'essai). Dans le panneau de droite, à côté de « Inspecteur », apparaît l'onglet **Mission**. S'il est caché, utilisez les flèches au bout de la rangée d'onglets.
4. Passez sur la vue **3D** (en haut de l'éditeur). Les décors, les gardes, les opérateurs et les véhicules s'y affichent comme en jeu.

Le dock « Mission » contient, de haut en bas :

| Zone | Rôle |
|---|---|
| Titre et chemin | Mission ouverte. |
| Avertissement orange | La carte vient d'un générateur Python (voir l'étape 9). |
| Nouvelle mission | Nom de dossier + bouton : crée une mission. |
| Vérification | Boutons « Vérifier » et « Essayer », puis leur résultat. |
| Informations | Objectifs de la mission et leur cible sur la carte. |
| Carte | Nuit, tenue de rigueur. |
| Trajet | Points du passant ou de la voiture sélectionné. N'apparaît qu'avec un tel élément sélectionné. |
| Pose | Grille, aide, outil en cours, palette des éléments. |

### 2. Créer la mission

1. En haut du dock, tapez le nom du dossier : `raid_depot`. Il doit être en minuscules, avec des chiffres et `_`, et commencer par une lettre.
2. Cliquez sur **Nouvelle mission** (ou appuyez sur Entrée).

Le greffon crée deux fichiers et ouvre la scène :

- `scenes/levels/raid_depot/raid_depot.tscn` : terrain d'herbe de 80 × 80 m, de jour, trois opérateurs (Alpha, Bravo, Charlie) au sud, zone d'extraction au nord, caméra ;
- `scenes/levels/raid_depot/mission.tres` : titre « Raid Depot », placée après les missions existantes, objectif « extracted ».

La mission figure déjà dans le choix des missions du jeu.

Si le dossier existe déjà, ou si le nom n'est pas valable, le dock l'indique en orange et ne crée rien.

### 3. Écrire les informations

1. Dans la section **Informations**, cliquez sur **Modifier dans l'inspecteur**. L'inspecteur affiche `mission.tres`.
2. Réglez :
   - **Title** : « Raid sur le dépôt » ;
   - **Description** : le briefing, affiché avant le lancement ;
   - **Camo** : camouflage conseillé (`night` pour une mission de nuit) ;
   - **Order** : rang dans le choix des missions (les missions de série vont de 10 en 10) ;
   - **Map** : laissez vide (ne sert qu'aux cartes UFO:AI).
3. Dans **Objectives**, ajoutez des éléments (« Add Element »), puis choisissez pour chacun un **Id** dans la liste proposée et écrivez son **Text**, la ligne du journal en jeu. Pour l'exemple :
   - `depot` : « Incendier le dépôt de carburant » ;
   - `documents` : « Récupérer les documents de l'officier » ;
   - `extracted` : « Ramener l'équipe à la zone d'extraction » (déjà présent) ;
   - `no_alert` : « Ne pas donner l'alerte » (condition bonus).

Le fichier est enregistré avec la scène (Ctrl+S). Dans le dock, chaque objectif s'affiche :

- ✓ en vert, avec sa cible : un clic la sélectionne ;
- ⚠ en orange : aucune cible sur la carte pour l'instant (normal ici, le dépôt et l'officier ne sont pas encore posés) ;
- • en gris : objectif suivi par le jeu lui-même, sans cible (`no_alert`, `no_operator_lost`).

### 4. Régler la carte

Dans la section **Carte** :

- Cochez **Nuit**. Le ciel, la lumière ambiante et le soleil (devenu lune) passent en réglage de nuit. En jeu, les gardes voient moins loin et les jumelles de vision nocturne sont abaissées d'office.
- **Tenue de rigueur** : « Aucune » ici. Les autres choix (Costume-cravate, Décontractée, Treillis) imposent une tenue à l'équipe, comme à la Réception.

Chaque réglage s'annule par Ctrl+Z.

### 5. Poser le décor

Principe de la pose :

1. Cliquez sur un élément de la palette (section **Pose**). Le bouton reste enfoncé et la ligne d'état indique l'outil et son cap.
2. Visez le sol dans la vue 3D : un cercle vert marque le point visé, une flèche le cap.
3. Clic gauche pour poser. L'outil reste actif : vous pouvez poser plusieurs fois de suite.
4. **R** tourne de 15° dans le sens horaire, **Maj+R** dans l'autre sens. Le cap 0° regarde le nord (vers -Z).
5. **Clic droit** ou **Échap** pour arrêter, ou cliquez à nouveau sur le bouton de l'outil.

Les éléments « tracés » (mur, route, trottoir, piste, ronde, passant, voiture) se posent en **deux clics** : le début, puis la fin. Entre les deux, la vue affiche le tracé et sa longueur.

La case **Grille de 0,5 m** aimante les points posés. Chaque pose est une action annulable (Ctrl+Z) et l'élément posé est sélectionné : ses réglages fins sont dans l'inspecteur.

Pour l'exemple :

1. **Route** : de (-30, 30) à (30, 30), le long du sud de la carte.
2. **Mur (tracé)** : quatre tracés pour une cour d'environ 30 × 20 m au centre. Le greffon pose des murs de 6 m bout à bout. Laissez une ouverture de quelques mètres au sud.
3. **Bâtiment** : un dans la cour, porte vers le sud. Dans l'inspecteur, réglez :
   - `size` : emprise (x, z) ;
   - `wall_height` ;
   - `doors` : une porte par élément (côté, décalage, verrouillée 0 ou 1) ; côtés : 0 vers +Z, 1 vers +X, 2 vers -Z, 3 vers -X ;
   - `windows` : (côté, décalage).
4. **Caisse** et **Muret** : des abris dans la cour.
5. **Haie / buisson** : quelques-uns hors de la cour. Ils cachent les corps.
6. **Lampadaire** : deux ou trois dans la cour, pour l'ambiance de nuit.

Les éléments qui bloquent le passage (murs, caisses, bâtiments) vont sous `NavigationRegion3D`, pour que les unités les contournent. Les revêtements et les buissons vont sous `Decor`, les lampadaires sous `Lamps`. Le greffon s'en charge. Si vous déplacez des nœuds à la main dans l'arbre, gardez ce rangement.

### 6. Placer l'équipe et les ennemis

**Équipe :**

- Les trois opérateurs du gabarit sont sous `Units`. Déplacez-les avec l'outil de déplacement de Godot (W) vers leur point de départ.
- **Opérateur** ajoute le suivant (Delta, puis Echo et Foxtrot ; six au plus).
- Dans l'inspecteur d'un opérateur :
  - `mission_explosives` : charges données d'office (mettez `1` à Alpha pour le dépôt) ;
  - `mission_primary` : arme imposée ;
  - `mission_nvg` : jumelles de vision nocturne ;
  - `mission_clothing` : tenue imposée.

**Ennemis :**

- **Garde posté** : un clic pour le poser, R pour l'orienter. Il garde son poste.
- **Garde en ronde** : deux clics, début et fin de la ronde. Le greffon crée le chemin `PatrolPaths/RouteN` et y attache le garde. Pour une ronde plus riche, sélectionnez le chemin dans l'arbre de scène : la barre d'outils de la vue 3D propose alors les outils de chemin de Godot (ajouter, déplacer, supprimer des points).
- **Pick-up armé** : comme une ronde ; le véhicule suit son chemin.
- Réglages d'un garde dans l'inspecteur :
  - `armed` ;
  - `stationary` ;
  - `blind` : sentinelle aveugle, pour les cibles d'entraînement ;
  - `launcher` et `rockets` : lance-roquettes ;
  - `documents` : porteur des documents.

Le **cône de vue** de chaque garde s'affiche au sol en jaune : la zone proche, plus soutenue, où il voit tout de suite, puis la zone lointaine. Cochez Nuit : la zone lointaine se réduit, comme en jeu. Placez les gardes pour que leurs cônes laissent un passage, sans en laisser un trop facile.

Pour l'exemple : deux gardes postés à l'entrée de la cour, une ronde autour du bâtiment, un garde en ronde le long de la route.

### 7. Poser les objectifs et l'extraction

- **Porteur des documents** : un garde posté qui porte les documents (objectif `documents`). Posez-le dans le bâtiment ou près de lui.
- **Dépôt de carburant** : une cible de sabotage (objectif `depot`) ; **Groupe électrogène** : idem avec `sabotage`. Dans l'inspecteur, `lights` peut désigner un nœud de lampadaires, qui s'éteignent quand la cible saute.
- **Zone d'extraction** : le gabarit en a déjà une. Réglez sa taille (`size`) dans l'inspecteur, ou déplacez-la. Une zone posée par la palette remplit `extracted` : toute l'équipe à l'intérieur. Avec un VIP, mettez `objective_id` à `vip_extracted`.
- **Convertible d'extraction** : remplit `extracted` quand l'équipe est à bord. Il sert aussi à l'insertion. Dans l'inspecteur : `documents_objective` pour rapporter des documents à bord, `livery`, `tail_number`.
- **Sabre** : véhicule de l'équipe. Son cercle orange montre la portée du bruit de son moteur.

Revenez à la section **Informations** : les trois objectifs de l'exemple sont maintenant verts, avec leur cible.

### 8. Ajouter des civils (facultatif)

- **Invité** : civil immobile, qui barre le passage (réception, cocktail).
- **Passant** : deux clics, puis il marche en aller-retour sur ce tracé. La propriété `loop` le fait tourner en boucle.
- **Boucle de voitures** : deux clics, aux coins opposés d'un rectangle de rues. Les voitures tournent dans le sens inverse des aiguilles d'une montre, virages arrondis. Elles servent d'abri et klaxonnent quand on leur barre la route ; le cercle orange montre jusqu'où le klaxon attire les gardes (22 m).

Pour modifier un trajet de passant ou de voiture :

- sélectionnez l'élément : son trajet apparaît en bleu, avec une poignée par point ;
- faites glisser une poignée pour déplacer le point (aimanté à la grille, annulable) ;
- la section **Trajet** du dock ajoute un point (un trajet ouvert est prolongé de 5 m ; dans une boucle, le nouveau point coupe en deux le segment qui la ferme) ou retire le dernier (il en reste au moins deux).

La voiture ou le passant s'affiche au premier point du trajet, d'où il partira.

### 9. Vérifier

Cliquez sur **Vérifier**. Le greffon calcule la navigation de la carte, comme le jeu, puis liste les problèmes :

- ✗ en rouge : **erreur**, la mission ne fonctionnera pas ;
- ⚠ en orange : **avertissement**, à examiner ;
- ✓ en vert : tout va bien (« Aucun problème trouvé », « Chemins à pied… atteignables »).

Un clic sur une ligne sélectionne le nœud en cause. Le détail des contrôles est dans la référence ci-dessous.

Un avertissement « pas de chemin à pied » n'est pas forcément une faute. La vérification ne compte ni les échelles, ni les cordes, ni les portes : une cible sur un toit, à l'étage ou derrière une porte est signalée, alors qu'elle est atteignable en jeu.

### 10. Essayer

Cliquez sur **Essayer**. La scène est enregistrée puis lancée seule, avec ses objectifs, l'équipe et son équipement, comme depuis le choix des missions. Arrêtez le jeu avec le bouton carré en haut à droite de l'éditeur (F8).

Pour jouer la mission depuis le jeu complet, lancez le projet (F5) : « Raid sur le dépôt » est dans le choix des missions, à la place donnée par **Order**.

### 11. Modifier une mission de série

Les missions de série s'ouvrent comme les autres : `scenes/levels/<dossier>/<dossier>.tscn`. Deux cas :

- **Carte écrite à la main ou par le greffon** (Terrain d'essai, Escorte, cartes UFO:AI…) : modifiez-la librement, puis enregistrez.
- **Carte générée** : le dock affiche en orange le générateur qui l'écrit, par exemple `tools/gen_wadi.py`. Une carte modifiée dans l'éditeur ne doit plus être régénérée. Le générateur le sait : il refuse d'écraser une carte modifiée depuis sa génération (ou une carte sans empreinte, comme le Didacticiel, retouché à la main) et l'indique. `MAPKIT_FORCE=1 python3 tools/gen_wadi.py` l'écrase quand même, en perdant les modifications. Une fois une carte reprise dans l'éditeur, elle devient la source : retirez son générateur du dépôt.

Les cartes UFO:AI (Entraînement A et B, Gare du désert) s'affichent dans l'éditeur, mais leurs tuiles sont construites à chaque ouverture. Seuls les éléments ajoutés à la scène sont enregistrés.

Les textures externes s'affichent dans l'éditeur mais ne sont jamais enregistrées dans la scène : le greffon les retire le temps de chaque enregistrement.

## Référence

### Palette

| Catégorie | Élément | Pose | Rangé sous | Remarques |
|---|---|---|---|---|
| Décor | Bâtiment | 1 clic | `NavigationRegion3D` | 8 × 6 m, une porte ; `size`, `doors`, `windows`, `wall_height`, couleurs dans l'inspecteur. |
| | Mur (tracé) | 2 clics | `NavigationRegion3D` | Murs de 6 m bout à bout. |
| | Mur de 6 m, Muret, Caisse, Échelle | 1 clic | `NavigationRegion3D` | |
| | Haie / buisson | 1 clic | `Decor` | Cachette pour les corps ; `kind` : buisson, eau, abri. |
| | Lampadaire | 1 clic | `Lamps` | |
| | Immeuble à étages | 1 clic | `NavigationRegion3D` | 3 étages, 14 × 10 m ; `storeys`, `size`, `doors`, `windows` dans l'inspecteur. |
| | Route, Trottoir, Piste | 2 clics | `Decor` | 9 m, 2,5 m, 4,5 m de large. |
| Obstacles | Mine, Engin improvisé | 1 clic | `NavigationRegion3D` | |
| | Barrière | 1 clic | `NavigationRegion3D` | Cap = sens de la route ; en travers, un muret de chaque côté. |
| Équipe | Opérateur | 1 clic | `Units` | Alpha à Foxtrot, six au plus. |
| | VIP | 1 clic | `Units` | Suit l'équipe ; objectifs `vip_alive`, `vip_extracted`. |
| Ennemis | Garde posté | 1 clic | `Enemies` | |
| | Garde en ronde, Pick-up armé | 2 clics | `Enemies` + `PatrolPaths` | Chemin `RouteN` créé avec lui. |
| | Avion ennemi | 2 clics | `Enemies` + `PatrolPaths` | Survole son chemin à `altitude` m (25 par défaut), montré au premier point. |
| | Renforts | 1 clic | `Enemies` | Point d'arrivée ; cible (`target`) : le dépôt de la carte, sinon la première cible de sabotage. |
| Civils | Invité | 1 clic | `NavigationRegion3D` | |
| | Passant | 2 clics | `Decor` | Aller-retour (`loop` pour une boucle). |
| | Boucle de voitures | 2 clics (coins) | `Decor` | |
| Objectifs | Porteur des documents | 1 clic | `Enemies` | `documents`. |
| | Groupe électrogène | 1 clic | `NavigationRegion3D` | `sabotage`. |
| | Dépôt de carburant | 1 clic | `NavigationRegion3D` | `depot`. |
| Extraction et véhicules | Zone d'extraction | 1 clic | racine | `extracted`. |
| | Convertible d'extraction | 1 clic | `NavigationRegion3D` | `extracted`, insertion. |
| | Sabre | 1 clic | `NavigationRegion3D` | |
| | Aire de poser | 1 clic | `Decor` | Disque de 14 m. |

Pour les éléments absents de la palette (ateliers du didacticiel, cachettes d'eau…), copiez un nœud d'une mission de série (Ctrl+C, Ctrl+V) ou ajoutez-le par « Instancier une scène enfant » ou par un nœud avec le bon script.

### Objectifs et leurs cibles

| Identifiant | Rempli par |
|---|---|
| `extracted` | Zone d'extraction ou convertible avec `objective_id = extracted`. |
| `vip_extracted` | Zone d'extraction avec ce `objective_id`, et un VIP. |
| `vip_alive` | Un VIP sous `Units` (condition : il ne doit pas mourir). |
| `documents` | Un garde avec `documents` coché, ou un convertible avec `documents_objective`. |
| `sabotage`, `depot` | Cible de sabotage avec cet `objective_id`. |
| `aircraft_destroyed` | Convertible ennemi à détruire (`objective_id`). |
| `raid_in_time` | Renforts (`Reinforcements`) avec cet `objective_id`. |
| `sabre_rally`, `sabre_extracted` | Sabre : `arrival_objective`, `stow_objective`. |
| `heli_hover`, `heli_rappel` | Convertible : `hover_objective`, `rappel_objective`. |
| `all_enemies_down` | Les gardes de la carte (tous hors de combat). |
| `no_operator_lost`, `no_alert` | Suivis par le jeu, sans cible. |
| `tuto_*` | Ateliers du didacticiel (`TutorialStation`). |

### Vérification

| Contrôle | Niveau |
|---|---|
| Aucun opérateur sous `Units`, ou plus de six | Erreur |
| Mission sans objectif, objectif sans identifiant ou sans cible sur la carte | Erreur |
| Garde, pick-up ou avion dont le trajet n'existe pas ou a moins de deux points | Erreur |
| Renforts sans cible valable (`target`) | Erreur |
| Pas de `NavigationRegion3D` avec un maillage, ou navigation vide | Erreur |
| Pas de `mission.tres` (mission absente du choix des missions), pas de titre | Avertissement |
| Identifiant d'objectif inconnu du jeu | Avertissement |
| Plus de 40 gardes (la carte ralentit) | Avertissement |
| Cible ou extraction sans chemin à pied depuis le premier opérateur | Avertissement |

### Raccourcis

| Action | Touche |
|---|---|
| Tourner de 15° (sens horaire / inverse) | R / Maj+R |
| Arrêter la pose | Échap ou clic droit |
| Annuler, rétablir | Ctrl+Z, Ctrl+Maj+Z |
| Enregistrer la scène (et `mission.tres`) | Ctrl+S |
| Lancer la scène ouverte / arrêter le jeu | F6 / F8 |

Les raccourcis du greffon se changent dans Éditeur > Paramètres de l'éditeur > Raccourcis, rubrique « mission_editor ». Ce sont des raccourcis de l'éditeur : la règle de l'InputMap ne concerne que le jeu.

### Limites de la première version

- **Sol plat** : la pose vise le plan y = 0. Pour un élément en hauteur (sur un toit), posez-le puis montez-le avec l'outil de déplacement.
- **Bâtiments** : seulement le bâtiment réglable et ce qui existe déjà ; pas de dessin libre de pièces ni d'étages.
- **Événements scriptés** (renforts, pick-ups qui arrivent, ateliers du didacticiel) : ils se modifient dans l'inspecteur, pas par le greffon.
- **Missions des joueurs** : le greffon ne sert que dans l'éditeur, pas dans le jeu exporté.

### Pour vérifier le greffon lui-même

`tools/editor_check/run.sh` ouvre des scènes dans l'éditeur, dans une copie du projet, et les photographie. `tools/editor_check/check_all.sh` les enregistre aussi et les compare aux originales : afficher une mission dans l'éditeur ne doit rien changer à son fichier. Les scénarios `tools/editor_check/step3.gd` à `step5.gd` rejouent la pose, les trajets et la vérification (`CAPTURE_TEST=step4 tools/editor_check/run.sh res://scenes/levels/sandbox/sandbox.tscn`).

## Plan de travail (première version, terminée)

Plan rédigé avant la réalisation, gardé pour mémoire. Les cinq étapes sont faites.

### Choix arrêtés

- **Un greffon dans l'éditeur Godot** (`addons/mission_editor/`), pas un éditeur dans le jeu. Il sert au développement : les joueurs ne créent pas de missions.
- **Première version : étapes 1 à 5** ci-dessous.
- **Les missions de série s'ouvrent aussi dans l'éditeur.**

### 1. Principe

Avec un greffon, une mission reste ce qu'elle est aujourd'hui : une scène `.tscn` dont la racine est un `LevelRoot`. Le greffon édite cette scène directement. Il n'y a ni format JSON, ni reconstruction au chargement, ni conversion des missions de série : elles s'ouvrent comme n'importe quelle scène.

Le greffon apporte ce que l'éditeur Godot ne sait pas faire seul :
- une palette des éléments du jeu, posés d'un clic dans la vue 3D ;
- l'affichage des décors et des unités procédurales ;
- des repères visuels : cônes de vue, trajets des rondes, portée du bruit ;
- un panneau pour les informations de la mission (titre, objectifs…) ;
- une vérification de la carte et un bouton pour l'essayer.

L'annulation et le rétablissement viennent de Godot (`EditorUndoRedoManager`), de même que l'inspecteur pour les réglages fins.

#### Trois obstacles à lever

1. **Les données des missions sont dans le code.** Titre, description, camouflage conseillé et objectifs sont écrits dans `scripts/levels/level_catalog.gd` (24 entrées). Pour que le greffon les modifie, ils doivent devenir une ressource éditable, `MissionInfo` (fichier `.tres`), rangée à côté de la scène. `LevelCatalog` lit ces ressources au lieu de son tableau.
2. **Les décors procéduraux sont invisibles dans l'éditeur.** Les bâtiments, gardes (`SoldierModel`), invités, passants, voitures, Sabre, convertible, etc. sont construits par leur script au lancement. Seuls `ladder.gd` et `low_wall.gd` sont `@tool`. Il faut les rendre `@tool` un par un, en ne gardant dans l'éditeur que la construction du modèle : pas de déplacement, d'IA, de bruit ni de groupes (garde `Engine.is_editor_hint()`).
   - Les cartes UFO:AI (`UfoMapLevel`) sont aussi construites au chargement : il faut un aperçu, construit dans l'éditeur sans être enregistré dans la scène.
   - Les textures externes (`TextureLibrary`) : même chose. C'est le point 101 a) d'`IMPROVEMENTS.md`.
3. **18 cartes sont générées** par `tools/gen_*.py` (`MapBuilder`). Une carte modifiée dans l'éditeur, puis régénérée, perdrait ses modifications. Voir § 6.

### 2. Le greffon

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

### 3. Vérification et essai

- **Bouton « Vérifier »** : il calcule le maillage de navigation dans l'éditeur et contrôle :
  - l'équipe a un point de départ ;
  - chaque objectif a sa cible sur la carte (porteur des documents, groupe électrogène, VIP…) ;
  - les objectifs et la zone d'extraction sont atteignables à pied depuis le départ, comme `build/shots/check_map.sh` ;
  - au-delà d'environ 40 gardes, un avertissement de performance (avec 72 gardes, on est tombé à 10 images/s).

  Chaque problème est listé ; un clic sélectionne le nœud en cause.
- **Bouton « Essayer »** : lance la scène ouverte (`EditorInterface.play_custom_scene`). Vérifié : lancée seule, une scène de niveau monte les objectifs (lus dans `mission.tres`), l'équipe et son équipement comme depuis le menu.
- **Nouvelle mission** : bouton du dock, à partir du gabarit `addons/mission_editor/template.tscn` (écrit par `tools/gen_mission_template.py`).
- **Catalogue** : une mission créée avec le greffon apparaît dans le choix des missions dès que sa `MissionInfo` existe (le catalogue lit les ressources du dossier `scenes/levels`).

### 4. Étapes, chacune avec son commit

1. ✓ **`MissionInfo`** : ressource des informations de mission, migration des 24 entrées de `level_catalog.gd` par un script, `LevelCatalog` qui lit les ressources. Le jeu doit se comporter exactement comme avant.
2. ✓ **Affichage dans l'éditeur** : décors et unités `@tool` (construction seule) ; aperçu des cartes UFO:AI et des textures externes, non enregistré. Vérifié en ouvrant chaque mission de série dans l'éditeur.
3. ✓ **Base du greffon** : dock, palette de décor, pose au clic, grille, rotation, annulation ; réglages de la carte ; avertissement sur les cartes générées et protection contre l'écrasement (§ 6).
4. ✓ **Unités, trajets et mission** : équipe, gardes et rondes, civils, voitures, avec leurs repères visuels et poignées de trajet ; panneau `MissionInfo` avec les objectifs et leurs cibles ; extraction.
5. ✓ **Vérification et essai** : bouton « Vérifier », bouton « Essayer », nouvelle mission visible dans le catalogue.

Après la première version : copier-coller entre missions, dessin des routes au pinceau, partir d'une carte UFO:AI comme fond.

### 5. Hors de la première version

- **Relief** : le sol reste plat.
- **Bâtiments** : seulement les bâtiments réglables qui existent déjà, pas de dessin libre de pièces ni d'étages.
- **Événements scriptés** : renforts déclenchés, pick-ups qui arrivent, ateliers du didacticiel. Les missions de série qui en ont s'ouvrent et se modifient, mais ces scripts ne s'éditent pas dans le greffon.
- **Missions créées par les joueurs** : le greffon ne sert pas dans le jeu exporté.

### 6. Cartes générées

18 cartes de série sont produites par `tools/gen_*.py` (`MapBuilder`). Une carte modifiée dans l'éditeur, puis régénérée, perdrait ses modifications. Règle retenue :

- **Avertissement** : quand la scène ouverte vient d'un générateur, le dock « Mission » l'affiche et nomme le script.
- **Pas d'écrasement** : `MapBuilder` note dans la scène une empreinte de son contenu au moment de la génération. Avant d'écrire, il compare la scène existante à cette empreinte. Si elle a été modifiée depuis, il refuse d'écrire et le signale.
- **Retrait au cas par cas** : une carte reprise dans l'éditeur devient la source ; son générateur est ensuite retiré du dépôt.

Fait à l'étape 3 : la scène porte le nom de son générateur et son empreinte (`metadata/generator`, `metadata/generated_hash` sur la racine). Une scène sans empreinte n'est pas écrasée non plus : c'est le cas du didacticiel, retouché à la main après sa génération. `MAPKIT_FORCE=1` force l'écriture.
