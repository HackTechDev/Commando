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

## Visage et corps des opérateurs retravaillés

- Visage : une tête lisse d'un seul tenant, avec une mâchoire qui s'affine. Elle a des yeux (blanc et iris), des sourcils, un nez, une bouche, des oreilles, et des cheveux qui suivent le crâne.
- Barbes de trois jours et barbes fournies avec moustache. Avec la cagoule, les yeux restent visibles dans l'ouverture.
- Corps : membres galbés (cuisses, mollets, avant-bras), genoux et coudes, mains gantées avec pouce, bottes avec tige, semelle et lacets. Le pantalon a des poches cargo et des bas resserrés.
- Torse : bassin, ceinturon à boucle, buste et épaules arrondis. Le gilet a des plaques avant et arrière, des porte-chargeurs à rabat, une poche administrative et un écusson.
- Les ennemis partagent le nouveau corps. Les animations sont inchangées.

## Modèle et animation (points 6.x)

- Mains articulées : quatre doigts de deux phalanges et un pouce. Elles se ferment sur l'arme, le couteau ou la grenade et en poing pour frapper. Elles s'ouvrent pour pousser, parer, s'agripper en escaladant ou prendre appui au sol, et se détendent le long du corps.
- Yeux vivants : clignements, regard qui erre au repos, yeux fermés une fois mort ou inconscient. La tête et les yeux suivent la cible : ennemi visé, attaqué ou point d'un lancer pour les opérateurs, cible ou endroit suspect pour les ennemis.
- Expressions : sourcils froncés et lèvres serrées dans l'effort (frappe, lancer, escalade, caisse), yeux plissés, sourcils relevés et bouche ouverte quand l'opérateur encaisse un coup, est saisi, vacille ou tombe.
- Tissus en relief : plis et coutures piquées sur l'uniforme, trame plus fine sur le gilet et les poches, en uni comme en camouflage.
- Silhouette de spécialité :
  - tireur d'élite : écharpe de camouflage, télémètre, tapis de tir roulé sur le haut du dos ;
  - éclaireur : jumelles sur la poitrine, poche à eau sans sac ;
  - sapeur : pied-de-biche d'effraction en travers du dos, bobine de cordeau détonant ;
  - infirmier : brassards à croix rouge et grand sac de soins à la hanche.
- Ennemis reconnaissables d'un coup d'œil :
  - casque ancien à bord évasé sous couvre-casque, casquette ou béret ;
  - visage découvert, avec peau, cheveux et barbe tirés au hasard (toujours les mêmes pour un même soldat) ;
  - gilet à quatre porte-chargeurs et bretelles croisées, radio pour certains ;
  - fusil d'assaut à crosse en bois et chargeur courbe ;
  - ni JVN, ni cagoule, ni sac.
- Déplacements subis : l'opérateur repoussé recule pas à pas, l'esquive se fait en pas chassés, et un soldat déséquilibré recule d'un pied. Le corps ne glisse plus avec une marche en avant.
- Ramassage du couteau de lancer : l'opérateur s'arrête un instant, s'accroupit en se penchant, ouvre la main vers le sol puis la referme. Il prend le couteau de la main gauche s'il tient son arme. Son ordre reprend ensuite.
- Un ennemi sans arme en alerte se met en garde entre deux coups : poings serrés devant le visage, genoux souples, léger rebond.

## Nouvelles armes principales

