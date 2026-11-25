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

## Tenues : treillis (militaire) ou civiles, faites pour se fondre dans la
## foule selon l'occasion (`LevelRoot.dress_code`). Une tenue civile choisie
## habille l'opérateur (`look` : propriétés du profil) et retire l'équipement
## militaire voyant.
const CLOTHING: Dictionary = {
	&"uniform": {
		"name": "Treillis",
		"description": "Tenue de combat. Ne trompe personne.",
		"look": {},
	},
	&"suit": {
		"name": "Costume-cravate",
		"description": "Pour une réception, un gala, un quartier d'affaires.",
		"look": {"camo": &"", "top_color": Color(0.12, 0.15, 0.24), "pants_color": Color(0.12, 0.15, 0.24), "headwear": &"none"},
	},
	&"casual": {
		"name": "Décontractée",
		"description": "Blouson, t-shirt et jean : pour une rue, un marché, un port.",
		"look": {"camo": &"", "top_color": Color(0.36, 0.28, 0.2), "pants_color": Color(0.2, 0.27, 0.38), "headwear": &"none"},
	},
}
## Équipement militaire qui trahit un opérateur en tenue civile (retiré quand
## on la choisit).
const MILITARY_GEAR: Array[StringName] = [&"balaclava", &"nvg", &"headset", &"vest", &"backpack", &"radio", &"knee_pads"]
## Armes principales assez compactes pour se cacher sous une veste.
const CONCEALABLE: Array[StringName] = [&"smg"]

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

## Morphologies : nom affiché.
const BODIES: Dictionary = {
	&"male": "Homme",
	&"female": "Femme",
}

## Teintes de peau (visage).
const SKINS: Array[Color] = [
	Color(0.93, 0.76, 0.64), Color(0.8, 0.62, 0.5), Color(0.66, 0.48, 0.35), Color(0.48, 0.33, 0.23), Color(0.31, 0.21, 0.15),
]

const HAIR_STYLES: Dictionary = {
	&"shaved": "Rasé",
	&"short": "Court",
	&"ponytail": "Queue de cheval",
	&"bun": "Chignon",
	&"long": "Cheveux longs",
	&"mohawk": "Crête",
	&"afro": "Afro",
	&"undercut": "Undercut (côtés rasés)",
}

const HAIR_COLORS: Array[Color] = [
	Color(0.06, 0.05, 0.05), Color(0.22, 0.14, 0.08), Color(0.42, 0.26, 0.13), Color(0.78, 0.64, 0.38), Color(0.52, 0.5, 0.48),
]

## Nez : nom, largeur et avancée (facteurs), bosse de l'arête et bout
## tombant (m).
const NOSES: Dictionary = {
	&"straight": {"name": "Droit", "width": 1.0, "projection": 1.0, "hump": 0.0, "droop": 0.0},
	&"small": {"name": "Petit", "width": 0.85, "projection": 0.7, "hump": 0.0, "droop": -0.002},
	&"broad": {"name": "Large", "width": 1.4, "projection": 0.9, "hump": 0.0, "droop": 0.002},
	&"aquiline": {"name": "Aquilin", "width": 0.95, "projection": 1.15, "hump": 0.007, "droop": 0.005},
}

## Mâchoires : nom et resserrement ajouté vers le menton (négatif : carrée).
const JAWS: Dictionary = {
	&"normal": {"name": "Moyenne", "squeeze": 0.0},
	&"narrow": {"name": "Fine", "squeeze": 0.1},
	&"square": {"name": "Carrée", "squeeze": -0.1},
}

## Yeux : nom, hauteur du globe (facteur), écartement (m), paupière au
## repos (part de l'œil couverte).
const EYES: Dictionary = {
	&"normal": {"name": "Moyens", "height": 0.6, "spacing": 0.037, "lid": 0.08},
	&"narrow": {"name": "Plissés", "height": 0.45, "spacing": 0.037, "lid": 0.35},
	&"round": {"name": "Ronds", "height": 0.75, "spacing": 0.038, "lid": 0.04},
	&"close": {"name": "Rapprochés", "height": 0.6, "spacing": 0.033, "lid": 0.12},
}

