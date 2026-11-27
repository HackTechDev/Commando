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
2. Sur la ligne en dessous, choisissez le terrain : largeur et profondeur (de 40 à 200 m, par pas de 10 ; ici 80 × 80), sol (Herbe, Désert, Sable, Terre, Roche, Ville, Neige ; ici Herbe) et **Nuit** (laissez-la décochée : on la règle à l'étape 4).
3. Cliquez sur **Nouvelle mission** (ou appuyez sur Entrée).

Le greffon crée deux fichiers et ouvre la scène :

- `scenes/levels/raid_depot/raid_depot.tscn` : terrain de la taille et du sol choisis, de jour ou de nuit, trois opérateurs (Alpha, Bravo, Charlie) à 6 m du bord sud, zone d'extraction à 6 m du bord nord, caméra sur l'équipe, limites de la caméra à 2 m des bords ;
- `scenes/levels/raid_depot/mission.tres` : titre « Raid Depot », placée après les missions existantes, objectif « extracted ».

La mission figure déjà dans le choix des missions du jeu.

Si le dossier existe déjà, ou si le nom n'est pas valable, le dock l'indique en orange et ne crée rien.

**Partir d'une carte UFO:AI.** La troisième ligne choisit le fond : **Terrain plat** (par défaut), ou l'une des cartes UFO:AI entières du dossier des cartes (`../CommandoAsset/maps`, fichiers `.map` à sa racine). Avec une carte, la taille et le sol ne servent pas : le greffon remplace le terrain plat par la carte (nœud `NavigationRegion3D/Map`, construit comme en jeu, toits et caisses compris), puis, une fois la carte construite (quelques secondes), place l'équipe sur ses points de départ, l'extraction sur le départ d'alien le plus éloigné, la caméra sur l'équipe et ses limites sur la carte. Avec **Gardes** coché, un garde posté se place sur chaque départ d'alien à plus de 15 m de l'équipe : ce sont des gardes ordinaires, à orienter, déplacer, changer en rondes ou supprimer. La mission est enregistrée aussitôt. Tout ce qu'on y ajoute ensuite se pose sur la carte comme ailleurs (case « Sur les toits et les étages »). En jeu, la carte ne place ni l'équipe ni des sentinelles : la mission joue ses propres éléments.

### 3. Écrire les informations

1. Dans la section **Informations**, cliquez sur **Titre, description, camouflage, date : inspecteur**. L'inspecteur affiche `mission.tres`, dont **Date** (« JJ/MM/AAAA ») et **Time** (« HH:MM ») : date et heure fictives de l'opération, affichées en jeu en haut à droite et sur l'écran de fin. Laissées vides, ce sont la date et l'heure du lancement de la mission.
2. Réglez :
   - **Title** : « Raid sur le dépôt » ;
   - **Description** : le briefing, affiché avant le lancement ;
   - **Camo** : camouflage conseillé (`night` pour une mission de nuit) ;
   - **Order** : rang dans le choix des missions (les missions de série vont de 10 en 10) ;
   - **Map** : laissez vide (ne sert qu'aux cartes UFO:AI).
3. Les objectifs se modifient dans le dock, sous le camouflage. Une ligne par objectif : son état, son identifiant (liste des identifiants du jeu), ↑ / ↓ pour l'ordre du journal, ✕ pour le retirer, puis son texte, la ligne du journal en jeu (validé par Entrée ou en quittant le champ). **+ Ajouter un objectif…** en ajoute un à la fin, avec un texte proposé à reprendre. Changer l'identifiant d'un objectif dont le texte est encore celui proposé change aussi le texte. Pour l'exemple :
   - `depot` : « Incendier le dépôt de carburant » ;
   - `documents` : « Récupérer les documents de l'officier » ;
   - `extracted` : « Ramener l'équipe à la zone d'extraction » (déjà présent) ;
   - `no_alert` : « Ne pas donner l'alerte » (condition bonus).

Chaque changement s'annule par Ctrl+Z, comme une modification de la scène ; le fichier est enregistré avec la scène (Ctrl+S). L'inspecteur (**Objectives**) reste possible. L'état de chaque objectif :

- ✓ en vert : il a une cible sur la carte ; un clic la sélectionne ;
- ⚠ en orange : aucune cible sur la carte pour l'instant (normal ici, le dépôt et l'officier ne sont pas encore posés) ;
- • en gris : objectif suivi par le jeu lui-même, sans cible (`no_alert`, `no_operator_lost`).

### 4. Régler la carte

Dans la section **Carte** :

- Cochez **Nuit**. Le ciel, la lumière ambiante et le soleil (devenu lune) passent en réglage de nuit. En jeu, les gardes voient moins loin et les jumelles de vision nocturne sont abaissées d'office.
- **Heure qui avance** (facultatif, dans l'inspecteur de la racine de la carte : `Time Flow`) : minutes de mission par seconde de jeu, depuis l'heure de la mission (**Time**). À 0,25, une nuit commencée à 01:45 voit l'aube (05:00) après 13 minutes de jeu : la lumière change, les jumelles se relèvent, les gardes voient de nouveau loin. L'objectif « Bonus : repartir avant l'aube » (`before_dawn`) est alors manqué.
- **Tenue de rigueur** : « Aucune » ici. Les autres choix (Costume-cravate, Décontractée, Treillis) imposent une tenue à l'équipe, comme à la Réception.
- **Limites de la caméra** : le cadre bleu clair, au sol, montre jusqu'où le centre de la vue peut aller en jeu. « Caler les limites de la caméra sur le terrain » le place à 2 m des bords du terrain. Pour le retoucher, sélectionnez `CameraRig` dans l'arbre de scène et tirez la poignée au milieu d'un bord : elle s'aimante à la grille, ne sort pas du terrain, se colle à son bord à moins de 1 m, et le cadre garde au moins 10 m de côté. « Vérifier » signale tout élément à plus de 10 m de ce cadre.
- **Vue du jeu** : ouvre une fenêtre qui montre la carte comme le joueur la verra au lancement : même angle, même orientation, même zoom de départ, centrée sur `CameraRig`. Glissez (clic gauche ou milieu) pour la déplacer, dans les limites de la caméra ; la molette ou − / + zoome dans les bornes du jeu ; ⟲ / ⟳ tournent de 45° ; « Départ » revient à la vue du début. La carte de couverture et les silhouettes de l'animation y apparaissent, pas les repères de l'éditeur.

Chaque réglage s'annule par Ctrl+Z.

### 5. Poser le décor

Principe de la pose :

1. Cliquez sur un élément de la palette (section **Pose**). Le bouton reste enfoncé et la ligne d'état indique l'outil et son cap.
2. Visez le sol dans la vue 3D : un cercle vert marque le point visé, une flèche le cap.
3. Clic gauche pour poser. L'outil reste actif : vous pouvez poser plusieurs fois de suite.
4. **R** tourne de 15° dans le sens horaire, **Maj+R** dans l'autre sens. Le cap 0° regarde le nord (vers -Z).
5. **Clic droit** ou **Échap** pour arrêter, ou cliquez à nouveau sur le bouton de l'outil.

Les éléments « tracés » (mur, route, trottoir, piste, voiture) se posent en **deux clics** : le début, puis la fin. Entre les deux, la vue affiche le tracé et sa longueur.

Les rondes (garde en ronde, pick-up armé, avion ennemi, drone) et les passants se tracent **point par point** : un clic par point, puis **double-clic** ou **Entrée** pour finir. **Retour arrière** retire le dernier point ; **clic droit** ou **Échap** abandonne le tracé en cours (un second clic droit arrête l'outil). La vue affiche le tracé, le nombre de points et la longueur.

La case **Grille de 0,5 m** aimante les points posés. La case **Sur les toits et les étages** pose sur la surface visée : toit d'un bâtiment, étage ou toit d'un immeuble, dessus d'un mur. Les murs eux-mêmes sont traversés. Décochée, tout se pose au sol. Revêtements, bâtiments, buissons, barrières, aire de poser et civils vont toujours au sol. Le second point d'un tracé reste à la hauteur du premier : une ronde commencée sur un toit y reste. Chaque pose est une action annulable (Ctrl+Z) et l'élément posé est sélectionné : ses réglages fins sont dans l'inspecteur.

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

**Relief et bâtiments dessinés** (catégorie « Relief et plans » de la palette, réglages dans la section du même nom du dock) :

- **Plateau** : deux clics aux coins opposés du dessus. Un plateau de 2 m aux flancs à pic, une rampe au sud (pente de 25°). Dans l'inspecteur : `height`, `size`, `ramps` (côté, décalage le long du côté ; côtés comme le bâtiment), `ramp_width`, couleurs. Le dessus se vise comme un toit (case « Sur les toits et les étages ») : un plateau sur un plateau fait un relief en gradins. Une échelle contre un flanc y fait monter aussi. Les flancs arrêtent la vue et les balles.
- **Pièce** : deux clics aux coins opposés. La première pièce crée un bâtiment dessiné ; les suivantes s'ajoutent au bâtiment sélectionné (ou à celui où l'on clique), à l'**étage** choisi dans le dock. Deux pièces qui se touchent partagent leur mur ; une pièce d'étage pose son sol sur le toit de celles du dessous, ou en surplomb.
- **Porte** et **Fenêtre** : un clic à moins de 1 m d'un mur de l'étage choisi. Les portes sont celles de l'immeuble (battant, crochetables si verrouillées : genre 2 dans `openings`) ; on voit à travers les fenêtres. Loin de tout mur, le geste est refusé et la ligne d'état le dit.
- **Escalier** : un clic au bas de la volée, **R** / **Maj+R** pour son sens ; la volée monte d'un étage (pente de 31°), la dalle au-dessus est percée. Une volée du dernier étage mène au toit.
- Le dock montre les pièces par étage, les ouvertures et les escaliers du bâtiment sélectionné, et retire le dernier de chaque. Pour commencer un autre bâtiment, sélectionnez autre chose (dans l'arbre de scène) avant de tracer sa première pièce.
- En jeu, le bâtiment s'affiche en coupe comme l'immeuble : l'étage le plus bas occupé par un opérateur, ou le niveau de vue choisi, et rien au-dessus.

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
- **Garde en ronde** : un clic par point de la ronde, double-clic ou Entrée pour finir. Le greffon crée le chemin `PatrolPaths/RouteN` et y attache le garde, posé au premier point et tourné vers le second. Le garde boucle : du dernier point, il revient au premier. Dans la vue, la ronde est dessinée en vert, la couleur du greffon : une bande au sol avec des chevrons dans le sens de marche, le retour au premier point plus pâle, et un pointillé du garde à son premier point s'il en est écarté. Pour retoucher la ronde ensuite, sélectionnez le chemin dans l'arbre de scène : la barre d'outils de la vue 3D propose alors les outils de chemin de Godot (ajouter, déplacer, supprimer des points).
- **Pick-up armé** : comme une ronde ; le véhicule suit son chemin.
- Réglages d'un garde dans l'inspecteur :
  - `kind` : soldat, officier (bande rouge au casque ; en alerte, il rallie les gardes à moins de 20 m, et rend plus vifs ceux à moins de 12 m) ou chien (modèle de chien en jeu ; dans l'éditeur, il garde l'apparence d'un soldat) ;
  - `armed` ;
  - `stationary` ;
  - `sweeping` : sentinelle qui balaie sans cesse du regard (avec `stationary`) ;
  - `blind` : sentinelle aveugle, pour les cibles d'entraînement ;
  - `launcher` et `rockets` : lance-roquettes ;
  - `documents` : porteur des documents.
  - `talk_partner` : un autre garde avec qui il bavarde (à moins de 4 m, à son poste ; il suffit de le régler sur l'un des deux) : moins attentifs, mais chacun remarque la disparition de l'autre.

Relève de la garde : ajoutez à la racine de la carte un nœud `GuardRelief` (Ajouter un nœud enfant, puis « GuardRelief »). Dans l'inspecteur, `post` est la sentinelle de service et `relief` le remplaçant (un garde posté au repos, ailleurs sur la carte) ; `first_at` et `interval` règlent la première relève et le rythme (secondes de jeu), `post_name` le nom du poste dans l'annonce radio.

Radio des gardes : un nœud `GuardRadio` à la racine de la carte. Dans l'inspecteur, `guards` liste les postes qui se signalent, `post_names` leur nom dans les annonces (« du pont »), `first_at` et `interval` le premier appel et le rythme (secondes de jeu). Un poste muet envoie le garde le plus proche voir ; un opérateur déguisé près du poste répond à sa place.

Le **cône de vue** de chaque garde s'affiche au sol en jaune : la zone proche, plus soutenue, où il voit tout de suite, puis la zone lointaine. Cochez Nuit : la zone lointaine se réduit, comme en jeu. Placez les gardes pour que leurs cônes laissent un passage, sans en laisser un trop facile.

Pour voir l'ensemble, cochez **Couverture des gardes** dans la section Carte. Le sol se colore case par case (1 m) selon ce que voient les gardes, avec les règles du jeu : murs et toits arrêtent la vue, la nuit réduit la zone lointaine. En **rouge**, la zone proche : on y est vu même accroupi. En **jaune**, la zone lointaine : on y est vu debout, pas accroupi. Plus la couleur est soutenue, plus il y a de gardes. Un garde en ronde compte sur tout son chemin, retour au premier point compris, dans les deux sens de marche. La carte se recalcule à chaque changement (pose, déplacement, Nuit) et n'est jamais enregistrée dans la scène. Les cases sans couleur sont les passages.

Une **caisse lourde** (palette « Caisse lourde (à deux) », ou `heavy` dans l'inspecteur d'une caisse) est cerclée de fer : il faut deux opérateurs pour la déplacer.

Le vent de la carte (`wind`, dans l'inspecteur de la racine) fait dériver les nuages de fumigène.

La neige et la pluie (« Chute de neige », « Pluie » dans la palette) tombent aussi dans la vue 3D, autour de ce que regarde la caméra de l'éditeur, sans le bruit de la pluie. Décochez **Météo (neige, pluie)** dans la section Carte pour les masquer pendant l'édition ; rien n'est enregistré.

Pour régler le rythme des rondes, utilisez la section **Animation** du dock. **▶ Lecture** fait avancer les rondes, pick-ups, avions, passants et voitures comme en jeu : vitesse de marche, pause à chaque point, boucle. Chaque unité mobile est représentée par une silhouette, et chaque garde par un cône de vue qui le suit. La **barre de temps** (3 minutes) place tout le monde à un instant choisi, **× 2** à **× 8** accélère, **⏮** revient au début et retire les silhouettes. Elles ne sont jamais enregistrées, et suivent chaque modification de la scène. Cherchez les fenêtres de passage : le moment où deux rondes se tournent le dos.

Pour l'exemple : deux gardes postés à l'entrée de la cour, une ronde autour du bâtiment, un garde en ronde le long de la route.

**Événements (facultatif) :**

- **Renforts** : un clic au point d'où ils arrivent, R pour les tourner. Dans la vue, un losange rose marque ce point, un carré la place de chaque soldat (côte à côte) et du pick-up (devant eux), et une bande mène à leur cible.
- **Pick-up qui arrive** : un pick-up armé seul, sans annonce, qui arrive 8 s après le déclenchement et fonce vers la zone qui l'a appelé.
- **Zone de déclenchement** : deux clics, aux coins opposés. Elle appelle l'événement sélectionné quand un opérateur y entre, une seule fois ; un pointillé rose la relie à lui. Tirez les poignées des coins pour la retoucher.
- La section **Événements** du dock montre une fiche par événement : ce qui le déclenche (objectif de la mission, zones), le délai, le nombre de soldats, le pick-up, l'annonce (compte à rebours affiché). **Tracer une zone** choisit l'outil de zone pour cet événement. Un événement peut avoir un objectif déclencheur et des zones : le premier qui se produit le lance.

Pour l'exemple : un pick-up qui arrive par la route quand l'équipe franchit le portail de la cour.

### 7. Poser les objectifs et l'extraction

- **Porteur des documents** : un garde posté qui porte les documents (objectif `documents`). Posez-le dans le bâtiment ou près de lui.
- **Dépôt de carburant** : une cible de sabotage (objectif `depot`) ; **Groupe électrogène** : idem avec `sabotage`. Dans l'inspecteur, `lights` peut désigner un nœud de lampadaires, qui s'éteignent quand la cible saute.
- **Zone d'extraction** : le gabarit en a déjà une. Réglez sa taille (`size`) dans l'inspecteur, ou déplacez-la. Une zone posée par la palette remplit `extracted` : toute l'équipe à l'intérieur. Avec un VIP, mettez `objective_id` à `vip_extracted`.
- **Convertible d'extraction** : remplit `extracted` quand l'équipe est à bord. Il sert aussi à l'insertion. Dans l'inspecteur : `documents_objective` pour rapporter des documents à bord, `livery`, `tail_number`.
- **Sabre** : véhicule de l'équipe. Son cercle orange montre la portée du bruit de son moteur.

Revenez à la section **Informations** : les trois objectifs de l'exemple sont maintenant verts, avec leur cible.

### 8. Ajouter des civils (facultatif)

- **Invité** : civil immobile, qui barre le passage (réception, cocktail).
- **Passant** : un clic par point, double-clic ou Entrée pour finir ; il marche en aller-retour sur ce tracé. La propriété `loop` le fait tourner en boucle.
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

La vérification tourne aussi seule à chaque enregistrement (Ctrl+S), tant que la case **Vérifier à chaque enregistrement** est cochée. Son résumé reste affiché sous le titre du dock (« ⚠ Vérification (enregistrement, 14:02) : 2 avertissements ») ; un clic dessus fait défiler le dock jusqu'au rapport. Si l'on enregistre pendant une vérification, une seconde la suit.

Les chemins passent, comme en jeu, par les échelles, les portes (même verrouillées : on les crochète ou on les fait sauter), les murets et les fenêtres. Une cible est atteinte quand le chemin arrive à 2 m du bord de son emprise au sol (un convertible ou un bâtiment n'a pas à être atteint en son centre). Une cible qu'aucun chemin n'atteint est cherchée par une corde de grappin, avec le calcul du jeu : une paroi de 1 à 9 m, lancée à 10 m au plus, depuis un endroit que l'équipe atteint. Trouvée, la ligne est en vert et indique d'où lancer (« atteint par une corde de grappin, lancée depuis (23, -15) jusqu'à 3,2 m ») : il faudra emporter un grappin dans l'équipement. Une seule corde est essayée, pas une suite de cordes. Un avertissement « pas de chemin » n'est pas forcément une faute : une cible peut se rejoindre autrement qu'à pied (à Héliportage, le Sabre, au-delà du ravin, s'élingue sous le convertible).

La vérification contrôle aussi le placement : opérateurs vus par un garde dès le départ, unités dans un mur ou les unes dans les autres, caisses qui se chevauchent, éléments hors du terrain ou trop loin des limites de la caméra, points de ronde hors de la zone praticable ou inaccessibles. Sur les cartes UFO:AI, l'équipe est placée au lancement sur les départs de la carte : sa place dans la scène n'est pas contrôlée.

### 10. Essayer

Cliquez sur **Essayer**. La scène est enregistrée puis lancée seule, avec ses objectifs, l'équipe et son équipement, comme depuis le choix des missions. Arrêtez le jeu avec le bouton carré en haut à droite de l'éditeur (F8).

Pour jouer la mission depuis le jeu complet, lancez le projet (F5) : « Raid sur le dépôt » est dans le choix des missions, à la place donnée par **Order**.

### 11. Modifier une mission de série

Les missions de série s'ouvrent comme les autres : `scenes/levels/<dossier>/<dossier>.tscn`. Deux cas :

- **Carte écrite à la main ou par le greffon** (Terrain d'essai, Escorte, cartes UFO:AI…) : modifiez-la librement, puis enregistrez.
- **Cartes de série** : toutes se modifient dans l'éditeur ; leur scène est la source (elles n'ont plus de générateur, § 6).

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
| | Sapin enneigé | 1 clic | `NavigationRegion3D` | Tronc solide (vue, balles), feuillage poudré de neige ; `height`, `variant`. |
| | Chute de neige | 1 clic | `Decor` | Flocons autour de ce que regarde la caméra ; `flakes`, `wind` ; `tracks` : traces de pas que les gardes suivent ; `sight_factor`, `hearing_factor`. Une seule par carte ; visible aussi dans l'éditeur. |
| | Pluie | 1 clic | `Decor` | Gouttes autour de ce que regarde la caméra, bruit de l'averse ; `drops`, `wind`, `volume_db`. Une seule par carte. |
| | Immeuble à étages | 1 clic | `NavigationRegion3D` | 3 étages, 14 × 10 m ; `storeys`, `size`, `doors`, `windows` dans l'inspecteur. |
| | Centre de commandement replié, déployé | 1 clic | `NavigationRegion3D` | `CommandCenter`, 45 m de long, porteurs vers l'ouest (cap pour le tourner) ; replié : plateau et coursive praticables ; déployé : pont de 34 × 20 m, salle des opérations et toit-terrasse. `deployed`, `hull_number` dans l'inspecteur. Les gardes et objectifs se posent sur ses ponts. |
| | Transporteur Mantis, rampe abaissée, relevée | 1 clic | `NavigationRegion3D` | `Mantis`, 47 m de long, nez vers l'ouest (cap pour le tourner) ; soute de 28 × 11 m au plancher à 0,6 m, rampe arrière et porte latérale. `ramp_open`, `hull_number`, `hold_lights` dans l'inspecteur ; `extraction` (on le vole : décollage avec l'équipe, objectif `objective_id`, véhicules à emporter `required_cargo`) ; groupe « Arrivée avec renforts » : `arrives`, `arrival_time`, `arrive_on_alarm`, `reinforcements`, `reinforcement_target`. La visée traverse son toit : les gardes, véhicules et objectifs se posent dans la soute. La vérification signale un véhicule enfermé derrière une rampe relevée. |
| | Route, Trottoir, Piste | 2 clics | `Decor` | 9 m, 2,5 m, 4,5 m de large. |
| Relief et plans | Plateau | 2 clics (coins) | `NavigationRegion3D` | Dessus à 2 m, une rampe au sud ; `height`, `ramps`, `ramp_width`. |
| | Pièce | 2 clics (coins) | `NavigationRegion3D` | Crée un bâtiment dessiné, ou s'ajoute au bâtiment sélectionné, à l'étage du dock. |
| | Porte, Fenêtre | 1 clic près d'un mur | (bâtiment) | À l'étage du dock ; refusée loin des murs. |
| | Escalier | 1 clic, R pour le sens | (bâtiment) | Monte d'un étage depuis celui du dock. |
| Obstacles | Mine, Engin improvisé | 1 clic | `NavigationRegion3D` | |
| | Barrière | 1 clic | `NavigationRegion3D` | Cap = sens de la route ; en travers, un muret de chaque côté. |
| Équipe | Opérateur | 1 clic | `Units` | Alpha à Foxtrot, six au plus. |
| | VIP | 1 clic | `Units` | Suit l'équipe ; objectifs `vip_alive`, `vip_extracted`. |
| Ravitaillement | Chargeurs, Grenades, Fumigènes, Trousse de soins | 1 clic | `Pickups` | Quantité (`amount`) dans l'inspecteur ; l'opérateur qui passe dessus prend ce qui lui manque. |
| Ennemis | Garde posté | 1 clic | `Enemies` | |
| | Garde en ronde, Pick-up armé | Un clic par point, double-clic ou Entrée | `Enemies` + `PatrolPaths` | Chemin `RouteN` créé avec lui. |
| | Avion ennemi | Un clic par point, double-clic ou Entrée | `Enemies` + `PatrolPaths` | Survole son chemin à `altitude` m (25 par défaut), montré au premier point. |
| | Drone de surveillance | Un clic par point, double-clic ou Entrée | `Enemies` + `PatrolPaths` | Survole son chemin à `altitude` m (12 par défaut), caméra vers le bas (disque de 8 m) ; abattu au tir libre, figé par le brouilleur. Refermez la boucle sur le premier point. |
| Événements | Renforts | 1 clic | `Enemies` | Point d'arrivée ; cible (`target`) : le dépôt de la carte, sinon la première cible de sabotage, sinon la zone qui les appelle. Réglages dans la section Événements. |
| | Pick-up qui arrive | 1 clic | `Enemies` | Renforts réduits à un pick-up armé, sans annonce, 8 s après le déclenchement ; à relier à une zone. |
| | Zone de déclenchement | 2 clics (coins) | `Triggers` | Appelle l'événement choisi quand un opérateur y entre (une fois). Coins à poignées. |
| Civils | Invité | 1 clic | `NavigationRegion3D` | |
| | Passant | Un clic par point, double-clic ou Entrée | `Decor` | Aller-retour (`loop` pour une boucle). |
| | Boucle de voitures | 2 clics (coins) | `Decor` | |
| Objectifs | Porteur des documents | 1 clic | `Enemies` | `documents`. |
| | Groupe électrogène | 1 clic | `NavigationRegion3D` | `sabotage`. |
| | Dépôt de carburant | 1 clic | `NavigationRegion3D` | `depot`. |
| Extraction et véhicules | Zone d'extraction | 1 clic | racine | `extracted`. |
| | Convertible d'extraction | 1 clic | `NavigationRegion3D` | `extracted`, insertion. |
| | Sabre | 1 clic | `NavigationRegion3D` | |
| | Hexapode | 1 clic | `NavigationRegion3D` | Marcheur ; `arrival_objective` comme le Sabre. |
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
| `sabre_rally`, `sabre_extracted` | Sabre : `arrival_objective`, `stow_objective` ; hexapode : `arrival_objective`. |
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
| Renforts sans cible valable (`target`) ni zone de déclenchement, ou dont la cible n'existe pas | Erreur |
| Arrivants (soldats côte à côte, pick-up devant) hors du terrain | Erreur |
| Zone de déclenchement qui ne désigne aucun événement valable | Erreur |
| Événement que rien ne déclenche (ni objectif, ni zone), objectif déclencheur absent de la mission, personne qui arrive | Avertissement |
| Zone de déclenchement sans chemin depuis le premier opérateur | Avertissement |
| Pas de `NavigationRegion3D` avec un maillage, ou navigation vide | Erreur |
| Bâtiment dessiné sans pièce | Erreur |
| Ouverture loin de tout mur de son étage, escalier hors des pièces de son étage ou à travers un mur | Avertissement |
| Pas de `mission.tres` (mission absente du choix des missions), pas de titre | Avertissement |
| Identifiant d'objectif inconnu du jeu | Avertissement |
| Plus de 40 gardes (la carte ralentit) | Avertissement |
| Cible ou extraction sans chemin depuis le premier opérateur (échelles, portes, murets et fenêtres comptés), même avec une corde de grappin | Avertissement |
| Cible atteinte seulement par une corde de grappin (d'où la lancer ; grappin à emporter) | Information (✓) |
| Opérateur vu par un garde dès le départ, debout (sauf insertion en vol : l'équipe commence à bord) | Avertissement |
| Unité (opérateur, VIP, garde, invité) dans un obstacle, ou deux unités à moins de 60 cm l'une de l'autre | Avertissement |
| Caisse ou cible de sabotage qui en chevauche une autre ou un mur (se toucher ou s'empiler est permis) | Avertissement |
| Élément ou point de ronde hors du terrain (`NavigationRegion3D/Ground`), ou à plus de 10 m des limites de la caméra (`CameraRig.bounds`) | Avertissement |
| Point de ronde (garde, pick-up) à plus de 1 m de la zone praticable, ou inaccessible depuis le précédent (de l'unité au premier point, jusqu'au retour au premier) | Avertissement |

### Raccourcis

| Action | Touche |
|---|---|
| Tourner de 15° (sens horaire / inverse) | R / Maj+R |
| Arrêter la pose (pendant un tracé de ronde : l'abandonner) | Échap ou clic droit |
| Finir une ronde ou un passant | Double-clic ou Entrée |
| Retirer le dernier point d'une ronde | Retour arrière |
| Annuler, rétablir | Ctrl+Z, Ctrl+Maj+Z |
| Enregistrer la scène (et `mission.tres`) | Ctrl+S |
| Lancer la scène ouverte / arrêter le jeu | F6 / F8 |

Les raccourcis du greffon se changent dans Éditeur > Paramètres de l'éditeur > Raccourcis, rubrique « mission_editor ». Ce sont des raccourcis de l'éditeur : la règle de l'InputMap ne concerne que le jeu.

### Limites de la première version

- **Relief en plateaux** : des plateaux à flancs droits et des rampes, pas de pente libre ni de terrain sculpté. La couverture des gardes et les éléments « au sol » restent à y = 0 (un garde sur un plateau voit bien depuis sa hauteur, mais les cases du dessus du plateau sont calculées au pied).
- **Fond UFO:AI** : les éléments « au sol » (revêtements, bâtiments, civils…) se posent à y = 0, la hauteur des départs de l'équipe, même là où la carte est plus haute ou plus basse ; la couverture des gardes est calculée à y = 0 aussi. La carte se construit à chaque ouverture de la scène (quelques secondes).
- **Bâtiments dessinés** : pièces rectangulaires alignées sur les axes du bâtiment, murs d'une seule épaisseur, volées droites ; pas de murs en biais, de balcons à garde-corps ni de parapets.
- **Événements scriptés** : renforts et pick-ups qui arrivent se règlent dans la section Événements du dock ; les ateliers du didacticiel, dans l'inspecteur.
- **Missions des joueurs** : le greffon ne sert que dans l'éditeur, pas dans le jeu exporté.
- **Animation** : trajets en ligne droite entre les points (en jeu, la navigation contourne les obstacles), sans les arrêts imprévus (passant bloqué, voiture qui freine derrière une autre ou klaxonne, garde alerté) ; le pick-up armé, qui ralentit dans les virages en jeu, prend un peu d'avance (environ 5 % de la distance parcourue).
- **Vue du jeu** : la carte telle qu'elle est posée, sans ce que le jeu change au lancement (convertible d'insertion en vol, toits ôtés quand une unité entre, interface) ; la largeur vue suit celle de la fenêtre (16:9 en jeu).
- **Couverture des gardes** : calculée au sol (y = 0), sans la fumée ni les gardes qui se retournent au bruit ; un garde en ronde est regardé à chaque point et au milieu de chaque segment, ce qui peut omettre un angle au passage d'un virage.

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
3. **18 cartes étaient générées** par `tools/gen_*.py` (`MapBuilder`). Une carte modifiée dans l'éditeur, puis régénérée, aurait perdu ses modifications. Voir § 6 : elles ont depuis été reprises dans l'éditeur.

### 2. Le greffon

- **Dock « Mission »**, quand la scène ouverte est un `LevelRoot` :
  - **palette par catégories** : décor (bâtiment, mur, muret, caisse, haie, lampadaire, échelle, route, trottoir), équipe, ennemis (garde posté, ronde, pick-up armé), civils (invité, passant, boucle de voitures), objectifs (documents, groupe électrogène…), extraction et véhicules (convertible, Sabre, hexapode) ;
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

**Sort des cartes (point 8.5 b) : toutes reprises dans l'éditeur.** Chacune des 17 cartes à empreinte a été ouverte dans l'éditeur, enregistrée, puis comparée à la scène générée, nœud par nœud et propriété par propriété (`tools/editor_check/check_all.sh`) : identiques. Les scènes enregistrées par l'éditeur, sans leurs métadonnées de génération, sont devenues la source, et les 18 générateurs (didacticiel compris) ont quitté le dépôt (l'historique git les garde). Une carte se modifie désormais dans l'éditeur. Restent `tools/mapkit.py` et `tools/gen_mission_template.py`, qui écrivent le gabarit des nouvelles missions ; l'avertissement du dock reste en place pour une carte qui aurait de nouveau un générateur (`tools/gen_<dossier>.py`).
