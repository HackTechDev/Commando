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
