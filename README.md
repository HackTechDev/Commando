# Commando

Jeu d'infiltration tactique en temps réel, vue 3D isométrique (Godot 4.7, GDScript typé).
Voir `CAHIER_DES_CHARGES.md` pour la vision, l'architecture et les jalons.

## Lancement

```sh
godot --path .            # lance le niveau sandbox
godot --headless --path . --quit-after 60   # vérification sans affichage
```

(`godot` = exécutable Godot 4.7.x.)

## Export Web (HTML)

```sh
./export_web.sh            # exporte dans build/web/
./export_web.sh --serve    # exporte puis sert le jeu sur http://localhost:8000
./export_web.sh --debug    # export en mode débogage
```

Le script cherche Godot dans la variable `GODOT`, puis dans le PATH, puis à son emplacement par défaut.

Le dossier `build/` n'est pas versionné. La page doit être servie en HTTP : l'ouvrir directement depuis le disque (`file://`) ne fonctionne pas. Les modèles d'export Web de Godot 4.7.2 doivent être installés.

## Contrôles

| Action | Touche (AZERTY) |
|---|---|
| Sélectionner | Clic gauche, rectangle, touches 1 à 3 (Maj : ajouter) |
| Marcher / courir | Clic droit / double clic droit |
| Tirer sur un ennemi | Clic droit sur l'ennemi |
| Couteau (élimination silencieuse) | V, puis clic gauche sur l'ennemi |
| Assommer | B, puis clic gauche sur l'ennemi |
| Lancer le couteau (jusqu'à 7 m) | T, puis clic gauche sur l'ennemi ; passer sur le couteau pour le ramasser |
| Pousser / tirer une caisse | P, puis clic gauche sur le côté de la caisse ; clic droit au sol pour la déplacer dans l'axe ; F pour lâcher |
| Grimper sur une caisse | Clic droit sur la caisse (un ordre au sol fait redescendre) |
| Arme à la bretelle / en main | G (bascule) |
| Recharger | R |
| Annuler l'ordre en cours | F (clic droit pour annuler une action V / B / T / P armée) |
| Accroupi / rampé | C / X (bascule) |
| Déplacer la caméra | ZQSD, flèches, bord d'écran, clic molette maintenu |
| Zoom | Molette |
| Rotation de la caméra | A / E (maintenir) |
| Centrer sur l'unité | Origine |
| Quitter | Bouton « Quitter » en haut à droite |

Les touches sont définies par position physique dans l'InputMap : sur un clavier QWERTY, ZQSD devient WASD et A/E devient Q/E.

## Tests

Aucun framework de tests n'est encore installé (GUT ou gdUnit4 à choisir, jalon M0).
