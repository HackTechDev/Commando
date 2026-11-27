# Idées d'amélioration

Pistes classées par priorité. Chaque point a un numéro (section.point, puis une lettre pour les sous-points) pour qu'on puisse y renvoyer. Les points faits sont retirés (voir `CHANGELOG.md`) ; les autres gardent leur numéro. Les renvois « § » et « M » pointent vers `CAHIER_DES_CHARGES.md`.

## 1. À faire en premier (fondations)

- **1.1 Tests, suite** : GUT est installé avec 106 tests (`./run_tests.sh`). Reste à :
  - **a)** accélérer les tests de jeu (environ 5 min aujourd'hui), par exemple en accélérant le temps du moteur ;
  - **b)** les lancer automatiquement avant chaque commit (crochet Git) ou en intégration continue ;
  - **c)** couvrir ce qui manque encore : HUD et contrôles à la souris, sélection, caméra, transitions de posture debout/accroupi, patrouille et poursuite des ennemis, réveil puis lutte, chargement d'autres cartes UFO:AI ;
  - **d)** tester `SoldierModel.sample_keys` et les poses clés.
- **1.5 Factoriser le code commun à `Commando` et `Enemy`** : déplacement par navigation, évitement, pas de côté, orientation et tir sont dupliqués. Extraire des composants (`MovementComponent`, `WeaponComponent`), comme le prévoit le §3.

## 2. Gameplay d'infiltration

- **2.5 Alarme générale et renforts** (§5.3) : sirène, points d'apparition de renforts, niveau d'alerte 2 qui ne retombe pas tout seul.
- **2.9 Végétation** (couche 6) : buissons où se cacher, qui masquent partiellement la vue.
- **2.16 Véhicules terrestres** (en plus du convertiroptère, de la voiture civile, du Sabre et du pick-up armé) :
  - **a)** camion bâché : ronde avec haltes ; on monte dans la benne pour voyager caché ; il amène des renforts qui en descendent à l'alerte (lié au 2.5) ;
  - **b)** moto avec side-car : rapide et bruyante, deux opérateurs, le passager tire en roulant ;
  - **c)** blindé léger : les balles ne le traversent pas ; on l'arrête d'une charge posée dessus ou d'une roquette ; projecteur qui balaie le terrain la nuit ;
  - **d)** jeep d'officier : traverse la carte ; une embuscade fait de l'officier et de ses documents un objectif ;
  - **e)** chariot élévateur ou engin de chantier : soulève les caisses lourdes (2.8 e) et ouvre un passage ;
  - **f)** ambulance ou camion de pompiers : véhicule civil, sortie discrète d'une évasion avec la bonne tenue ;
  - **g)** bateau pneumatique : infiltration par l'eau (carte côtière ou rivière) ; moteur audible, pagaies silencieuses ;
  - **h)** centre de commandement mobile (`CommandCenter`), suite : aujourd'hui décor fixe en deux versions. Le déployer ou le replier en cours de mission (flancs, vérins), le faire rouler replié, et lui donner de vraies lumières pour les cartes de nuit.
- **2.17 Véhicules aériens** :
  - **a)** hélicoptère de patrouille ennemi : survol et vol stationnaire, cône de projecteur au sol la nuit, appelé par une alerte ;
  - **b)** drone de surveillance : ronde aérienne, vue de dessus que les toits n'arrêtent pas ; abattu au silencieux ou brouillé ;
  - **c)** avion de transport au sol (base aérienne) : cachette dans la soute, sabotage, ou moyen d'extraction ;
  - **d)** parachutage d'ouverture : zone d'atterrissage choisie en début de mission, dispersion selon le vent (`LevelRoot.wind`) ;
  - **e)** ballon captif d'observation : poste de guet très haut, qu'on fait tomber en coupant son câble.
- **2.22 Leurres à retardement** : réveil ou radio qui sonne au bout de quelques secondes, pour attirer un garde hors de son poste (en plus des appâts).
- **2.24 Progression des opérateurs** : l'expérience des missions (discrétion, tir, soins) améliore un peu leurs réglages.

## 4. Contrôles et lisibilité

- **4.2 Prévisualisation du chemin** (§5.1) : tracer l'itinéraire avant et pendant le déplacement.
- **4.3 Cône à la demande** (§5.2) : n'afficher le cône qu'au survol ou avec Maj + clic, et montrer aussi la portée de tir des opérateurs.
- **4.5 Annulation propre pendant l'escalade** : l'opérateur n'accepte aucun ordre pendant 1 à 1,4 s. Il faudrait mettre l'ordre en file d'attente plutôt que de l'ignorer.
- **4.6 Groupes de contrôle** : enregistrer une sélection de plusieurs opérateurs sous un chiffre, et la rappeler. Ctrl + chiffre sélectionne déjà un opérateur et centre la caméra sur lui ; reste aussi le double appui sur un chiffre pour centrer la caméra.
- **4.9 Portée des lancers** : quand T ou N est armé, afficher au sol autour de l'opérateur concerné :
  - **a)** pour le couteau, les cercles de 7 m et de 4 m (où le lancer porte toujours), et la trajectoire au survol d'un ennemi ;
  - **b)** pour la grenade, le cercle de 12 m, et la zone de l'explosion au survol du sol.
