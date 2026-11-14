# Textures

Les textures ne sont pas dans le dépôt : elles sont lues à la volée au
chargement d'un niveau (`TextureLibrary`, appelé par `LevelRoot`) depuis un
dossier externe, par défaut `../CommandoAsset/textures` (réglage de projet
`commando/assets/texture_dir`, ou variable d'environnement
`COMMANDO_TEXTURES`). Un chemin relatif part du dossier du projet quand le jeu
tourne depuis l'éditeur, et du dossier de l'exécutable dans un jeu exporté.

Un matériau demande une texture par une métadonnée donnant son chemin relatif
à ce dossier : `albedo_source`, `normal_source` ou `roughness_source`. Une
caisse choisit sa variante avec sa propriété `skin`. Une texture manquante
laisse le matériau à sa seule couleur, avec un avertissement.

## Licence

Le lot vient du jeu UFO:AI (http://ufoai.org) et mélange plusieurs licences :
certaines textures ne sont pas libres (liste sur http://ufoai.org/licenses/),
d'autres viennent de mayang.com ou cgtextures.com, utilisables dans un jeu
mais pas redistribuables en tant que textures. À vérifier une par une avant
toute diffusion publique, ou à remplacer par des textures CC0 (M10).

## Textures utilisées

| Texture | Usage |
|---|---|
| `tex_nature/grass_mowed_green_a.jpg` | sol du sandbox |
| `tex_nature/dirt002.png` | chemin de ronde du sandbox |
| `tex_ctp1/bricks_g_1.jpg` | murs (`wall.tscn`) |
| `tex_base/ecrate_cln.jpg` | caisses (`crate.tscn`) |
| `tex_base/ecrate_drty-fmtl3.jpg` | variante de caisse sombre |
| `tex_base/ecrate_dunno.jpg` | variante de caisse à bandes de danger |