const SCARS: Dictionary = {
	&"none": "Aucune",
	&"cheek": "Joue",
	&"brow": "Sourcil",
	&"lip": "Lèvre",
}

## Peinture de camouflage du visage (trahit un opérateur en tenue civile).
const FACE_PAINTS: Dictionary = {
	&"none": "Aucune",
	&"stripes": "Bandes",
	&"full": "Visage couvert",
}

const BEARDS: Dictionary = {
	&"none": "Rasé de près",
	&"stubble": "Barbe courte",
	&"full": "Barbe fournie",
}

## Accessoires (interrupteurs de `OperatorProfile`) : nom affiché.
const ACCESSORIES: Dictionary = {
	&"balaclava": "Cagoule",
	&"nvg": "Jumelles de vision nocturne GPNVG-18 (casque)",
	&"headset": "Casque audio",
	&"vest": "Gilet tactique",
	&"backpack": "Sac à dos",
	&"radio": "Radio",
	&"knee_pads": "Genouillères",
	&"sunglasses": "Lunettes de soleil Oakley",
}

## Armes principales : nom, description et réglages de tir (`UnitStats`).
## La carabine reprend les réglages de base de l'opérateur.
const PRIMARY: Dictionary = {
	&"carbine": {
		"short": "Carabine",
		"name": "Carabine silencieuse",
		"description": "Polyvalente : portée moyenne, discrète.",
		"stats": {
			"fire_range": 16.0, "aim_time": 0.4, "fire_interval": 0.5, "fire_damage": 34.0,
			"hit_chance_near": 0.95, "hit_chance_far": 0.6, "magazine_size": 10, "reserve_ammo": 20,
			"reload_time": 2.0, "gunshot_noise_radius": 8.0, "suppressed": true,
		},
	},
	&"smg": {
		"short": "PM",
		"name": "Pistolet-mitrailleur silencieux",
		"description": "Très discret et rapide, mais courte portée et faibles dégâts.",
		"stats": {
			"fire_range": 11.0, "aim_time": 0.3, "fire_interval": 0.3, "fire_damage": 25.0,
			"hit_chance_near": 0.95, "hit_chance_far": 0.5, "magazine_size": 15, "reserve_ammo": 30,
			"reload_time": 1.6, "gunshot_noise_radius": 5.0, "suppressed": true,
		},
	},
	&"dmr": {
		"short": "Précision",
		"name": "Fusil de précision",
		"description": "Longue portée et gros dégâts ; lent, peu de munitions, plus bruyant.",
		"stats": {
			"fire_range": 24.0, "aim_time": 0.7, "fire_interval": 1.1, "fire_damage": 60.0,
			"hit_chance_near": 0.97, "hit_chance_far": 0.8, "magazine_size": 5, "reserve_ammo": 10,
			"reload_time": 2.5, "gunshot_noise_radius": 12.0, "suppressed": true,
		},
	},
	&"shotgun": {
		"short": "Combat",
		"name": "Fusil de combat",
		"description": "Dévastateur de près, inutile de loin ; sans silencieux, il s'entend de loin.",
		"stats": {
			"fire_range": 8.0, "aim_time": 0.35, "fire_interval": 0.9, "fire_damage": 70.0,
			"hit_chance_near": 0.98, "hit_chance_far": 0.5, "magazine_size": 6, "reserve_ammo": 12,
			"reload_time": 2.8, "gunshot_noise_radius": 18.0, "suppressed": false,
		},
	},
	&"pump_shotgun": {
		"short": "Pompe",
		"name": "Fusil à pompe",
		"description": "Une gerbe de plombs qui fauche à bout portant mais se disperse vite : dégâts en chute avec la distance, pompe à manœuvrer après chaque tir, magasin tubulaire de 5 cartouches. Bruyant.",
		"stats": {
			"fire_range": 9.0, "aim_time": 0.35, "fire_interval": 1.0, "fire_damage": 95.0, "fire_damage_far": 20.0,
			"hit_chance_near": 0.99, "hit_chance_far": 0.7, "magazine_size": 5, "reserve_ammo": 15,
			"reload_time": 3.2, "gunshot_noise_radius": 18.0, "suppressed": false,
		},
	},
	&"famas": {
		"short": "FAMAS",
		"name": "FAMAS",
		"description": "Fusil d'assaut bullpup français : cadence très élevée et chargeur de 25, mais sans silencieux.",
		"stats": {
			"fire_range": 15.0, "aim_time": 0.35, "fire_interval": 0.3, "fire_damage": 30.0,
			"hit_chance_near": 0.93, "hit_chance_far": 0.55, "magazine_size": 25, "reserve_ammo": 50,
			"reload_time": 2.2, "gunshot_noise_radius": 16.0, "suppressed": false,
		},
	},
	&"scar_l": {
		"short": "SCAR-L",
		"name": "FN SCAR Light",
		"description": "Fusil d'assaut 5,56 mm silencieux : la carabine en mieux approvisionnée, un peu plus lourde.",
		"stats": {
			"fire_range": 17.0, "aim_time": 0.4, "fire_interval": 0.45, "fire_damage": 34.0,
			"hit_chance_near": 0.95, "hit_chance_far": 0.62, "magazine_size": 20, "reserve_ammo": 40,
			"reload_time": 2.1, "gunshot_noise_radius": 9.0, "suppressed": true,
		},
	},
	&"scar_h": {
		"short": "SCAR-H",
		"name": "FN SCAR Heavy",
		"description": "Fusil de combat 7,62 mm silencieux : plus de portée et de dégâts, cadence plus lente.",
		"stats": {
			"fire_range": 20.0, "aim_time": 0.5, "fire_interval": 0.6, "fire_damage": 46.0,
			"hit_chance_near": 0.95, "hit_chance_far": 0.7, "magazine_size": 15, "reserve_ammo": 30,
			"reload_time": 2.4, "gunshot_noise_radius": 11.0, "suppressed": true,
		},
	},
	&"hk417": {
		"short": "HK417",
		"name": "HK417",
		"description": "Fusil de tireur d'élite 7,62 mm à lunette, silencieux : précis de loin, semi-automatique.",
		"stats": {
			"fire_range": 22.0, "aim_time": 0.6, "fire_interval": 0.8, "fire_damage": 52.0,
			"hit_chance_near": 0.96, "hit_chance_far": 0.76, "magazine_size": 10, "reserve_ammo": 20,
			"reload_time": 2.4, "gunshot_noise_radius": 11.0, "suppressed": true,
		},
	},
	&"hecate": {
		"short": "Hécate",
		"name": "PGM Hécate II",
		"description": "Fusil de précision lourd en 12,7 mm, à verrou : touche et abat d'un seul tir à très longue portée. Visée longue, cadence lente, très lourd et sans silencieux : la détonation s'entend de très loin.",
		"stats": {
			"fire_range": 48.0, "aim_time": 1.4, "fire_interval": 2.4, "fire_damage": 160.0,
			"hit_chance_near": 0.88, "hit_chance_far": 0.85, "magazine_size": 7, "reserve_ammo": 14,
			"reload_time": 3.8, "gunshot_noise_radius": 32.0, "suppressed": false,
		},
	},
	&"m249": {
		"short": "M249",
		"name": "M249 (mitrailleuse légère)",
		"description": "Feu de saturation : bande de 100 cartouches, mais lourde, imprécise de loin, très bruyante et longue à recharger.",
		"stats": {
			"fire_range": 18.0, "aim_time": 0.7, "fire_interval": 0.15, "fire_damage": 26.0,
			"hit_chance_near": 0.85, "hit_chance_far": 0.42, "magazine_size": 100, "reserve_ammo": 100,
			"reload_time": 4.5, "gunshot_noise_radius": 22.0, "suppressed": false,
		},
	},
}

