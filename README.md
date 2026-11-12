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
godot --headless --path . --export-release "Web" build/web/index.html
cd build/web && python3 -m http.server 8000   # puis ouvrir http://localhost:8000
```

Le dossier `build/` n'est pas versionné. La page doit être servie en HTTP : l'ouvrir directement depuis le disque (`file://`) ne fonctionne pas. Les modèles d'export Web de Godot 4.7.2 doivent être installés.

## Contrôles

| Action | Touche (AZERTY) |
|---|---|
| Sélectionner | Clic gauche, rectangle, touches 1 à 3 (Maj : ajouter) |
| Marcher / courir | Clic droit / double clic droit |
| Tirer sur un ennemi | Clic droit sur l'ennemi |
| Grimper sur une caisse | Clic droit sur la caisse (un ordre au sol fait redescendre) |
| Recharger | R |
| Annuler l'ordre en cours | F |
| Accroupi / rampé | C / X (bascule) |
| Déplacer la caméra | ZQSD, flèches, bord d'écran, clic molette maintenu |
| Zoom | Molette |
| Rotation de la caméra | A / E (maintenir) |
| Centrer sur l'unité | Origine |
| Quitter | Bouton « Quitter » en haut à droite |

Les touches sont définies par position physique dans l'InputMap : sur un clavier QWERTY, ZQSD devient WASD et A/E devient Q/E.

## Tests

Aucun framework de tests n'est encore installé (GUT ou gdUnit4 à choisir, jalon M0).
