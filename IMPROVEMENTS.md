# Idées d'amélioration

Pistes classées par priorité. Les renvois « § » et « M » pointent vers `CAHIER_DES_CHARGES.md`.

## 1. À faire en premier (fondations)

- **Tests, suite** : GUT est installé avec 63 tests (`./run_tests.sh`). Reste à : accélérer les tests de jeu (environ 3 min aujourd'hui), par exemple en accélérant le temps du moteur ; les lancer automatiquement avant chaque commit (crochet Git) ou en intégration continue ; couvrir ce qui manque encore (HUD et contrôles à la souris, sélection, caméra, transitions de posture debout/accroupi, patrouille et poursuite des ennemis, réveil puis lutte, chargement d'autres cartes UFO:AI) ; tester `SoldierModel.sample_keys` et les poses clés.
- **Rendre le hasard injectable** : parade, esquive, précision des tirs et du lancer utilisent `randf()` directement. Les tests s'en sortent avec `seed()` et des probabilités fixées à 0 ou 1, mais un générateur par unité (ou global, avec graine) rendrait les parties rejouables.
- **Restructurer l'IA ennemie en vraie machine à états** (§5.3). `enemy.gd` mélange détection, patrouille, poursuite, tir, corps à corps (coup, poussée, déséquilibre), saisie et perte de connaissance avec un `enum` et des minuteurs ; il deviendra ingérable avec les états `Investigate`, `Search`, `Return`.
- **Restructurer les actions de `Commando`** : déplacement, attaque, escalade, corps à corps, prise, lancer, recul, défense sont autant de variables et de branches dans `_physics_process`, avec des remises à zéro dispersées (`stop`, `_on_died`, chaque ordre). Une petite file d'actions (une action courante, interruptible ou non) simplifierait l'ajout de nouveaux gestes.
- **Factoriser le code commun à `Commando` et `Enemy`** : déplacement par navigation, évitement, pas de côté, orientation et tir sont dupliqués. Extraire des composants (`MovementComponent`, `WeaponComponent`) comme le prévoit le §3.
- **Préparer la sauvegarde rapide** (M7) : donner dès maintenant à chaque composant un couple `save_state()` / `load_state()`, sinon il faudra tout reprendre plus tard.
- **Mettre à jour le cahier des charges** : l'univers est passé au militaire moderne et la caméra tourne librement, mais les §1 et §4 disent encore le contraire.
- **Créer `CLAUDE.md`** pointant vers le cahier des charges, le chemin de Godot et les commandes de vérification.

## 2. Gameplay d'infiltration

- **Ouïe des ennemis** (§5.2) : tirs, coups, cri d'une victime poignardée de face et couteau raté émettent déjà `noise_emitted`, mais personne n'écoute. Ajouter `HearingComponent`, le bruit de la course, et un état `Investigate` qui envoie l'ennemi voir la source. `Enemy.startle` (couteau raté) est un palliatif à remplacer.
- **Découverte des corps** : un ennemi qui voit un cadavre ou un camarade assommé devrait donner l'alerte ; pouvoir porter et cacher les corps (M5). Sans cela, l'élimination silencieuse n'a aucun risque.
- **Ligoter un ennemi assommé** (§5.4) pour qu'il ne se réveille pas.
- **États `Search` et `Return`** : après avoir perdu sa cible, l'ennemi fouille la zone puis reprend sa ronde avec une vigilance accrue, au lieu de repartir comme si de rien n'était.
- **Alarme générale et renforts** (§5.3) : sirène, points d'apparition de renforts, niveau d'alerte 2 qui ne retombe pas tout seul.
- **Plusieurs ennemis et types** : sentinelle fixe qui balaie du regard, officier, chien. Le sandbox n'a qu'un soldat et une cible d'entraînement, ce qui ne permet pas de tester la coordination (un ennemi qui voit un camarade se faire saisir, plusieurs ennemis au corps à corps).
- **Mouvement de tête des ennemis** : pauses et rotations du regard en patrouille, pour rendre les cônes moins prévisibles.
- **Caisses, suite** : cacher un corps derrière ou dessous, écraser ou coincer un ennemi, faire tomber une caisse d'un rebord, tourner une caisse, caisses trop lourdes pour un seul opérateur (pousser à deux), et réaction des ennemis à un décor qui a bougé.
- **Végétation** (couche 6) : buissons où se cacher, qui masquent partiellement la vue.
- **Ramassage de munitions et de soins** (§5.5) : un opérateur à sec ou blessé le reste jusqu'à la fin.
- **Munitions et rechargement pour les ennemis**, pour créer des fenêtres d'action.
- **Couverture** : réduire la probabilité d'être touché derrière une caisse ou un angle de mur ; aujourd'hui seule la ligne de vue compte.
- **Tirs ratés** : ils n'ont aucun effet. Ils pourraient toucher un obstacle, une autre unité, ou faire du bruit à l'impact.

