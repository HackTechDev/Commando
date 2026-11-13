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