## Armes secondaires (portées à la cuisse) : nom, description et réglages de
## tir. L'opérateur la dégaine quand l'arme principale est à sec, ou sur
## ordre (Y).
const SECONDARY: Dictionary = {
	&"pistol": {
		"name": "Pistolet silencieux",
		"description": "Arme de secours discrète : courte portée, chargeur de 8.",
		"stats": {
			"fire_range": 10.0, "aim_time": 0.3, "fire_interval": 0.45, "fire_damage": 28.0,
			"hit_chance_near": 0.92, "hit_chance_far": 0.5, "magazine_size": 8, "reserve_ammo": 16,
			"reload_time": 1.5, "gunshot_noise_radius": 5.0, "suppressed": true,
		},
	},
	&"machine_pistol": {
		"name": "Pistolet automatique",
		"description": "Cadence élevée mais peu précis, et sans silencieux.",
		"stats": {
			"fire_range": 9.0, "aim_time": 0.25, "fire_interval": 0.2, "fire_damage": 18.0,
			"hit_chance_near": 0.9, "hit_chance_far": 0.4, "magazine_size": 18, "reserve_ammo": 18,
			"reload_time": 1.8, "gunshot_noise_radius": 14.0, "suppressed": false,
		},
	},
	&"hk45": {
		"name": "HK45 silencieux à lampe",
		"description": "Calibre .45, plus puissant que le pistolet. Sa lampe (Maj + changer d'arme) éblouit un garde proche la nuit, mais se voit de loin.",
		"stats": {
			"fire_range": 11.0, "aim_time": 0.35, "fire_interval": 0.5, "fire_damage": 36.0,
			"hit_chance_near": 0.92, "hit_chance_far": 0.5, "magazine_size": 10, "reserve_ammo": 20,
			"reload_time": 1.6, "gunshot_noise_radius": 5.5, "suppressed": true,
		},
	},
	&"none": {"name": "Aucune", "description": "", "stats": {}},
}
## Armes secondaires qui portent une lampe tactique.
const LAMP_SIDEARMS: Array[StringName] = [&"hk45"]

