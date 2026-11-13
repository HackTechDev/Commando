# Idées d'amélioration

Pistes classées par priorité. Les renvois « § » et « M » pointent vers `CAHIER_DES_CHARGES.md`.

## 1. À faire en premier (fondations)

- **Installer un framework de tests** (GUT ou gdUnit4, M0). Aucun test unitaire n'existe : toutes les vérifications ont été faites avec des scripts jetables. Premières cibles : `VisionComponent.zone_for`, `HealthComponent`, munitions et rechargement, `SoldierModel.sample_keys`, `Climbable.get_access_points`.
- **Restructurer l'IA ennemie en vraie machine à états** (§5.3). `enemy.gd` mélange détection, patrouille, poursuite et tir dans un seul script avec un `enum` ; il deviendra ingérable avec les états `Investigate`, `Search`, `Return`, `Stunned`.
- **Factoriser le code commun à `Commando` et `Enemy`** : déplacement par navigation, évitement, pas de côté, orientation et tir sont dupliqués. Extraire des composants (`MovementComponent`, `WeaponComponent`) comme le prévoit le §3.
- **Préparer la sauvegarde rapide** (M7) : donner dès maintenant à chaque composant un couple `save_state()` / `load_state()`, sinon il faudra tout reprendre plus tard.
- **Mettre à jour le cahier des charges** : l'univers est passé au militaire moderne et la caméra tourne librement, mais les §1 et §4 disent encore le contraire.
- **Créer `CLAUDE.md`** pointant vers le cahier des charges, le chemin de Godot et les commandes de vérification.

## 2. Gameplay d'infiltration

- **Ouïe des ennemis** (§5.2) : les tirs émettent déjà `noise_emitted`, mais personne n'écoute. Ajouter `HearingComponent`, le bruit de la course, et un état `Investigate` qui envoie l'ennemi voir la source.
- **Découverte des corps** : un ennemi qui voit un cadavre ou un camarade assommé devrait donner l'alerte ; pouvoir porter et cacher les corps (M5). Sans cela, l'élimination silencieuse n'a aucun risque.
- **Ligoter un ennemi assommé** (§5.4) pour qu'il ne se réveille pas.
- **États `Search` et `Return`** : après avoir perdu sa cible, l'ennemi fouille la zone puis reprend sa ronde avec une vigilance accrue, au lieu de repartir comme si de rien n'était.
- **Alarme générale et renforts** (§5.3) : sirène, points d'apparition de renforts, niveau d'alerte 2 qui ne retombe pas tout seul.
- **Plusieurs ennemis et types** : sentinelle fixe qui balaie du regard, officier, chien. Le sandbox n'a qu'un seul soldat.
- **Mouvement de tête des ennemis** : pauses et rotations du regard en patrouille, pour rendre les cônes moins prévisibles.
- **Végétation** (couche 6) : buissons où se cacher, qui masquent partiellement la vue.
- **Ramassage de munitions et de soins** (§5.5) : un opérateur à sec ou blessé le reste jusqu'à la fin.
- **Munitions et rechargement pour les ennemis**, pour créer des fenêtres d'action.
- **Couverture** : réduire la probabilité d'être touché derrière une caisse ou un angle de mur ; aujourd'hui seule la ligne de vue compte.
- **Tirs ratés** : ils n'ont aucun effet. Ils pourraient toucher un obstacle, une autre unité, ou faire du bruit à l'impact.

## 2 bis. Combat rapproché

Idées restantes, classées par ordre de mise en œuvre conseillé (crosse, prises par derrière, lutte, parade et contre sont faits).

### Attaque

- **Coup de coude** et **coup de genou** (saisie par la nuque) : variantes à très courte portée.
- **Balayage** : coup de pied bas qui fauche les jambes ; l'ennemi tombe, sonné moins longtemps.
- **Enchaînement direct + crochet** : plus lisible qu'un coup unique.
- **Projection** : saisie et jeté au sol par-dessus la hanche, puis coup au sol.
- **Désarmement** : arracher l'arme d'un ennemi en alerte pris de court ; il devient inoffensif sans être neutralisé.
- **Bouclier humain** : saisir un ennemi par derrière et s'en couvrir ; déplacement lent, tir au pistolet seulement, les autres hésitent à tirer.
- **Pistolet à silencieux** (déjà modélisé sur la cuisse) : plus discret, moins précis, utilisable arme à la bretelle.

