class_name GearCatalog
extends RefCounted
## Choix offerts pour personnaliser un opérateur (`OperatorProfile`) :
## camouflages, palette, couvre-chefs, visages, coupes, armes et équipement.
## Les armes principales changent les réglages de tir de l'unité
## (`apply_weapon`) ; le reste ne change que l'apparence.

## Camouflages : nom, quatre couleurs du motif (la première domine), couleur
## conseillée du gilet et du couvre-chef.
const CAMOS: Dictionary = {
	&"woodland": {
		"name": "Woodland",
		"colors": [Color(0.33, 0.36, 0.22), Color(0.19, 0.25, 0.14), Color(0.37, 0.27, 0.17), Color(0.09, 0.09, 0.07)],
		"vest": Color(0.24, 0.27, 0.18),
		"headwear": Color(0.28, 0.31, 0.2),
	},
	&"desert": {
		"name": "Désert",
		"colors": [Color(0.74, 0.64, 0.47), Color(0.6, 0.49, 0.33), Color(0.46, 0.37, 0.25), Color(0.84, 0.77, 0.62)],
		"vest": Color(0.56, 0.48, 0.35),
		"headwear": Color(0.66, 0.57, 0.41),
	},
	&"urban": {
		"name": "Urbain",
		"colors": [Color(0.44, 0.45, 0.46), Color(0.29, 0.3, 0.31), Color(0.62, 0.63, 0.63), Color(0.14, 0.14, 0.15)],
		"vest": Color(0.2, 0.21, 0.22),
		"headwear": Color(0.25, 0.26, 0.27),
	},
	&"snow": {
		"name": "Neige",
		"colors": [Color(0.9, 0.92, 0.93), Color(0.74, 0.77, 0.79), Color(0.56, 0.6, 0.62), Color(0.97, 0.97, 0.98)],
		"vest": Color(0.8, 0.82, 0.83),
		"headwear": Color(0.88, 0.9, 0.91),
	},
	&"night": {
		"name": "Nuit",
		"colors": [Color(0.12, 0.14, 0.2), Color(0.07, 0.08, 0.11), Color(0.19, 0.21, 0.27), Color(0.04, 0.04, 0.05)],
		"vest": Color(0.08, 0.09, 0.11),
		"headwear": Color(0.1, 0.11, 0.14),
	},
}

## Couleurs unies proposées pour les vêtements.
const PALETTE: Array[Color] = [
	Color(0.3, 0.33, 0.24), Color(0.24, 0.27, 0.18), Color(0.4, 0.42, 0.3), Color(0.55, 0.52, 0.38),
	Color(0.68, 0.6, 0.45), Color(0.5, 0.4, 0.28), Color(0.36, 0.28, 0.2), Color(0.16, 0.17, 0.14),
	Color(0.08, 0.08, 0.09), Color(0.25, 0.26, 0.27), Color(0.45, 0.46, 0.47), Color(0.72, 0.73, 0.73),
	Color(0.9, 0.91, 0.92), Color(0.12, 0.15, 0.24), Color(0.2, 0.27, 0.38), Color(0.4, 0.17, 0.14),
]

## Couvre-chefs : nom affiché.
const HEADWEAR: Dictionary = {
	&"helmet": "Casque balistique",
	&"cap": "Casquette",
	&"boonie": "Chapeau de brousse",
	&"beanie": "Bonnet",
	&"none": "Aucun",
}

## Teintes de peau (visage).
const SKINS: Array[Color] = [
	Color(0.93, 0.76, 0.64), Color(0.8, 0.62, 0.5), Color(0.66, 0.48, 0.35), Color(0.48, 0.33, 0.23), Color(0.31, 0.21, 0.15),
]

const HAIR_STYLES: Dictionary = {
	&"shaved": "Rasé",
	&"short": "Court",
	&"ponytail": "Queue de cheval",
	&"mohawk": "Crête",
}

const HAIR_COLORS: Array[Color] = [
	Color(0.06, 0.05, 0.05), Color(0.22, 0.14, 0.08), Color(0.42, 0.26, 0.13), Color(0.78, 0.64, 0.38), Color(0.52, 0.5, 0.48),
]

const BEARDS: Dictionary = {
	&"none": "Rasé de près",
	&"stubble": "Barbe courte",
	&"full": "Barbe fournie",
}

## Accessoires (interrupteurs de `OperatorProfile`) : nom affiché.
const ACCESSORIES: Dictionary = {
	&"balaclava": "Cagoule",
	&"nvg": "Jumelles de vision nocturne (casque)",
	&"headset": "Casque audio",
	&"vest": "Gilet tactique",
	&"backpack": "Sac à dos",
	&"radio": "Radio",
	&"knee_pads": "Genouillères",
}