## 2 bis. Combat rapproché

Idées restantes, classées par ordre de mise en œuvre conseillé. Déjà faits : uppercut et coups de pied, coup de crosse, étranglement et égorgement par derrière, lutte de l'ennemi en alerte, parade, esquive et contre, lancer de couteau.

### Attaque

- **Coup de coude** et **coup de genou** (saisie par la nuque) : variantes à très courte portée.
- **Balayage** : coup de pied bas qui fauche les jambes ; l'ennemi tombe, sonné moins longtemps.
- **Enchaînement direct + crochet** : plus lisible qu'un coup unique.
- **Projection** : saisie et jeté au sol par-dessus la hanche, puis coup au sol.
- **Désarmement** : arracher l'arme d'un ennemi en alerte pris de court ; il devient inoffensif sans être neutralisé.
- **Bouclier humain** : saisir un ennemi par derrière et s'en couvrir ; déplacement lent, tir au pistolet seulement, les autres hésitent à tirer.
- **Pistolet à silencieux** (déjà modélisé sur la cuisse) : plus discret, moins précis, utilisable arme à la bretelle.
- **Lancer de couteau, suite** : récupérer le couteau directement sur le corps (aujourd'hui il tombe à côté), en porter plusieurs selon l'opérateur, ou lancer un objet pour faire diversion (caillou, douille) une fois l'ouïe en place.

### Défense

- **Roulade** : plonger au sol pour sortir d'un cône de vision ou d'une ligne de tir, et finir couché.
- **Garde de l'ennemi** : un ennemi en alerte lève les bras, ce qui impose un contre ou une prise par derrière.
- **Riposte au corps à corps** des ennemis à court de munitions (les ennemis frappent déjà au contact).
- **Parade au choix du joueur** : touche de défense au bon moment au lieu du tirage au sort.
- **Appel à l'aide** : un ennemi saisi mais pas encore neutralisé crie (bruit qui attire les autres ; dépend de l'ouïe des ennemis).
- **Esquive contre les obstacles** : le pas de côté est tiré au hasard à gauche ou à droite, même si un mur ou une caisse est de ce côté ; choisir le côté libre.
- **Corps à corps à plusieurs** : un seul ennemi frappe à la fois et l'opérateur ne se défend que contre lui ; gérer deux assaillants (le second profite de la parade) et les coéquipiers qui viennent aider.

## 3. Contrôles et lisibilité

