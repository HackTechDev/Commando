# Changelog

## Première ébauche (M0 partiel, aperçu de M1 et M2)

- Arborescence du projet, autoloads `EventBus`, `GameState`, `SelectionManager`, InputMap, noms des couches de collision.
- Caméra isométrique orthographique : déplacement, zoom, rotation par pas de 90°, limites.
- Unité `Commando` : sélection (clic, rectangle, touches), déplacement par `NavigationAgent3D`, marche/course, postures debout/accroupi/rampé.
- Modèle 3D procédural d'opérateur des forces spéciales modernes (`SoldierModel`), animé par code.
- Niveau `sandbox` : sol, murs, caisses, navigation générée au chargement, trois opérateurs.

## Ennemi et cône de vision (M3)

- `Enemy` : patrouille en boucle sur les points d'un `Path3D`, avec pause à chaque point.
- `VisionComponent` : cône affiché au sol, occulté par les murs et les caisses, zone proche (détection immédiate) et zone lointaine (cibles debout uniquement).
- Jauge de détection progressive au-dessus de l'ennemi, états `PATROL` / `SUSPICIOUS` / `ALERT`, cône vert / jaune / rouge.
- Indicateur d'alerte global dans le HUD.

## Poursuite et tir en alerte

- En alerte, l'ennemi court vers la cible jusqu'à portée, vise puis tire (traceur, bruit `gunshot`) ; précision décroissante avec la distance et la posture de la cible.
- Cible perdue de vue : il court à sa dernière position connue, y attend, puis reprend sa patrouille.
- `HealthComponent` : points de vie des commandos, affichés dans le HUD ; mort d'un opérateur (corps au sol, retiré de la sélection, message d'échec).

## Tir des opérateurs

- Clic droit sur un ennemi : les unités sélectionnées s'approchent jusqu'à avoir une ligne de tir, puis tirent jusqu'à sa mort.
- Les ennemis ont des points de vie ; un ennemi touché passe en alerte vers le tireur ; mort, il reste au sol et son cône disparaît.

## Munitions limitées

- Chargeur de 10 cartouches et 20 en réserve par opérateur ; rechargement automatique à chargeur vide ou manuel (R), 2 s.
- À sec, l'opérateur cesse d'attaquer et refuse les ordres d'attaque ; le HUD affiche chargeur / réserve.

## Collisions entre unités

- Opérateurs et ennemis se bloquent physiquement et se contournent (évitement de `NavigationAgent3D`).
- Une unité à l'arrêt ne se fait pas pousser ; une destination occupée par une autre unité met fin à l'ordre à proximité.

## Rotation fluide de la caméra

- La caméra tourne en continu tant que A / E est maintenue, avec accélération et arrêt progressifs.

## HUD

- Portraits des opérateurs en bas à gauche : numéro, nom, barre de vie, posture, munitions, surbrillance de sélection ; clic pour sélectionner, double clic pour centrer la caméra.
- Barre d'actions en bas à droite : accroupi, rampé, recharger, stop (nouvelle touche F), avec infobulles.
- Indicateur d'alerte en haut à droite ; thème unique `res://assets/ui/theme.tres`.

## Grimper sur les caisses

- Clic droit sur une caisse : un opérateur sélectionné la rejoint et grimpe dessus ; un ordre au sol le fait redescendre du côté le plus proche de sa destination.
- Une seule unité par caisse ; depuis la caisse, l'opérateur tire par-dessus les obstacles bas et ne redescend que s'il n'a pas de ligne de tir.

## Animation d'escalade

- Montée en plusieurs temps : arme en bandoulière, élan, mains sur le rebord, traction, passage d'une jambe, redressement (1,4 s).
- Descente : accroupi au bord, appui des mains, chute, réception fléchie, redressement (1 s).
- Les bras du modèle sont désormais articulés (épaule et coude) et posés par IK.

## Bouton « Quitter »

- Bouton « Quitter » en haut à droite du HUD, à côté de l'indicateur d'alerte ; il ferme le jeu immédiatement.

## Passage direct entre caisses voisines

