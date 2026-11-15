# Idées d'amélioration

Pistes classées par priorité. Chaque point a un numéro (section.point, puis une lettre pour les sous-points) pour qu'on puisse y renvoyer. Les points faits sont barrés et gardent leur numéro. Les renvois « § » et « M » pointent vers `CAHIER_DES_CHARGES.md`.

## 1. À faire en premier (fondations)

- **1.1 Tests, suite** : GUT est installé avec 106 tests (`./run_tests.sh`). Reste à :
  - **a)** accélérer les tests de jeu (environ 5 min aujourd'hui), par exemple en accélérant le temps du moteur ;
  - **b)** les lancer automatiquement avant chaque commit (crochet Git) ou en intégration continue ;
  - **c)** couvrir ce qui manque encore : HUD et contrôles à la souris, sélection, caméra, transitions de posture debout/accroupi, patrouille et poursuite des ennemis, réveil puis lutte, chargement d'autres cartes UFO:AI ;
  - **d)** tester `SoldierModel.sample_keys` et les poses clés.
- **1.2 Rendre le hasard injectable** : parade, esquive, précision des tirs et du lancer utilisent `randf()` directement. Les tests s'en sortent avec `seed()` et des probabilités fixées à 0 ou 1, mais un générateur par unité (ou global, avec graine) rendrait les parties rejouables.
- **1.3 Restructurer l'IA ennemie en vraie machine à états** (§5.3). `enemy.gd` mélange avec un `enum` et des minuteurs :
  - la détection, la patrouille et la poursuite ;
  - le tir ;
  - le corps à corps (coup, poussée, déséquilibre) ;
  - la saisie et la perte de connaissance.

  Il deviendra ingérable avec les états `Investigate`, `Search` et `Return`.
- **1.4 ~~Restructurer les actions de `Commando`~~** (fait) : un ordre en cours et un geste en cours (`CommandoAction`, dans `scripts/units/actions/`).
- **1.5 Factoriser le code commun à `Commando` et `Enemy`** : déplacement par navigation, évitement, pas de côté, orientation et tir sont dupliqués. Extraire des composants (`MovementComponent`, `WeaponComponent`), comme le prévoit le §3.
- **1.6 ~~Préparer la sauvegarde rapide~~** (fait) (M7) : donner dès maintenant à chaque composant un couple `save_state()` / `load_state()`, sinon il faudra tout reprendre plus tard.
- **1.7 ~~Mettre à jour le cahier des charges~~** (fait) : univers militaire contemporain (§1), rotation libre de la caméra (§4, §10, §13).
- **1.8 ~~Créer `CLAUDE.md`~~** (fait) : documents de référence, chemin de Godot, commandes de vérification, conventions.

## 2. Gameplay d'infiltration

- **2.1 Ouïe des ennemis** (§5.2) : beaucoup d'actions émettent déjà `noise_emitted`, mais personne n'écoute. C'est le cas des tirs, des coups, du cri d'une victime poignardée de face, du couteau raté, des explosions et de l'équipement d'un opérateur trop chargé qui court.
  - **a)** ajouter un `HearingComponent` et le bruit de la course ;
  - **b)** ajouter un état `Investigate`, qui envoie l'ennemi voir la source ;
  - **c)** remplacer `Enemy.startle` (couteau raté, ennemis épargnés par une explosion), qui n'est qu'un palliatif.