- **Curseur contextuel** (§5.1) : changer le curseur au survol d'un ennemi (tirer), d'une caisse (grimper) ou d'un endroit inaccessible.
- **Prévisualisation du chemin** (§5.1) : tracer l'itinéraire avant et pendant le déplacement.
- **Cône à la demande** (§5.2) : n'afficher le cône qu'au survol ou avec Maj + clic, et montrer en plus la portée de tir des opérateurs.
- **Pause tactique et ordres simultanés** (§5.1) : aucun des deux n'existe, alors que la planification est un pilier du jeu.
- **Annulation propre pendant l'escalade** : l'opérateur n'accepte aucun ordre pendant 1 à 1,4 s ; mettre l'ordre en file d'attente plutôt que de l'ignorer.
- **Groupes de contrôle** (Ctrl + chiffre) et double appui sur un chiffre pour centrer la caméra.
- **Retour visuel des tirs** : le modèle a désormais recul et flash de bouche ; manquent l'impact sur la cible ou l'obstacle et un marqueur de dégâts.
- **Lignes de vue bloquées** : indiquer pourquoi un opérateur ne tire pas ou ne lance pas (hors de portée, obstacle, à sec, sans couteau).
- **Portée du lancer** : quand T est armé, afficher au sol le cercle de 7 m (et de 4 m, où le lancer porte toujours) autour de l'opérateur concerné, et la trajectoire au survol d'un ennemi.
- **Retour des actions refusées** : un ordre impossible (lancer sans couteau, assommer un ennemi déjà inconscient) ne fait rien ; afficher un court message ou un son.

## 4. Interface

- **Portraits avec image** : rendre le modèle 3D dans un `SubViewport` pour chaque opérateur.
- **Opérateurs, suite** :
  - vrais visages (texture ou modèle) et plus de coupes ;
  - couleurs libres (sélecteur) en plus de la palette ;
  - motifs de camouflage propres à chaque vêtement ;
  - portrait 3D dans le HUD de mission.