## Équipement : nom affiché et nombre maximal.
const EQUIPMENT: Dictionary = {
	&"throwing_knives": {"name": "Couteaux de lancer", "max": 2},
	&"grenades": {"name": "Grenades", "max": 4},
	&"smoke_grenades": {"name": "Grenades fumigènes", "max": 3},
	&"stun_grenades": {"name": "Grenades assourdissantes", "max": 3},
	&"explosives": {"name": "Charges explosives", "max": 2},
	&"medkit": {"name": "Trousse de soins", "max": 1},
	&"shield": {"name": "Bouclier balistique", "max": 1},
	&"grapnel": {"name": "Grappin", "max": 1},
	&"hatchet": {"name": "Hachette", "max": 1},
	&"launcher_grenades": {"name": "Grenades de 40 mm (lance-grenades M320)", "max": 4},
	&"launcher_smoke": {"name": "Obus fumigènes de 40 mm (M320)", "max": 3},
	&"launcher_gas": {"name": "Obus lacrymogènes de 40 mm (M320)", "max": 3},
}

## Lance-grenades M320 : monté sous le garde-main de ces armes principales,
## porté seul (avec sa crosse) sinon. Emporté dès qu'on prend des munitions
## de 40 mm ; son poids (`LAUNCHER_WEIGHT`) s'ajoute alors une fois.
const LAUNCHER_RIFLES: Array[StringName] = [&"carbine", &"famas", &"scar_l", &"scar_h", &"hk417"]
const LAUNCHER_AMMO: Array[StringName] = [&"launcher_grenades", &"launcher_smoke", &"launcher_gas"]
const LAUNCHER_WEIGHT := 1.5

