class_name OperatorProfile
extends Resource
## Personnalisation d'un opérateur de l'équipe : identité, visage, tenue,
## accessoires, armes et équipement (choix dans `GearCatalog`). Réglée dans
## l'écran « Opérateurs », sauvegardée par `OperatorRoster` et appliquée en
## mission par `Commando` (réglages de tir) et `SoldierModel` (apparence).

## Identités par défaut des trois opérateurs (indicatif, nom, visage).
const DEFAULTS: Array[Dictionary] = [
	{"callsign": "Alpha", "name": "Marc Delaunay", "skin": 1, "hair_style": &"short", "hair_color": 1, "beard": &"stubble"},
	{"callsign": "Bravo", "name": "Inès Morel", "skin": 2, "hair_style": &"ponytail", "hair_color": 0, "beard": &"none"},
	{"callsign": "Charlie", "name": "Karim Benali", "skin": 3, "hair_style": &"shaved", "hair_color": 0, "beard": &"full"},
]

# Identité.
@export var name: String = ""
@export var callsign: String = ""
## Indices dans `GearCatalog.SKINS` et `HAIR_COLORS`.
@export var skin: int = 1
@export var hair_style: StringName = &"short"
@export var hair_color: int = 1
@export var beard: StringName = &"none"

# Tenue : camouflage du haut et du pantalon (`GearCatalog.CAMOS`, vide : uni).
@export var camo: StringName = &""
@export var top_color := Color(0.3, 0.33, 0.24)
@export var pants_color := Color(0.3, 0.33, 0.24)
## Gilet et équipement (poches, ceinturon, sac).
@export var vest_color := Color(0.16, 0.17, 0.14)
@export var headwear_color := Color(0.25, 0.27, 0.2)

# Accessoires.
@export var headwear: StringName = &"helmet"
@export var balaclava: bool = true
@export var nvg: bool = true
@export var headset: bool = true
@export var vest: bool = true
@export var backpack: bool = true
@export var radio: bool = true
@export var knee_pads: bool = true

# Armement.
@export var primary: StringName = &"carbine"
@export var secondary: StringName = &"pistol"
@export var throwing_knives: int = 1
@export var grenades: int = 0
@export var explosives: int = 0
@export var medkit: int = 0

const _COLOR_KEYS: Array[String] = ["top_color", "pants_color", "vest_color", "headwear_color"]
const _NAME_KEYS: Array[String] = ["camo", "hair_style", "beard", "headwear", "primary", "secondary"]
const _BOOL_KEYS: Array[String] = ["balaclava", "nvg", "headset", "vest", "backpack", "radio", "knee_pads"]
const _INT_KEYS: Array[String] = ["skin", "hair_color", "throwing_knives", "grenades", "explosives", "medkit"]


## Profil par défaut de l'opérateur numéro `index` (0 à 2).
static func defaults(index: int) -> OperatorProfile:
	var profile := OperatorProfile.new()
	var identity: Dictionary = DEFAULTS[clampi(index, 0, DEFAULTS.size() - 1)]
	for key: String in identity:
		profile.set(key, identity[key])
	return profile


## Le JVN se fixe sur le casque : sans casque, il n'est pas porté.
func wears_nvg() -> bool:
	return nvg and headwear == &"helmet"


## Choisit le camouflage `id` (vide : uni) : haut et pantalon prennent sa
## couleur dominante, gilet et couvre-chef ses couleurs conseillées.
func set_camo(id: StringName) -> void:
	camo = id
	if id.is_empty():
		return
	var entry: Dictionary = GearCatalog.CAMOS[id]
	top_color = entry["colors"][0]
	pants_color = entry["colors"][0]
	vest_color = entry["vest"]
	headwear_color = entry["headwear"]


## Données JSON (couleurs en « rrggbb »).
func to_dict() -> Dictionary:
	var data := {"name": name, "callsign": callsign}
	for key in _COLOR_KEYS:
		data[key] = (get(key) as Color).to_html(false)
	for key in _NAME_KEYS:
		data[key] = String(get(key))
	for key in _BOOL_KEYS + _INT_KEYS:
		data[key] = get(key)
	return data


## Profil lu de `data` ; ce qui manque ou n'est pas valide garde la valeur
## par défaut de l'opérateur `index`.
static func from_dict(data: Dictionary, index: int) -> OperatorProfile:
	var profile := defaults(index)
	for key: String in ["name", "callsign"]:
		if data.get(key) is String:
			profile.set(key, (data[key] as String).strip_edges().left(24))
	for key in _COLOR_KEYS:
		if data.get(key) is String and Color.html_is_valid(data[key]):
			profile.set(key, Color.html(data[key]))
	var choices := {
		"camo": GearCatalog.CAMOS, "hair_style": GearCatalog.HAIR_STYLES, "beard": GearCatalog.BEARDS,
		"headwear": GearCatalog.HEADWEAR, "primary": GearCatalog.PRIMARY, "secondary": GearCatalog.SECONDARY,
	}
	for key in _NAME_KEYS:
		var value := StringName(str(data.get(key, "")))
		if (key == "camo" and value.is_empty()) or (choices[key] as Dictionary).has(value):
			profile.set(key, value)
	for key in _BOOL_KEYS:
		if data.get(key) is bool:
			profile.set(key, data[key])
	var limits := {
		"skin": GearCatalog.SKINS.size() - 1, "hair_color": GearCatalog.HAIR_COLORS.size() - 1,
		"throwing_knives": GearCatalog.EQUIPMENT[&"throwing_knives"]["max"], "grenades": GearCatalog.EQUIPMENT[&"grenades"]["max"],
		"explosives": GearCatalog.EQUIPMENT[&"explosives"]["max"], "medkit": GearCatalog.EQUIPMENT[&"medkit"]["max"],
	}
	for key in _INT_KEYS:
		var value: Variant = data.get(key)
		if value is int or value is float:
			profile.set(key, clampi(int(value), 0, limits[key]))
	if profile.callsign.is_empty():
		profile.callsign = defaults(index).callsign
	return profile