- Un opérateur perché qui reçoit l'ordre d'aller sur une caisse collée à la sienne y passe à pied, sans redescendre ; pour une caisse en diagonale, il passe par la caisse intermédiaire.
- Si la caisse visée est occupée, un opérateur déjà perché reste où il est au lieu de redescendre.

## Export Web

- Préréglage d'export « Web » (`export_presets.cfg`), sans threads pour être hébergeable partout ; sortie dans `build/web/`.
- Script `export_web.sh` : export Web automatisé, avec options `--serve` et `--debug`.
- En passant d'une caisse à l'autre, l'opérateur marche réellement (jambes animées), à 60 % de sa vitesse au sol.

## Élimination silencieuse

- Couteau (V) et assommer (B) : l'action s'arme par la touche ou le bouton, puis un clic gauche sur un ennemi la confie à l'opérateur sélectionné le plus proche ; clic droit pour annuler.
- L'opérateur s'approche à la vitesse de sa posture et frappe à 1,3 m : animation de saisie et de frappe, couteau visible dans la main.
- Couteau : mort immédiate, sans alerte. Assommer : l'ennemi tombe 25 s (« z z » au-dessus de lui), ne voit plus rien, ne bloque plus le passage ; à son réveil il donne l'alerte sur place, puis reprend sa ronde.
- Un ennemi assommé peut être achevé au couteau ou par balle.
- Correction : une unité retirée de la scène quitte désormais la sélection.

## Ennemi d'entraînement

- Options `armed` et `stationary` sur les ennemis : sans arme, il ne tire jamais (bras le long du corps) ; immobile, il ne se déplace pas, même en alerte.
- Sandbox : un ennemi sans arme et immobile (`Enemies/TrainingDummy`) à l'ouest du terrain, dos aux opérateurs, pour s'entraîner au couteau.

## Escalade sans traverser la caisse

- Cheville articulée : les pieds restent à plat (IK simple compensant hanche et genou), ce qui évite aussi les pointes de pied enfoncées dans le sol en position accroupie.
- Poses clés de montée et de descente recalculées par optimisation (géométrie de la caisse de 1,2 m) : passage de jambe au-dessus du rebord, appui des mains sur le dessus, descente face au vide (accroupi au bord, saut, réception accroupie).
- Interpénétration mesurée avec la caisse : au pire 2,5 cm à la montée et 3 cm à la descente (contre 49 cm et 17 cm auparavant).

## Postures et animations de combat

- Accroupi : marche accroupie en mouvement, un genou à terre à l'arrêt.
- Rampé : appui sur les coudes, buste relevé, arme pointée vers l'avant ; en reptation, les genoux remontent sur le côté, à plat au sol.
- Visée : l'unité qui attaque épaule son arme (buste de trois quarts, tête dans l'axe) ; elle reste épaulée 1,5 s après chaque tir.
- Tir : recul de l'arme et petit flash de bouche, pour les opérateurs comme pour les ennemis.
- Rechargement : arme inclinée, la main gauche retire le chargeur, le lâche au sol (il disparaît après quelques secondes), en prend un neuf dans le gilet et l'insère.
- Blessure : le buste et la tête encaissent le choc, dans le sens du tir quand il est connu.
- Mort et perte de connaissance : les genoux cèdent, le corps bascule sur le dos, l'arme tombe à côté et les bras retombent ; à plat ventre, il s'affaisse sur place. Un ennemi qui se réveille se relève.

## Reptation améliorée

- Cycle en diagonale : le coude gauche avance pendant que le genou droit remonte, puis l'inverse ; les deux jambes travaillent en continu.
- Rythme lié à la distance parcourue (environ 0,8 m par cycle), au lieu d'un cycle trop lent qui faisait glisser le corps.
- La main gauche lâche l'arme pour prendre appui au sol et se soulève en avançant ; la main droite porte l'arme, qui avance avec le coude droit ; coudes au sol.
- Épaules et bassin ondulent, le corps avance par poussées et se fait plus bas ; la tête reste tournée vers l'avant.

## Transitions de posture

