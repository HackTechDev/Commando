# Idées d'amélioration

Pistes classées par priorité. Chaque point a un numéro (section.point, puis une lettre pour les sous-points) pour qu'on puisse y renvoyer. Les points faits sont retirés (voir `CHANGELOG.md`) ; les autres gardent leur numéro. Les renvois « § » et « M » pointent vers `CAHIER_DES_CHARGES.md`.

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
- **1.5 Factoriser le code commun à `Commando` et `Enemy`** : déplacement par navigation, évitement, pas de côté, orientation et tir sont dupliqués. Extraire des composants (`MovementComponent`, `WeaponComponent`), comme le prévoit le §3.

## 2. Gameplay d'infiltration

- **2.1 Ouïe des ennemis** (§5.2) : beaucoup d'actions émettent déjà `noise_emitted`, mais personne n'écoute. C'est le cas des tirs, des coups, du cri d'une victime poignardée de face, du couteau raté, des explosions et de l'équipement d'un opérateur trop chargé qui court. *Amorcé avec 3.12 : `Enemy._on_noise` écoute le bus, mais ne réagit qu'à l'appel à l'aide (`&"help"`) et au caillou de diversion (`&"distraction"`, 3.7 b) ; les autres bruits restent à brancher.*
  - **a)** ajouter un `HearingComponent` et le bruit de la course ;
  - **b)** ajouter un état `Investigate`, qui envoie l'ennemi voir la source ;
  - **c)** remplacer `Enemy.startle` (couteau raté, ennemis épargnés par une explosion), qui n'est qu'un palliatif.
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
- **2.13 Tirs ratés** : une balle manquée s'arrête déjà sur le premier obstacle (gerbe de poussière). Reste à lui faire toucher une autre unité sur sa trajectoire, et faire du bruit à l'impact.
- **2.14 Explosifs, suite** :
  - **b)** charge à retardement, en plus de la mise à feu à distance ;
  - **c)** grenades assourdissantes pour l'infiltration (les fumigènes existent) ;
  - **d)** fumée qui dérive avec le vent, et qui gêne aussi la visée des opérateurs.

## 4. Contrôles et lisibilité

- **4.2 Prévisualisation du chemin** (§5.1) : tracer l'itinéraire avant et pendant le déplacement.
- **4.3 Cône à la demande** (§5.2) : n'afficher le cône qu'au survol ou avec Maj + clic, et montrer aussi la portée de tir des opérateurs.
- **4.5 Annulation propre pendant l'escalade** : l'opérateur n'accepte aucun ordre pendant 1 à 1,4 s. Il faudrait mettre l'ordre en file d'attente plutôt que de l'ignorer.
- **4.6 Groupes de contrôle** (Ctrl + chiffre), et double appui sur un chiffre pour centrer la caméra.
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
- **5.8 Traduction** : passer tous les textes par `tr()` (français et anglais, M10).
- **5.10 Rendre les touches affichées dynamiques** : les boutons affichent « [C] » ou « [R] » en dur au lieu de lire l'InputMap.

## 6. Modèle et animation

- Ne pas implémenter : **6.6 Passer à des modèles et animations CC0** avec un `AnimationTree` (M10), quand le prototype sera stabilisé. `soldier_model.gd` dépasse 2 000 lignes de géométrie et d'images clés écrites à la main.

## 7. Niveau et technique

- **7.1 Maillage de navigation** : il est généré 0,5 m au-dessus du sol, et un réglage sur chaque agent compense ce décalage. Il faudrait trouver la cause (taille des cellules) plutôt que compenser.
- **7.2 Îlots de navigation sur les caisses** : le dessus des caisses collées reçoit un bout de maillage inutile. L'exclure à la génération.
- **7.3 Escalade sur les cartes UFO:AI** : placer échelles (`Ladder`) et murets (`LowWall`) sur ces cartes (ils existent déjà sur les cartes faites main).
- **7.5 Occlusion** (M8) : le décor des cartes UFO:AI s'efface déjà entre la caméra et les opérateurs. Reste à faire de même pour les murs et bâtiments des cartes faites main (un opérateur derrière l'un d'eux est invisible, sauf à l'intérieur d'un `Building`).
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
  - **f)** remplacer les modèles absents (arbres, mobilier) par des modèles CC0 ;
  - **h)** cartes aléatoires assemblées à partir des tuiles et des `.ump`.
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
  - **e)** sons d'ambiance ;
  - **f)** sous-titres des sons importants, pour l'accessibilité (le signal `Sfx.played` existe).

## 9. Sabre

Idées pour le véhicule léger des forces spéciales (`Sabre`, carte « Patrouille Sabre »). Priorité suggérée : 9.2, 9.8, 9.9 et 9.15, qui rééquilibrent la 12,7 (aujourd'hui elle balaie le poste de contrôle sans risque).

Tactique et discrétion :


Armement :


Dégâts et logistique :


Cartes et missions :

- **9.12 Convoi de nuit** : rejoindre en Sabre le convertible d'extraction, puis embarquer (les deux véhicules dans une même mission).
- **9.13 Barrage routier** : un poste avec une barrière, à forcer à faible vitesse (bruit, dégâts) ou à ouvrir discrètement à pied.
- **9.14 Mines et IED** sur la piste : un opérateur à pied devant le véhicule les détecte ; sinon le véhicule saute.
- **9.15 Pick-ups ennemis (technicals)** : ils patrouillent la piste et prennent le Sabre en chasse s'ils l'entendent ; une vraie cible pour la 12,7 et le missile.
- **9.16 Raid éclair** : objectif chronométré (détruire un dépôt et repartir avant l'arrivée des renforts).

Commandes et confort :

- **9.19 Caméra qui suit** le véhicule pendant le trajet (option).