- **2.2 Découverte des corps** : un ennemi qui voit un cadavre ou un camarade assommé devrait donner l'alerte. Il faudrait aussi pouvoir porter et cacher les corps (M5). Sans cela, l'élimination silencieuse ne comporte aucun risque.
- **2.3 Ligoter un ennemi assommé** (§5.4), pour qu'il ne se réveille pas.
- **2.4 États `Search` et `Return`** : après avoir perdu sa cible, l'ennemi repart aujourd'hui comme si de rien n'était. Il devrait fouiller la zone, puis reprendre sa ronde avec une vigilance accrue.
- **2.5 Alarme générale et renforts** (§5.3) : sirène, points d'apparition de renforts, niveau d'alerte 2 qui ne retombe pas tout seul.
- **2.6 Plusieurs ennemis et types** : sentinelle fixe qui balaie du regard, officier, chien. Le sandbox n'a qu'un soldat et une cible d'entraînement. On ne peut donc pas tester la coordination : un ennemi qui voit un camarade se faire saisir, plusieurs ennemis au corps à corps.
- **2.7 Mouvement de tête des ennemis** : pauses et rotations du regard en patrouille, pour rendre les cônes moins prévisibles.
- **2.8 Caisses, suite** :
  - **a)** cacher un corps derrière ou dessous ;
  - **b)** écraser ou coincer un ennemi ;
  - **c)** faire tomber une caisse d'un rebord ;
  - **d)** tourner une caisse ;
  - **e)** caisses trop lourdes pour un seul opérateur (pousser à deux) ;
  - **f)** réaction des ennemis à un décor qui a bougé.
- **2.9 Végétation** (couche 6) : buissons où se cacher, qui masquent partiellement la vue.
- **2.10 Ramassage de munitions, de grenades et de soins** (§5.5) : un opérateur à sec ou blessé le reste jusqu'à la fin, sauf avec une trousse de soins.
- **2.11 Munitions et rechargement pour les ennemis**, pour créer des fenêtres d'action.
- **2.12 Couverture** : réduire la probabilité d'être touché derrière une caisse ou un angle de mur. Aujourd'hui, seule la ligne de vue compte.
- **2.13 Tirs ratés** : ils n'ont aucun effet. Ils pourraient toucher un obstacle ou une autre unité, ou faire du bruit à l'impact.
- **2.14 Explosifs, suite** :
  - **a)** dégâts au décor : caisses et bidons projetés ou détruits, murs fragiles ;
  - **b)** charge à retardement, en plus de la mise à feu à distance ;
  - **c)** grenades fumigènes ou assourdissantes pour l'infiltration.

## 3. Combat rapproché

Idées restantes, classées par ordre de mise en œuvre conseillé. Déjà faits :
- uppercut, coups de pied et coup de crosse ;
- étranglement et égorgement par derrière ;
- lutte de l'ennemi en alerte ;
- parade, esquive et contre ;
- lancer de couteau ;
- arme secondaire.

### Attaque

- **3.1 ~~Coup de coude~~** et **~~coup de genou~~** (saisie par la nuque) (fait) : variantes à très courte portée.
- **3.2 ~~Balayage~~** (fait) : coup de pied bas qui fauche les jambes. L'ennemi tombe et reste sonné moins longtemps.
- **3.3 ~~Enchaînement direct + crochet~~** (fait) : plus lisible qu'un coup unique.
- **3.4 Projection** : saisir l'ennemi, le jeter au sol par-dessus la hanche, puis le frapper au sol.
- **3.5 Désarmement** : arracher l'arme d'un ennemi en alerte pris de court. Il devient inoffensif sans être neutralisé.
- **3.6 Bouclier humain** : saisir un ennemi par derrière et s'en couvrir. L'opérateur se déplace lentement et ne tire qu'à l'arme secondaire ; les autres ennemis hésitent à tirer.
- **3.7 Lancer de couteau, suite** :
  - **a)** récupérer le couteau directement sur le corps (aujourd'hui, il tombe à côté) ;
  - **b)** lancer un objet pour faire diversion (caillou, douille), une fois l'ouïe en place (2.1).

### Défense