## Armes principales : nom, description et réglages de tir (`UnitStats`).
## La carabine reprend les réglages de base de l'opérateur.
const PRIMARY: Dictionary = {
	&"carbine": {
		"name": "Carabine silencieuse",
		"description": "Polyvalente : portée moyenne, discrète.",
		"stats": {
			"fire_range": 16.0, "aim_time": 0.4, "fire_interval": 0.5, "fire_damage": 34.0,
			"hit_chance_near": 0.95, "hit_chance_far": 0.6, "magazine_size": 10, "reserve_ammo": 20,
			"reload_time": 2.0, "gunshot_noise_radius": 8.0, "suppressed": true,
		},
	},
	&"smg": {
		"name": "Pistolet-mitrailleur silencieux",
		"description": "Très discret et rapide, mais courte portée et faibles dégâts.",
		"stats": {
			"fire_range": 11.0, "aim_time": 0.3, "fire_interval": 0.3, "fire_damage": 25.0,
			"hit_chance_near": 0.95, "hit_chance_far": 0.5, "magazine_size": 15, "reserve_ammo": 30,
			"reload_time": 1.6, "gunshot_noise_radius": 5.0, "suppressed": true,
		},
	},
	&"dmr": {
		"name": "Fusil de précision",
		"description": "Longue portée et gros dégâts ; lent, peu de munitions, plus bruyant.",
		"stats": {
			"fire_range": 24.0, "aim_time": 0.7, "fire_interval": 1.1, "fire_damage": 60.0,
			"hit_chance_near": 0.97, "hit_chance_far": 0.8, "magazine_size": 5, "reserve_ammo": 10,
			"reload_time": 2.5, "gunshot_noise_radius": 12.0, "suppressed": true,
		},
	},
	&"shotgun": {
		"name": "Fusil de combat",
		"description": "Dévastateur de près, inutile de loin ; sans silencieux, il s'entend de loin.",
		"stats": {
			"fire_range": 8.0, "aim_time": 0.35, "fire_interval": 0.9, "fire_damage": 70.0,
			"hit_chance_near": 0.98, "hit_chance_far": 0.5, "magazine_size": 6, "reserve_ammo": 12,
			"reload_time": 2.8, "gunshot_noise_radius": 18.0, "suppressed": false,
		},
	},
}

## Armes secondaires (portées à la cuisse).
const SECONDARY: Dictionary = {
	&"pistol": "Pistolet silencieux",
	&"machine_pistol": "Pistolet automatique",
	&"none": "Aucune",
}

## Équipement : nom affiché et nombre maximal.
const EQUIPMENT: Dictionary = {
	&"throwing_knives": {"name": "Couteaux de lancer", "max": 2},
	&"grenades": {"name": "Grenades", "max": 4},
	&"explosives": {"name": "Charges explosives", "max": 2},
	&"medkit": {"name": "Trousse de soins", "max": 1},
}

## Taille (pixels) des textures de camouflage.
const CAMO_SIZE := 128

static var _camo_textures: Dictionary = {}


## Copie de `base` avec les réglages de tir de l'arme principale `weapon`.
static func apply_weapon(base: UnitStats, weapon: StringName) -> UnitStats:
	var stats := base.duplicate() as UnitStats
	var entry: Dictionary = PRIMARY.get(weapon, PRIMARY[&"carbine"])
	var values: Dictionary = entry["stats"]
	for key: String in values:
		stats.set(key, values[key])
	return stats


## Texture (répétable) du camouflage `camo`, générée une fois : taches de bruit
## des trois dernières couleurs sur la première.
static func camo_texture(camo: StringName) -> Texture2D:
	if _camo_textures.has(camo):
		return _camo_textures[camo]
	var colors: Array = CAMOS[camo]["colors"]
	var layers: Array[Image] = []
	for i in 3:
		var noise := FastNoiseLite.new()
		noise.seed = 17 + i * 31 + camo.hash() % 1000
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.035 if i < 2 else 0.06
		layers.append(noise.get_seamless_image(CAMO_SIZE, CAMO_SIZE))
	var image := Image.create(CAMO_SIZE, CAMO_SIZE, false, Image.FORMAT_RGB8)
	for y in CAMO_SIZE:
		for x in CAMO_SIZE:
			var color: Color = colors[0]
			# Des grandes taches aux petites : chaque couche recouvre la précédente.
			for i in 3:
				if layers[i].get_pixel(x, y).r > (0.58 if i < 2 else 0.66):
					color = colors[i + 1]
			image.set_pixel(x, y, color)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_camo_textures[camo] = texture
	return texture