- Se coucher : l'opérateur se met à genoux, pose la main gauche au sol, puis s'allonge (1,1 s depuis debout, 0,9 s depuis accroupi).
- Se relever : appui sur la main, genou à terre, puis debout (1,1 s) ou accroupi (0,8 s).
- L'animation part de la pose du moment (en marche, en pleine transition), sans à-coup ; l'arme reste tenue de la main droite, pointée vers l'avant.
- Pendant la transition, l'opérateur ne se déplace pas et ne tire pas ; l'ordre en cours reprend ensuite.

## Arme à la bretelle

- Nouveau geste : l'opérateur bascule son fusil canon vers le bas, le laisse pendre sur son flanc droit et lâche la poignée pour avoir les mains libres (0,7 s) ; il le reprend en main par le geste inverse.
- Automatique avant de grimper ou de redescendre (l'escalade attend la fin du geste) et pendant l'approche d'un ennemi au corps à corps ; l'arme est reprise une fois l'action terminée.
- Mains libres : les bras se balancent à la marche ; couché, les deux mains prennent appui au sol et travaillent en alternance pendant la reptation.
- L'opérateur ne tire et ne recharge qu'arme en main.

## Touche « arme à la bretelle »

- G (ou le bouton « Bretelle » de la barre d'actions) passe l'arme des opérateurs sélectionnés à la bretelle, ou la leur fait reprendre en main. Avec une sélection mixte, tous la passent à la bretelle.
- Un ordre d'attaque ou de rechargement fait reprendre l'arme automatiquement.

## Uppercut

- « Assommer » se fait désormais mains nues, arme à la bretelle, par un uppercut : genoux fléchis et buste tourné, main gauche qui saisit l'ennemi, poing droit à la hanche ; puis jambes et hanches qui se détendent, fente vers la cible et poing qui remonte en arc jusqu'au menton.
- Le couteau garde son animation de frappe.

## Coups de pied

- Trois coups de pied s'ajoutent à l'uppercut pour assommer : coup de pied de face (genou monté puis jambe tendue), circulaire (pivot sur le pied d'appui, jambe qui fouette jusqu'à la poitrine) et chassé latéral (de profil, genou ramené puis poussée du talon). Poings en garde, regard sur la cible.
- L'opérateur choisit un coup au hasard, jamais deux fois de suite le même ; accroupi, il donne un uppercut.

## Coup de crosse

- « Assommer » dépend désormais de l'arme : arme en main, l'opérateur frappe d'un coup de crosse (arme ramenée sur la hanche, crosse projetée vers le visage avec rotation du buste et fente) ; arme à la bretelle (G), il frappe à mains nues (uppercut ou coup de pied).
- Pour assommer, l'opérateur ne passe plus automatiquement son arme à la bretelle ; il le fait toujours pour le couteau et l'escalade.

## Prises par derrière

- Dans le dos d'un ennemi, « Assommer » devient un étranglement : l'opérateur se colle à lui, passe le bras autour du cou et serre (2,5 s) ; la victime se débat, mains à la gorge, puis s'effondre en avant, inconsciente, sans un bruit.
- Le couteau devient un égorgement : main gauche sur la bouche, lame passée sous la gorge (1 s), chute vers l'avant, silencieux.
- La victime est immobilisée dès la saisie (son cône s'éteint) ; si l'opérateur est tué avant la fin, elle se dégage et passe en alerte.
- De face, les coups restent les mêmes, mais le couteau fait crier la victime (bruit de 6 m).

## Lutte de l'ennemi en alerte

- Un ennemi en alerte qui voit l'opérateur arriver de face le repousse : poussée à deux mains (ou du plat de l'arme, tenue en travers de la poitrine), l'opérateur encaisse et recule d'un mètre, le coup (couteau ou assommer) n'a pas lieu.
- L'ennemi reste en alerte et reprend le combat ; il faut le prendre de flanc ou de dos.

## Parade, esquive et contre

- Au contact de sa cible (1,6 m), un ennemi en alerte frappe au lieu de tirer : coup de crosse s'il est armé, uppercut sinon (25 PV, un coup toutes les 2 s environ). Un ennemi sans arme vient désormais au contact.
- L'opérateur pare (45 % : arme levée en travers du visage, ou avant-bras croisés à mains nues), esquive (35 % : pas de côté, buste baissé) ou encaisse. Occupé (en train de frapper, couché, en escalade), il encaisse toujours.
- Un coup paré ou esquivé déséquilibre l'ennemi 1,5 s : il recule, vacille, ne frappe ni ne tire, et ne repousse plus l'opérateur. C'est la fenêtre du contre : un ordre « Assommer » ou « Couteau » réussit à coup sûr, et part aussitôt s'il était déjà donné pendant l'attaque.

## Casque des opérateurs

- Nouveau casque balistique « high cut » pour les opérateurs : coque découpée au-dessus des oreilles avec garniture, rails RIS crantés sur les flancs (lampe tactique sur le rail droit), protection auditive électronique fixée aux rails par des adaptateurs, micro sur perche, support et jumelles de vision nocturne relevées, contrepoids à l'arrière, marqueur d'équipe.
- Les soldats ennemis gardent leur casque simple, ce qui aide à distinguer les camps.

## Lancer de couteau

- Nouvelle action « Lancer » (T ou bouton, puis clic gauche sur un ennemi) : l'opérateur sélectionné le plus proche s'approche à 7 m avec une ligne de vue dégagée, passe son arme à la bretelle, arme le bras derrière la tête et lance ; le couteau vole en tournoyant.
- Touché, l'ennemi meurt sans bruit (vers l'avant s'il est atteint dans le dos). Le lancer porte toujours jusqu'à 4 m, puis de moins en moins (70 % à 7 m).
- Raté, le couteau file au-delà et tombe près de l'ennemi, qui l'entend et devient méfiant.
- Chaque opérateur a un couteau de lancer : il reste au sol (repère violet) et se ramasse en passant dessus. Le portrait indique « sans couteau » en attendant. Le couteau de combat (V) reste toujours disponible.

## Pousser et tirer les caisses

- Nouvelle action « Caisse » (P ou bouton, puis clic gauche sur le côté d'une caisse) : l'opérateur sélectionné le plus proche rejoint ce côté, se relève s'il le faut, passe son arme à la bretelle et pose les mains sur la caisse.
- Clic droit au sol : il pousse (buste en avant, mains à plat, 1 m/s) ou tire (buste en arrière, mains au rebord, 0,8 m/s) la caisse dans l'axe du côté tenu, jusqu'au point visé ou au premier obstacle (mur, autre caisse, unité, ennemi assommé).
- La caisse frotte au sol (bruit de 3 m). La navigation est recalculée dès qu'elle s'arrête : chemins, points d'escalade et passages entre caisses suivent sa nouvelle position.
- Tout autre ordre (attaque, corps à corps, escalade, rechargement, reprise de l'arme avec G, posture), F ou P fait lâcher la caisse. On ne peut ni saisir une caisse occupée, ni monter sur une caisse tenue.
- Les jambes marchent en poussant ou en tirant (elles restaient figées et le corps glissait) : pas courts et appuyés, cadence réglée sur la vitesse de la caisse ; pieds en arrière et jambe arrière qui pousse pour pousser, pieds en avant et marche à reculons pour tirer.

## Sons provisoires

- Premiers sons, synthétisés par le jeu au démarrage (aucun fichier audio) : tirs (sourds pour les armes à silencieux des opérateurs, détonation pour les ennemis), pas (plus forts en courant, discrets accroupi ou en poussant une caisse, bruissement en rampant), impacts, chutes de corps, coups, couteau, parade, esquive, lancer, tintement du couteau au sol, rechargement, caisse qui frotte.
- Signaux d'état des ennemis : deux bips montants quand l'un passe en alerte, un bip interrogatif quand il devient méfiant.
- Interface : bip de sélection, double bip d'ordre reçu, bip d'action armée (V, B, T, P), son grave d'ordre refusé.
- Sons positionnels 3D : l'écoute se fait au centre de la vue, plus ou moins haut selon le zoom ; un son hors de l'écran est plus faible et vient du bon côté.
- Bus audio du cahier des charges : Master, Musique, SFX, Voix, UI.

## Textures du sandbox

- Sol en herbe, chemin de terre qui suit la ronde de la sentinelle, murs en parpaings, caisses en bois (trois variantes : claire, sombre, marquée de bandes de danger).
- Textures tirées du lot `../CommandoAsset/textures` (anciennement `data/textures`) et copiées dans `assets/textures` (origine de chacune dans `assets/TEXTURES.md`).
- Nouvelle propriété `skin` des caisses (`Climbable`) pour choisir la texture d'une caisse dans l'éditeur.

## Textures lues au chargement du niveau

- Les textures ne sont plus copiées dans le projet : chaque niveau les lit au chargement dans le dossier externe `../CommandoAsset/textures` (`TextureLibrary`), en décodant les images en parallèle.
- Un matériau désigne sa texture par une métadonnée (`albedo_source`, `normal_source`, `roughness_source`) ; la propriété `skin` des caisses devient un chemin dans ce dossier.
- Dossier réglable (réglage de projet `commando/assets/texture_dir`, variable d'environnement `COMMANDO_TEXTURES`) ; une texture manquante laisse le matériau à sa couleur, avec un avertissement.
- Liste des textures utilisées et licence : `assets/TEXTURES.md`.

## Cartes UFO:AI

- Lecture des cartes sources d'UFO:AI (`.map`, format Radiant de Quake 2) à la volée, au chargement du niveau, depuis `../CommandoAsset/maps` (`UfoMap`, `UfoMapLevel`).
- Géométrie reconstruite à partir des brushes : maillage texturé (textures du lot externe, cartes normales quand elles existent, faces lumineuses, tonneaux lissés), collisions (sol, murs qui masquent la vue, murs invisibles qui arrêtent seulement les unités).
- Opérateurs placés sur les points de départ de la carte, sentinelles fixes sur les positions des aliens, limites de la caméra réglées sur la carte.
- Premier niveau converti : `scenes/levels/training_a/training_a.tscn` (carte d'entraînement de 41 × 41 m, 8 sentinelles).
- Navigation plus fine sur ce niveau (cellules de 10 cm) pour passer dans les couloirs d'une case.

## Menu de démarrage

- Le jeu s'ouvre sur un menu qui propose les cartes (terrain d'essai, Entraînement A) avec leur description ; une carte dont le fichier UFO:AI est introuvable est grisée, avec la raison.
- Chargement du niveau en arrière-plan, avec sa progression.
- Bouton « Menu » dans le HUD pour abandonner la partie et revenir au choix de la carte.

## Tests automatisés

- Framework de tests GUT 9.7.1 installé (`addons/gut`), lancé par `./run_tests.sh` ou depuis le panneau GUT de l'éditeur.
- 63 tests permanents remplacent les scripts de vérification jetables perdus : logique pure (cône de vision, points de vie, cartes UFO:AI, textures et dossiers externes, sons) et parties jouées (escalade, fusillade, postures, coups pour assommer, coup de crosse, prises par derrière, lutte, parade, esquive, contre, lancer de couteau, caisses, sons, carte `training_a`, menu).
- GUT et les tests sont exclus de l'export Web.

## Caisses des cartes UFO:AI

- Les caisses en bois des cartes UFO:AI (cubes d'une case posés au sol, rien dessus) deviennent de vraies caisses du jeu : on peut y grimper, passer de l'une à sa voisine, les pousser et les tirer. Elles gardent leurs textures d'origine. Neuf caisses sur `training_a`.
- Échelle des cartes ramenée à 32 unités = 1,2 m (au lieu de 1,28 m) pour que ces caisses aient la hauteur prévue par les animations d'escalade ; `training_a` mesure désormais 38,4 m de côté.
- Les murs invisibles qui doublaient ces caisses disparaissent avec elles.

## Escalade des murs depuis une caisse

- Depuis le dessus d'une caisse, un opérateur peut grimper sur le mur voisin (murs pleins de 2,25 à 2,5 m sur les cartes UFO:AI) : clic droit sur le dessus du mur. Ordonné depuis le sol, il passe par la caisse la plus proche qui y mène.
- Sur les murs, il marche de case en case et peut redescendre sur une autre caisse. Pour revenir au sol, il repasse par une caisse ; s'il n'y en a plus (caisse poussée ailleurs), il saute.

## Saut du haut d'un mur

- Descendre d'un mur sans caisse à côté se fait désormais par un vrai saut : l'opérateur s'accroupit au bord, prend son impulsion, tombe jambes groupées (chute accélérée), se réceptionne accroupi puis se relève (1,7 s). La réception fait du bruit (son sourd, bruit signalé dans un rayon de 4 m).

## Bidons déplaçables

- Les 22 bidons de `training_a` se poussent et se tirent comme les caisses (même ordre : action caisse, puis clic de destination). On ne monte pas dessus : un clic droit sur un bidon envoie à côté. Ils gardent leurs textures et ont une collision cylindrique.
- Les murs invisibles partagés entre un objet déplaçable et du décor fixe sont désormais découpés au lieu de figer l'objet : seule l'emprise de l'objet est retirée.

## Confirmation avant de quitter

- Les boutons « Quitter » du menu et du jeu ouvrent une petite fenêtre « Quitter le jeu ? » (Quitter / Annuler). « Annuler » est sélectionné par défaut et Échap annule ; le jeu est en pause tant que la fenêtre est ouverte.
- Le bouton « Menu » en jeu demande aussi confirmation : « Revenir au menu ? La partie en cours sera perdue. » (Menu / Annuler).

## Deux nouveaux niveaux

- **Entraînement B** (`training_b`) : grande carte UFO:AI de 100 × 62 m, bunkers, tranchées et murets.
- **Gare du désert** (`fighter_crash`) : 56 × 58 m, hameau en ruine, voie ferrée et wagons sur un relief en terrasses. L'épave du vaisseau, faite de modèles 3D absents, n'apparaît pas.
- Douze sentinelles sur chacune, réparties sur toute la carte (au lieu des douze premières positions du fichier, toutes du même côté).
- Déplacements plus sûrs sur terrain inégal (opérateurs et ennemis) : une marche basse (jusqu'à 35 cm) est franchie d'elle-même, et un point de chemin bloqué (coéquipier immobile dessus, décalage en hauteur sur une pente) est sauté au lieu de faire tourner l'unité en rond.

## Écran de chargement

- Les niveaux se préparent derrière un écran de chargement (nom du niveau, étape en cours, points animés) au lieu de figer l'affichage : la carte UFO:AI est lue sur un fil de travail, le décor construit par tranches entre deux images, et la navigation générée en arrière-plan. Le jeu reste en pause jusqu'à la fin ; un ordre donné entre-temps s'exécute ensuite.
- Correction : quitter un niveau pendant sa préparation ne laisse pas le jeu en pause.

## Bâtiments et escaliers d'Entraînement B

- Quand un opérateur entre dans un bâtiment, le toit s'efface en fondu et ne fait plus d'ombre : on voit l'intérieur. Les clics traversent le toit effacé pour donner des ordres à l'intérieur. Le toit réapparaît quand plus aucun opérateur n'est dessous, et il reste solide : un opérateur peut toujours se tenir dessus.
- Les petits escaliers (0,9 m de large) entre le terrain et les tranchées se montent et se descendent : la navigation de `training_b` les prend en compte, et le modèle de l'opérateur suit les marches en douceur au lieu de sauter d'un coup.

## Toits sur toutes les cartes UFO:AI

- Les toits sont aussi repérés sur la Gare du désert (gare, hangars) : le repérage précédent n'en trouvait aucun, car les opérateurs y partent d'une terrasse plus haute que les bâtiments.
- Bâtiments à étage : au rez-de-chaussée, l'étage et son toit s'effacent aussi ; à l'étage, seul le toit.
- Les deux pans d'un toit en pente s'effacent ensemble.
- Sur Entraînement B, les tranchées couvertes laissent aussi voir l'intérieur.

## Personnalisation des opérateurs

- Nouvelle entrée « Opérateurs » au menu principal : un écran pour personnaliser les trois opérateurs de l'équipe, choisis par des portraits cliquables (indicatif et nom).
- Identité : nom, indicatif (affiché dans le HUD, nom complet en info-bulle), teinte du visage, barbe, coupe et couleur des cheveux.
- Tenue : couleurs du haut, du pantalon, du gilet et du couvre-chef (palette de 16 teintes), ou camouflage woodland, désert, urbain, neige ou nuit.
- Accessoires : couvre-chef (casque balistique, casquette, chapeau de brousse, bonnet, aucun), cagoule, jumelles de vision nocturne, casque audio, gilet tactique, sac à dos, radio, genouillères.
- Armement : carabine silencieuse, pistolet-mitrailleur silencieux, fusil de précision ou fusil de combat, chacun avec ses réglages de tir en mission (portée, dégâts, cadence, chargeur, bruit) ; arme secondaire ; couteaux de lancer (0 à 2), grenades, charges explosives et trousse de soins (pour l'instant seulement visibles sur l'opérateur).
- Aperçu 3D en temps réel : l'opérateur tourne sur un socle, on le fait pivoter en glissant et on zoome à la molette ; animations repos, marche, course, accroupi, couché et visée.
- Bouton pour remettre un opérateur dans sa tenue par défaut (avec confirmation).
- Les choix sont sauvegardés aussitôt et s'appliquent automatiquement en mission.


## Opérateurs : équipement utilisable, spécialités et préparation de mission

- En mission, l'équipement sert enfin :
  - **arme secondaire** : l'opérateur dégaine seul son pistolet quand l'arme principale est à sec, ou sur ordre (H). Le pistolet se tient à deux mains et l'arme principale passe dans le dos.
  - **grenades** (N, puis clic au sol) : l'opérateur s'approche à 12 m et lance. La grenade vole en cloche puis explose 1 s après être retombée (dégâts jusqu'à 4 m, les murs protègent). L'explosion est très bruyante et rend méfiants les ennemis proches qu'elle épargne.
  - **charges explosives** : K pose une charge aux pieds de l'opérateur (il s'accroupit pour l'armer), L fait sauter les charges posées.
  - **trousse de soins** (J) : l'opérateur soigne le plus blessé à moins de 2 m, lui compris (+50 PV en 2 s).
- Ces actions ont des boutons dans le HUD, sur une seconde rangée. Les portraits affichent l'équipement restant et l'arme secondaire en main.
- Charge portée : chaque arme, accessoire et équipement a un poids. Jusqu'à 18 kg, aucune gêne. Jusqu'à 23 kg, l'opérateur est 8 % plus lent. Jusqu'à 28 kg, il est 18 % plus lent et son équipement s'entend quand il court. Au-delà, l'écran refuse d'ajouter du poids. La tenue par défaut (17,5 kg) ne change rien.
- Spécialités, chacune avec un petit bonus et une tenue conseillée :
  - tireur d'élite : +15 % de portée, meilleure précision de loin ;
  - éclaireur : +10 % de vitesse ;
  - sapeur : explosions plus larges, charges posées plus vite ;
  - infirmier : soins plus forts et plus rapides.
- Écran « Opérateurs » :
  - annuler le dernier changement (bouton ou Ctrl+Z) ;
  - « Même tenue pour l'équipe » ;
  - raccourcis : 1 à 3 pour l'opérateur, Tab / Maj+Tab pour l'onglet ;
  - visage en 3D dans les sélecteurs ;
  - décor de l'aperçu assorti au camouflage (forêt, désert, ville, neige, nuit) ;
  - la caméra cadre ce qu'on modifie (tête, buste, arme, jambes) ;
  - nouvelles animations : rechargement, lancer de couteau, coup de couteau, escalade d'une caisse ;
  - comparaison des armes principales en barres (portée, dégâts, cadence, chargeur, discrétion) ;
  - jauge de charge ;
  - jusqu'à 6 tenues enregistrées par opérateur (onglet « Tenues enregistrées »).
- « Jouer » ouvre une préparation de mission : le camouflage conseillé pour la carte (un bouton pour toute l'équipe, un par opérateur), le choix d'une tenue enregistrée par opérateur, puis « Lancer la mission ».

## Casque des opérateurs retravaillé

- La coque est maintenant un vrai casque « high cut » : découpée au-dessus des oreilles, ras des sourcils devant et plus basse sur la nuque, avec une bordure caoutchouc et une doublure visibles.
- Rails latéraux courbes et crantés, lampe sur le rail droit, platine de JVN épousant le front, bras articulé et bagues des jumelles, scratchs sur le dessus et l'arrière, contrepoids sur la nuque.
- Jugulaire : sangles devant et derrière l'oreille jusqu'à la mentonnière, avec ou sans cagoule.