- **3.8 Roulade** : plonger au sol pour sortir d'un cône de vision ou d'une ligne de tir, et finir couché.
- **3.9 ~~Garde de l'ennemi~~** (fait) : un ennemi en alerte lève les bras, ce qui impose un contre ou une prise par derrière.
- **3.10 ~~Riposte au corps à corps~~** (fait) des ennemis à court de munitions (les ennemis frappent déjà au contact).
- **3.11 ~~Parade au choix du joueur~~** (fait) : une touche de défense, à presser au bon moment, au lieu du tirage au sort.
- **3.12 Appel à l'aide** : un ennemi saisi mais pas encore neutralisé crie, et ce bruit attire les autres. Dépend de l'ouïe des ennemis (2.1).
- **3.13 ~~Esquive contre les obstacles~~** (fait) : le pas de côté est tiré au hasard à gauche ou à droite, même si un mur ou une caisse se trouve de ce côté. Il faudrait choisir le côté libre.
- **3.14 Corps à corps à plusieurs** : aujourd'hui, un seul ennemi frappe à la fois et l'opérateur ne se défend que contre lui. Il faudrait gérer deux assaillants (le second profite de la parade) et les coéquipiers qui viennent aider.

## 4. Contrôles et lisibilité

- **4.1 ~~Curseur contextuel~~** (fait) : viseur sur un ennemi, flèche d'escalade sur une caisse ou une corniche, ordres sur le VIP, cible de l'action armée (couteau, lancer, grenade, caisse), sens interdit sur un endroit inaccessible.
- **4.2 Prévisualisation du chemin** (§5.1) : tracer l'itinéraire avant et pendant le déplacement.
- **4.3 Cône à la demande** (§5.2) : n'afficher le cône qu'au survol ou avec Maj + clic, et montrer aussi la portée de tir des opérateurs.
- **4.4 ~~Pause tactique et ordres simultanés~~** (fait) : Espace met le jeu en pause sans bloquer les ordres ; Tab prépare un ordre par unité (affiché à l'écran), Entrée les lance ensemble.
- **4.5 Annulation propre pendant l'escalade** : l'opérateur n'accepte aucun ordre pendant 1 à 1,4 s. Il faudrait mettre l'ordre en file d'attente plutôt que de l'ignorer.
- **4.6 Groupes de contrôle** (Ctrl + chiffre), et double appui sur un chiffre pour centrer la caméra.
- **4.7 ~~Retour visuel des tirs~~** (fait) : impact des balles manquées sur le premier obstacle (gerbe de poussière), gerbe rouge et chiffre de dégâts sur la cible touchée, étincelles sur un bouclier.
- **4.8 ~~Lignes de vue bloquées~~** (fait) : indiquer pourquoi un opérateur ne tire pas ou ne lance pas (hors de portée, obstacle, à sec, sans couteau).
- **4.9 Portée des lancers** : quand T ou N est armé, afficher au sol autour de l'opérateur concerné :
  - **a)** pour le couteau, les cercles de 7 m et de 4 m (où le lancer porte toujours), et la trajectoire au survol d'un ennemi ;
  - **b)** pour la grenade, le cercle de 12 m, et la zone de l'explosion au survol du sol.
- **4.10 Retour des actions refusées** : certains ordres impossibles ne font toujours rien (assommer un ennemi déjà inconscient). Afficher un court message, en plus du son de refus déjà joué pour les lancers, les charges et les soins.

## 5. Interface

- **5.1 Portrait 3D dans le HUD de mission** : l'écran « Opérateurs » montre déjà le visage en 3D de chaque opérateur, mais les portraits du HUD n'ont que du texte.
- **5.2 Opérateurs, suite** :
  - **a)** plus de traits de visage au choix (nez, mâchoire, yeux), plus de coupes, cicatrices et peintures de camouflage ;
  - **b)** couleurs libres (sélecteur) en plus de la palette ;
  - **c)** motifs de camouflage propres à chaque vêtement.
- **5.3 Équipement, suite** :
  - **a)** gestes propres à la pose d'une charge et aux soins (aujourd'hui, l'opérateur reste simplement accroupi ou debout) ;
  - **b)** grenade qui rebondit et roule selon le relief ;
  - **c)** munitions de l'arme secondaire visibles en même temps que celles de la principale ;
  - **d)** effet visuel de soin.