- **4.10 Retour des actions refusées** : certains ordres impossibles ne font toujours rien (assommer un ennemi déjà inconscient). Afficher un court message, en plus du son de refus déjà joué pour les lancers, les charges et les soins.
- **4.12 Rediffusion** : revoir la mission en accéléré, cônes de vue affichés, pour comprendre où l'on a été repéré.
- **4.13 Ralenti tactique** : temps ralenti (pas en pause) pendant lequel on peut toujours donner des ordres.
- **4.14 Portée du bruit** : avant une action (course, caisse, tir), un cercle au sol montre jusqu'où elle s'entendra.
- **4.15 Roue d'équipement** (`KEYBOARD_ACTION.md`, §2.4) : une touche maintenue affiche autour du curseur tout l'équipement des opérateurs sélectionnés ; on relâche sur l'objet voulu. Le jeu reste en pause tant qu'elle est ouverte. À faire si l'équipement continue de grossir.
- **4.16 Touche contextuelle** (`KEYBOARD_ACTION.md`, §2.5) : une touche « Utiliser » fait l'action logique selon ce qui est sous le curseur (couteau, porter, caisse, échelle, porte, véhicule) ; les touches dédiées restent pour forcer un choix.

## 5. Interface

- **5.3 Équipement, suite** :
  - **a)** gestes propres à la pose d'une charge et aux soins (aujourd'hui, l'opérateur reste simplement accroupi ou debout) ;
  - **b)** grenade qui rebondit et roule selon le relief ;
  - **c)** munitions de l'arme secondaire visibles en même temps que celles de la principale ;
  - **d)** effet visuel de soin ;
  - **e)** obus de 40 mm du M320 : une apparence propre à chaque type en vol (explosif, fumigène, lacrymogène).
- **5.8 Traduction** : passer tous les textes par `tr()` (français et anglais, M10).
- **5.11 Touches du README** : les tableaux de touches du README sont écrits à la main et montrent les touches d'origine. Les générer depuis l'InputMap, comme l'aide en jeu.

## 6. Modèle et animation

- Ne pas implémenter : **6.6 Passer à des modèles et animations CC0** avec un `AnimationTree` (M10), quand le prototype sera stabilisé. `soldier_model.gd` dépasse 2 000 lignes de géométrie et d'images clés écrites à la main.

## 7. Niveau et technique

- **7.1 Maillage de navigation** : il est généré 0,5 m au-dessus du sol, et un réglage sur chaque agent compense ce décalage. Il faudrait trouver la cause (taille des cellules) plutôt que compenser.
- **7.2 Îlots de navigation sur les caisses** : le dessus des caisses collées reçoit un bout de maillage inutile. L'exclure à la génération.
- **7.3 Escalade sur les cartes UFO:AI** : placer échelles (`Ladder`) et murets (`LowWall`) sur ces cartes (ils existent déjà sur les cartes faites main).
- **7.7 Grandes cartes** :
  - **a)** sur `training_b` (100 × 62 m), la navigation met plus d'une seconde à se régénérer après chaque caisse déplacée : la générer par tuiles (un `NavigationMesh` par zone) ;
  - **b)** la lecture de la carte sur un fil de travail est trois fois plus lente que sur le fil principal (2,2 s contre 0,7 s) : à creuser ;
  - **c)** charger les modèles 3D des cartes (`misc_model`, `.md2`) pour l'épave de `fighter_crash` et les autres cartes.
- **7.8 Murs escaladables, suite** :
  - **b)** corniches sur les murs minces ou en biais (aujourd'hui, seules les cases entières du dessus comptent) ;
  - **c)** vue et tir depuis le haut d'un mur à régler (portée de vision, couverture).
- **7.9 Cartes UFO:AI, suite** :
  - **a)** caisses restées fixes : piles de deux caisses, caisses à couvercle, caisses blanches surmontées, palettes basses. Il faut les escalader à d'autres hauteurs (2,4 m pour une pile, 0,6 m pour une palette, avec de nouvelles animations) et pouvoir déplacer une pile entière ;
  - **b)** lumières (`light`) ;
  - **c)** portes (`func_door`) et objets destructibles (`func_breakable`) ;
  - **f)** remplacer les modèles absents (arbres, mobilier) par des modèles CC0 ;
  - **h)** cartes aléatoires assemblées à partir des tuiles et des `.ump`.
- **7.10 Textures, suite** :
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
  - **e)** sons d'ambiance (vent, circulation, oiseaux ; la pluie a déjà le sien, synthétisé) ;
  - **f)** sous-titres des sons importants, pour l'accessibilité (le signal `Sfx.played` existe).
- **7.12 Sauvegarde complète** : plusieurs emplacements avec vignette, en plus de la sauvegarde rapide.
- **7.13 Performances des grandes cartes** : regrouper les tests de vue des gardes (aujourd'hui un par garde et par image) pour tenir une soixantaine de gardes.
- **7.14 Sauvegarde rapide de la lampe** : l'état allumé ou éteint de la lampe du HK45 (`Commando.lamp_on`) n'est pas sauvegardé ; au chargement, elle est toujours éteinte.

## 8. Éditeur de mission

Greffon `addons/mission_editor`, première version décrite dans `MISSION_EDITOR.md`.

- **8.4 Confort d'édition** :
  - **a)** copier-coller entre missions ; rotation et alignement d'un groupe d'éléments ;
  - **b)** routes au pinceau, avec carrefours, et trottoirs posés le long des routes.
- **8.5 Fiabilité et ménage** :
  - **a)** tests GUT du greffon, sans affichage : vérification (`checker.gd`), palette, cibles des objectifs, création d'une mission ; scénarios de `tools/editor_check` dans la routine de vérification.

## 10. Missions et campagne

- **10.1 Campagne** : carte d'opérations où les missions s'enchaînent ; opérateurs perdus pour de bon, matériel récupéré.
- **10.2 Objectifs secondaires et notation** : aucun mort, aucune alerte, temps limite, documents en bonus ; note en fin de mission.
- **10.4 Rondes tirées au hasard** : même carte, gardes et rondes différents à chaque partie (graine de `GameRng`), pour la rejouabilité.