## Poids (kg) de ce que porte un opérateur : tenue de base, armes, accessoires
## (casque compris) et équipement (à l'unité).
const BASE_WEIGHT := 2.0
const WEIGHTS: Dictionary = {
	&"carbine": 3.5, &"smg": 2.8, &"dmr": 6.0, &"shotgun": 4.0, &"pump_shotgun": 3.6,
	&"famas": 3.8, &"scar_l": 3.6, &"scar_h": 4.3, &"hk417": 5.0, &"m249": 8.0, &"hecate": 13.8,
	&"pistol": 1.0, &"machine_pistol": 1.6, &"hk45": 1.3, &"none": 0.0,
	&"helmet": 1.4, &"nvg": 0.75, &"headset": 0.3, &"vest": 3.0, &"backpack": 4.0,
	&"radio": 1.0, &"knee_pads": 0.4, &"balaclava": 0.0, &"sunglasses": 0.05,
	&"throwing_knives": 0.3, &"grenades": 0.6, &"smoke_grenades": 0.5, &"stun_grenades": 0.4, &"explosives": 2.0, &"medkit": 1.5,
	&"shield": 7.0, &"grapnel": 2.5, &"hatchet": 0.9, &"launcher_grenades": 0.25, &"launcher_smoke": 0.25, &"launcher_gas": 0.25,
}
## Paliers de charge : jusqu'à `limit` kg, vitesses multipliées par `speed` ;
## le palier lourd fait du bruit en courant (`noise`, rayon en m). Au-delà de
## `MAX_LOAD`, l'écran refuse d'ajouter du poids.
const LOAD_TIERS: Array[Dictionary] = [
	{"name": "Légère", "limit": 18.0, "speed": 1.0, "noise": 0.0},
	{"name": "Moyenne", "limit": 23.0, "speed": 0.92, "noise": 0.0},
	{"name": "Lourde", "limit": 28.0, "speed": 0.82, "noise": 3.0},
]
const MAX_LOAD := 28.0

## Spécialités : nom, bonus (description), réglages modifiés (multiplicateur,
## ou ajout pour les chances de toucher) et tenue conseillée (propriétés du
## profil).
const SPECIALTIES: Dictionary = {
	&"none": {"name": "Polyvalent", "description": "Aucun bonus particulier.", "bonus": {}, "outfit": {}},
	&"marksman": {
		"name": "Tireur d'élite",
		"description": "+15 % de portée de tir, +10 points de précision à longue distance.",
		"bonus": {"fire_range": 1.15, "hit_chance_far": 0.1},
		"outfit": {"primary": &"dmr", "secondary": &"pistol", "headwear": &"boonie", "backpack": false, "nvg": false, "grenades": 0, "explosives": 0},
	},
	&"scout": {
		"name": "Éclaireur",
		"description": "+10 % de vitesse dans toutes les postures.",
		"bonus": {"walk_speed": 1.1, "run_speed": 1.1, "crouch_speed": 1.1, "crawl_speed": 1.1},
		"outfit": {"primary": &"smg", "secondary": &"pistol", "headwear": &"cap", "backpack": false, "radio": true, "throwing_knives": 2, "explosives": 0},
	},
	&"sapper": {
		"name": "Sapeur",
		"description": "Explosions 30 % plus larges, charges posées deux fois plus vite.",
		"bonus": {"grenade_radius": 1.3, "explosive_radius": 1.3, "plant_time": 0.5},
		"outfit": {"primary": &"shotgun", "secondary": &"pistol", "headwear": &"helmet", "backpack": true, "explosives": 2, "grenades": 2},
	},
	&"medic": {
		"name": "Infirmier",
		"description": "Soins 60 % plus efficaces et deux fois plus rapides.",
		"bonus": {"heal_amount": 1.6, "heal_time": 0.5},
		"outfit": {"primary": &"carbine", "secondary": &"pistol", "headwear": &"helmet", "backpack": true, "medkit": 1, "explosives": 0},
	},
}