- **Équipement, suite** :
  - gestes propres à la pose d'une charge et aux soins (l'opérateur reste simplement accroupi ou debout) ;
  - grenade qui rebondit et roule selon le relief ;
  - ennemis qui entendent les bruits (explosions, équipement d'un opérateur chargé) au lieu d'être seulement rendus méfiants dans un rayon ;
  - munitions de l'arme secondaire visibles en même temps que celles de la principale ;
  - effet visuel de soin.
- **Préparation de mission, suite** : aperçu de la carte, objectifs, et modification complète de la tenue sans passer par l'écran « Opérateurs ».
- **Menu, suite** : confirmation avant d'abandonner une partie, menu pause sur Échap, aperçu de chaque carte, mémoriser la dernière carte jouée, proposer automatiquement les autres cartes UFO:AI du dossier.
- **Écran de fin et redémarrage** : après « ÉCHEC — opérateur tué », la partie continue ; proposer de recommencer.
- **Journal d'objectifs, minimap, menus principal et pause, options** (§6).
- **Traduction** : passer tous les textes par `tr()` (français et anglais, M10).
- **Aide repliable** : les lignes de contrôles en haut de l'écran, de plus en plus longues (V, B, T, G…), devraient se masquer avec une touche.
- **Rendre les touches affichées dynamiques** : les boutons montrent « [C] », « [R] » en dur au lieu de lire l'InputMap.

## 5. Modèle et animation

- **Différencier les trois opérateurs** (§5.4) : silhouettes, équipement et compétences propres (choc, tireur d'élite, sapeur) ; ils sont identiques.
- **Casque et silhouette des ennemis** : les opérateurs ont désormais un casque balistique détaillé ; les ennemis gardent l'ancien modèle générique. Leur donner un équipement propre (casquette, casque plus ancien, gilet différent) pour les reconnaître d'un coup d'œil.
- **Pas pendant les déplacements subis** : recul après une poussée et esquive glissent le corps avec une marche approximative ; ajouter un vrai pas en arrière et un pas chassé.
- **Geste de ramassage** : le couteau de lancer est ramassé sans se baisser.
- **Réaction des ennemis désarmés** : sans arme, un ennemi en alerte garde les bras le long du corps entre deux coups ; lui donner une garde.
- **Passer à des modèles et animations CC0** avec un `AnimationTree` (M10) quand le prototype sera stabilisé. `soldier_model.gd` dépasse 1 500 lignes d'images clés écrites à la main.

## 6. Niveau et technique

- **Maillage de navigation** : il est généré 0,5 m au-dessus du sol et compensé par un réglage sur chaque agent ; trouver la cause (taille des cellules) plutôt que compenser.
- **Îlots de navigation sur les caisses** : le dessus des caisses collées reçoit un bout de maillage inutile ; l'exclure à la génération.
- **Escalade généralisée** : murets, échelles, toits (`NavigationLink3D`), et ennemis capables de grimper ou au moins de tirer sur un opérateur perché sans rester bloqués.
- **Coût du cône de vision** : 49 lancers de rayon par ennemi et par image ; ne le recalculer que si l'ennemi a bougé, ou réduire le nombre de segments à distance de la caméra.
- **Occlusion** (M8) : murs transparents entre la caméra et l'unité sélectionnée ; un opérateur derrière un mur est aujourd'hui invisible.
- **Structure de niveau** (§7) : `LevelRoot` avec `SpawnPoints`, `Objectives`, `CameraBounds`, `ExtractionZone`, et un premier objectif simple pour avoir une boucle de jeu complète.
- **Grandes cartes** : sur `training_b` (100 × 62 m), la navigation met plus d'une seconde à se régénérer après chaque caisse déplacée : générer par tuiles (`NavigationMesh` par zone). La lecture de la carte sur un fil de travail est trois fois plus lente que sur le fil principal (2,2 s contre 0,7 s), à creuser. Charger les modèles 3D des cartes (`misc_model`, `.md2`) pour l'épave de `fighter_crash` et les autres cartes.
- **Murs escaladables, suite** : réaction des sentinelles au bruit de réception d'un saut (signalé, pas encore écouté) ; corniches sur les murs minces ou en biais (aujourd'hui seules les cases entières du dessus comptent) ; vue et tir depuis le haut d'un mur à régler (portée de vision, couverture).
- **Cartes UFO:AI, suite** : caisses restées fixes (piles de deux caisses, caisses à couvercle, caisses blanches surmontées, palettes basses) : escalade à d'autres hauteurs (2,4 m pour une pile, 0,6 m pour une palette, ce qui demande de nouvelles animations), déplacement d'une pile entière ; lumières (`light`) ; portes (`func_door`) et objets destructibles (`func_breakable`) ; étages (masquer les niveaux supérieurs, cf. occlusion M8 ; les toits d'un seul niveau s'effacent déjà) ; toits : effacer aussi les murs qui masquent un opérateur côté caméra, ne pas effacer les surplombs de terrain, n'effacer que la partie d'une dalle qui couvre une tranchée, voir l'intérieur au survol de la souris, repérage plus rapide (2 s sur Entraînement B) ou mis en cache par carte ; remplacer les modèles absents (arbres, mobilier) par des modèles CC0 ; patrouilles pour les sentinelles (aujourd'hui fixes) ; cartes aléatoires assemblées à partir des tuiles et des `.ump` ; menu de choix de la carte ; inclure cartes et textures dans un paquet pour l'export Web.
- **Textures, suite** : aperçu des textures externes dans l'éditeur (greffon qui les applique à l'ouverture d'une scène sans les enregistrer dans le `.tscn`) ; écran de chargement et chargement en arrière-plan quand les niveaux grossiront ; compression pour la carte graphique (`Image.compress`) ou cache des textures préparées si le chargement devient lent ; remplacer les textures UFO:AI (licences mélangées, voir `assets/TEXTURES.md`) par des textures CC0 (M10) ; ajouter cartes normales et de rugosité ; casser la répétition de l'herbe (mélange de deux textures, taches de terre) ; texturer les uniformes et l'équipement ; bords du chemin moins nets (décalques ou mélange dans le shader du sol).
- **Son, suite** (§9) : remplacer les sons synthétisés par de vrais sons CC0 (M10) ; musique dynamique selon le niveau d'alerte (bus « Musique » prêt) ; répliques des opérateurs à la sélection et aux ordres (bus « Voix ») ; réglages de volume par bus dans les options ; sons d'ambiance ; sous-titres des sons importants pour l'accessibilité (le signal `Sfx.played` existe).
