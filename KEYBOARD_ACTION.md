# Clavier : gestion des touches d'action

Toutes les lettres du clavier étaient prises. Depuis, le cycle par famille (2.1) et le passage des menus sur F1 à F3 (2.2) ont libéré « ; », H, O, M et quatre variantes avec Maj. Avant cela, chaque nouvel objet (M320, obus fumigène et lacrymogène, Taser, lampe du HK45) a donc reçu une variante avec Maj ou une touche de ponctuation. Cette note fait l'inventaire des touches et propose comment en libérer, du plus utile au moins prioritaire.

Les touches sont définies par position physique (`project.godot`, section `[input]`) ; elles sont données ici en AZERTY, la disposition par défaut.

## 1. Inventaire actuel

### Lettres (23 prises ; H, O et M libres)

| Touche | Action | Usage en mission |
|---|---|---|
| Z Q S D | Caméra (avec les flèches) | Constant |
| A / E | Rotation de la caméra | Fréquent |
| F | Stop | Fréquent |
| R | Recharger | Fréquent |
| C / X | Accroupi / rampé | Constant |
| V | Couteau | Fréquent |
| B (Maj : Taser) | Assommer | Fréquent |
| T | Lancer (couteau, caillou) | Fréquent |
| G | Bretelle | Occasionnel |
| Y (Maj : lampe) | Arme secondaire | Occasionnel |
| N (appuis suivants : fumigène, assourdissante) | Grenades à la main | Occasionnel |
| K (Maj : à retardement) / L | Poser une charge / la faire sauter | Occasionnel |
| P (Maj : tourner) | Caisse | Occasionnel |
| J | Trousse de soins | Rare |
| U | Bouclier | Rare |
| W | Grappin | Rare |
| I | Parer | Réflexe (au bon moment) |

### Ponctuation, chiffres et touches spéciales

| Touche | Action |
|---|---|
| : | Tir libre |
| ! | Porter un corps |
| , | Roulade |
| ù (appuis suivants : obus fumigène, lacrymogène) | Lance-grenades M320 |
| ² | Jumelles, puis vue thermique |
| F1 / F2 / F3 | Aide / objectifs / minicarte |
| 1 à 6 (Ctrl : centrer) | Sélection des opérateurs |
| Espace | Pause tactique |
| Tab / Entrée | Ordres simultanés : préparer / exécuter |
| Maj | Ajout à la sélection, variante d'action |
| Ctrl | Sélection et centrage |
| Origine | Centrer la caméra |
| Page préc. / Page suiv. | Étage affiché |
| Flèches | Caméra |

### Encore libres

- Chiffres **7, 8, 9, 0**, et **)** et **=** à leur droite.
- **^** et **$** (à droite de P), **;** (libéré par le cycle des grenades).
- **F4 à F12**.
- **H**, **O** et **M**, libérées par le passage des menus sur F1 à F3 : en réserve pour les prochaines actions de mission.
- **Inser**, **Suppr**, **Fin**, **Retour arrière**.
- Boutons latéraux de la souris (4 et 5 de Godot, à ne pas confondre avec la molette), molette avec Maj ou Ctrl.
- **Alt**, à éviter pour les actions fréquentes : le système l'intercepte souvent (menus, gestionnaire de fenêtres sous Linux).

### Le problème

- Les variantes avec Maj s'accumulent : Maj+N, Maj+K, Maj+P, Maj+B, Maj+Y, Maj+;, Maj+ù. Le joueur doit les apprendre une à une, et toutes ne suivent pas la même logique (Maj+B donne le Taser, qui n'est pas une variante d'« assommer »).
- Les objets d'une même famille sont éparpillés : grenade sur N, fumigène sur ;, obus fumigène sur Maj+;, M320 sur ù.
- Des commandes de menu (H, O, M) occupent des lettres bien placées alors qu'elles servent peu en mission.
- Chaque nouvel objet demandera encore une touche.

## 2. Pistes, de la plus rentable à la plus ambitieuse

### 2.1 Grouper par famille, avec un cycle (fait)

Une touche par famille d'objets, au lieu d'une touche par objet :

- **Lancer à la main** (N) : grenade, fumigène, assourdissante.
- **Lance-grenades** (ù) : obus explosif, fumigène, lacrymogène.

La touche arme l'action avec le dernier type utilisé. Un second appui, l'action encore armée, passe au type suivant que l'équipe possède (les types épuisés sont sautés), un troisième au suivant, et ainsi de suite. Le curseur et le bouton du HUD affichent le type choisi, et Échap ou le clic droit annule.

Ce que ça libère : « ; » et les variantes Maj+N, Maj+; et Maj+ù. Un nouveau type de grenade ou d'obus n'a plus besoin de touche.