- **5.4 ~~Préparation de mission, suite~~** (fait) : aperçu de la carte, objectifs, et modification complète de la tenue sans passer par l'écran « Opérateurs ».
- **5.5 ~~Menu, suite~~** (fait) :
  - **a)** ~~menu pause sur Échap~~ ;
  - **b)** ~~aperçu de chaque carte~~ (vue du dessus enregistrée à la première partie) ;
  - **c)** ~~mémoriser la dernière carte jouée~~ ;
  - **d)** ~~proposer automatiquement les autres cartes UFO:AI du dossier~~.
- **5.6 ~~Écran de fin et redémarrage~~** (fait) : après « ÉCHEC — opérateur tué », la partie continue. Proposer de recommencer.
- **5.7 ~~Journal d'objectifs, minimap, menu pause, options~~** (fait) (§6).
- **5.8 Traduction** : passer tous les textes par `tr()` (français et anglais, M10).
- **5.9 ~~Aide repliable~~** (fait : page d'aide sur H) : les lignes de contrôles en haut de l'écran sont de plus en plus longues (V, B, T, N, K…) et devraient se masquer avec une touche.
- **5.10 Rendre les touches affichées dynamiques** : les boutons affichent « [C] » ou « [R] » en dur au lieu de lire l'InputMap.

## 6. Modèle et animation

- **6.1 ~~Corps, suite~~** (fait) :
  - **a)** ~~doigts articulés autour des armes et des objets~~ (fait) ;
  - **b)** ~~clignement des yeux et regard qui suit la cible~~ (fait) ;
  - **c)** ~~expressions (effort, douleur)~~ (fait) ;
  - **d)** ~~plis et coutures sur les vêtements (texture)~~ (fait) ;
  - **e)** ~~silhouette propre à chaque spécialité~~ (fait).
- **6.2 ~~Silhouette des ennemis~~** (fait) : casque ancien, casquette ou béret, visage découvert et varié, gilet à chargeurs, fusil d'assaut à crosse en bois.
- **6.3 ~~Pas pendant les déplacements subis~~** (fait) : marche à reculons, pas chassés sur le côté, pas en arrière quand il vacille.
- **6.4 ~~Geste de ramassage~~** (fait).
- **6.5 ~~Réaction des ennemis désarmés~~** (fait) : garde de boxe en alerte.
- Ne pas implémenter : **6.6 Passer à des modèles et animations CC0** avec un `AnimationTree` (M10), quand le prototype sera stabilisé. `soldier_model.gd` dépasse 2 000 lignes de géométrie et d'images clés écrites à la main.

## 7. Niveau et technique

- **7.1 Maillage de navigation** : il est généré 0,5 m au-dessus du sol, et un réglage sur chaque agent compense ce décalage. Il faudrait trouver la cause (taille des cellules) plutôt que compenser.
- **7.2 Îlots de navigation sur les caisses** : le dessus des caisses collées reçoit un bout de maillage inutile. L'exclure à la génération.
- **7.3 ~~Escalade généralisée~~** (fait) : échelles (`Ladder`) jusqu'aux toits plats, murets à enjamber (`LowWall`), par des liens de navigation (`TraversalLink`) qu'empruntent aussi les ennemis et le VIP. Un ennemi armé tire d'en bas sur un opérateur perché. Reste : placer échelles et murets sur les cartes UFO:AI.
- **7.4 ~~Coût du cône de vision~~** (fait) : recalculé seulement si l'ennemi bouge ou tourne, si un obstacle est déplacé, ou une fois par seconde ; pas hors de l'écran ; moins de segments caméra très dézoomée.
- **7.5 Occlusion** (M8) : rendre transparents les murs entre la caméra et l'unité sélectionnée. Aujourd'hui, un opérateur derrière un mur est invisible.
- **7.6 Structure de niveau** (§7) : `LevelRoot` avec `SpawnPoints`, `Objectives`, `CameraBounds` et `ExtractionZone`, et un premier objectif simple pour avoir une boucle de jeu complète.
- **7.7 Grandes cartes** :
  - **a)** sur `training_b` (100 × 62 m), la navigation met plus d'une seconde à se régénérer après chaque caisse déplacée : la générer par tuiles (un `NavigationMesh` par zone) ;
  - **b)** la lecture de la carte sur un fil de travail est trois fois plus lente que sur le fil principal (2,2 s contre 0,7 s) : à creuser ;
  - **c)** charger les modèles 3D des cartes (`misc_model`, `.md2`) pour l'épave de `fighter_crash` et les autres cartes.