## Décor de l'aperçu selon le camouflage : sol, ciel, lumière et éléments
## de décor (`props`).
const BACKDROPS: Dictionary = {
	&"": {"ground": Color(0.24, 0.26, 0.25), "sky": Color(0.16, 0.18, 0.17), "sun": Color(1, 1, 1), "energy": 1.0, "ambient": Color(0.55, 0.58, 0.55), "props": &""},
	&"woodland": {"ground": Color(0.22, 0.3, 0.15), "sky": Color(0.42, 0.55, 0.6), "sun": Color(1.0, 0.96, 0.85), "energy": 1.0, "ambient": Color(0.5, 0.58, 0.48), "props": &"trees"},
	&"desert": {"ground": Color(0.72, 0.6, 0.42), "sky": Color(0.78, 0.7, 0.55), "sun": Color(1.0, 0.92, 0.78), "energy": 1.25, "ambient": Color(0.68, 0.6, 0.5), "props": &"rocks"},
	&"urban": {"ground": Color(0.36, 0.36, 0.37), "sky": Color(0.5, 0.53, 0.57), "sun": Color(0.95, 0.96, 1.0), "energy": 0.9, "ambient": Color(0.55, 0.56, 0.58), "props": &"walls"},
	&"snow": {"ground": Color(0.86, 0.89, 0.92), "sky": Color(0.7, 0.76, 0.82), "sun": Color(0.92, 0.96, 1.0), "energy": 0.9, "ambient": Color(0.7, 0.74, 0.8), "props": &"pines"},
	&"night": {"ground": Color(0.07, 0.08, 0.1), "sky": Color(0.02, 0.03, 0.06), "sun": Color(0.55, 0.65, 1.0), "energy": 0.45, "ambient": Color(0.22, 0.26, 0.38), "props": &"rocks"},
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


## Copie de `base` avec les réglages de tir de l'arme secondaire `weapon`
## (null sans arme secondaire).
static func secondary_stats(base: UnitStats, weapon: StringName) -> UnitStats:
	var values: Dictionary = SECONDARY.get(weapon, SECONDARY[&"none"])["stats"]
	if values.is_empty():
		return null
	var stats := base.duplicate() as UnitStats
	for key: String in values:
		stats.set(key, values[key])
	return stats


## Poids total (kg) porté par l'opérateur `profile`.
static func load_of(profile: OperatorProfile) -> float:
	var total := BASE_WEIGHT + float(WEIGHTS.get(profile.primary, 0.0)) + float(WEIGHTS.get(profile.secondary, 0.0))
	if profile.headwear == &"helmet":
		total += WEIGHTS[&"helmet"]
	if profile.wears_nvg():
		total += WEIGHTS[&"nvg"]
	for key: StringName in [&"headset", &"vest", &"backpack", &"radio", &"knee_pads", &"balaclava", &"sunglasses"]:
		if profile.get(key):
			total += WEIGHTS[key]
	for key: StringName in EQUIPMENT:
		total += WEIGHTS[key] * int(profile.get(key))
	if carries_launcher(profile):
		total += LAUNCHER_WEIGHT
	return snappedf(total, 0.1)


## Vrai si `profile` emporte le lance-grenades (des munitions de 40 mm).
static func carries_launcher(profile: OperatorProfile) -> bool:
	for key in LAUNCHER_AMMO:
		if int(profile.get(key)) > 0:
			return true
	return false


## Palier de charge (`LOAD_TIERS`) de `weight` kg.
static func load_tier(weight: float) -> Dictionary:
	for tier in LOAD_TIERS:
		if weight <= float(tier["limit"]) + 0.001:
			return tier
	return LOAD_TIERS[LOAD_TIERS.size() - 1]


## Applique à `stats` (modifié sur place) le palier de charge de `weight` kg
## et les bonus de la spécialité `specialty`.
static func apply_load_and_specialty(stats: UnitStats, weight: float, specialty: StringName) -> void:
	var tier := load_tier(weight)
	for key: String in ["walk_speed", "run_speed", "crouch_speed", "crawl_speed"]:
		stats.set(key, float(stats.get(key)) * float(tier["speed"]))
	stats.gear_noise_radius = tier["noise"]
	var bonus: Dictionary = SPECIALTIES.get(specialty, SPECIALTIES[&"none"])["bonus"]
	for key: String in bonus:
		if key.begins_with("hit_chance"):
			stats.set(key, minf(float(stats.get(key)) + float(bonus[key]), 1.0))
		else:
			stats.set(key, float(stats.get(key)) * float(bonus[key]))


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
