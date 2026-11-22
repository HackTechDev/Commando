# Éditeur de mission

Analyse et plan de travail. L'implémentation n'a pas commencé.

Le cahier des charges prévoit un « éditeur de niveaux intégré ». La proposition : un éditeur dans le jeu, ouvert depuis le menu principal. On y pose les éléments sur une carte vue de dessus, on règle les objectifs, et on lance la mission directement pour l'essayer.

## 1. Une mission enregistrée comme un fichier de données

Une mission est un fichier `user://missions/<nom>.json`, pas une scène Godot. Elle se joue dans une scène générique qui reconstruit la carte au chargement, comme `ufo_map.tscn` le fait déjà pour les cartes UFO:AI (`LevelCatalog.GENERIC_SCENE`).

Contenu du fichier :

- **Carte** : taille, type de sol, nuit ou jour (`LevelRoot.night`), tenue de rigueur (`LevelRoot.dress_code`), camouflage conseillé, texte de briefing.
- **Décor** : bâtiments (taille, portes et verrous, fenêtres, hauteur, toit), murs, caisses, haies, lampadaires, routes et trottoirs, véhicules (Sabre, convertible d'extraction).
- **Équipe** : point de départ, nombre d'opérateurs, équipement imposé (tenue, arme principale, jumelles, explosifs).
- **Ennemis** : position, orientation, garde posté ou ronde avec son trajet, porteur des documents, pick-ups armés.
- **Civils** : invités, passants avec leurs trajets, boucles de voitures.
- **Objectifs** : choisis parmi ceux qui existent déjà (`documents`, `sabotage`, `vip_extracted`, `extracted`, `all_enemies_down`, `no_alert`, `no_operator_lost`…), chacun lié à sa cible sur la carte.

Le maillage de navigation est déjà calculé au chargement des niveaux (`LevelRoot`) : rien n'est à précalculer.

Aujourd'hui, `tools/mapkit.py` (`MapBuilder`) écrit des `.tscn` depuis Python. Il faut porter cette construction en GDScript pour que le jeu bâtisse la carte lui-même : une classe `MissionBuilder` qui crée directement les objets du jeu (`Building`, caisses, `Guest`, `Passerby`, `TrafficCar`, `Enemy`, etc.), avec les mêmes paramètres que les méthodes de `MapBuilder`.

## 2. L'écran de l'éditeur

- **Caméra** : celle du jeu (`CameraRig`), vue de dessus, avec une grille magnétique de 0,5 m qu'on peut désactiver.
- **Palette à gauche**, par catégories : décor, équipe, ennemis, civils, objectifs, extraction.
- **Inspecteur à droite** : les réglages de l'objet sélectionné (taille d'un bâtiment, portes verrouillées, cône de vue et posture d'un garde…).
- **Outils** :
  - placer, sélectionner, déplacer et tourner, supprimer, dupliquer ;
  - tracé point par point pour les rondes, les passants, les boucles de voitures, les rues et les murs ;
  - zone pour l'extraction.
- **Aperçus pour aider à placer les ennemis** : cônes de vision des gardes, trajets des rondes, portée du bruit.
- **Annuler et rétablir.**
- **Vérification avant d'enregistrer** :
  - l'équipe a un point de départ ;
  - chaque objectif est atteignable à pied et la zone d'extraction aussi, comme le contrôle de chemins de `build/shots/check_map.sh` ;
  - chaque objectif a sa cible ;
  - au-delà d'environ 40 gardes, un avertissement de performance (avec 72 gardes, on est tombé à 10 images/s).
- **« Essayer »** : lance la mission telle quelle, et Échap ramène à l'éditeur au même endroit.
- **Commandes** : toutes passent par l'InputMap, par position de touche (AZERTY par défaut), et sont ajoutées au README.

## 3. Intégration au jeu

- Une entrée « Éditeur de mission » dans le menu principal.
- Dans le choix des missions, une rubrique « Missions personnelles », lue depuis le dossier `user://missions`.
- Les objectifs (`Objectives`), l'écran de fin, l'équipement des opérateurs et la sauvegarde rapide fonctionnent comme pour les autres missions.
- Une mission est un simple fichier, qu'on peut copier pour l'échanger.

## 4. Étapes, chacune avec son commit

1. **Format et chargement** : format JSON, `MissionBuilder` et la scène générique. Pour le valider, `tools/gen_reception.py` produit aussi une version JSON de Réception, et on vérifie qu'elle se joue comme l'originale.
2. **Base de l'éditeur** : caméra, grille, palette de décor, placer, déplacer et supprimer, enregistrer et ouvrir.
3. **Unités et trajets** : équipe, gardes postés et rondes, civils, voitures.
4. **Mission** : objectifs, extraction, briefing, réglages de carte (nuit, tenue), vérification.
5. **Essai et catalogue** : bouton « Essayer » avec retour à l'éditeur, missions personnelles dans le menu.
6. **Finitions** : annuler et rétablir, copier-coller, dessin des routes, puis éventuellement partir d'une carte UFO:AI comme fond.

La première version vise les étapes 1 à 5.

## 5. Hors de la première version

- **Relief** : le sol reste plat.
- **Bâtiments** : seulement les bâtiments réglables qui existent déjà, pas de dessin libre de pièces ni d'étages.
- **Événements scriptés** : pas de renforts déclenchés, de pick-ups qui arrivent ni de dialogues de tutoriel.
- **Missions de série** : elles restent en `.tscn` ; l'éditeur ne les modifie pas.

## 6. Questions ouvertes

1. **Où placer l'éditeur ?** Intégré au jeu, comme proposé ici, ou un greffon dans l'éditeur Godot ? Le greffon serait plus rapide à faire (inspecteur et annulation fournis), mais il ne servirait qu'au développeur, pas aux joueurs.
2. **Quel périmètre pour la première version ?** Proposition : les étapes 1 à 5.
3. **Les missions de série** devraient-elles aussi pouvoir s'ouvrir dans l'éditeur ? Ce serait un gros travail de conversion.