### Défense

- **Roulade** : plonger au sol pour sortir d'un cône de vision ou d'une ligne de tir, et finir couché.
- **Garde de l'ennemi** : un ennemi en alerte lève les bras, ce qui impose un contre ou une prise par derrière.
- **Riposte au corps à corps** des ennemis à court de munitions (les ennemis frappent déjà au contact).
- **Parade au choix du joueur** : touche de défense au bon moment au lieu du tirage au sort.
- **Appel à l'aide** : un ennemi saisi mais pas encore neutralisé crie (bruit qui attire les autres ; dépend de l'ouïe des ennemis).

## 3. Contrôles et lisibilité

- **Curseur contextuel** (§5.1) : changer le curseur au survol d'un ennemi (tirer), d'une caisse (grimper) ou d'un endroit inaccessible.
- **Prévisualisation du chemin** (§5.1) : tracer l'itinéraire avant et pendant le déplacement.
- **Cône à la demande** (§5.2) : n'afficher le cône qu'au survol ou avec Maj + clic, et montrer en plus la portée de tir des opérateurs.
- **Pause tactique et ordres simultanés** (§5.1) : aucun des deux n'existe, alors que la planification est un pilier du jeu.
- **Annulation propre pendant l'escalade** : l'opérateur n'accepte aucun ordre pendant 1 à 1,4 s ; mettre l'ordre en file d'attente plutôt que de l'ignorer.
- **Groupes de contrôle** (Ctrl + chiffre) et double appui sur un chiffre pour centrer la caméra.
- **Retour visuel des tirs** : le modèle a désormais recul et flash de bouche ; manquent l'impact sur la cible ou l'obstacle et un marqueur de dégâts.
- **Lignes de vue bloquées** : indiquer pourquoi un opérateur ne tire pas (hors de portée, obstacle, à sec).

## 4. Interface

- **Portraits avec image** : rendre le modèle 3D dans un `SubViewport` pour chaque opérateur.
- **Écran de fin et redémarrage** : après « ÉCHEC — opérateur tué », la partie continue ; proposer de recommencer.
- **Journal d'objectifs, minimap, menus principal et pause, options** (§6).
- **Traduction** : passer tous les textes par `tr()` (français et anglais, M10).
- **Aide repliable** : les deux lignes de contrôles en haut de l'écran devraient se masquer avec une touche.
- **Rendre les touches affichées dynamiques** : les boutons montrent « [C] », « [R] » en dur au lieu de lire l'InputMap.

## 5. Modèle et animation

- **Différencier les trois opérateurs** (§5.4) : silhouettes, équipement et compétences propres (choc, tireur d'élite, sapeur) ; ils sont identiques.
- **Passer à des modèles et animations CC0** avec un `AnimationTree` (M10) quand le prototype sera stabilisé.

## 6. Niveau et technique

- **Maillage de navigation** : il est généré 0,5 m au-dessus du sol et compensé par un réglage sur chaque agent ; trouver la cause (taille des cellules) plutôt que compenser.
- **Îlots de navigation sur les caisses** : le dessus des caisses collées reçoit un bout de maillage inutile ; l'exclure à la génération.
- **Escalade généralisée** : murets, échelles, toits (`NavigationLink3D`), et ennemis capables de grimper ou au moins de tirer sur un opérateur perché sans rester bloqués.
- **Coût du cône de vision** : 49 lancers de rayon par ennemi et par image ; ne le recalculer que si l'ennemi a bougé, ou réduire le nombre de segments à distance de la caméra.
- **Occlusion** (M8) : murs transparents entre la caméra et l'unité sélectionnée ; un opérateur derrière un mur est aujourd'hui invisible.
- **Structure de niveau** (§7) : `LevelRoot` avec `SpawnPoints`, `Objectives`, `CameraBounds`, `ExtractionZone`, et un premier objectif simple pour avoir une boucle de jeu complète.
- **Son** (§9) : aucun pour l'instant ; même des bips provisoires pour les tirs, les pas et l'alerte amélioreraient beaucoup la lisibilité.