Retenu : le cycle tourne en boucle sur les types disponibles ; l'appui ne désarme que s'il n'y a aucun autre type (le comportement d'avant, pour une équipe qui n'a qu'une sorte de grenade). Échap et le clic droit annulent toujours. Les boutons du HUD restent un par type (`PlayerController.cycle_family`).

### 2.2 Inventaire des actions par fréquence, puis redistribution

Trois paliers d'usage :

- **Constant ou fréquent** : une lettre autour de la main gauche, autour de ZQSD (A, E, R, F, C, X, V, B, T, G).
- **Occasionnel** : une lettre plus loin, ou une famille avec cycle (2.1).
- **Rare** : chiffres 7 à 0, touches de fonction, ou roue d'équipement (2.4).

Les commandes de menu (aide, objectifs, minicarte) peuvent passer sur F1, F2 et F3. Elles libèrent H, O et M, bien placées, pour des actions de mission.

### 2.3 Les chiffres 7 à 0 comme emplacements d'équipement

1 à 6 restent la sélection des opérateurs. 7, 8, 9 et 0 deviennent des emplacements d'équipement rare, dans un ordre fixe, par exemple :

| Touche | Emplacement |
|---|---|
| 7 | Trousse de soins |
| 8 | Grappin |
| 9 | Taser |
| 0 | Bouclier |

C'est une convention connue des jeux tactiques. Elle libère J, W, U et la variante Maj+B.

### 2.4 Une roue d'équipement

Une touche maintenue affiche autour du curseur une roue avec tout l'équipement des opérateurs sélectionnés (quantités, objets épuisés grisés). On relâche sur l'objet voulu, ce qui arme l'action comme aujourd'hui. Le jeu passe en pause tactique tant que la roue est ouverte.

C'est le moyen le plus évolutif : l'équipement peut grossir sans toucher au clavier. Il demande plus de travail (interface, souris, manette éventuelle). La touche de la roue doit être très accessible : Espace si la pause tactique passe ailleurs, ou un bouton latéral de la souris.

### 2.5 Une touche qui dépend du contexte

Une touche « Utiliser » (ou le clic du milieu, qui ouvre déjà le menu d'un ennemi) fait l'action logique selon ce qui est sous le curseur :

| Sous le curseur | Action |
|---|---|
| Ennemi de dos | Couteau |
| Ennemi assommé | Ligoter |
| Corps | Porter |
| Caisse | La saisir |
| Échelle, muret | Monter |
| Porte | Ouvrir |
| Véhicule | Monter à bord |

Les touches dédiées restent pour forcer un choix (assommer plutôt que tuer), mais les actions qui n'ont qu'un sens selon la cible (porter, caisse) peuvent perdre leur touche.

### 2.6 Règles pour les modificateurs

- **Maj** donne toujours une variante *de la même action* (grenade → assourdissante, charge → à retardement). Le Taser sur Maj+B fait exception : à déplacer s'il reçoit un emplacement (2.3) ou une place dans la roue (2.4).
- **Ctrl** reste réservé à la sélection et à la caméra (Ctrl + chiffre).
- Pas plus de deux niveaux par touche (seule, avec Maj).
- Pas d'**Alt** pour les actions de mission.

### 2.7 Écran de configuration des touches

Tout passe déjà par l'InputMap, et `KeyNames` affiche le nom imprimé sur le clavier du joueur. Un écran dans les options (liste des actions, clic puis appui pour réassigner, détection des conflits, retour aux valeurs par défaut), enregistré dans `user://`, est donc peu coûteux. Il règle aussi les dispositions autres que l'AZERTY (QWERTZ, Bépo).

À prévoir alors :

- les libellés en dur restants (point 5.10 de `IMPROVEMENTS.md`) ;
- le texte de l'écran des opérateurs, qui cite des touches en dur ;
- l'aide en jeu et le README, à générer depuis l'InputMap plutôt qu'à la main.

## 3. Ordre conseillé

1. ~~**Cycle par famille (2.1)**~~ : fait.
2. ~~**Inventaire et redistribution (2.2)**~~ : aide, objectifs et minicarte sur F1 à F3 (fait) ; H, O et M sont en réserve.
3. **Emplacements 7 à 0 (2.3)** pour l'équipement rare : libère J, W et U, et sort le Taser de Maj+B.
4. **Écran de configuration (2.7)**, une fois les touches stabilisées.
5. **Roue d'équipement (2.4)**, si l'équipement continue de grossir.

La touche contextuelle (2.5) est un chantier de jeu plus que de clavier : à envisager avec les ordres au clic du milieu.