- FAMAS : bullpup à cadence très élevée, chargeur de 25, sans silencieux.
- FN SCAR Light (5,56 mm) : silencieux, chargeur de 20, couleur sable.
- FN SCAR Heavy (7,62 mm) : silencieux, plus de portée et de dégâts, cadence plus lente.
- HK417 : fusil de tireur d'élite 7,62 mm à lunette, silencieux.
- M249 : mitrailleuse légère, bande de 100 cartouches. Elle est lourde (8 kg), bruyante, peu précise de loin et longue à recharger.
- Chaque arme a son modèle 3D, son poids et ses réglages de tir. La comparaison des armes de l'écran « Opérateurs » montre maintenant une ligne par arme.
- Corrigé : une erreur pouvait survenir quand un son était joué juste après un changement de niveau (voix libérée avec l'ancienne scène).

## Actions des opérateurs restructurées

- Ce que fait un opérateur est désormais une action (`scripts/units/actions/`). Chaque ordre (déplacement, attaque, approche d'escalade, de corps à corps ou de lancer, caisse) et chaque geste (frappe, lancer, charge, soins, ramassage, parade, recul) a sa classe et sa propre remise à zéro.
- Petits changements de comportement :
  - un couteau de lancer déjà lancé part même si un nouvel ordre arrive pendant le geste ;
  - un opérateur occupé à lancer ou à ramasser encaisse les coups au lieu de parer ;
  - poser une charge ou soigner est abandonné pour parer ou esquiver.

## Personnages non joueurs : VIP à escorter

- Nouvelle carte d'essai « Escorte » : il faut ramener un VIP jusqu'à la zone d'extraction, au nord-est. Elle est gardée par deux lignes de murs, deux patrouilles et une sentinelle.
- `Vip` : un personnage non joueur en costume, sans arme, repéré par un anneau doré. Le joueur ne lui donne pas d'ordres :
  - il se rallie à l'opérateur en vue le plus proche (6 m) et le suit à 1,8 m ;
  - il court quand son guide court ou s'il est distancé ;
  - il prend la posture de son guide (accroupi, couché) ;
  - si son guide s'éloigne à plus de 14 m, il l'attend sur place ; seul pendant l'alarme, il s'accroupit.
- Les ennemis repèrent le VIP, lui tirent dessus et le frappent comme un opérateur. Les grenades le blessent aussi.
- `ExtractionZone` : zone tracée au sol. Quand tous les VIP y sont entrés, la mission est réussie ; si l'un d'eux meurt, elle est manquée. Le résultat s'affiche à la place de l'indicateur d'alerte. Une fois à l'abri dans la zone, le VIP n'est plus pris pour cible.
- `SoldierModel` a une tenue civile (`civilian`) : costume, chemise, cravate, mains nues et chaussures de ville, sans aucun équipement militaire.

## Bouclier balistique

- Nouvel équipement « Bouclier balistique » (7 kg), à choisir dans l'écran « Opérateurs ».
- En mission, U ou le bouton « Bouclier » le lève ou le baisse. Levé :
  - l'opérateur le tient de la main gauche et tire à l'arme de poing, qu'il dégaine de lui-même ;
  - il marche 30 % plus lentement, ne court plus et ne peut pas ramper (se coucher baisse le bouclier) ;
  - reprendre l'arme principale baisse le bouclier.
- Les balles ennemies qui croisent le bouclier levé sont arrêtées, avec un tintement métallique. Cela protège le porteur et ceux qui s'abritent derrière lui (un coéquipier, un VIP). Les tirs venant de côté ou de dos passent toujours.
- Pendant un geste (frappe, lancer, soins, escalade, caisse), le bouclier passe un instant dans le dos, puis revient.
- Modèle 3D : panneau noir, hublot de visée, bande aux couleurs de l'équipe, poignée à l'arrière. Il est porté dans le dos quand il est baissé.

## Modèle féminin

- Écran « Opérateurs », section Visage : nouveau choix « Morphologie » (Homme / Femme), sauvegardé avec l'opérateur.
- Silhouette féminine :
  - un peu plus petite (95 %), taille plus fine, buste et épaules plus étroits, hanches plus larges ;
  - cou et bras plus fins ;
  - visage plus fin : mâchoire étroite, menton moins marqué, petit nez, lèvres plus pleines, sourcils fins, sans barbe.
- Deux nouvelles coupes pour tous : « Cheveux longs » (sur les épaules, visibles même sous un casque) et « Chignon ».
- Bravo (Inès Morel) a désormais la morphologie féminine et les cheveux longs par défaut.

## Visage : bouche, nez et barbe

- La bouche est posée sur le visage (ou sur la barbe) au lieu de flotter devant, pour les deux morphologies.
- Nouveau nez modelé : arête partant d'entre les yeux, bout arrondi, ailes et narines, ancré dans la peau. Il est plus petit pour une opératrice.
- Barbe courte et barbe fournie : elles épousent désormais la mâchoire sous le nez et remontent en favoris jusqu'aux oreilles. La barbe fournie s'épaissit vers le menton et garde sa moustache. Auparavant, c'était un ellipsoïde qui flottait à plusieurs centimètres du visage et cachait le nez.

## Changement d'arme animé, bretelle 3 points

- Corrigé : avec l'arme de poing en main (bouclier levé, ou touche H), l'arme principale apparaissait mal placée, en travers du dos et dépassant sur le côté.
- Le changement d'arme est maintenant un mouvement continu :
  - l'arme principale descend des mains et pend à sa bretelle 3 points, sur le flanc droit, canon vers le bas ;
  - le pistolet sort de l'étui de cuisse jusqu'à la main ;
  - pour revenir, le pistolet rentre dans l'étui, puis l'arme principale remonte de la bretelle.
- Avec le bouclier, celui-ci ne passe du dos à l'avant qu'une fois le fusil lâché. Le tout prend environ 1,2 s, pendant lequel l'opérateur ne tire pas.

## Ordres au VIP : menu circulaire

- Le VIP ne suit plus d'office l'opérateur le plus proche : il attend un ordre.
- Clic du milieu sur le VIP (sans glisser, sinon la caméra se déplace) : un menu circulaire s'ouvre autour du curseur.
  - « Suivre l'opérateur » : le VIP suit l'opérateur sélectionné (le plus proche de lui si plusieurs le sont) et imite sa posture. L'option est grisée sans sélection.
  - « Attendre ici » : il quitte son guide et reste sur place.
- Survol pour mettre une option en évidence, clic gauche pour la choisir ; clic droit, clic du milieu, Échap ou clic hors de la couronne pour fermer.
- Au-dessus du VIP, une étiquette indique « Suit <opérateur> » ou « Attend ». Son guide mort, il attend sur place.

## Escalade généralisée : échelles, murets, toits

- Échelle (`Ladder`) contre un bâtiment à toit plat : un clic droit sur le toit y conduit l'opérateur. Il passe son arme à la bretelle, gravit les barreaux (mains et pieds en alternance), puis se rétablit sur le toit. Il redescend face à l'échelle.
- Muret (`LowWall`, 1 m) : il arrête la marche, mais le chemin peut passer par-dessus. L'opérateur l'enjambe (escalade, puis descente de l'autre côté).
- Ces passages sont des liens de navigation : les ennemis et le VIP les empruntent aussi, par exemple pour rejoindre un opérateur réfugié sur un toit.
- Un ennemi armé tire d'en bas sur un opérateur perché (caisse, mur, toit), sans chercher à passer dessous ; il ne tente plus de le frapper au corps à corps.
- Terrain d'essai : un bunker avec son échelle et un muret, à l'est.

## Curseur contextuel

- Le curseur indique ce que ferait un clic à l'endroit survolé, avec des curseurs dessinés pour le jeu :
  - viseur rouge sur un ennemi (tirer) ;
  - flèche verte sur une caisse ou une corniche (grimper) ;
  - cercle bleu sur le VIP (ses ordres, clic du milieu) ;
  - sens interdit sur un endroit inaccessible (dessus d'un mur, hors du terrain).
- Une action armée montre sa cible : poignard (couteau, assommer), poignard lancé, cible de grenade, flèches de déplacement d'une caisse ; sens interdit hors d'une cible valable.
- Au-dessus de l'interface, le curseur redevient la flèche habituelle.

## Grappin

- Nouvel équipement, le grappin (2,5 kg), à choisir dans l'écran « Opérateurs ». Il pend au flanc gauche de l'opérateur, en rouleau de corde.
- W (ou le bouton « Grappin »), puis clic gauche sur un point en hauteur : l'opérateur sélectionné le plus proche qui en a un va au pied de la paroi, lance le grappin, puis monte à la corde jusqu'au point visé.
- La corde épouse le relief : sur des terrasses en gradins, l'opérateur escalade les ressauts bas comme une caisse et gravit les parois hautes à la corde, en alternant les mains.
- Portée : le point visé doit être à 10 m au plus du pied de la paroi et de 1 à 9 m plus haut. Le curseur montre un grappin vert quand c'est possible, un sens interdit sinon.
- La corde reste en place : coéquipiers, VIP et ennemis peuvent l'emprunter, dans les deux sens.
- Terrain d'essai : des terrasses en gradins à l'est, à côté du bunker.

## Pause tactique et ordres simultanés

- Espace : pause tactique. Le jeu s'arrête, mais on peut toujours sélectionner, déplacer la caméra et donner des ordres ; ils partent à la reprise. Un bandeau le rappelle en haut de l'écran.
- Tab : préparation d'ordres simultanés. Chaque unité garde le dernier ordre reçu (déplacement, tir, couteau, lancer, grenade, grappin, caisse, escalade) sans l'exécuter ; un trait pointillé numéroté montre sa destination ou sa cible. Entrée lance tous les ordres en même temps ; Tab à nouveau les abandonne.
- Les deux se combinent : en pause, préparer les ordres de chaque unité, les lancer, puis reprendre.
- Les sons d'interface jouent aussi pendant la pause.

## Retour visuel des tirs

- Une balle manquée ne traverse plus les murs : elle s'arrête sur le premier obstacle derrière la cible (mur, caisse, sol), dans une petite gerbe de poussière.
- Une balle qui touche fait jaillir une gerbe rouge sur la cible, et le chiffre des dégâts (« -25 ») s'élève au-dessus d'elle avant de s'effacer : jaune sur un ennemi, rouge sur un opérateur ou le VIP.
- Une balle arrêtée par un bouclier fait des étincelles.

## Cône de vision moins coûteux

- Le cône affiché d'un ennemi (un rayon par segment) n'est plus recalculé à chaque image : seulement quand l'ennemi bouge ou tourne, quand une caisse est déplacée, et au plus tard une fois par seconde. Une sentinelle immobile ne coûte presque plus rien.
- Hors de l'écran, le cône attend d'y revenir pour être recalculé.
- Caméra très dézoomée, le cône a moins de segments (jusqu'à 16 au lieu de 48).
- La détection des opérateurs, elle, ne change pas : un rayon par cible, à chaque image.

## Étages affichés au choix

- Page suiv. / Page préc. choisissent l'étage affiché : les toits de cet étage et des étages supérieurs s'effacent, même sans opérateur dessous. On voit ainsi l'intérieur d'un bâtiment avant d'y entrer, étage par étage.
- Au-dessus du dernier étage, l'affichage normal revient (seuls les toits au-dessus d'un opérateur s'effacent). Un bandeau rappelle l'étage choisi.

## Toits et murs, suite

- Le décor des cartes UFO:AI s'efface en pointillé autour de chaque opérateur, quand un mur, un surplomb ou une dalle est entre lui et la caméra : on ne perd plus un opérateur derrière un bâtiment. Le sol qu'il foule et ce qui est plus bas que ses genoux restent affichés.
- Un toit ne s'efface plus d'un bloc : seule sa partie au-dessus de l'intérieur couvert disparaît, avec 50 cm de marge pour les murs. Une dalle de terrain qui couvre une tranchée, ou un surplomb au-dessus d'un passage, ne s'efface plus qu'au-dessus du passage ; les clics ne la traversent que là.
- Garder la souris sur un toit (0,8 s) l'efface : on voit l'intérieur sans y entrer.
- Le repérage des toits est mis en cache par carte (`user://roof_cache`) : les chargements suivants sautent ce calcul (2 s sur Entraînement B).

## Page d'aide

- H ouvre une page d'aide qui liste toutes les commandes par rubrique (sélection, combat, équipement, tactique, caméra), avec les touches lues dans l'InputMap selon la disposition du clavier. Le jeu est en pause tant qu'elle est ouverte ; H, Échap ou un clic la referment. Elle s'ouvre aussi pendant la pause tactique, qui reste active à la fermeture.
- Les longues lignes de commandes en haut de l'écran sont remplacées par un rappel « H : aide ».
- Le changement d'arme passe de H à Y.

## Indicatifs des opérateurs

- Un petit texte au-dessus de chaque opérateur affiche son indicatif (Alpha, Bravo…). Il reste lisible quel que soit le zoom, se voit même derrière un mur, passe au jaune quand l'opérateur est sélectionné, descend quand il s'accroupit ou rampe, et disparaît à sa mort.

## Sauvegarde d'état (préparation de la sauvegarde rapide)

- Opérateurs, VIP, ennemis, points de vie, caisses déplaçables et zone d'extraction savent donner et reprendre leur état (`save_state()` / `load_state()`) : place, orientation, posture, vie, munitions, équipement, arme en main, bouclier, état d'alerte ou perte de connaissance d'un ennemi, guide du VIP, VIP évacués.
- `QuickSave` réunit ces états par chemin de nœud, avec le niveau d'alerte, les écrit dans un fichier et les rend à un niveau rechargé. Les touches de sauvegarde et de chargement viendront avec M7.

## Pourquoi l'opérateur ne tire pas

- Sous l'indicatif, un court message orangé dit pourquoi l'opérateur ne tire pas ou ne lance pas encore : « Hors de portée » ou « Obstacle : pas de ligne de tir » pendant qu'il s'approche, pour un tir, un couteau ou une grenade.
- Un ordre refusé s'explique un instant : « À sec », « Plus de couteau », « Plus de grenade ».

## Menu, suite

- Échap ouvre un menu pause : reprendre, recommencer la mission, aide, menu principal, quitter. Il annule d'abord une action armée (couteau, grenade…). L'aide et les confirmations ouvertes depuis lui y ramènent.
- Chaque carte du menu a une vignette : une vue du dessus, enregistrée à la fin du premier chargement (`user://previews`).
- La dernière carte jouée passe en tête de liste, sélectionnée (`user://settings.cfg`, autoload `Settings`).
- Les autres cartes UFO:AI du dossier (`.map` hors catalogue) sont proposées à la suite, jouables dans un niveau générique : opérateurs sur les points de départ, sentinelles sur les positions des aliens, camouflage deviné d'après le nom.

## Préparation de mission, suite

- La préparation montre l'aperçu de la carte et ses objectifs (escorter le VIP, neutraliser les sentinelles, ne perdre personne…), décrits dans le catalogue des niveaux.
- « Modifier la tenue… » ouvre l'écran « Opérateurs » complet (identité, tenue, accessoires, armement, équipement) par-dessus la préparation, sur l'opérateur choisi ; « Retour à la préparation » y ramène avec les changements.

## Écran de fin et redémarrage

- À la fin d'une mission (VIP évacué ou tué, opérateur tué), un écran annonce « MISSION RÉUSSIE » ou « MISSION ÉCHOUÉE » avec la raison (« ÉCHEC — Bravo tué »), après un court délai, jeu en pause. Il propose de recommencer (le niveau est rechargé), de continuer à jouer, ou de revenir au menu.

## Journal d'objectifs, minicarte, options (5.7)

- `Objectives` suit les objectifs du niveau (catalogue) : en cours, rempli, échoué. Toutes les sentinelles neutralisées ou un opérateur tué terminent la mission ; la mort du VIP fait échouer son objectif.
- Journal d'objectifs en haut à droite (O), affiché quelques secondes au début de la partie.
- Minicarte en haut à gauche (touche à droite de L : M sur AZERTY) : aperçu de la carte, opérateurs, VIP, ennemis (gris s'ils sont assommés), champ de la caméra ; un clic y centre la caméra.
- Menu pause : bouton « Options » (volumes général, musique, effets ; plein écran ; défilement aux bords de l'écran), enregistrées dans `user://settings.cfg`.

## Fusil à pompe

- Nouvelle arme principale « Fusil à pompe » : 95 points de dégâts à bout portant, 20 à 9 m (les dégâts baissent avec la distance), magasin tubulaire de 5 cartouches (+15), sans silencieux.
- Modèle : long canon, magasin tubulaire, garde-main mobile ; après chaque tir, la main gauche manœuvre la pompe (avec son bruit). Le rechargement se fait cartouche par cartouche, sans chargeur qui tombe.
- `UnitStats.fire_damage_far` et `damage_at(distance)` : dégâts selon la distance, pour toute arme qui le souhaite. La comparaison des armes affiche « 95 → 20 ».

## Grappin : raison des refus

- Touche du grappin sans opérateur équipé : « Pas de grappin (à équiper : écran Opérateurs) » s'affiche sous l'indicatif, au lieu d'un curseur interdit partout. Le grappin s'ajoute dans l'onglet Armement de l'écran Opérateurs.
- Lancer refusé : la raison s'affiche (« Grappin : pas assez haut », « trop loin », « relief trop accidenté »…).
- Les tests n'utilisent plus la dernière carte jouée du joueur ni son cache des toits (`UfoMapLevel.roof_cache_dir`).

## Esquive du côté libre (3.13)

- Le pas de côté part du côté dégagé (mur, caisse, autre unité testés sur le trajet) ; au hasard si les deux le sont. Coincé des deux côtés, l'opérateur pare au lieu d'esquiver.

## Parade au choix du joueur (3.11)

- Touche de parade (I) : un coup qui porte dans les 0,45 s qui suivent l'appui est paré à coup sûr, et l'assaillant est déséquilibré (contre possible). On ne peut rappuyer qu'au bout de 0,9 s.
- Sans la touche, l'opérateur encaisse. L'ancienne défense au hasard (parade ou esquive) reste disponible : option « Parade automatique » du menu pause.

## Garde de l'ennemi (3.9)

- Un ennemi en alerte dont la cible est à moins de 2,2 m devant lui lève sa garde : arme en travers de la poitrine (poings levés sans arme), genoux fléchis. En garde, il ne tire plus : il avance pour frapper.
- Un coup de face sur un ennemi en garde est repoussé ; l'opérateur affiche « En garde : parer son coup pour contrer, ou le prendre à revers ». Parer (touche I) le déséquilibre et ouvre le contre ; par derrière, la prise reste possible.

## Riposte au corps à corps des ennemis à sec (3.10)

- Les ennemis ont un nombre de cartouches (`EnemyStats.ammo`, 30 pour le soldat ; sauvegardé par la sauvegarde rapide). À sec (déclic à vide), un ennemi ne tire plus : il charge jusqu'au contact et frappe à coups de crosse.

## Coup de coude et coup de genou (3.1)

- À mains nues, au contact (moins de 0,95 m) ou pour un contre après une parade, l'opérateur s'avance et frappe du coude (horizontal, en pivotant le buste) ou du genou (mains derrière la nuque de la cible), en alternance.
- `SoldierModel.MOVES` : coups décrits par des pistes (corps, jambe droite) et des trajets de mains, pour ajouter de nouveaux coups sans code d'animation.

## Enchaînement direct + crochet (3.3)

- Nouveau coup à mains nues dans le tirage : direct du gauche (la cible encaisse, reste debout), puis crochet du droit qui l'assomme. Le geste dure 1,6 fois un coup simple.

## Balayage et menu de corps à corps (3.2)

- Clic du milieu sur un ennemi (opérateur sélectionné) : menu circulaire de corps à corps (assommer, couteau, balayage).
- Balayage : accroupi d'un coup, main au sol, l'opérateur fauche les jambes d'un coup de pied bas en pivotant. L'ennemi tombe à la renverse et reste sonné 30 % du temps d'un ennemi assommé.

## Projection (3.4)

- Menu de corps à corps → « Projection » : l'opérateur saisit l'ennemi au col et à la manche, pivote et le fait passer par-dessus sa hanche. L'ennemi bascule en l'air et retombe sur le dos devant lui, sonné un instant ; l'opérateur s'accroupit aussitôt à côté de sa poitrine et le frappe au sol, ce qui l'assomme pour de bon.

## Désarmement (3.5)

- Menu de corps à corps → « Désarmer » : l'opérateur s'avance au contact, saisit l'arme à deux mains, la tord et l'arrache. Elle tombe au sol ; l'ennemi lève les mains et ne fait plus rien (ni tir, ni coup, ni poursuite, plus de cône de vision), sans être neutralisé : on peut encore l'assommer.
- De face, il faut le prendre de court : pas encore en alerte, en alerte depuis moins de 1,5 s, ou déséquilibré par une parade. Sinon, il repousse l'opérateur comme pour un coup.
- Un ennemi désarmé ne compte plus pour le niveau d'alerte ; l'état est conservé par la sauvegarde rapide.

## Bouclier humain (3.6)

- Menu de corps à corps → « Bouclier humain » : l'opérateur saisit l'ennemi par derrière (refusé de face, ou sans arme de poing), le bras gauche autour du cou, et dégaine son pistolet.
- L'otage reste devant lui, tourné comme lui. L'opérateur avance à pas lents (45 % de la marche, même en courant), reste debout, tire au pistolet ; grenades, couteaux, escalade, caisses, soins, bouclier et autres corps à corps attendent qu'il lâche l'otage.
- Les ennemis retiennent leur tir tant que l'otage couvre la ligne de tir.
- Clic du milieu sur l'otage : « Relâcher » (il se dégage et donne l'alerte) ou « Assommer » (V sur l'otage fait de même). Si l'opérateur est tué, l'otage se libère.

## Appel à l'aide (3.12)

- Un ennemi saisi crie à l'aide après 1,2 s, puis toutes les 2,5 s : à pleine voix (12 m) s'il est tenu en otage, étouffé (4 m) s'il est étranglé. Une victime égorgée n'a pas le temps de crier.
- Première ouïe des ennemis : ceux qui entendent l'appel passent en alerte et courent vers le cri.

## Couteau planté dans le corps (3.7 a)

- Un couteau de lancer qui touche reste planté dans le torse de la cible, dans l'axe du lancer, et la suit dans sa chute. Le repère violet se place au sol sous lui ; on le ramasse en passant sur le corps.

## Caillou de diversion (3.7 b)

- T, puis clic gauche au sol : l'opérateur le plus proche lance un caillou (jusqu'à 14 m, sans limite). Il tombe avec un bruit sec.
- Les ennemis qui l'entendent (7 m) deviennent méfiants, vont voir au pas, balaient les alentours du regard trois secondes, puis reprennent leur ronde. Un ennemi en alerte n'en tient pas compte.

## Roulade (3.8)

- Touche « , » (AZERTY) : les opérateurs sélectionnés plongent vers le curseur sur 2,5 m (moins si un obstacle les arrête), se reçoivent sur les mains et finissent couchés, en 0,8 s. Couchés dès l'envol, ils sont plus difficiles à toucher.
- Refusée depuis la position couchée, perché, pendant un autre geste ou avec un otage.

## Corps à corps à plusieurs (3.14)

- Un second ennemi qui vient frapper un opérateur déjà au contact d'un camarade le contourne pour l'attaquer de flanc (100° du premier).
- Pendant que l'opérateur pare ou esquive, un autre assaillant frappe aussitôt, sans attendre sa récupération, et son coup passe.
- Un opérateur attaqué au corps à corps appelle les coéquipiers inoccupés à moins de 8 m : ils accourent pour assommer l'assaillant (souvent par derrière, d'une prise).

## Didacticiel

- Nouveau niveau « Didacticiel », en tête du menu : une allée du sud au nord, sept ateliers signalés par un « ? » jaune (« ✓ » vert une fois réussis) :
  1. se déplacer (sélection, marche, caméra) jusqu'à un cercle ;
  2. courir et se baisser (course, postures, roulade, muret à enjamber) ;
  3. grimper (caisses, échelle du bunker, déplacer une caisse) jusqu'au toit ;
  4. corps à corps sur trois mannequins (assommer, couteau, menu des coups, parade) ;
  5. stand de tir, trois cibles (tir, rechargement, arme de poing, grenade) ;
  6. infiltration : une sentinelle non armée qui patrouille derrière un mur (cône de vision, caillou, pause tactique) ;
  7. zone de fin, qui termine la mission une fois les autres ateliers réussis.
- Petite fenêtre d'astuce à gauche de l'écran (`TutorialPanel`) : titre, étape « n / 7 », texte où les touches sont lues dans l'InputMap (AZERTY ou autre). Le jeu continue ; × la masque, « ? Astuce » la rouvre. À la réussite d'un atelier, elle l'annonce et indique la suite.
- Chaque atelier est un objectif du journal.
- `Enemy.blind` : ennemi qui ne voit rien (mannequins et cibles d'entraînement), sans cône affiché.

## Chargement des cartes UFO:AI

- La lecture de la carte et le repérage des toits tournent chacun sur un fil dédié (`Thread`) au lieu du `WorkerThreadPool`, où la tâche restait parfois sans démarrer (suite de tests bloquée sur `test_roof_detection_is_cached_per_map`). Un niveau quitté en plein calcul attend la fin du fil.

## Grenades fumigènes et gestes de lancer

- Nouvel équipement « Grenades fumigènes » (3 au plus, 0,5 kg pièce), choisi dans l'écran Opérateurs ou la préparation de mission.
- Touche « ; » (AZERTY, à droite de « , ») ou bouton « Fumigène » de la barre d'actions, puis clic au sol : l'opérateur le plus proche qui en a un s'approche à 12 m et le lance.
- Le nuage (`SmokeCloud`) se forme en 2 s, fait 4 m de rayon et dure environ 16 s : un ennemi ne voit rien à travers ni depuis l'intérieur. Il ne blesse personne.
- Gestes de lancer distincts (`SoldierModel.ThrowStyle`) :
  - grenade lancée loin : la main gauche dégoupille, le bras droit s'arme derrière la tête, pas en avant, lâcher puis accompagnement ;
  - grenade lobée à la cuillère sous 5 m, genoux fléchis ;
  - caillou lancé d'un petit mouvement du poignet ;
  - couteau : geste vif inchangé.
- L'objet tenu (grenade, fumigène, caillou, couteau) est visible dans la main jusqu'au lâcher.

## Ordres simultanés, suite

- La pose d'une charge, sa mise à feu, les soins et la roulade se préparent aussi en mode ordres simultanés (Tab) : par exemple, faire sauter une charge au moment où un coéquipier plonge hors d'un cône de vision, puis tout lancer d'Entrée.
- Sur la carte, la mise à feu préparée est tracée vers la charge, en rouge.

## Rondes des sentinelles (7.9 g)

- Sur les cartes UFO:AI, une sentinelle sur deux (`UfoMapLevel.patrol_ratio`) fait une ronde autour de son poste ; les autres restent fixes.
- La ronde est tracée une fois la navigation prête (`UfoMapLevel.patrol_route`) : deux points atteignables à 6 à 12 m, de part et d'autre du poste (le premier du côté où regarde la sentinelle), au même étage et sans grand détour ; la sentinelle repasse par son poste entre les deux. Un seul point trouvé : un aller-retour ; aucun : elle reste fixe.
- Une sentinelle en ronde n'est plus fixe : en alerte, elle poursuit comme un soldat.

## Coiffures des opératrices

- Chignon refait : boule enroulée sur elle-même (torsade) tenue par un élastique, haut sur l'arrière du crâne tête nue, plus bas sous un casque ou une casquette pour dépasser sous le bord.
- Cheveux longs refaits : sept mèches effilées qui épousent l'arrière de la tête et tombent sur la nuque, deux mèches qui encadrent le visage, frange de côté tête nue.

## Hachette

- Nouvel équipement « Hachette » (une au plus, 0,9 kg), choisi dans l'écran Opérateurs ou la préparation de mission.
- Au corps à corps (menu circulaire, clic du milieu sur l'ennemi : « Hachette », grisée si aucun opérateur sélectionné n'en porte) : coup de haut en bas, bras armé au-dessus de l'épaule, pas en avant.
- Elle tue net, même de face, sans laisser à la victime le temps de crier ; mais le choc s'entend (1,5 fois le bruit d'un coup de poing). Comme les autres coups, elle est repoussée par un ennemi en garde ; elle achève un ennemi au sol.
- La hachette n'apparaît dans la main que pendant le coup.

## Dégâts au décor (2.14 a)

- Une explosion (grenade, charge) détruit les caisses et bidons tout près (moins de 45 % de son rayon) et projette les autres, jusqu'à 2,5 m, dans l'axe du souffle et jusqu'au premier obstacle. Un objet sur lequel se tient un opérateur, ou qu'il pousse, ne bouge pas.
- Murs fragiles (`FragileWall`, briques fissurées) : ils arrêtent la vue et les balles, mais une explosion proche les abat et ouvre un passage. Le terrain d'essai en a un, au sud-ouest.
- Éclats projetés qui retombent et restent quelques secondes au sol (`Debris`). La navigation est recalculée ; l'état (détruit, abattu) est sauvegardé par la sauvegarde rapide.

## Tir libre

- Touche « : » (AZERTY, à droite de « ; ») ou bouton « Tir libre », puis clic gauche sur un mur, un objet ou le sol : chaque opérateur sélectionné s'approche à portée s'il le faut, épaule et tire une rafale de 5 coups sur ce point (rechargement compris). Se prépare aussi en ordres simultanés.
- Chaque balle part avec un écart qui dépend de la distance et de la précision de l'arme, et s'arrête sur le premier obstacle (gerbe de poussière) ; un ennemi sur la trajectoire est touché.
- Les objets destructibles cèdent sous les balles : mur fragile (environ 9 coups de carabine), caisse (7), bidon (4). Un objet sur lequel se tient un opérateur, ou qu'il pousse, ne cède pas.
- Bruyant comme tout tir.

## Corps : porter, déposer, cacher (2.2)

- Touche « ! » (AZERTY, à droite de « : ») ou bouton « Porter », puis clic gauche sur un ennemi mort ou assommé : l'opérateur sélectionné le plus proche va le prendre sur ses épaules. De nouveau « ! » : il le dépose le long de son flanc droit. Se prépare aussi en ordres simultanés.
- Le porteur marche lentement (60 % de la marche), reste debout, arme à la bretelle : ni tir, ni lancer, ni escalade, ni corps à corps. Mort, il lâche le corps ; un ennemi assommé qui se réveille sur ses épaules lui échappe.
- Un ennemi qui voit un corps (mort ou assommé) pas encore découvert crie (les ennemis proches accourent) et passe en alerte vers lui. La fumée et les murs cachent le corps comme un opérateur.
- Cachettes (`HidingSpot`) : buisson, eau (le corps s'y enfonce) et abri ; un corps sous un toit est aussi caché. Le terrain d'essai a un buisson et une mare à l'ouest.
- Le corps porté et l'état « découvert » sont gardés par la sauvegarde rapide.

## Paquet Web : cartes et textures embarquées

- `tools/web_pack.py` copie trois cartes UFO:AI (par défaut celles du catalogue : `training_a`, `training_b`, `fighter_crash`) et les seules textures qu'elles utilisent, plus celles des scènes du jeu, dans `web_assets/` (images gardées telles quelles, importeur `keep`) ; il complète le filtre d'inclusion du préréglage Web. Options `--maps`, `--export`, `--clean`.
- Sur le Web, `AssetPaths` lit `res://web_assets/maps` et `res://web_assets/textures` quand le paquet est présent.
- Export Web sans fils : `UfoMapLevel._run_in_thread` exécute la tâche dans le fil principal.

## Portes, fenêtres et bâtiments

- `Door` : porte pivotante ; fermée, elle arrête la marche, la vue et les balles. Le seuil est coupé dans la navigation (obstacle) et se passe par un lien (`TraversalLink`, sorte `DOOR`) : une unité qui l'emprunte ouvre la porte en passant, sans changer de posture. Clic droit sur une porte : l'opérateur le plus proche l'ouvre ou la ferme (pas si quelqu'un est dans le passage).
- Porte verrouillée (métal sombre) : réservée aux ennemis, qui ont les clés (couche de navigation 2) ; un opérateur la crochète, accroupi, en 4 s. Une explosion proche ou des balles (tir libre) la font voler en éclats.
- `WallWindow` : fenêtre sans vitre ; la vue et les balles passent au-dessus de l'allège (une unité accroupie reste cachée), on l'enjambe comme un muret.
- `Building` : bâtiment à quatre murs, portes, fenêtres, sol et toit. Opérateur à l'intérieur : vue en coupe (toit et haut des murs effacés en fondu, traversés par les clics). Un corps déposé à l'intérieur est caché. Un bâtiment dans la sandbox (porte avant, porte arrière verrouillée, trois fenêtres).
- Sauvegarde rapide : état des portes (ouverte, verrouillée, détruite).

## Convertible et carte « Base aérienne »

- `TiltrotorModel` : convertible quadrirotor fictif construit en code (d'après trois visuels de référence) : fuselage à facettes au nez en bec et verrière en fentes, deux paires d'ailes épaisses, quatre nacelles chanfreinées numérotées avec prises d'air et feux de position, rotors à 2–6 pales (disque flou à pleine vitesse), tourelle sous le menton, canon latéral, crochets d'élingage, train d'atterrissage. Livrées olive, grise et hiver (camouflage numérique généré). Épave : coque calcinée, pales tordues.
- `Tiltrotor` : l'appareil posé au sol, obstacle (marche, vue, balles) et cible : une explosion près de la coque (charge, grenade) le détruit ; le réservoir saute à son tour (rayon 7 m), l'épave brûle et fume, l'objectif `aircraft_destroyed` est rempli et la mission réussie 3 s plus tard. Sauvegarde rapide de l'état.
- Carte « Base aérienne » (`scenes/levels/airbase/`) : plateforme et convertible au centre, hangar (échelle vers le toit), poste de garde, armurerie verrouillée, murets, caisses, buissons, clôture sud à deux brèches ; sept soldats (deux patrouilles, cinq sentinelles). Objectifs : détruire le convertible sans perdre d'opérateur.
- `Commando.mission_explosives` : charges fournies par le niveau, en plus de l'équipement choisi (Alpha et Charlie en ont une sur la base aérienne).

## Convertible agrandi, soute accessible

- L'appareil est agrandi d'un quart (`Tiltrotor.SCALE`, environ 21 m de long) ; la plateforme de la base aérienne et ses abords suivent (rayon 13,5 m, ronde, murets et caisses écartés).
- Soute ouverte : queue relevée, rampe abaissée jusqu'au sol (bandes jaunes, vérins), plancher, bancs, cloison du cockpit. La collision est creuse (nez, parois, toit, dessus de la queue ; plancher et rampe à part) : la navigation monte la rampe et couvre le plancher.
- Clic droit sur l'appareil : la sélection embarque, les unités à la file dans l'axe de la soute (`SelectionManager.order_board`). Opérateur à bord : coque translucide sans ombre, clics qui la traversent jusqu'au plancher ; les parois le cachent des ennemis (sauf par l'arrière ouvert). Un corps déposé dans la soute est caché.

## HUD : plus de bouton « Quitter »

- Le bouton « Quitter » en haut à droite disparaît du jeu ; on quitte par le menu pause (Échap, « Quitter », avec confirmation).

## Convertible : rampe et pilotage

- Clic milieu sur un opérateur dans la soute : menu circulaire de bord, « Fermer » / « Ouvrir » (la rampe se relève jusqu'au bout de la queue, ou s'abaisse) et « Piloter ».
- Rampe relevée : elle arrête la marche, la vue et les balles ; la navigation est recalculée (plus d'accès à la soute). Impossible tant que quelqu'un se tient dessus. État gardé par la sauvegarde rapide.
- « Piloter » : possible quand tous les opérateurs vivants sont à bord. La rampe se relève, les rotors se lancent (bruit qui alerte la garde), puis l'appareil décolle avec l'équipe ; l'objectif de la carte est rempli (« détruire ou voler ») et la mission réussie.
- En vol, la coque redevient opaque (elle n'est translucide qu'au sol, opérateur à bord).

## Retour au menu sans plantage

- Retour au menu (écran de fin ou menu pause) avec des opérateurs sélectionnés : le HUD, déjà hors de la scène, ne rafraîchit plus ses boutons quand les unités quittent la sélection (le jeu plantait).

## Casque audio : arceau courbe

- Sans casque balistique, le casque audio a un vrai arceau : bande courbe qui passe au sommet de la tête (ou par-dessus casquette, bob, béret, bonnet), coussin sous le sommet, coulisses qui entrent dans les coquilles. La barre droite au-dessus de la tête disparaît.
- Coquilles rapprochées de la tête (`SoldierModel.EAR_CUP_OFFSET`), coussinets contre les tempes ; micro et bras du casque balistique suivent.

## Clic droit : arrêter une unité en route

- Clic droit simple pendant qu'une unité sélectionnée marche ou court vers sa destination : elle s'arrête (`SelectionManager.stop_walkers`, `Commando.is_walking`). Le clic droit suivant donne la nouvelle destination.
- Le double clic droit reste un ordre de course (il redirige sans arrêt) ; en ordres simultanés (Tab), le clic droit prépare toujours un ordre.

## Clic sur un toit : la hauteur est gardée

- Un clic droit sur une surface où l'on peut se tenir (toit, dessus du bunker du didacticiel) garde la hauteur du point visé ; seul un clic sur le flanc d'un mur vise le sol à son pied (`PlayerController.FLAT_SURFACE`). Avant, la destination était ramenée au sol : l'opérateur montait l'échelle, redescendait, remontait et s'arrêtait en haut.

## Fusil PGM Hécate II et tir à longue distance

- Nouvelle arme principale `hecate` (PGM Hécate II, 12,7 mm, à verrou) : portée 48 m (deux fois celle des autres armes), 160 de dégâts (une cible abattue d'un tir), précision qui baisse peu avec la distance ; visée de 1,4 s, un tir toutes les 2,4 s, chargeur de 7 (+14), sans silencieux (détonation entendue à 32 m), 13,8 kg. Choisissable sur l'écran des opérateurs.
- Modèle 3D (`SoldierModel._build_hecate`) : boîtier massif, long canon à frein de bouche, crosse squelette avec monopode, grosse lunette à tourelles, poignée de transport, bipied replié.
- `Commando.mission_primary` : une carte peut imposer l'arme principale d'un opérateur (sans toucher à son profil d'équipe).
- Didacticiel : huitième atelier « Tir à longue distance » (objectif `tuto_sniper`) à l'est du stand de tir ; Charlie y porte l'Hécate et abat trois cibles placées à 40–42 m sans quitter le stand. Les ateliers suivants sont renumérotés.

## Convertible : vol stationnaire, rappel, tir depuis la soute ; carte « Héliportage »

- Menu de bord (clic milieu sur un opérateur dans la soute) : « Ouverture » / « Fermeture » de la porte (la rampe), « Monter » (vol stationnaire à 10 m avec ceux à bord), en vol « Descendre en rappel » et « Atterrir » ; « Piloter » (décollage qui termine la mission) seulement là où il a un sens (`ends_mission`).
- En vol, les opérateurs à bord (`Commando.airborne_in`) ne reçoivent que des ordres de tir. Porte fermée, ils ne tirent pas ; porte ouverte, ils tirent par l'ouverture (la coque n'arrête plus leurs balles, ni leurs tirs manqués).
- Rappel : l'opérateur rejoint le bout de la rampe abaissée et descend une corde jusqu'au sol (2,5 m/s). On n'atterrit pas pendant un rappel ni avec quelqu'un sous l'appareil. La navigation est recalculée à la montée et à l'atterrissage (le sol sous l'appareil se libère en vol). État de vol gardé par la sauvegarde rapide.
- Carte « Héliportage » (`tools/gen_heliport.py`) : le convertible seul sur sa plateforme, l'équipe à côté, trois cibles d'entraînement. Objectifs : monter en vol stationnaire, descendre en rappel, abattre les cibles depuis l'appareil.
- Libellés du menu de bord : « Ouvrir » / « Fermer » deviennent « Ouverture » / « Fermeture ».

## Carte de nuit et vision nocturne

- Nouvelle carte « Nuit sans lune » : un dépôt clos (entrepôt, dortoir, caisses, buissons) gardé par cinq soldats, dont deux en ronde, éclairé seulement par la lune et cinq lampadaires.
- `LevelRoot.night` : sur une carte de nuit, la portée de vue lointaine des ennemis tombe à 55 % (zone proche inchangée), et le filtre de vision nocturne (`NightVision`) est ajouté.
- `Commando.mission_nvg` : la mission équipe les opérateurs de jumelles de vision nocturne, et du casque qui les porte.
- Vision nocturne : la lumière est amplifiée en vert phosphore, avec grain, lignes et vignettage circulaire ; les lampes éblouissent un peu. Les cônes de vision et les marqueurs d'équipe gardent leur teinte, et l'interface reste en couleurs. Elle est allumée d'office si un opérateur vivant porte des JVN ; touche ² (à gauche de 1) pour l'éteindre ou la rallumer. Elle s'éteint quand le dernier porteur tombe.
- Les jumelles s'abaissent devant les yeux des opérateurs quand la vision nocturne est allumée, et se relèvent sur le casque quand elle est éteinte.

## Rangers refaits

- La tige est portée par la jambe et non plus par le pied : elle suit le tibia quelle que soit la flexion de la cheville. À genou, elle ne sort plus de la jambe en équerre.
- Tige plus haute, avec col rembourré, languette, laçage croisé et crochets ; le pantalon blouse sur le haut de la tige ; une rotule comble la pliure de la cheville.
- Pied : talon arrondi, cou-de-pied incliné, bout renforcé et laçage ; semelle crantée au bout arrondi, talon plus épais. Le VIP en civil garde des chaussures basses.
- Un genou à terre : le tibia arrière remonte vers la cheville et le pied se dresse sur la pointe, orteils repliés, semelle crantée vers l'arrière ; il ne s'enfonce plus dans le sol.

## Extraction par le convertible (8.1)

- `Tiltrotor.extraction` : l'appareil n'est pas là au début de la mission (caché, sans collision ; la navigation passe sur son point de pose).
- Clic milieu sur un opérateur au sol : « Appeler l'extraction ». Le convertible arrive de l'arrière en 14 s, rotors lancés ; le bruit des rotors, émis au sol sous lui toutes les 1,5 s, fait accourir les ennemis.
- Au-dessus de son point de pose, il attend que la place soit libre d'opérateurs et de VIP ; les ennemis attirés dessous sont écartés sur le côté au moment du poser. Posé, il abaisse la rampe.
- Il repart seul 1,5 s après que tous les opérateurs vivants et les VIP sont à bord, si les autres objectifs sont remplis (« Extraction : objectifs en cours » sinon) : objectif rempli, « RÉUSSITE — équipe extraite ». Détruit au sol, il fait échouer la mission.
- « Nuit sans lune » : convertible d'extraction au sud du dépôt, nouvel objectif « Repartir à bord du convertible d'extraction » ; l'équipe part plus à l'ouest.
- `Objectives.done_except` et groupe `objectives`.

## Riposte ennemie contre le convertible (8.7)

- En l'air (approche d'extraction, montée, vol stationnaire, descente), le convertible est une cible : un ennemi armé sans opérateur en vue, qui le voit à moins de 1,5 fois sa portée de tir, s'arrête, se tourne vers lui et tire (+15 % de chances de toucher : grande cible). Chaque coup de feu fait du bruit.
- Structure de 400 points ; une balle en ôte le quart de ses dégâts, avec étincelles et ricochet. Jauge « Structure NN % » au-dessus de l'appareil dès la première balle ; fumée sous la moitié.
- À zéro, l'appareil est abattu : atterrissage d'urgence à la verticale avec ceux à bord (« Appareil touché : atterrissage d'urgence »), ou droit sur sa zone pendant une approche. Hors d'usage, il ne revole plus (« appareil endommagé ») ; un appareil d'extraction abattu fait échouer la mission. Sur la base aérienne, l'épave posée peut encore être détruite.
- Il n'est pas visé en partance (la mission est gagnée), ni posé.
- Structure et état « abattu » gardés par la sauvegarde rapide.

## Canon latéral du convertible (8.5)

- Clic milieu sur un opérateur à bord : « Canon latéral » (un seul servant ; « Lâcher le canon » pour arrêter). Au sol comme en vol, le canon tire alors seul sur l'ennemi debout le plus proche qu'il peut atteindre : côté droit de l'appareil, vers l'avant ou le travers, à moins de 40 m.
- Le canon pivote vers sa cible (pièce à part du modèle : boîtier, canon, poignées, caisse de munitions) et tire des rafales de 6 coups (45 de dégâts, écart qui croît avec la distance), traçantes orangées.
- Les balles arrêtées par une caisse, un bidon ou un mur fragile les abîment : un ennemi abrité derrière reste une cible, l'abri cède vite.
- Très bruyant : chaque rafale s'entend à 50 m.
- Le servant qui quitte la soute (marche, rappel) ou tombe lâche le canon.

## Vol tous feux éteints (8.9)

- Sur une carte de nuit, le convertible vole feux de position éteints (`Tiltrotor.blacked_out`). Les ennemis ne le voient qu'à 14 m (au lieu de 1,5 fois leur portée de tir) ; le bruit des rotors, lui, porte toujours et les attire. Sur « Nuit sans lune », les gardes ouvrent le feu à la fin de l'approche plutôt qu'au milieu.
- Une rafale du canon latéral trahit l'appareil pendant 3 s : il redevient visible de loin.
- Un stroboscope infrarouge sur le dos de l'appareil clignote (un éclair toutes les 1,2 s), visible seulement en vision nocturne (`NightVision.viewing`) : l'équipe suit l'appareil, pas les ennemis.
- Extraction : l'appareil cesse d'être une cible dès qu'il touche le sol (avant, les gardes tiraient encore pendant que les rotors ralentissaient).

## Sabre, véhicule léger des forces spéciales

- `SabreModel` : 4×4 ouvert d'après l'Arquus Sabre (dérivé du Sherpa Light), construit en code sur la base `FacetModel` partagée avec le convertible : capot, pare-brise, caisse ouverte, arceau, tourelleau avec 12,7 pivotante, 7,62 latérales, tube antichar, roue de secours, jerricans, antennes ; les roues tournent et braquent.
- `Sabre` : cinq places (volant, chef de bord, arrière gauche, arrière droit, tourelle). Clic droit sur le véhicule : les opérateurs sélectionnés le rejoignent et montent. À bord (`Commando.riding`), un opérateur ne marche plus et tire depuis sa place.
- Conduite : avec un passager sélectionné, clic droit au sol ; le véhicule suit le chemin de navigation à 8 m/s, ralentit dans les virages, s'arrête devant une unité et renonce au bout de 3 s. Le moteur fait du bruit (24 m, toutes les secondes) ; les passagers sont emportés.
- Menu de bord (clic milieu sur un passager) : descendre, tout le monde descend, prendre le volant, passer à la tourelle, ouvrir ou cesser le feu avec la 12,7 (`MountedGun`, tout autour du véhicule, 45 m).
- Sauvegarde rapide : position, cap, équipage et feu de la tourelle.
- Nouvelle carte « Patrouille Sabre » (désert) : piste du départ au point de ralliement, une patrouille et un poste de contrôle ; objectifs : conduire le Sabre au drapeau et neutraliser les gardes.

## Sabre dans la soute du convertible

- Clic droit sur un convertible posé, rampe abaissée, avec un passager du Sabre sélectionné : le véhicule roule jusque derrière la rampe, s'aligne, replie son arceau (tourelleau compris) et ses antennes, monte la rampe en épousant sa pente et se gare à l'avant de la soute (`Sabre.load_into`, `Tiltrotor.cargo`).
- Le convertible l'emporte avec son équipage en vol stationnaire comme au décollage. Dans la soute, la 12,7 est muette ; on monte à bord et on en descend par l'arrière du véhicule.
- Clic droit au sol, appareil posé et rampe abaissée : le Sabre redescend la rampe en marche arrière, redéploie l'arceau et file vers sa destination.
- Sauvegarde rapide : véhicule garé ou non.
- « Patrouille Sabre » : la mission commence à côté d'un convertible d'insertion, le Sabre garé dans sa soute (`Sabre.start_stowed_in`).

## Translucidité dans l'export web

- La coque du convertible (opérateur à bord) et le haut des bâtiments (opérateur à l'intérieur) s'estompent désormais aussi dans l'export web. `GeometryInstance3D.transparency`, ignoré par le rendu Compatibility (WebGL 2), est remplacé par `MeshFade`, qui estompe des copies des matériaux de chaque surface par leur canal alpha.

## Déplacement en vol stationnaire (8.4)

- En vol stationnaire, « Déplacer » dans le menu de bord, puis clic sur la carte : le convertible pivote, vole jusqu'au point (9 m/s, bruit des rotors au sol sous lui) et s'arrête le bout de la rampe au-dessus (`Tiltrotor.fly_to`).
- La corde de rappel descend jusqu'au premier sol sous la rampe (`rope_foot`) : terrain, toit ou caisse. Une équipe se dépose sur un toit, une autre au sol ailleurs.
- L'appareil ne se pose que sur un terrain plat : nez, queue et nacelles au niveau du centre (« terrain impropre » sinon).
- Les passagers et le véhicule en soute suivent l'appareil, rotation comprise ; la sauvegarde rapide garde sa position et son cap.

## Hélitreuillage (8.3)

- En vol stationnaire, porte ouverte : clic droit sur l'appareil avec des opérateurs au sol (ou sur un toit) sélectionnés. Ils rejoignent le pied de la corde et y sont treuillés jusqu'à la soute (`Tiltrotor.request_winch`, 1,8 m/s).
- Un VIP qui se tient au pied de la corde est treuillé aussi (il suit son escorte).
- Pendant un treuillage, l'appareil ne se déplace pas et ne se pose pas.

## Hauteur de vol et bruit (8.10)

- Trois paliers de vol stationnaire : 10, 20 et 30 m (« Prendre de l'altitude » / « Perdre de l'altitude » dans le menu de bord, `Tiltrotor.change_altitude`).
- En vol, les rotors s'entendent en continu (toutes les 2 s en vol stationnaire) au sol sous l'appareil. Le rayon décroît avec la hauteur : 40 m jusqu'au premier palier, 28 m à 20 m, 16 m à 30 m (`rotor_noise_radius`). L'approche de l'appareil d'extraction, à 30 m, est donc plus discrète au début.
- Plus haut, la corde est plus longue : un rappel depuis 30 m prend environ 14 s.
- Le menu affiche, pour chaque palier, le rayon du bruit.

## Insertion en début de mission (8.2)

- `Tiltrotor.insertion` : la mission commence en vol stationnaire à 30 m au-dessus de la place de l'appareil, toute l'équipe en soute, porte ouverte. On le déplace (8.4) et on descend en rappel ; près des sentinelles, le bruit des rotors les alerte (8.10).
- Soute vide, « Renvoyer l'appareil » au menu radio (clic milieu sur un opérateur au sol) : il prend de la hauteur et quitte la zone. S'il est aussi l'appareil d'extraction, « Appeler l'extraction » le fait revenir se poser sur sa zone, dans son cap d'origine.

## Tireur d'élite embarqué (8.6)

- Depuis la soute d'un convertible en vol, un fusil de précision (portée d'au moins 20 m : Hécate, HK417) porte plus loin grâce à la hauteur : +1/30 de sa portée par mètre, jusqu'à 1,6 fois (`Commando.fire_range`). L'Hécate passe de 48 à 77 m à 30 m de haut.
- En vol, les vibrations réduisent la précision de toutes les armes : 85 % de la précision au sol appareil stabilisé, 45 % juste après un mouvement, montée ou déplacement, qui remonte en 4 s (`Tiltrotor.steadiness`).

## Lance-roquettes ennemi (8.8)

- `Enemy.launcher` : un garde porte un lance-roquettes en travers du dos (`SoldierModel.set_launcher`), avec `rockets` roquettes (2 par défaut).
- Contre un convertible en vol à moins de 60 m qu'il voit, il tire en priorité, même s'il a des opérateurs en vue : 2,2 s de visée, une roquette avec un écart de quelques mètres, 6 s de rechargement.
- `Rocket` : file à 34 m/s avec une traînée de fumée. Près de la coque (fusée de proximité), elle explose et ôte 230 points de structure sur 400 (`Tiltrotor.take_rocket`) : deux roquettes abattent l'appareil. Sinon, elle explose sur le premier obstacle (petite charge) ou se perd après 110 m.
- Sans roquettes, il redevient un garde ordinaire ; le tube disparaît. La sauvegarde garde les roquettes restantes.

## Diversion par le convertible (8.11)

- Appareil parti (extraction pas encore appelée, ou insertion renvoyée) : « Diversion » au menu radio, puis clic sur la carte. Il passe une fois en rase-mottes (15 m) au-dessus du point, venu du côté de sa zone de pose, et file au-delà (`Tiltrotor.divert`).
- Pendant le passage, le bruit (34 m, toutes les 0,8 s) rend les sentinelles méfiantes : elles vont voir (`distraction`), sans donner l'alerte.
- Une diversion par mission. L'appareil reste ensuite à appeler pour l'extraction ; abattu pendant le passage, il tombe sur place.

## Ravitaillement dans la soute (8.12)

- « Ravitaillement » au menu de bord du convertible : l'opérateur reprend sa dotation de départ, munitions de réserve des deux armes, grenades, fumigènes, trousses de soins et charges (`Commando.resupply`).
- La soute emporte trois lots (`Tiltrotor.supplies`), un par opérateur ravitaillé ; « rien ne manque » si sa dotation est complète. Un message liste ce qui a été repris.
- La sauvegarde rapide garde les lots restants.

## Évacuation des blessés (8.13)

- Un opérateur blessé (moins de 60 % de sa santé) à bord du convertible : « Évacuer le blessé » au menu de bord. Il quitte la mission, sauvé (`Commando.evacuate`) : caché, hors du groupe des opérateurs, il n'est plus une cible et l'appareil d'extraction ne l'attend plus.
- Il ne compte pas comme perdu (`no_operator_lost` reste rempli). Son portrait affiche « Évacué » et ne se sélectionne plus.
- On n'évacue pas le dernier opérateur. La sauvegarde rapide garde l'évacuation.

## Transport de corps et de documents (8.14)

- `Enemy.documents` : un officier porte une sacoche de documents en cuir à la hanche (`SoldierModel.set_documents`).
- Un opérateur qui passe près de son corps (mort ou assommé, et que personne ne porte) prend les documents : « Documents récupérés », mention « Documents » sur son portrait.
- `Tiltrotor.documents_objective` : l'objectif est rempli dès que les documents sont à bord, sur un opérateur ou avec le corps de l'officier porté dans la soute.
- La sauvegarde rapide garde qui porte les documents.

## Élingage (8.15)

- En vol stationnaire : « Élinguer » au menu de bord accroche, sous les deux crochets du modèle, la caisse déplaçable libre ou le Sabre vide le plus proche (4 m autour des crochets ou du pied de la corde). Elle est hissée en 2,5 s, à 3 m d'élingues.
- La charge suit l'appareil pendant « Déplacer » et les changements d'altitude ; sans collision pendant le transport (navigation et vues recalculées).
- « Larguer la charge » la dépose sous l'appareil, au sol ou sur un toit : bloquer une porte, créer un abri, poser le Sabre ailleurs.
- On n'atterrit pas et on ne renvoie pas l'appareil avec une charge. Abattu, il la lâche sur place. La sauvegarde rapide garde la charge suspendue.

## Raid nocturne sur « Nuit sans lune » (8.16)

- L'équipe commence à bord du convertible (`insertion`), en vol stationnaire à 30 m au sud-ouest du dépôt, hors de portée d'oreille des gardes. Rappel, puis on renvoie l'appareil ; rappelé par radio, il revient se poser au même endroit pour l'extraction.
- `SabotageTarget` : groupe électrogène sur patins au fond de la cour. Une charge qui explose tout près le détruit (carcasse noircie), remplit l'objectif `sabotage` et éteint les lampadaires qu'il alimente.
- Objectifs : saboter le groupe électrogène, repartir à bord, ne perdre personne. Neutraliser tous les gardes n'est plus exigé. Alpha et Bravo reçoivent une charge de la mission.

## Course contre la montre (8.17)

- `Tiltrotor.pickup_window` : appelée, l'extraction ne se pose pas. Elle reste en vol stationnaire au-dessus de son point, porte ouverte, pendant le temps donné ; on y monte au treuil (clic droit sur l'appareil). Ni atterrissage ni déplacement pendant l'attente.
- Décompte au-dessus des opérateurs, toutes les 10 s puis chaque seconde à la fin.
- Elle repart dès que toute l'équipe (et les VIP) est à bord et les objectifs remplis : réussite. À la fin du temps, elle repart avec ceux qui sont à bord : échec s'il manque quelqu'un ou si les objectifs sont inachevés. Abattue pendant l'attente, l'extraction échoue.
- « Patrouille Sabre » : extraction en 60 s à l'ouest du poste de contrôle (objectif `extracted`).

## Appareil ennemi (8.18)

- `EnemyAircraft` : convertible ennemi (livrée grise) en ronde, en boucle sur un chemin (`patrol_path`) à 25 m, à 7 m/s.
- Sous lui, un cercle au sol montre ce qu'il voit : de jour, 10 m de rayon sous et devant l'appareil ; de nuit, la tache de son projecteur (7 m), qui balaie de part et d'autre.
- Un opérateur à découvert dans le cercle (ni dans une cachette, ni sous un toit, ni masqué par un mur) est repéré en 0,5 s : le cercle rougit, puis l'alerte part autour de lui (45 m) et les gardes accourent. Ensuite, 10 s avant une nouvelle alerte.
- Hors d'atteinte : on l'évite. « Nuit sans lune » en a un, qui tourne au-dessus du dépôt.

## Moteur coupé (9.1)

- Au volant du Sabre : « Couper le moteur ». Le véhicule avance en roue libre à 2 m/s, sans aucun bruit, sur 15 m au plus en tout ; ensuite « plus d'élan », et il faut « Relancer le moteur » (bruyant) pour rouler de nouveau.
- La sauvegarde rapide garde l'état du moteur et l'élan restant.

## Phares et conduite de nuit (9.2)

- La nuit, le Sabre roule tous feux éteints : 55 % de sa vitesse, et les sentinelles ne repèrent son équipage que dans la zone proche de leur cône, même le tireur debout à la tourelle.
- Au volant, de nuit : « Allumer les phares ». Deux projecteurs éclairent la route sur 28 m ; le Sabre roule à pleine vitesse, mais une sentinelle qui le voit le repère jusqu'à 45 m, quelle que soit la posture de l'équipage (`Sabre.sight_zone`).
- Correction : au-delà de la portée du cône (cas des phares), la détection montait à reculons ; elle monte désormais au plus lent.
- La sauvegarde rapide garde l'état des phares.

## Structure et pannes du Sabre (9.8)

- Jauge de structure (400 points) au-dessus du Sabre dès le premier dégât, avec l'état des pneus et du moteur.
- Une balle tirée sur un passager touche la carrosserie une fois sur deux (`Sabre.shields_rider`) : le passager est épargné, le véhicule encaisse. Les tirs des opérateurs (et les rafales) qui touchent la caisse l'abîment aussi (`take_shot`).
- Une balle près d'une roue peut crever un pneu (vitesse divisée par deux). Dans le capot, elle use le moteur : il fume à mi-usure, puis lâche (« moteur hors d'usage », véhicule immobilisé).
- Les explosions l'abîment selon la distance (`Explosion.VEHICLES_GROUP`) : structure, moteur, pneus.
- À zéro, c'est une épave noircie et fumante ; l'équipage saute à terre, blessé.
- Clic milieu sur le Sabre, avec un opérateur à pied sélectionné : menu du véhicule, « Réparer ». Il va à l'avant et répare pneus et moteur en 6 s, s'il reste sur place ; la caisse reste abîmée.
- La sauvegarde rapide garde structure, pneus, moteur et épave.

## Le Sabre comme couvert (9.3)

- Menu du véhicule (clic milieu sur le Sabre, opérateurs à pied sélectionnés) : « S'abriter derrière ». Ils se placent côte à côte le long de la caisse, du côté opposé aux ennemis (en alerte ou méfiants, sinon le plus proche), et s'accroupissent.
- Accroupis derrière, les sentinelles ne les voient pas. Une balle tirée sur quelqu'un à travers le véhicule frappe la carrosserie, qui s'abîme (`Sabre.blocks_shot`, jauge de 9.8).
- Refusé quand le Sabre roule, est dans une soute ou est élingué.

## Leurre du moteur au ralenti (9.4)

- « Moteur au ralenti » : au volant, ou depuis le menu du véhicule avec un opérateur à pied à moins de 3,5 m. Le Sabre arrêté fait du bruit (24 m, toutes les 1,5 s), même vide : les gardes deviennent méfiants et viennent voir (`distraction`), sans donner l'alerte.
- Il s'arrête en roulant, si le moteur lâche ou si le véhicule est détruit ; « Couper le ralenti » pour le faire taire.
- Un garde à poste fixe ne quitte pas sa place pour un bruit, mais se tourne désormais vers lui et le surveille (avant, il balayait au hasard) : le leurre détourne aussi son regard.

## 7,62 latérales servies (9.5)

- Le chef de bord (avant droit) et l'arrière gauche servent chacun une mitrailleuse de 7,62 : « 7,62 : feu à volonté » dans le menu de leur place.
- Champ de tir limité : avant et droite pour le chef de bord, arrière et gauche pour l'arrière gauche. Les armes pivotent désormais sur leur bras (`SabreModel.side_gun_pivots`).
- Même composant que la 12,7 (`MountedGun`), mais 32 m de portée au lieu de 45, 35 de dégâts au lieu de 60, et un bruit de 40 m au lieu de 55. Elles tirent aussi en roulant, pas dans une soute ni sur une épave.
- La sauvegarde rapide garde leur état.

## Missile antichar du Sabre (9.6)

- Tout passager sauf le conducteur : « Missile antichar » au menu de sa place, puis clic sur la cible (sol, mur, caisse, ennemi, véhicule), à 90 m au plus, véhicule à l'arrêt.
- Après 2,5 s de visée, interrompue si le Sabre repart ou si le tireur quitte sa place, le missile part du tube avec une traînée de fumée et explose sur le premier obstacle : rayon de 4,5 m, 160 de dégâts, murs fragiles abattus, caisses détruites, véhicules endommagés.
- Un seul missile par mission (`Sabre.missiles`), gardé par la sauvegarde rapide.
- `Rocket` sert aussi au missile : charge réglable, et la fusée de proximité contre les appareils devient optionnelle.

## Tir désigné à la 12,7 (9.7)

- Tireur de la tourelle : « 12,7 : tir désigné », puis clic sur un ennemi ou un objet destructible (caisse, bidon, mur fragile, véhicule).
- La mitrailleuse y concentre son feu, même sans feu à volonté et même si d'autres ennemis sont plus près, tant que la cible tient debout et reste à portée (`MountedGun.designated`). Ensuite elle reprend le feu à volonté s'il était ouvert, sinon elle se tait.
- « 12,7 : cesser le feu » annule aussi la désignation.

## Ravitaillement au Sabre (9.9)

- Les jerricans et les caisses du plateau emportent quatre lots (`Sabre.supplies`). Un opérateur y reprend sa dotation de départ : munitions de réserve, grenades, fumigènes, trousses et charges (`Commando.resupply`, comme dans la soute du convertible).
- À bord : « Se ravitailler » au menu de sa place. À pied : menu du véhicule, « Se ravitailler » ; les opérateurs sélectionnés à qui il manque quelque chose vont au hayon et se servent en arrivant.
- La sauvegarde rapide garde les lots restants.

## Corps et otage sur le plateau du Sabre (9.10)

- Menu du véhicule : « Coucher sur le plateau ». Un opérateur à pied qui porte un corps (ennemi mort ou assommé) ou tient un otage va au hayon et le couche en travers du plateau arrière, ce qui lui libère les mains. L'otage est ligoté : assommé, il ne se réveille pas tant qu'il y reste (`Enemy.on_vehicle`).
- Deux places. Les corps suivent le véhicule, cachés sous la bâche : les gardes ne les découvrent pas. Le corps d'un officier (8.14) remplit l'objectif des documents si le Sabre monte dans la soute du convertible.
- « Décharger le plateau » les dépose au sol derrière le hayon ; on peut aussi reprendre un corps sur l'épaule.
- La sauvegarde rapide garde ce qui est sur le plateau.

## Escorte du VIP en Sabre (9.11)

- Un VIP qui suit un opérateur monté dans le Sabre le rejoint et s'assoit à une place passagère libre (arrière droite, arrière gauche, puis chef de bord). Il ne prend jamais le volant ni la tourelle.
- À bord, il suit le véhicule, profite de la nuit (phares éteints) et de l'abri partiel de la caisse comme un opérateur.
- Il descend avec « Tout le monde descend », ou de lui-même quand le véhicule entre dans la zone d'extraction, ce qui remplit l'objectif d'escorte.
- La sauvegarde rapide garde les VIP à bord.

## Points de passage du Sabre (9.17)

- Passager sélectionné : Maj (sélection additive) + clic droit ajoute un point au bout de l'itinéraire du Sabre. Le véhicule les enchaîne sans s'arrêter, jusqu'à huit points en attente.
- Chaque point en attente est marqué au sol par un disque numéroté, effacé quand le véhicule le passe.
- Un clic droit simple remplace l'itinéraire ; s'arrêter ou une route bloquée l'efface.

## Rouler et débarquer (9.18)

- Menu de bord : « Débarquer à l'arrivée » (ou « Rester à bord à l'arrivée » pour l'annuler).
- Au bout de l'itinéraire, points de passage compris, les passagers sautent à terre et se postent accroupis derrière la caisse, du côté opposé aux ennemis (même placement que « S'abriter derrière »).
- Le conducteur reste au volant et le tireur de la 12,7 à la tourelle, pour couvrir ou repartir. Un VIP reste assis.
- Pas de débarquement sur un arrêt forcé (route bloquée, élan épuisé, ordre d'arrêt).

## Caméra qui suit le véhicule (9.19)

- Tant que le Sabre roule avec un passager sélectionné, la caméra reste centrée sur lui.
- Déplacer la caméra à la main (touches, bord d'écran, glisser) suspend le suivi jusqu'à l'arrêt du véhicule ; il reprend au trajet suivant.
- Option « La caméra suit le véhicule en route » (activée par défaut), dans les options du menu pause et du menu principal.

## Barrage routier (9.13)

- Nouvel objet `RoadBarrier` : deux poteaux, un coffret de commande et une lisse rayée rouge et blanc en travers de la piste. La carte « Patrouille Sabre » en a une à l'entrée du poste de contrôle.
- Forcer : le Sabre qui roule dessus brise la lisse. Le fracas s'entend à 30 m et le véhicule prend de 20 (au pas) à 90 (à pleine vitesse) de dégâts, avec un pneu crevé une fois sur deux au-delà de 70 % de la vitesse.
- Ouvrir : clic droit sur la barrière avec des opérateurs à pied sélectionnés. Le plus proche va au coffret et la lève en 1,2 s, avec un grincement qui ne porte qu'à 3 m ; même geste pour la baisser.
- La lisse n'a pas de collision : les fantassins passent dessous et la navigation n'est pas coupée. La sauvegarde rapide garde son état (levée, brisée).
- Générateur `tools/gen_patrol.py` mis à jour.

## Mines et IED (9.14)

- Nouvel objet `Landmine` : mine antichar ou engin explosif improvisé (`improvised`), enfoui et invisible. « Patrouille Sabre » a un IED sur la piste, à mi-chemin du poste.
- Seuls les véhicules la déclenchent : un Sabre qui roule dessus saute (explosion de 3,5 m, épave, passagers blessés, bruit à 45 m).
- Un opérateur à pied qui passe à moins de 2,5 m (1,5 m de nuit) la repère. Elle est alors balisée d'un fanion « MINE » ou « IED », la navigation la contourne, et le Sabre s'arrête devant au lieu de rouler dessus.
- Clic droit sur une mine repérée avec des opérateurs à pied sélectionnés : le plus proche va la désamorcer, accroupi, en 4 s.
- La sauvegarde rapide garde l'état de chaque mine (repérée, désamorcée, explosée).

## Pick-ups ennemis armés, « technicals » (9.15)

- Nouvel ennemi `Technical` : pick-up avec un chauffeur et un mitrailleur debout derrière une mitrailleuse lourde à bouclier. « Patrouille Sabre » en a un, qui fait sa ronde à l'est du poste.
- Il entend les bruits (moteur du Sabre, tirs, explosions) jusqu'à leur portée plus 10 m et fonce vers le dernier entendu. S'il voit un opérateur ou un VIP (28 m de jour, 13 m de nuit sauf phares allumés, moitié moins pour un opérateur couché), il s'arrête, donne l'alerte et tire par rafales. La caisse du Sabre arrête une partie des balles.
- Faute de nouveau contact pendant 10 s, il reprend sa ronde.
- Destructible : 300 de structure, blindage léger (les balles ne font que 35 % de leurs dégâts). Grenades, charges, mines et missile comptent pleinement. Détruit, c'est une épave noircie et fumante.
- La 12,7 et les 7,62 du Sabre au feu à volonté le prennent pour cible d'elles-mêmes quand aucun ennemi à pied n'est à portée ; le tir désigné marche aussi.
- La sauvegarde rapide garde sa position, sa structure et son épave.

## Convoi de nuit (9.12)

- Nouvelle carte « Convoi de nuit » (générateur `tools/gen_convoy.py`). De nuit, l'équipe ramène son Sabre par une piste sinueuse jusqu'au terrain d'extraction ; le convertible ne repart qu'avec le véhicule dans sa soute.
- Sur la route :
  - un poste fermé par une barrière, avec deux sentinelles sous un lampadaire ;
  - une mine et un IED ;
  - un guetteur et une ronde dans les rochers ;
  - un pick-up armé à l'est ;
  - deux gardes au terrain d'extraction.
- Nouvel objectif de véhicule : `Sabre.stow_objective`, rempli quand le Sabre entre dans la soute d'un convertible. Ici « Faire monter le Sabre dans la soute du convertible d'extraction », exigé avant le départ de l'extraction.
- La caméra de « Patrouille Sabre » et du « Convoi de nuit » couvre toute la carte (100 m), pour la caméra qui suit le véhicule.

## Raid éclair (9.16)

- « Convoi de nuit » devient un raid. Il faut faire sauter un dépôt de carburant au nord-ouest, gardé par une sentinelle et une ronde, puis ramener le Sabre jusqu'à l'extraction.
- Nouveau nœud `Reinforcements` : quand un objectif est rempli (ici le dépôt détruit), un compte à rebours s'affiche en haut de l'écran (« Renforts dans 1:59 »). À zéro, quatre soldats en alerte et un pick-up armé arrivent par le nord et foncent vers le dépôt (`Technical.hunt`).
- Nouvel objectif bonus « Repartir avant l'arrivée des renforts » (`Objectives.OPTIONAL`) : manqué à l'arrivée des renforts, il reste affiché en échec mais ne bloque ni l'extraction ni la réussite.
- `SabotageTarget.fuel` : variante dépôt de carburant (citerne et fûts). Détruit, il s'embrase dans une explosion secondaire qui s'entend à 70 m, et son lampadaire s'éteint.

## Menu principal : liste des cartes lisible

- Chaque carte de la liste n'affiche plus que trois lignes de description (texte complet en infobulle) : les descriptions longues des dernières missions faisaient qu'une seule carte tenait à l'écran.
- La description complète s'affiche dans la préparation de la mission (défilante si elle est longue).
- La liste occupe toute la hauteur disponible de la fenêtre, titre et boutons compris.

## La Tour : immeuble à cinq étages

- Nouvel élément `Tower` (`scripts/props/tower.gd`) : un immeuble de plusieurs étages (cinq par défaut, 3,2 m chacun), avec un toit-terrasse accessible bordé d'un parapet. Ses dalles sont solides : elles arrêtent la vue et les balles. Il a des fenêtres à chaque étage, et des portes (dont une verrouillée) au rez-de-chaussée.
- Un escalier à volées alternées longe le mur nord : deux couloirs séparés par une cloison, des paliers aux deux bouts, une trémie dans chaque dalle avec son garde-corps. La navigation y passe : un opérateur monte du rez-de-chaussée au toit en 13 s environ. Les ennemis en patrouille sur un étage l'empruntent aussi.
- Vue en coupe :
  - quand un opérateur est dans l'immeuble, l'étage le plus bas qu'il occupe s'affiche coupé à hauteur de hanche ;
  - tout ce qui est au-dessus s'efface en fondu : murs, dalles, volées, ainsi que les caisses, les cachettes, les ennemis et les corps ;
  - les touches d'étage (Page suiv. / Page préc.) choisissent aussi l'étage affiché ; `Roof.storey_count` compte les étages des immeubles ;
  - les parties effacées laissent passer les clics.
- Un ennemi dans un immeuble compte comme à couvert pour les corps cachés, comme dans un `Building`.
- Le convertible en attente au-dessus d'un toit valide l'objectif « documents » dès qu'un opérateur qui les porte est treuillé à bord.
- Nouvelle carte « La Tour » (générateur `tools/gen_tower.py`), de jour, en ville :
  - neuf gardes, de la cour jusqu'au toit (rondes intérieures aux 1er et 3e étages) ;
  - un officier au 4e étage porte des documents ;
  - l'extraction attend 90 s en vol stationnaire au-dessus de la terrasse : on y est treuillé.
- Vérifié par scénarios : chemins de navigation vers chaque étage et le toit ; montée à pied, la coupe suivant l'étage ; rendus de la coupe aux 2e et 4e étages ; mission de bout en bout (documents, appel, treuil des trois opérateurs, « RÉUSSITE »). La suite GUT n'a pas été lancée.

## Kit de génération de cartes et « Oued sec »

- `tools/mapkit.py` : outils communs aux générateurs (`MapBuilder`). Il couvre le décor (piste, rochers, buissons, caisses, murs, bâtiments, lampadaires, aire de poser), les unités, les ennemis et leurs rondes, les pick-ups, l'appareil ennemi, les renforts, les véhicules et objets de mission. Il gère le jour et la nuit.
- Nouvelle carte « Oued sec » (`tools/gen_wadi.py`), de jour, en Sabre. Il faut détruire un relais radar retranché (missile antichar, tir désigné ou charge). Sur la piste : un barrage gardé, trois engins (mines et IED), un pick-up armé. À l'arrivée, le Sabre doit monter dans la soute de l'extraction.
- Vérifié par scénario : chemins du départ au relais et à l'extraction ; un missile tiré à 30 m détruit le relais et remplit l'objectif. La suite GUT n'a pas été lancée.

## Kasbah

- Nouvelle carte « Kasbah » (`tools/gen_kasbah.py`), de jour, en ville. On y emploie l'insertion en vol stationnaire (8.2), le déplacement de l'appareil et le rappel sur les toits (8.4), la hauteur de vol (8.10), les documents d'un officier (8.14) et l'extraction au treuil en temps limité (8.3, 8.17).
- Disposition : sept maisons à toit plat et un immeuble de bureaux de trois étages (`Tower`). L'officier est au 2e étage ; des gardes occupent le rez-de-chaussée, le 1er étage, la terrasse et un toit voisin. L'extraction attend 75 s au-dessus de la terrasse.
- `mapkit.add_tower` : immeuble à étages dans les générateurs.
- Vérifié par scénario : chemins de la place jusqu'au 2e étage et à la terrasse, et retour. La suite GUT n'a pas été lancée.

## Nid de frelons

- Nouvelle carte « Nid de frelons » (`tools/gen_hornets.py`), de jour, sur un plateau rocheux. Il faut neutraliser un camp retranché et ses avant-postes. Trois gardes portent des lance-roquettes, dont un qui en a trois (8.8), et le reste du camp riposte contre l'appareil (8.7).
- L'équipe commence en vol stationnaire (8.2). L'appui vient de la soute : le canon latéral (8.5) et Alpha à l'Hécate, plus loin grâce à la hauteur (8.6). La soute a trois lots de ravitaillement (8.12). Le même appareil sert à l'extraction.
- Vérifié par scénario : chemins de la zone de poser au camp et à l'avant-poste ouest. La suite GUT n'a pas été lancée.

## Feux éteints

- Nouvelle carte « Feux éteints » (`tools/gen_blackout.py`), de nuit. Il faut saboter le groupe électrogène d'une station radio, ce qui éteint ses lampadaires.
- On y emploie le vol tous feux éteints (8.9), l'appareil ennemi à projecteur qui tourne au-dessus de la station (8.18) et la diversion par le convertible pour attirer les sentinelles du portail (8.11). Un garde à lance-roquettes punit l'appareil qui vole trop près (8.8).
- Vérifié par scénario : chemins de la zone de poser à la station et au groupe électrogène ; rendu de nuit. La suite GUT n'a pas été lancée.

## Pont aérien

- Nouvelle carte « Pont aérien » (`tools/gen_airlift.py`), de jour. Un ravin infranchissable sépare l'équipe, en vol au nord, de son Sabre resté au sud. Il faut élinguer le véhicule (8.15), lui faire passer le ravin, le larguer, puis le conduire jusqu'au poste d'observation au-delà d'un barrage, d'une mine et d'un pick-up armé.
- `mapkit.wall_line` : murs de 6 m bout à bout entre deux points.
- Vérifié par scénario : le ravin coupe bien la navigation ; l'appareil vole au-dessus du Sabre, l'élingue, le largue rive nord, d'où un chemin mène au poste. La suite GUT n'a pas été lancée.

## Ligne de front

- Nouvelle carte « Ligne de front » (`tools/gen_frontline.py`), de jour. Il faut faire sauter un dépôt de munitions au fond d'une zone tenue (tranchées, bunker, poste de commandement, garde à lance-roquettes).
- 90 s après l'explosion, des renforts arrivent : cinq soldats et un pick-up armé (9.16), avec l'objectif bonus de partir avant eux.
- Le convertible d'insertion et d'extraction sert de base : ravitaillement en soute (8.12) et évacuation des blessés (8.13).
- `mapkit.reinforcements` règle le délai, l'effectif et le pick-up.
- Vérifié par scénario : chemins de la zone de poser au dépôt et au bunker, et du point d'arrivée des renforts au dépôt. La suite GUT n'a pas été lancée.

## Escorte motorisée

- Nouvelle carte « Escorte motorisée » (`tools/gen_motorcade.py`), de jour. Il faut prendre un ambassadeur à la maison sûre et le conduire en Sabre (9.11) jusqu'à la zone d'extraction. En route : un barrage gardé, une mine, un IED, un village tenu en embuscade et deux pick-ups armés.
- On y emploie les points de passage (9.17), le débarquement d'assaut (9.18) et la caméra qui suit le véhicule (9.19).
- `mapkit.vip` et `mapkit.extraction_zone`.
- Vérifié par scénario : le VIP qui suit Alpha monte à bord en 6 s ; le Sabre roule jusqu'à la zone ; le VIP en descend, d'où « RÉUSSITE — VIP évacué ». La suite GUT n'a pas été lancée.

## Col silencieux

- Nouvelle carte « Col silencieux » (`tools/gen_silentpass.py`), de nuit. Il faut faire passer le Sabre par l'unique défilé, entre deux falaises qui barrent la carte, jusqu'au point de ralliement.
- La sortie du col est gardée par deux sentinelles sous un lampadaire et une ronde. On y joue la discrétion : phares (9.2), moteur coupé en roue libre (9.1), leurre du moteur au ralenti (9.4), abri derrière le véhicule (9.3).
- L'extraction attend 60 s en vol stationnaire au-dessus d'une clairière (8.17).
- Vérifié par scénario : chemin du départ au ralliement ; aucun contournement du col (il faut 107 m pour franchir 20 m de falaise). La suite GUT n'a pas été lancée.

## Enlèvement

- Nouvelle carte « Enlèvement » (`tools/gen_snatch.py`), de jour. Il faut enlever un officier dans sa villa fortifiée : l'assommer ou le prendre en otage, le coucher sur le plateau du Sabre (9.10), puis faire monter le véhicule dans la soute de l'extraction. L'officier sur le plateau, ou ses documents (8.14), remplissent l'objectif.
- Gardes au portail, dans la villa et en ronde ; un garde au terrain d'extraction ; un pick-up armé à l'est.
- Vérifié par scénario de bout en bout : officier assommé, porté puis couché sur le plateau ; Sabre chargé dans l'extraction posée ; « documents », « sabre_extracted » puis « RÉUSSITE — équipe extraite ». La suite GUT n'a pas été lancée.

## Embuscade

- Nouvelle carte « Embuscade » (`tools/gen_ambush.py`), de jour. La piste du ralliement traverse une vallée tenue des deux côtés : dix tireurs derrière des murets, une mine, un IED et trois pick-ups armés.
- Il faut nettoyer la vallée au feu du Sabre : 12,7 en feu à volonté ou en tir désigné, 7,62 latérales (9.5), missile. Le véhicule encaisse et se répare (9.8), se ravitaille (9.9) et sert d'abri (9.3).
- L'extraction attend 90 s en vol stationnaire, au treuil.
- Vérifié par scénario : chemin du départ au ralliement ; au rendu, les murets longent la vallée et abritent les tireurs. La suite GUT n'a pas été lancée.

## Mouvement sur la corde du convertible

- Rappel depuis un appareil en vol stationnaire : l'opérateur va au bout de la rampe, saisit la corde et se laisse pendre dessous. Il glisse ensuite jusqu'au sol, en vibrant un peu. Pose : main droite haute, main gauche à hauteur du menton, jambes croisées autour de la corde (pied droit devant, qui freine), arme à la bretelle, regard vers le sol.
- Treuillage : l'opérateur (ou le VIP) pend au crochet, les deux mains serrées au-dessus de la tête, les jambes ballantes qui oscillent à contretemps. Il regarde l'appareil et se balance lentement. Arrivé en haut, il est hissé sur la rampe puis rejoint sa place dans la soute.
- Placement : sur la corde, l'unité fait face à l'appareil, la corde à 24 cm devant la poitrine (`SoldierModel.ROPE_GAP`), les mains sous le point d'attache. Un opérateur accroupi ou couché se relève avant de descendre.
- `SoldierModel.rope_move` (`FAST_ROPE`, `HOIST`) pilote la pose. Le modèle continue de s'animer pendant le trajet, alors que l'unité a son traitement suspendu, sauf quand le jeu est en pause.
- Vérifié par scénario et rendus rapprochés : rappel à 10 m (pose de glissade jusqu'au sol, puis pose normale), treuillage (pose pendue pendant la montée, normale à bord). La suite GUT n'a pas été lancée.

## Montée à la corde main après main

- Au treuil, un opérateur grimpe désormais main après main. Une main serre la corde, bras tendu, et descend jusqu'au ventre pendant que le corps monte ; puis elle lâche, s'ouvre et va reprendre plus haut, en s'écartant de la corde pour passer devant l'autre. Les deux mains alternent à une demi-période d'écart.
- Les jambes serrent la corde, et chaque genou remonte quand la main du même côté tire. Le regard est tourné vers l'appareil.
- Le geste est calé sur la hauteur réellement gagnée (`SoldierModel.ROPE_PULL_LOW`, `ROPE_GRIP_SHARE`) : la main serrée reste immobile sur la corde, à 3 cm près.
- Aidé par le treuil, l'opérateur monte à 1,2 m/s (`Tiltrotor.CLIMB_SPEED`), soit environ trois prises par seconde. Le VIP reste hissé pendu au crochet, à 1,8 m/s.
- Vérifié par scénario : hauteur des mains mesurée pendant la montée, et rendus successifs. La suite GUT n'a pas été lancée.

## Câble du treuil arrêté au crochet

- Pendant un treuillage, le câble ne pend plus jusqu'au sol : il s'arrête au crochet de l'unité accrochée la plus basse, à sa ceinture (`Tiltrotor.HOOK_HEIGHT`, 1 m), et raccourcit avec la montée.
- Un crochet (lest et anneau d'acier) termine le câble du treuil. La corde de rappel n'en a pas.
- Quand plus personne n'est accroché, le câble redescend au sol à 3 m/s (`CABLE_DROP_SPEED`) pour le suivant ; il retombe aussitôt si quelqu'un s'accroche entre-temps.
- Vérifié par scénario : bas du câble à la hauteur de la ceinture pendant la montée (3,09 m pour 3,09 m), redescente en 3 s depuis 8,8 m ; rendu rapproché du crochet. La suite GUT n'a pas été lancée.

## Le VIP grimpe aussi à la corde

- Au treuil, le VIP grimpe désormais main après main, comme les opérateurs, accroché au câble par la ceinture, à la même vitesse (1,2 m/s, `Tiltrotor.CLIMB_SPEED`).
- La pose « pendu au crochet » (`RopeMove.HOIST`) et la vitesse du treuil seul (`WINCH_SPEED`, 1,8 m/s) n'ont plus d'usage et sont retirées.
- Vérifié par scénario : un VIP au pied du câble, sous Alpha qui monte déjà ; sa main serrée reste fixe sur la corde ; il arrive à bord. La suite GUT n'a pas été lancée.

## Tenues civiles et lunettes de soleil

- Deux tenues s'ajoutent au treillis, onglet « Tenue » de l'écran « Opérateurs » (`GearCatalog.CLOTHING`, `OperatorProfile.clothing`) :
  - costume-cravate : veste et pantalon bleu nuit, chemise, cravate, revers, chaussures de ville ;
  - décontractée : blouson ouvert sur un t-shirt chiné, jean, ceinture de cuir, baskets à semelle blanche.
- Les choisir retire l'équipement militaire voyant et met tête nue. En tenue civile, l'étui de cuisse et les couteaux de poitrine disparaissent (portés sous la veste), et le pistolet-mitrailleur se cache une fois à la bretelle.
- Se fondre dans la foule : une mission peut déclarer une tenue de rigueur (`LevelRoot.dress_code`). Un opérateur qui en a l'air (`Commando.looks_civilian` : tenue civile sans rien de militaire, debout, au pas, mains libres, arme compacte cachée) est repéré bien moins vite (`Commando.blend_factor`). Dans la tenue de l'occasion, à distance, la détection plafonne sous le seuil de méfiance ; de près, ×0,25. Une autre tenue civile : ×0,6. Une fois l'alerte donnée, plus d'effet.
- Kasbah demande la tenue décontractée, La Tour le costume-cravate (scènes, générateurs, fiches de mission). `MapBuilder` accepte `dress_code`.
- Nouvel accessoire : lunettes de soleil Oakley (`sunglasses`), enveloppantes, verres miroir, 50 g.
- Vérifié par rendus (les trois tenues, visages, écran « Opérateurs ») et par scénario sur Kasbah, garde à 8,5 m : décontractée, PM à la bretelle, la détection reste à 0,16 ; à 2 m, alerte en 4 s ; en costume, alerte en 2,5 s ; avec une carabine ou le PM en main, alerte en 1,3 s, comme en treillis. La suite GUT n'a pas été lancée.

## Carte « Réception »

- Nouvelle mission (`tools/gen_reception.py`, `scenes/levels/reception/`) : une garden-party de jour dans le parc d'une résidence gardée, tenue de rigueur costume-cravate. Prendre les documents de l'hôte dans son bureau, puis repartir par l'extraction, qui se pose derrière la grille de service au nord.
- L'équipe arrive en costume, pistolet-mitrailleur sous la veste. C'est une tenue imposée par la mission (`Commando.mission_clothing`, `MapBuilder.team(clothing=…)`) ; le profil des opérateurs n'est pas modifié.
- Invités (`Guest`, `MapBuilder.guests`) : civils en costume ou tailleur, apparence tirée d'une graine, par groupes qui bavardent. Ils barrent le passage (la navigation les contourne) sans cacher la vue ni arrêter les balles, et ne réagissent à rien.
- Gardes : deux à la grille d'honneur, à l'écart de l'allée ; un sur le perron, un dans le bureau ; deux rondes dans le parc, une autour de la résidence ; un à la grille de service.
- Objectif bonus `no_alert` (« Ne jamais donner l'alerte ») : il échoue à la première alerte générale sans empêcher la réussite. Il était déjà listé par « Entraînement B » mais n'était géré nulle part.
- Vérifié par scénario. L'équipe, PM à la bretelle, passe la grille et traverse le parc au pas : détection plafonnée à 0,16, aucune méfiance. Dans le bureau, le garde devient méfiant. Chemins de navigation contrôlés (rue, perron, bureau, porte de service, extraction). La suite GUT n'a pas été lancée.

## Cravate et devant du costume refaits

- Cravate : nœud bombé, plus large en haut ; pan qui s'élargit vers le bas ; soie à rayures en biais plus claires. La couleur varie selon le personnage (bordeaux, marine, vert, or, prune) et reste la même pour un même civil.
- Chemise dans l'encolure en V, col à pointes de part et d'autre du nœud, col blanc autour du cou.
- Les revers se croisent au bas du V, comme une veste boutonnée, et cachent le bout de la cravate.
- Toutes ces pièces épousent désormais le buste (`SoldierModel._chest_panel`, `_chest_front`, poitrine féminine comprise) : de profil, elles ne flottent plus en planche devant la poitrine.
- Vérifié par rendus rapprochés (face, trois-quarts, profil ; homme et femme). La suite GUT n'a pas été lancée.

## Blouson de la tenue décontractée refait

- Le t-shirt chiné est plaqué sur le buste, de l'encolure au bas du blouson, avec son col rond.
- Les pans du blouson ouvert ont une épaisseur visible et s'écartent vers le haut. La fermeture éclair court sur leur tranche.
- Poches de poitrine à rabat en relief, avec bouton-pression ; col montant côtelé, ouvert devant ; bas côtelé.
- Les pièces épousent le buste jusqu'à la taille (`_chest_front` étendu sous la poitrine) au lieu de flotter en planches.
- Vérifié par rendus rapprochés (face, trois-quarts, profil ; homme et femme). La suite GUT n'a pas été lancée.

## Réception : quartier autour de la résidence

- La carte passe de 100 × 100 m à 220 × 220 m. La résidence et son parc ne bougent pas ; un quartier résidentiel les entoure.
- Rues goudronnées bordées de trottoirs : deux avenues, une rue nord, des rues ouest et est. Nouvelles bandes `road` et `sidewalk` de `MapBuilder.track`.
- Bâti : deux rangées de maisons de ville entre les avenues, avec une placette (terrasse de café) ; des maisons à jardin à l'ouest et à l'est ; un îlot au nord.
- Ruelles le long des murs de la résidence, avec haies et poubelles. Haies dans les jardins.
- Passants en tenue décontractée (`Guest`, couleurs variées de blouson et de jean) à la terrasse, à l'arrêt de bus et sur les trottoirs.
- L'équipe part du coin sud-ouest. Quatre gardes s'ajoutent (13 en tout) : rondes sur l'avenue et dans les rues ouest et est, guetteur au nord de la pelouse d'atterrissage.
- Vérifié par scénario : l'équipe, PM à la bretelle, va du départ au bureau en une minute environ, sans méfiance dans les rues ni dans le parc ; le garde du bureau devient méfiant de près. Chemins de navigation contrôlés (290 m d'un coin à l'autre). La suite GUT n'a pas été lancée.

## Passants dans les rues

- Nouveau décor `Passerby` (`MapBuilder.passersby`) : un civil qui marche le long d'un tracé, en aller-retour ou en boucle, à son propre pas (vitesses variées).
  - Il tient sa droite pour croiser les autres et change de côté en douceur au demi-tour.
  - Il s'arrête devant quelqu'un (opérateur, garde, VIP, autre passant), puis repart au bout de 2,5 s au plus.
  - Comme les invités, il ne voit rien, ne réagit à rien et ne barre pas le passage. Apparence partagée avec les invités (`Guest.random_look`).
- Réception : 32 passants sur les trottoirs. Une boucle fait le tour de l'îlot de la placette ; des allers-retours suivent les deux avenues et les rues ouest, est et nord.
- Figurants allégés (`CrowdModel`) : hors de l'écran ils ne s'animent pas ; à l'écran, une image sur trois (immobiles) ou sur deux (en marche). Les passants avancent une fois par image et, hors de l'écran, ne sont replacés qu'une image sur dix.
  - Les 54 figurants immobiles de Réception coûtaient environ 26 ms de script par image. La carte passe de 7 à 27 images/s, mesurées pendant qu'une autre partie tournait sur la machine.
  - Avec les 32 passants en marche, elle reste autour de 22 à 29 images/s, autant qu'avec les passants immobiles.
- Vérifié par scénario : cap dans le sens de la marche, demi-tour au bout du trottoir, arrêt devant Alpha puis reprise. La suite GUT n'a pas été lancée.

## Voitures dans les rues

- Nouveau décor `TrafficCar` : une berline procédurale aux couleurs variées, avec caisse, capot et coffre, habitacle vitré, pare-chocs, phares, feux arrière, rétroviseurs et roues qui tournent.
  - Elle roule en boucle sur la voie de droite et accélère ou freine en douceur.
  - Elle s'arrête à environ 1,5 m de son pare-chocs devant quelqu'un (opérateur, garde, VIP, passant) ou derrière une autre voiture. Au bout de 5 s, elle passe quand même.
  - Comme les figurants, elle ne voit rien, ne fait pas de bruit qui compte et ne barre pas le passage.
- `MapBuilder.traffic` décale le tracé des rues sur la voie de droite et arrondit les virages aux carrefours.
- Réception : 7 voitures sur trois boucles (autour de l'îlot de la placette, autour de la résidence, grand tour en sens inverse).
- Vérifié par scénario : 6,8 m/s de moyenne sur sa boucle ; arrêt devant Alpha posé sur la voie (pare-chocs à 1,4 m), reprise quand il s'écarte ; prise de virage dans un carrefour. La suite GUT n'a pas été lancée.

## Voitures abris

- Les voitures (`TrafficCar`, désormais `AnimatableBody3D`) ont une caisse solide sur la couche des obstacles qui cachent la vue, comme les murs et le Sabre. Elle va du ras du sol au toit (1,38 m).
- Elles arrêtent le regard et les balles : un opérateur accroupi ou couché derrière est caché ; debout, il dépasse du toit et reste visible. Elles barrent aussi le passage.
- Devant une unité (opérateur, garde, VIP), une voiture attend sans limite au lieu de passer au bout de 5 s. Devant un passant ou une autre voiture, l'attente maximale reste.
- Vérifié par scénario : garde à 8 m, Alpha derrière une voiture arrêtée. Debout il est vu, accroupi ou couché il ne l'est pas ; la voiture partie, il l'est à nouveau. Alpha posé sur la voie depuis 9 s, la voiture reste arrêtée, pare-chocs à 1,5 m. La suite GUT n'a pas été lancée.

## « S'abriter derrière » une voiture

- Clic milieu sur une voiture civile avec des opérateurs à pied sélectionnés : menu « Voiture », « S'abriter derrière ».
  - La voiture pile, et les places se calculent là où elle s'arrête.
  - Les opérateurs s'y accroupissent côte à côte, du côté opposé aux ennemis (alertés ou méfiants, sinon le plus proche).
  - Elle attend tant qu'un opérateur abrité reste à moins de 3,5 m, et au moins 12 s pour leur laisser le temps d'arriver ; elle repart quand ils s'en vont.
- Le calcul de la menace et des places est commun avec le Sabre (`CoverSpots`). Les gardes morts n'y comptent plus.
- Une voiture arrêtée pour une unité ou un abri (`TrafficCar.halted`) est attendue sans limite par celles qui la suivent. Deux voitures de la même boucle mesurent leur écart le long du tracé : la suivante freine à temps, même au sortir d'un virage.
- Vérifié par scénario :
  - le menu s'ouvre sur la voiture et la voiture s'arrête aussitôt ;
  - Alpha et Bravo, vus debout sur le trottoir par un garde de l'autre côté de la rue, s'accroupissent à 2 m de la voiture, côté opposé, et ne sont plus vus ;
  - la voiture suivante s'arrête 1,6 m derrière, au sortir d'un virage ;
  - après 13 s les deux voitures attendent toujours, et repartent quand les opérateurs s'éloignent.
- La suite GUT n'a pas été lancée.

## Les gardes viennent voir une voiture qui klaxonne

- Une voiture arrêtée pour une unité, pour un abri ou derrière une voiture ainsi arrêtée klaxonne au bout de 5 s, puis toutes les 7 s tant qu'elle reste bloquée (nouveau son `horn`, deux notes tenues).
- Chaque coup de klaxon est un bruit de diversion de 22 m (`TrafficCar.honked`). Les gardes à portée deviennent méfiants sans donner l'alerte, et ils viennent voir à la portière du conducteur ; un garde posté se tourne vers le bruit sans quitter son poste.
- Un arrêt devant un passant ou une autre voiture qui roule ne fait pas klaxonner.
- Vérifié par scénario avec Alpha abrité derrière une voiture :
  - premier coup de klaxon à 6,3 s après l'ordre (le temps de piler, plus 5 s) ;
  - un garde en ronde à 11 m devient méfiant, s'approche, contourne la caisse par l'avant et repère Alpha ;
  - un garde à 40 m ne réagit pas ;
  - un garde posté se tourne vers le bruit sans bouger.
- La suite GUT n'a pas été lancée.

## Jumelles de vision nocturne GPNVG-18

- L'accessoire du casque balistique devient « Jumelles de vision nocturne GPNVG-18 (casque) ».
- Le modèle 3D est refait en panoramique à quatre tubes : un pont large avec un bouton et des molettes, deux tubes centraux devant les yeux avec oculaires, et deux tubes extérieurs plus petits, tournés de 30° vers l'extérieur.
- Relevées, l'appareil bascule vers le ciel au-dessus du front ; abaissées, les quatre tubes passent devant les yeux. Le contrepoids sur la nuque et le support ne changent pas.
- Poids : 0,75 kg (au lieu de 0,6).
- Vérifié par rendu (face, profil, trois-quarts, relevées et abaissées). La suite GUT n'a pas été lancée.

## Vue verte dès que les jumelles sont abaissées

- La vision nocturne (`NightVision`) est installée sur toutes les cartes, plus seulement la nuit. La touche `toggle_nvg` (² par défaut) abaisse ou relève les jumelles de tous les opérateurs qui en portent, et affiche ou retire la vue verte.
- La nuit, rien ne change : jumelles abaissées d'office, forte amplification.
- De jour, elles restent relevées au départ. Abaissées, la vue verte n'amplifie que faiblement la lumière (1,3 au lieu de 6), pour que l'image reste lisible au lieu de virer au blanc.
- Aide (H) et README mis à jour.
- Vérifié par scénario et rendus :
  - de jour (Base aérienne), vue normale au départ ; à la touche, vue verte, et seuls Bravo et Charlie, qui portent des jumelles, les abaissent ;
  - de nuit (Nuit), vue verte d'office ; à la touche, les jumelles se relèvent et la vue verte disparaît.
- La suite GUT n'a pas été lancée.

## Éditeur de mission, étape 1 : informations de mission en ressources

- Nouvelles ressources `MissionInfo` (titre, description, camouflage conseillé, carte UFO:AI requise, place dans le menu, objectifs) et `MissionObjective` (identifiant, proposé dans une liste par l'inspecteur, et texte).
- Chaque mission a son fichier `scenes/levels/<nom>/mission.tres`, à côté de sa scène `<nom>.tscn`. Les 23 entrées du tableau `LevelCatalog.LEVELS` y ont été migrées par `tools/godot/migrate_missions.gd`.
- `LevelCatalog.levels()` lit ces fichiers (triés par `order`) et les garde en mémoire ; `LevelCatalog.reload()` les relit. Le tableau `LEVELS` disparaît ; tests et scripts de rendu passent par `levels()`.
- Vérifié par scénario : le catalogue lu des fichiers est identique à l'ancien tableau, entrée par entrée (23 missions) ; menu, briefing et lancement d'une mission inchangés. La suite GUT n'a pas été lancée.

## Éditeur de mission, étape 2 : décors et unités visibles dans l'éditeur

- Les décors et unités construits par leur script s'affichent dans l'éditeur Godot : bâtiments et tours (portes, fenêtres), haies, mines, barrières, cibles de sabotage, murs fragiles, invités, passants et voitures (au début de leur trajet), Sabre, convertibles, avion ennemi, pick-ups armés, zone d'extraction, ateliers du didacticiel, et les modèles des gardes, opérateurs et VIP.
- Les cartes UFO:AI (Entraînement A et B, Gare du désert) sont construites en aperçu dans l'éditeur, sans placer les unités ni les ennemis.
- Nouveau greffon `addons/mission_editor` (activé) : il pose les textures externes sur la scène de mission ouverte et les retire le temps de chaque enregistrement (point 7.10 a d'`IMPROVEMENTS.md`).
- Rien de ce qui s'affiche dans l'éditeur n'est enregistré : les scripts ne modifient dans l'éditeur aucune propriété enregistrée (les couches de collision des cibles, invités et murs fragiles ne sont plus réglées que dans le jeu).
- Outils de vérification `tools/editor_check` : `run.sh` ouvre et photographie des scènes dans l'éditeur, dans une copie du projet ; `check_all.sh` les enregistre aussi et compare chaque scène enregistrée à l'originale, propriété par propriété.
- Vérifié : les 23 missions s'ouvrent dans l'éditeur sans erreur de script, avec décors, unités et textures ; enregistrées depuis l'éditeur, elles sont identiques aux originales. La suite GUT n'a pas été lancée.

## Éditeur de mission, étape 3 : base du greffon

- Dock « Mission » (panneau de droite) quand une mission est ouverte : titre, réglages de la carte (nuit ou jour avec son éclairage, tenue de rigueur), grille, palette du décor.
- Pose au clic dans la vue 3D : bâtiment, mur de 6 m, tracé de mur, muret, caisse, haie, lampadaire, échelle, route, trottoir, piste. Grille de 0,5 m, rotation par pas de 15° (R / Maj+R), arrêt par clic droit ou Échap ; repère du point visé, du cap et de la longueur du tracé dans la vue. Poses et réglages s'annulent (Ctrl+Z).
- Raccourcis du greffon dans les raccourcis de l'éditeur (« mission_editor »).
- Cartes générées : le dock nomme le générateur. Les générateurs (`tools/mapkit.py`, `write_scene`) écrivent leur nom et une empreinte dans la scène, et refusent d'écraser une carte modifiée depuis ou sans empreinte (`MAPKIT_FORCE=1` pour forcer). Les 17 cartes générées sont estampillées (seules les deux lignes de métadonnées changent) ; le didacticiel, retouché à la main, n'est plus écrasé par `gen_tutorial.py`.
- Vérifié dans l'éditeur (`tools/editor_check/step3.gd`, sur le Terrain d'essai et l'Oued sec) : poses sous le bon parent, au bon cap, enregistrées sans les nœuds d'aperçu ; nuit et tenue annulées puis rétablies ; dock et avertissement affichés. La suite GUT n'a pas été lancée.

## Éditeur de mission, étape 4 : unités, trajets et mission

- Palette complétée : opérateur (nom et numéro suivants), VIP, garde posté, garde en ronde et pick-up armé (avec leur chemin sous `PatrolPaths`), invité, passant, boucle de voitures, porteur des documents, groupe électrogène, dépôt de carburant, zone d'extraction, convertible d'extraction, Sabre.
- Repères dans la vue 3D (`addons/mission_editor/gizmos.gd`) : cône de vue des gardes (zones proche et lointaine, réduite la nuit), trajets des passants et des voitures avec une poignée par point (aimantée à la grille, annulable), portée du klaxon et du moteur du Sabre.
- Dock : section « Informations » (objectifs et leur cible sur la carte, ⚠ si elle manque, clic pour la sélectionner ; ouverture de `mission.tres` dans l'inspecteur, création pour une nouvelle mission, enregistrement avec la scène) ; section « Trajet » pour le passant ou la voiture sélectionné (ajouter, retirer un point).
- Passants et voitures : aperçu replacé au début du trajet quand on en déplace les points (`place_preview`).
- Vérifié dans l'éditeur (`tools/editor_check/step4.gd`, Terrain d'essai) : poses, trajets, poignée, annulations, cibles des objectifs, repères ; la carte enregistrée se joue (ronde, voiture, passant et pick-up en route, porteur des documents, Delta dans l'équipe). La suite GUT n'a pas été lancée.

## Éditeur de mission, étape 5 : vérification, essai, nouvelle mission

- Bouton « Vérifier » (`addons/mission_editor/checker.gd`) : équipe (au moins un opérateur, six au plus), informations de la mission, cible de chaque objectif, trajets des rondes et des pick-ups, plus de 40 gardes, et chemins à pied depuis le premier opérateur vers chaque cible et vers l'extraction (navigation calculée dans l'éditeur). Chaque problème se clique pour sélectionner le nœud en cause.
- Bouton « Essayer » : enregistre la scène et la lance seule ; objectifs, équipe et équipement comme depuis le choix des missions.
- « Nouvelle mission » : nom de dossier, puis scène créée à partir du gabarit (`template.tscn`, écrit par `tools/gen_mission_template.py` : terrain d'herbe de 80 m, trois opérateurs, extraction) et son `mission.tres`, ouverte aussitôt et visible dans le choix des missions.
- Première version de l'éditeur de mission terminée (étapes 1 à 5 de `MISSION_EDITOR.md`).
- Vérifié dans l'éditeur (`tools/editor_check/step5.gd`) : rapport sans problème sur le Terrain d'essai, erreurs volontaires détectées, avertissements justes sur Kasbah (extraction sur le toit, officier à l'étage) et Réception ; nouvelle mission créée, vérifiée, essayée, puis jouée (ronde, porteur des documents, objectifs, titre au catalogue). Les 23 missions de série, ouvertes et enregistrées avec le greffon complet, restent identiques. La suite GUT n'a pas été lancée.

## Éditeur de mission : palette complète (8.1 a)

- Nouveaux éléments dans la palette : immeuble à étages, mine, engin improvisé, barrière (en travers de la route, un muret de chaque côté, comme `MapBuilder.barrier`), avion ennemi (deux clics : son chemin sous `PatrolPaths`), renforts (dirigés vers le dépôt de la carte, sinon la première cible de sabotage), aire de poser.
- L'avion ennemi s'affiche dans l'éditeur au début de son trajet, à son altitude.
- « Vérifier » signale des renforts sans cible valable.
- Vérifié dans l'éditeur (`tools/editor_check/step81a.gd`, Convoi de nuit) puis en jeu : mines actives, barrière, immeuble construit, avion en vol à 25 m, renforts reliés au dépôt. La suite GUT n'a pas été lancée.

## Éditeur de mission : pose sur les toits et les étages (8.1 b)

- Les éléments se posent sur la surface visée : toit d'un bâtiment, étage ou toit d'un immeuble, dessus d'un mur, décor des cartes UFO:AI ; les murs sont traversés. Case « Sur les toits et les étages » dans le dock (cochée par défaut).
- Revêtements, bâtiments, immeubles, buissons, barrières, aire de poser et civils restent au sol ; le second point d'un tracé reste à la hauteur du premier.
- Vérifié dans l'éditeur (`tools/editor_check/step81b.gd`, Kasbah) : garde sur le toit d'une maison (3,4 m) et d'un immeuble (9,6 m), route et case décochée au sol, ronde tracée sur un toit ; en jeu, les gardes y tiennent et la ronde parcourt le toit. La suite GUT n'a pas été lancée.

## Éditeur de mission : chemins par échelles, portes, murets et fenêtres (8.2 a)

- « Vérifier » recrée dans sa navigation les passages que le jeu crée au lancement : échelles, portes (même verrouillées), murets, fenêtres, y compris ceux des bâtiments. Les extrémités viennent d'une fonction partagée avec le jeu (`link_ends()` dans `ladder.gd`, `door.gd`, `low_wall.gd`, `wall_window.gd`).
- Une cible est atteinte à 2 m du bord de son emprise au sol, et non plus à 4 m de son centre (convertible posé sur un toit).
- Fausses alertes levées : hôte de Réception, officier, extraction de Kasbah et de La Tour. Reste, à juste titre, le Sabre d'Héliportage, au-delà du ravin.
- Vérifié en jeu : les passages créés sont identiques avant et après (nombre et positions, Kasbah, Réception, La Tour). La suite GUT n'a pas été lancée.

## Éditeur de mission : carte de couverture des gardes (8.3 a)

- Case « Couverture des gardes » dans la section Carte du dock : le sol se colore par cases de 1 m selon ce que voient les gardes, en rouge la zone proche (vu même accroupi), en jaune la zone lointaine (vu debout), plus soutenu quand plusieurs gardes voient la case. Gardes postés à leur place, gardes en ronde sur tout leur chemin ; de nuit, zone lointaine réduite.
- Recalculée à chaque action (pose, déplacement, Nuit, annulation), jamais enregistrée dans la scène (`addons/mission_editor/coverage.gd`).
- Le dock suit aussi les annulations faites directement sur l'historique de la scène.
- Vérifié (`tools/editor_check/step83a.gd`, Kasbah, Réception, bac à sable) : pour chaque garde posté, cases identiques à celles calculées dans le jeu lancé ; de nuit, 2 483 cases vues à Kasbah tombent à 1 003 ; rien dans la scène enregistrée. La suite GUT n'a pas été lancée.

## Éditeur de mission : rondes tracées point par point (8.1 c)

- Garde en ronde, pick-up armé, avion ennemi et passant se tracent en un clic par point ; double-clic ou Entrée pour finir, Retour arrière pour retirer le dernier point, clic droit ou Échap pour abandonner le tracé (un second pour arrêter l'outil). La vue montre le tracé, le nombre de points et la longueur ; le dock guide chaque étape.
- Le garde est posé au premier point, tourné vers le second.
- Vérifié (`tools/editor_check/step81c.gd`, Terrain d'essai) : ronde de quatre points avec un point retiré, pick-up et passant de trois points, un point seul ne pose rien, abandon au clic droit, annulation. Scénarios précédents adaptés. La suite GUT n'a pas été lancée.

## Éditeur de mission : rondes dessinées (8.1 d)

- Les rondes des gardes, pick-ups armés et avions ennemis sont dessinées dans la vue 3D en vert, la couleur du greffon : bande au sol, chevrons dans le sens de marche, retour au premier point plus pâle, pointillé de l'unité à son premier point. Le dessin suit en direct les retouches faites avec les outils de chemin de Godot.
- Carte de couverture : le retour du dernier point au premier est compté (le garde boucle).
- Vérifié par capture dans l'éditeur (`tools/editor_check/step81c.gd`, Terrain d'essai) : ronde tracée, chemin retouché, garde écarté de son chemin. La suite GUT n'a pas été lancée.

## Éditeur de mission : contrôles de placement (8.2 b)

- « Vérifier » signale aussi : opérateur vu par un garde dès le départ ; unité dans un obstacle ou sur une autre ; caisse ou cible de sabotage qui en chevauche une autre ou un mur ; élément ou point de ronde hors du terrain ou à plus de 10 m des limites de la caméra ; point de ronde hors de la zone praticable ou inaccessible. Un clic sur l'avertissement sélectionne les nœuds en cause.
- Sur les cartes UFO:AI, l'équipe (placée au lancement) n'est pas contrôlée.
- Vérifié (`tools/editor_check/step82b.gd`, Terrain d'essai) : chaque faute posée est signalée, et seulement elle ; sur les 24 cartes, seul un vrai défaut apparaît (Héliportage : `BarrierGuard2` posé dans le muret de la barrière). La suite GUT n'a pas été lancée.

## Héliportage : garde de la barrière hors du muret

- `BarrierGuard2` était posé dans le muret nord-est de la barrière (signalé par les contrôles de placement de l'éditeur) : décalé de 1,2 m vers la piste, en (16,4 ; -15,3), même cap (`tools/gen_airlift.py`, carte régénérée).
- Vérifié : « Vérifier » ne signale plus que le Sabre, au-delà du ravin. La suite GUT n'a pas été lancée.

## Éditeur de mission : terrain choisi à la création (8.1 e)

- Sous « Nouvelle mission », le dock propose la largeur et la profondeur du terrain (40 à 200 m), le sol (herbe, désert, sable, terre, roche, ville) et la nuit. L'équipe, l'extraction, la caméra et ses limites suivent la taille du terrain.
- Vérifié (`tools/editor_check/step81e.gd`) : réglages par défaut, scène identique à la précédente ; mission de 120 × 60 m sur sable, de nuit : sol, couleurs, éclairage, positions et limites justes, « Vérifier » sans problème. La suite GUT n'a pas été lancée.

## Éditeur de mission : limites de la caméra (8.1 f)

- Les limites de déplacement de la caméra (`CameraRig.bounds`) sont dessinées au sol en cadre bleu clair. `CameraRig` sélectionné, une poignée au milieu de chaque bord les règle : aimantée à la grille, gardée sur le terrain, collée à son bord à moins de 1 m, 10 m de côté au moins.
- Bouton « Caler les limites de la caméra sur le terrain » (section Carte) : cadre à 2 m des bords du terrain.
- Vérifié (`tools/editor_check/step81f.gd`, Terrain d'essai) : chaque bord tiré, annulations, geste abandonné, calage et son annulation, limites enregistrées dans la scène. La suite GUT n'a pas été lancée.

## Éditeur de mission : vérification à chaque enregistrement (8.2 c)

- « Vérifier » tourne seule après chaque enregistrement de la mission (case « Vérifier à chaque enregistrement », cochée par défaut). Son résumé (erreurs, avertissements, origine et heure) s'affiche sous le titre du dock ; un clic montre le rapport. Un enregistrement pendant une vérification en relance une à la fin.
- Vérifié (`tools/editor_check/step82c.gd`, Terrain d'essai) : résumé après Ctrl+S, faute signalée à l'enregistrement, seconde vérification en attente puis lancée, case décochée sans effet, résumé masqué à l'ouverture d'une autre scène. La suite GUT n'a pas été lancée.

## Éditeur de mission : chemins par une corde de grappin (8.2 d)

- « Vérifier » cherche, pour une cible qu'aucun chemin n'atteint, une corde de grappin lancée depuis la zone atteinte par l'équipe, avec le calcul du jeu (`GrapnelRope.plan`, qui accepte désormais une carte de navigation). Trouvée, la ligne (✓) dit d'où la lancer et rappelle d'emporter un grappin ; sinon l'avertissement précise « même avec une corde de grappin ».
- Vérifié (`tools/editor_check/step82d.gd`, Terrain d'essai) : extraction sur un toit de 3,2 m sans échelle, atteinte par corde ; cible sur un toit de 10,2 m, signalée. En jeu, Alpha, avec un grappin, monte sur ce toit par la corde. Sur les 23 cartes de série, rien de nouveau, moins d'une seconde par carte. La suite GUT n'a pas été lancée.

## Éditeur de mission : rondes et trajets animés (8.3 b)

- Section « Animation » du dock : ▶ Lecture, barre de temps de 3 minutes, vitesse × 1 à × 8, ⏮. Gardes en ronde (avec leur cône de vue), pick-ups armés, avions ennemis (et leur cercle de détection), passants et voitures avancent dans la vue 3D comme en jeu ; silhouettes jamais enregistrées, refaites à chaque modification.
- Comparé au jeu lancé à 5, 10, 20 et 40 s (Réception, Blackout, Convoi) : 50 unités sur 52 à moins de 2 m ; restent une voiture retenue derrière une autre et le pick-up, qui ralentit dans les virages.
- Correction : une vérification en cours (lancée par l'enregistrement) n'échoue plus quand on ouvre une autre scène ; elle s'arrête.
- Vérifié (`tools/editor_check/step83b.gd`) : lecture, barre de temps, modification, enregistrement sans silhouettes, retour au début. La suite GUT n'a pas été lancée.

## Éditeur de mission : vue du jeu (8.3 c)

- Bouton « Vue du jeu » (section Carte) : fenêtre qui montre la carte sous l'angle, l'orientation et le zoom de départ de la caméra du jeu, centrée sur `CameraRig`. Glisser pour la déplacer (dans les limites de la caméra), molette ou − / + pour zoomer (dans les bornes du jeu), ⟲ / ⟳ pour tourner de 45°, « Départ » pour revenir. La fenêtre suit la scène ouverte.
- Vérifié (`tools/editor_check/step83c.gd`, Kasbah) : caméra à la même position et de la même taille qu'au lancement du jeu, même cadrage ; zoom borné, déplacement gardé dans les limites, retour au départ, changement de scène. La suite GUT n'a pas été lancée.

## Éditeur de mission : événements et zones de déclenchement (8.4 d)

- Jeu : zone de déclenchement (`TriggerZone`, invisible) : le premier opérateur qui y entre déclenche l'événement qu'elle désigne, une seule fois (sauvegarde rapide comprise). Les renforts (`Reinforcements`) se lancent par leur objectif, par une zone, ou les deux ; sans cible, ils foncent vers la zone qui les a appelés ; `announce` décoché, ils arrivent sans compte à rebours ni alerte ; `count` à 0 : un pick-up seul.
- Palette, nouvelle catégorie « Événements » : Renforts, Pick-up qui arrive, Zone de déclenchement (deux clics, reliée à l'événement sélectionné ou choisi dans le dock).
- Section « Événements » du dock : une fiche par événement (déclenchement, objectif déclencheur, délai, soldats, pick-up, annonce), « Tracer une zone ». Repères dans la vue : zones à poignées de coin, liens vers leur événement, point et places d'arrivée, trait vers la cible.
- Vérification : événement que rien ne déclenche, objectif déclencheur absent de la mission, zone sans événement, zone sans chemin depuis l'équipe, arrivants hors du terrain.
- Vérifié (`tools/editor_check/step84d.gd`, puis en jeu sur la carte enregistrée) : la zone lance le pick-up une seule fois, sans annonce ; l'autre lance les renforts annoncés (« Renforts dans 0:15 ») ; tous arrivent et foncent vers leur zone. La suite GUT n'a pas été lancée.

## Éditeur de mission : carte UFO:AI comme fond (8.6 b)

- « Nouvelle mission » propose un fond : terrain plat, ou l'une des cartes UFO:AI entières du dossier des cartes. La carte remplace le terrain plat ; une fois construite, l'équipe se place sur ses départs, l'extraction sur le départ d'alien le plus éloigné, la caméra et ses limites sur la carte ; avec « Gardes », un garde posté sur chaque départ d'alien à plus de 15 m de l'équipe. On y ajoute ensuite ses éléments comme sur une autre carte.
- Jeu : `UfoMapLevel` donne les départs de la carte (`player_starts`, `alien_starts`), aussi dans l'éditeur ; sans `units_parent` ni `enemies_parent`, la mission garde ses propres unités (c'était déjà le cas).
- Vérification : sur une carte de fond, l'équipe est contrôlée comme ailleurs (elle n'est sautée que si la carte la place au lancement) ; le terrain des contrôles et du calage de la caméra est l'emprise de la carte.
- Vérifié (`tools/editor_check/step86b.gd`, carte « office ») : mission créée en 7 s, 3 opérateurs, extraction, 16 gardes ; en jeu : 17 ennemis (les gardes posés et une ronde, pas de sentinelles ajoutées), équipe à sa place, Alpha suit la navigation jusqu'à son but. La suite GUT n'a pas été lancée.

## Éditeur de mission : relief et bâtiments dessinés (8.6 a)

- Jeu : plateau (`Terrace`) aux flancs à pic et à rampes, dont le dessus est un sol où l'on marche et les flancs un obstacle ; bâtiment dessiné (`DrawnBuilding`) fait de pièces rectangulaires par étage, aux murs partagés, avec portes (celles de l'immeuble), fenêtres et volées d'escalier ; il hérite de l'immeuble sa coupe par étage et le niveau de vue.
- Palette, catégorie « Relief et plans » : Plateau, Pièce, Porte, Fenêtre, Escalier. Section « Relief et bâtiments dessinés » du dock : étage où poser, contenu du bâtiment sélectionné, retrait du dernier élément. Chaque geste s'annule ; un plateau ou un bâtiment se reconstruit dès qu'un réglage change.
- Vérification : bâtiment sans pièce, ouverture loin des murs, escalier hors des pièces de son étage.
- Vérifié (`tools/editor_check/step86a.gd`, puis en jeu) : extractions sur le plateau, dans la seconde pièce et à l'étage toutes atteintes, dans la vérification comme en jeu (rampe, porte intérieure, escalier) ; coupe au rez-de-chaussée puis à l'étage. La suite GUT n'a pas été lancée.

## Cartes de série reprises dans l'éditeur (8.5 b)

- Les 17 cartes générées (Base aérienne, Pont aérien, Embuscade, Feux éteints, Convoi de nuit, Ligne de front, Héliportage, Nid de frelons, Kasbah, Escorte motorisée, Nuit sans lune, Patrouille Sabre, Réception, Col silencieux, Enlèvement, La Tour, Oued sec) sont désormais des scènes enregistrées par l'éditeur Godot, sans métadonnées de génération : elles se modifient dans l'éditeur de mission, sans avertissement du dock.
- Leurs générateurs `tools/gen_*.py` et celui du didacticiel sont retirés du dépôt ; restent `tools/mapkit.py` et `tools/gen_mission_template.py` (gabarit des nouvelles missions).
- Vérifié carte par carte (`tools/editor_check/check_all.sh` puis `compare.gd`) : chaque scène reprise est identique à la scène générée, nœud par nœud et propriété par propriété, aux deux métadonnées de génération près. La suite GUT n'a pas été lancée.

## Éditeur de mission : objectifs dans le dock (8.4 c)

- Section « Informations » : chaque objectif se modifie sur place, avec son identifiant (liste du jeu), son texte, ↑ / ↓ pour l'ordre du journal et ✕ pour le retirer ; « + Ajouter un objectif… » en ajoute un, avec un texte proposé. L'état des cibles (✓, ⚠, •) reste affiché à côté. Chaque changement s'annule par Ctrl+Z ; `mission.tres` est enregistré avec la scène.
- Vérifié (`tools/editor_check/step84c.gd`, Kasbah) : texte, identifiant, ajout, ordre, retrait, annulation et rétablissement, enregistrement, puis objectifs relus dans le catalogue du jeu dans le nouvel ordre. La suite GUT n'a pas été lancée.

## Ouïe des ennemis (2.1)

- `HearingComponent` sur chaque ennemi : il entend tous les bruits du jeu dans leur rayon, réduit de moitié à travers un mur. Cris, appels à l'aide, coups de feu (y compris ceux des opérateurs, selon le silencieux) et explosions donnent l'alerte : il court à la source.
- Pas de course, coups, couteau raté qui tombe, réception d'un saut, caisse poussée, équipement lourd, fumigène et appâts le rendent méfiant : il va voir (activité `Investigate`), regarde autour de lui, puis reprend sa ronde. Un bruit faible le fait seulement se tourner.
- Nouveau bruit : les pas d'un opérateur qui court debout (2,5 m) ; la marche reste silencieuse. La réception d'un saut (4 m) est désormais entendue (point 7.8 a).
- `Enemy.startle` est retiré : le couteau raté et les ennemis épargnés par une explosion réagissent à leur bruit.
- Vérifié en jeu sur le bac à sable (pas dans le dos, coup faible, caillou, tir derrière le bunker et à découvert, explosion, couteau tombé, cri, fumigène trop loin, sauvegarde rapide pendant une enquête). La suite GUT n'a pas été lancée.

## Fouille et retour des ennemis (2.4)

- Cible perdue : l'ennemi fouille les environs du dernier point connu (trois points, regard autour de chacun), méfiant, puis rentre au point de sa ronde le plus proche, ou à son poste et à son cap pour un garde sans ronde. Un garde fixe fouille du regard.
- Après une fouille, il reste plus vigilant pendant 90 s (jauge de détection 1,5 fois plus rapide).
- Un bruit entendu en pleine fouille la déplace ; une enquête sur un bruit se termine aussi par le retour au poste.
- Fouille, retour et vigilance sont gardés par la sauvegarde rapide.
- Vérifié en jeu sur le bac à sable : alerte sans cible, fouille, reprise de la ronde ; garde sans ronde revenu à son poste et à son cap ; caillou ; bruit en pleine fouille ; sauvegarde pendant une fouille ; alerte en 1,2 s au lieu de 1,8 s quand il est vigilant. La suite GUT n'a pas été lancée.

## Regard des ennemis en patrouille (2.7)

- Au calme, les ennemis jettent des coups d'œil sur le côté au hasard (25 à 55°), balaient du regard pendant leurs pauses (±60°) et font des haltes imprévues en route. Le cône de vision et la tête suivent le regard.
- Plus vigilants après une fouille : coups d'œil plus fréquents et plus larges.
- Vérifié en jeu sur le bac à sable : 6 coups d'œil et 2 haltes en 60 s de ronde ; un opérateur à 50° sur le côté n'est vu que pendant un coup d'œil ; en alerte, le regard revient dans l'axe. La suite GUT n'a pas été lancée.

## Ravitaillement à ramasser (2.10)

- Nouvel objet `SupplyPickup` : chargeurs, grenades, fumigènes ou trousse de soins, avec son modèle et un repère au sol de sa couleur. Un opérateur à pied qui passe dessus prend ce qui lui manque (dans la limite de sa dotation de départ, au moins 2 grenades, 2 fumigènes et 1 trousse) ; le reste du lot demeure pour un autre. Texte flottant au ramassage.
- Un ennemi armé abattu laisse un chargeur à côté de son corps.
- Éditeur de mission : catégorie « Ravitaillement » dans la palette (parent `Pickups`).
- Sauvegarde rapide : quantité restante des lots de la carte et chargeur de chaque ennemi.
- Vérifié en jeu sur le bac à sable (opérateur à sec, grenades partagées entre deux opérateurs, opérateur déjà pourvu, trousse ramassée puis utilisée, chargeur d'un ennemi abattu, rien pour un mannequin sans arme, sauvegarde rapide) et par un rendu des quatre modèles. La suite GUT n'a pas été lancée.

## Couverture (2.12)

- Derrière une caisse, un muret ou à l'angle d'un mur, une cible est plus dure à toucher : la chance de toucher dépend de la part du corps visible depuis l'arme (`Cover`), et une balle manquée finit souvent dans l'abri.
- S'applique aux tirs des ennemis, des opérateurs et des pick-up armés.
- Vérifié en jeu sur le bac à sable, 200 tirs par cas à 8-9 m : 56 % de touchés à découvert, 33 % debout derrière une caisse (moitié du corps visible), 40 % à l'angle d'un mur (deux tiers), aucun accroupi derrière la caisse ; balles manquées arrêtées par la caisse ou le mur. La suite GUT n'a pas été lancée.

## Occlusion des cartes faites main (7.5)

- Un mur, un bâtiment ou un décor solide qui cache un opérateur à la caméra s'estompe en fondu (25 % d'opacité), puis revient quand plus personne n'est derrière. Les clics le traversent tant qu'il est estompé.
- Le fondu se combine avec l'effacement des toits et la coupe des immeubles.
- Les cartes UFO:AI gardent leur propre découpe.
- Vérifié en jeu sur le bac à sable par des rendus (Alpha derrière le bunker, puis dans un bâtiment). La suite GUT n'a pas été lancée.

## Hasard rejouable (1.2)

- `GameRng` : chaque unité a son propre générateur, dont la graine dérive de la graine de la mission. Parade, esquive, précision des tirs et du lancer, couverture, véhicules, regard et fouille des ennemis l'utilisent ; les effets visuels gardent le hasard global.
- La graine de la mission est affichée dans la console au lancement ; `-- --seed=N` la rejoue. La sauvegarde rapide garde l'état des générateurs.
- Les tests imposent la graine 1234 (`GameRng.forced_seed`).
- Vérifié en jeu : 40 tirs d'un ennemi identiques avec la même graine, différents avec une autre, et identiques après une sauvegarde rapide au milieu. Tests de parade, désarmement, équipement, tirs, otage, prises, lancer, tir libre et fusil à pompe au vert ; suite complète non relancée.

## Page « Configuration »

- Menu de démarrage : bouton « Configuration », qui ouvre la page du même nom. Pour l'instant, une option : son activé ou coupé (enregistrée, appliquée aussitôt ; les volumes des options sont gardés).
- Vérifié en jeu (rendu du menu et de la page ; son coupé puis rétabli ; Échap). Tests du menu au vert.

## Page « Configuration » : volume

- Son activé, une barre règle le volume général (0 à 100 %, enregistré ; c'est le même réglage que « Volume général » des options). Son coupé, la barre est masquée.
- Vérifié en jeu (rendu de la page, barre masquée son coupé).

## IA ennemie en machine à états (1.3)

- `enemy.gd` (1 640 lignes) est découpé : un état par comportement dans `scripts/enemies/behaviors/` (`EnemyPatrol`, `EnemyWatch`, `EnemyInvestigate`, `EnemySearch`, `EnemyReturn`, `EnemyChase`, `EnemyStunned`, `EnemyGrabbed`, `EnemyDisarmed`), et trois composants : tir (`EnemyGunner`), corps à corps (`EnemyBrawler`), regard (`EnemyGaze`). `enemy.gd` garde la perception, les transitions, les corps et la sauvegarde.
- Comportement inchangé. Vérifié en jeu, ancien et nouveau code avec la même graine : corps à corps, poussée, saisie et cris, réveil, fouille, sauvegarde rapide et rechargement, désarmement donnent les mêmes résultats ; ouïe, fouille et retour, regard et couverture se comportent comme avant. Seul changement : un ennemi assommé ou saisi n'affiche plus d'activité périmée.
- Tests mis à jour pour les nouveaux noms (`stunned_behavior.left`, `brawler.cooldown`, `patrol_behavior.pause_left`, `EnemyBrawler.FLANK_ANGLE`, `EnemyGrabbed.HELP_DELAY`). Suite GUT non lancée.


## Ctrl + chiffre : sélection et centrage

- Ctrl + chiffre (rangée du haut) sélectionne l'opérateur et centre la caméra sur lui (action `select_focus` de l'InputMap, Ctrl par défaut). Le chiffre seul ne fait que sélectionner, comme avant.
- Aide en jeu et README mis à jour. Vérifié en jeu.

## Date, heure et durée de l'opération

- En haut à droite, avant l'alerte : « Opération du 22/11/2026 à 14:32 » (lancement de la mission, heure locale) et un chronomètre de la durée (temps de jeu, arrêté pendant les pauses).
- L'écran de fin rappelle la date et la durée de l'opération. La sauvegarde rapide les garde.
- Vérifié en jeu (rendus du HUD et de l'écran de fin ; chronomètre arrêté en pause, rendu au rechargement).

## Date et heure fictives des missions

- `MissionInfo` : champs `date` (« JJ/MM/AAAA ») et `time` (« HH:MM ») de l'opération, réglables dans l'inspecteur depuis l'éditeur de mission (« Titre, description, camouflage, date : inspecteur »). Affichés en jeu (en haut à droite, écran de fin) et dans la préparation de la mission ; vides ou invalides, ce sont la date et l'heure du lancement.
- Les quatre missions de nuit ont une heure nocturne : Feux éteints 02:30, Nuit sans lune 01:45, Convoi de nuit 03:10, Col silencieux 04:20 (date : celle du lancement).
- Vérifié en jeu (Nuit sans lune à 01:45, Terrain d'essai à l'heure du lancement, préparation de Feux éteints).

## Tir sur ordre : de sa place

- Clic droit sur un ennemi : l'opérateur tire de là où il est. Hors de portée ou derrière un obstacle, il ne s'approche plus : il garde l'ennemi en joue, affiche « Hors de portée » ou l'obstacle, et tire dès que la cible passe à portée. C'est au joueur de le rapprocher.
- Aide en jeu et README mis à jour ; tests du tir adaptés (l'opérateur est placé à portée).
- Vérifié en jeu : immobile hors de portée, tir dès que la cible est à portée ; le stand de tir du didacticiel reste à portée (13 m pour 16 m).

## « Kasbah » devient « Centre de commandement »

- La carte s'appelle désormais « Centre de commandement » (titre du menu, de la préparation et du HUD ; nœud racine de la scène). Le dossier devient `scenes/levels/command_center/` (scène `command_center.tscn`).


## Carte polaire : « Station polaire »

- Nouvelle mission « Station polaire » (`scenes/levels/polar_station/`), de jour, 110 × 96 m, sur sol enneigé : une station de recherche aux bâtiments rouges dans une enceinte (portail au sud, brèche à l'est), un groupe électrogène à saboter (il éteint les lampadaires), une crête de glace à l'ouest, un lac gelé à l'est, des congères, des sapins. Huit gardes : deux au portail, une ronde dehors, une dedans, un guetteur sur la crête, un au groupe électrogène, un devant le dortoir, un autour du lac. Camouflage conseillé : neige.
- Lumière froide et brume légère, chute de neige continue.
- `SnowPine` : sapin enneigé procédural ; le tronc arrête la vue et les balles.
- `Snowfall` : particules de neige qui suivent la caméra.
- Éditeur de mission : sol « Neige » pour une nouvelle mission ; « Sapin enneigé » et « Chute de neige » dans la palette (Décor).

## Carte urbaine sous la pluie : « Quartier sous la pluie »

- Nouvelle mission « Quartier sous la pluie » (`scenes/levels/rainy_district/`), en fin de journée, 120 × 124 m : quatre rues avec trottoirs et passages piétons, huit immeubles de deux à six niveaux (escaliers, toits-terrasses), des boutiques, voitures et passants, des flaques, des lampadaires allumés.
- Objectif : prendre les documents de l'officier, au 4e étage du siège, et les rapporter à bord du convertible d'extraction, sur la place nord-est. Quatorze gardes : dans les rues, à chaque niveau du siège, sur les toits.
- Ciel bas, lumière grise, brume, sol mouillé (brillant).
- `Rainfall` : pluie en traits fins qui suit la caméra, avec le bruit de l'averse (boucle synthétisée, bus SFX).
- `WeatherParticles` : base commune de la neige (`Snowfall`) et de la pluie.
- Éditeur de mission : « Pluie » dans la palette (Décor). Les deux nouvelles cartes s'ouvrent et s'enregistrent dans l'éditeur sans changement.

## Ligoter un ennemi assommé (2.3)

- Menu de corps à corps (clic du milieu) : « Ligoter », sur un ennemi assommé. L'opérateur s'en approche, s'accroupit 3 s et lui lie poignets et chevilles : il ne se réveille plus de la mission (marque « ligoté » au-dessus de lui). Un nouvel ordre ou un corps emporté interrompt le geste.
- On peut toujours le porter, le cacher ou l'achever. L'état est gardé par la sauvegarde rapide.