- **7.8 Murs escaladables, suite** :
  - **a)** réaction des sentinelles au bruit de réception d'un saut (signalé, pas encore écouté) ;
  - **b)** corniches sur les murs minces ou en biais (aujourd'hui, seules les cases entières du dessus comptent) ;
  - **c)** vue et tir depuis le haut d'un mur à régler (portée de vision, couverture).
- **7.9 Cartes UFO:AI, suite** :
  - **a)** caisses restées fixes : piles de deux caisses, caisses à couvercle, caisses blanches surmontées, palettes basses. Il faut les escalader à d'autres hauteurs (2,4 m pour une pile, 0,6 m pour une palette, avec de nouvelles animations) et pouvoir déplacer une pile entière ;
  - **b)** lumières (`light`) ;
  - **c)** portes (`func_door`) et objets destructibles (`func_breakable`) ;
  - **d)** ~~étages : masquer les niveaux supérieurs (cf. l'occlusion, 7.5). Les toits d'un seul niveau s'effacent déjà~~ (fait) ;
  - **e)** ~~toits, suite~~ (fait) :
    - ~~effacer aussi les murs qui masquent un opérateur côté caméra~~ ;
    - ~~ne pas effacer les surplombs de terrain~~ (seule la bande au-dessus du passage s'efface) ;
    - ~~n'effacer que la partie d'une dalle qui couvre une tranchée~~ ;
    - ~~voir l'intérieur au survol de la souris~~ ;
    - ~~accélérer le repérage (2 s sur Entraînement B) ou le mettre en cache par carte~~ ;
  - **f)** remplacer les modèles absents (arbres, mobilier) par des modèles CC0 ;
  - **g)** patrouilles pour les sentinelles, aujourd'hui fixes ;
  - **h)** cartes aléatoires assemblées à partir des tuiles et des `.ump` ;
  - **i)** inclure cartes et textures dans un paquet pour l'export Web.
- **7.10 Textures, suite** :
  - **a)** aperçu des textures externes dans l'éditeur : un greffon qui les applique à l'ouverture d'une scène, sans les enregistrer dans le `.tscn` ;
  - **b)** si le chargement devient lent : compression pour la carte graphique (`Image.compress`), ou cache des textures préparées ;
  - **c)** remplacer les textures UFO:AI, aux licences mélangées (voir `assets/TEXTURES.md`), par des textures CC0 (M10) ;
  - **d)** ajouter des cartes normales et de rugosité ;
  - **e)** casser la répétition de l'herbe (mélange de deux textures, taches de terre) ;
  - **f)** texturer les uniformes et l'équipement ;
  - **g)** rendre les bords du chemin moins nets (décalques, ou mélange dans le shader du sol).
- **7.11 Son, suite** (§9) :
  - **a)** remplacer les sons synthétisés par de vrais sons CC0 (M10) ;
  - **b)** musique dynamique selon le niveau d'alerte (le bus « Musique » est prêt) ;
  - **c)** répliques des opérateurs à la sélection et aux ordres (bus « Voix ») ;
  - **d)** réglage du volume par bus dans les options ;
  - **e)** sons d'ambiance ;
  - **f)** sous-titres des sons importants, pour l'accessibilité (le signal `Sfx.played` existe).
