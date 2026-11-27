class_name OperatorProfile
extends Resource
## Personnalisation d'un opérateur de l'équipe : identité, visage, tenue,
## accessoires, armes et équipement (choix dans `GearCatalog`). Réglée dans
## l'écran « Opérateurs », sauvegardée par `OperatorRoster` et appliquée en
## mission par `Commando` (réglages de tir) et `SoldierModel` (apparence).

## Identités par défaut des trois opérateurs (indicatif, nom, visage).
const DEFAULTS: Array[Dictionary] = [
	{"callsign": "Alpha", "name": "Marc Delaunay", "skin": 1, "hair_style": &"short", "hair_color": 1, "beard": &"stubble"},
	{"callsign": "Bravo", "name": "Inès Morel", "body": &"female", "skin": 2, "hair_style": &"long", "hair_color": 0, "beard": &"none"},
	{"callsign": "Charlie", "name": "Karim Benali", "skin": 3, "hair_style": &"shaved", "hair_color": 0, "beard": &"full"},
]

# Identité.
@export var name: String = ""
@export var callsign: String = ""
## Morphologie (`GearCatalog.BODIES`) : silhouette et visage du modèle.
@export var body: StringName = &"male"
## Indices dans `GearCatalog.SKINS` et `HAIR_COLORS`.
@export var skin: int = 1
@export var hair_style: StringName = &"short"
@export var hair_color: int = 1
@export var beard: StringName = &"none"
## Traits du visage (`GearCatalog.NOSES`, `JAWS`, `EYES`, `SCARS`,
## `FACE_PAINTS`).
@export var nose: StringName = &"straight"
@export var jaw: StringName = &"normal"
@export var eyes: StringName = &"normal"
@export var scar: StringName = &"none"
@export var face_paint: StringName = &"none"

# Tenue : camouflage du haut et du pantalon (`GearCatalog.CAMOS`, vide : uni).
@export var camo: StringName = &""
## Camouflage propre au pantalon (`SAME_CAMO` : celui du haut ; vide : uni),
## au gilet et au couvre-chef (vide : uni).
@export var pants_camo: StringName = &"="
@export var vest_camo: StringName = &""
@export var headwear_camo: StringName = &""
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
## Lunettes de soleil (enveloppantes, verres miroir).
@export var sunglasses: bool = false
## Tenue (`GearCatalog.CLOTHING`) : treillis ou tenue civile.
@export var clothing: StringName = &"uniform"
## Blessure gardée d'une mission à l'autre : points de vie manquants au
## départ, jusqu'à ce qu'une trousse le soigne en mission.
@export var wound: float = 0.0

# Armement.
@export var primary: StringName = &"carbine"
@export var secondary: StringName = &"pistol"
@export var throwing_knives: int = 1
@export var grenades: int = 0
## Grenades fumigènes : un nuage qui coupe la vue des ennemis.
@export var smoke_grenades: int = 0
## Grenades assourdissantes : éclair et détonation qui sonnent les ennemis
## proches quelques secondes.
@export var stun_grenades: int = 0
@export var explosives: int = 0
@export var medkit: int = 0
## Bouclier balistique (0 ou 1) : levé, il arrête les balles venant de face.
@export var shield: int = 0
## Grappin (0 ou 1) : lancé vers un point en hauteur, on y monte à la corde.
@export var grapnel: int = 0
## Hachette (0 ou 1) : au corps à corps, tue même de face, mais bruyamment.
@export var hatchet: int = 0
## Grenades explosives de 40 mm pour le lance-grenades M320 (sous le canon).
@export var launcher_grenades: int = 0
## Obus fumigènes de 40 mm (M320) : un nuage tiré de loin.
@export var launcher_smoke: int = 0
## Obus lacrymogènes de 40 mm (M320) : un nuage de gaz qui suffoque les gardes.
@export var launcher_gas: int = 0
## Lunette thermique sur l'arme principale : vise à travers la fumée, et
## donne la vue thermique (touche des JVN).
@export var thermal_scope: bool = false
## Taser : nombre de cartouches (un tir chacune) ; le garde touché s'effondre.
@export var taser: int = 0
## Brouilleur : nombre de charges ; chacune aveugle les drones proches.
@export var jammer: int = 0

## Spécialité (`GearCatalog.SPECIALTIES`) : petit bonus en mission.
@export var specialty: StringName = &"none"
## Tenues enregistrées : [{"name": String, "outfit": Dictionary}] (voir
## `outfit_dict`), au plus `MAX_SAVED_OUTFITS`.
@export var saved_outfits: Array[Dictionary] = []

const MAX_SAVED_OUTFITS := 6
## Pantalon assorti au haut (`pants_camo`).
const SAME_CAMO := &"="
## Camouflages par vêtement.
const PART_CAMO_KEYS: Array[String] = ["pants_camo", "vest_camo", "headwear_camo"]
## Propriétés d'une tenue : apparence (hors visage) et armement.
const OUTFIT_KEYS: Array[String] = [
	"clothing", "sunglasses", "camo", "pants_camo", "vest_camo", "headwear_camo", "top_color", "pants_color", "vest_color", "headwear_color", "headwear",
	"balaclava", "nvg", "headset", "vest", "backpack", "radio", "knee_pads",
	"primary", "secondary", "throwing_knives", "grenades", "smoke_grenades", "stun_grenades", "explosives", "medkit", "shield", "grapnel", "hatchet",
	"launcher_grenades", "launcher_smoke", "launcher_gas", "taser", "jammer", "thermal_scope",
]
## Propriétés copiées vers les autres opérateurs (« même tenue ») : camouflage,
## couleurs, couvre-chef et accessoires, sans l'armement.
const LOOK_KEYS: Array[String] = [
	"clothing", "sunglasses", "camo", "pants_camo", "vest_camo", "headwear_camo", "top_color", "pants_color", "vest_color", "headwear_color", "headwear",
	"balaclava", "nvg", "headset", "vest", "backpack", "radio", "knee_pads",
]

const _COLOR_KEYS: Array[String] = ["top_color", "pants_color", "vest_color", "headwear_color"]
const _NAME_KEYS: Array[String] = ["body", "clothing", "camo", "pants_camo", "vest_camo", "headwear_camo", "nose", "jaw", "eyes", "scar", "face_paint", "hair_style", "beard", "headwear", "primary", "secondary", "specialty"]
const _BOOL_KEYS: Array[String] = ["balaclava", "nvg", "headset", "vest", "backpack", "radio", "knee_pads", "sunglasses", "thermal_scope"]
const _INT_KEYS: Array[String] = ["skin", "hair_color", "throwing_knives", "grenades", "smoke_grenades", "stun_grenades", "explosives", "medkit", "shield", "grapnel", "hatchet",
	"launcher_grenades", "launcher_smoke", "launcher_gas", "taser", "jammer"]


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
## Camouflage du vêtement `part` (`top`, `pants`, `vest`, `headwear`) ;
## vide s'il est uni.
func camo_of(part: StringName) -> StringName:
	match part:
		&"pants":
			return camo if pants_camo == SAME_CAMO else pants_camo
		&"vest":
			return vest_camo
		&"headwear":
			return headwear_camo
	return camo


func set_camo(id: StringName) -> void:
	camo = id
	pants_camo = SAME_CAMO
	if id.is_empty():
		return
	var entry: Dictionary = GearCatalog.CAMOS[id]
	top_color = entry["colors"][0]
	pants_color = entry["colors"][0]
	vest_color = entry["vest"]
	headwear_color = entry["headwear"]


## Revêt la tenue `id` (`GearCatalog.CLOTHING`) : une tenue civile donne ses
## couleurs, tête nue, et retire l'équipement militaire voyant.
func set_clothing(id: StringName) -> void:
	clothing = id
	var look: Dictionary = GearCatalog.CLOTHING[id]["look"]
	for key: String in look:
		set(key, look[key])
	if is_civilian():
		for key: StringName in GearCatalog.MILITARY_GEAR:
			set(key, false)


## Vrai en tenue civile (costume ou décontractée).
func is_civilian() -> bool:
	return clothing != &"uniform"


## Copie conforme du profil.
func copy() -> OperatorProfile:
	return from_dict(to_dict(), 0)


## Tenue portée (propriétés `OUTFIT_KEYS`), au format JSON.
func outfit_dict() -> Dictionary:
	var data := to_dict()
	var outfit := {}
	for key in OUTFIT_KEYS:
		outfit[key] = data[key]
	return outfit


## Revêt la tenue `outfit` (format de `outfit_dict`) ; ce qui manque ou n'est
## pas valide est laissé tel quel.
func wear_outfit(outfit: Dictionary) -> void:
	var data := to_dict()
	for key in OUTFIT_KEYS:
		if outfit.has(key):
			data[key] = outfit[key]
	_assign(from_dict(data, 0), OUTFIT_KEYS)


## Reprend l'apparence (`LOOK_KEYS`) de `other`.
func copy_look_from(other: OperatorProfile) -> void:
	_assign(other, LOOK_KEYS)


## Enregistre la tenue portée sous le nom `title` (remplace celle du même nom).
## Renvoie faux s'il y en a déjà `MAX_SAVED_OUTFITS`.
func save_outfit(title: String) -> bool:
	title = title.strip_edges().left(24)
	if title.is_empty():
		title = "Tenue %d" % (saved_outfits.size() + 1)
	for entry in saved_outfits:
		if entry["name"] == title:
			entry["outfit"] = outfit_dict()
			return true
	if saved_outfits.size() >= MAX_SAVED_OUTFITS:
		return false
	saved_outfits.append({"name": title, "outfit": outfit_dict()})
	return true


## Applique les propriétés de la tenue conseillée pour la spécialité.
func wear_specialty_outfit() -> void:
	var outfit: Dictionary = GearCatalog.SPECIALTIES[specialty]["outfit"]
	for key: String in outfit:
		set(key, outfit[key])


func _assign(source: OperatorProfile, keys: Array[String]) -> void:
	for key in keys:
		set(key, source.get(key))


## Données JSON (couleurs en « rrggbb »).
func to_dict() -> Dictionary:
	var data := {"name": name, "callsign": callsign}
	for key in _COLOR_KEYS:
		data[key] = (get(key) as Color).to_html(false)
	for key in _NAME_KEYS:
		data[key] = String(get(key))
	for key in _BOOL_KEYS + _INT_KEYS:
		data[key] = get(key)
	data["saved_outfits"] = saved_outfits.duplicate(true)
	data["wound"] = wound
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
		"camo": GearCatalog.CAMOS, "pants_camo": GearCatalog.CAMOS, "vest_camo": GearCatalog.CAMOS, "headwear_camo": GearCatalog.CAMOS, "hair_style": GearCatalog.HAIR_STYLES, "beard": GearCatalog.BEARDS,
		"body": GearCatalog.BODIES, "headwear": GearCatalog.HEADWEAR, "primary": GearCatalog.PRIMARY, "secondary": GearCatalog.SECONDARY,
		"specialty": GearCatalog.SPECIALTIES, "clothing": GearCatalog.CLOTHING,
		"nose": GearCatalog.NOSES, "jaw": GearCatalog.JAWS, "eyes": GearCatalog.EYES, "scar": GearCatalog.SCARS, "face_paint": GearCatalog.FACE_PAINTS,
	}
	for key in _NAME_KEYS:
		var value := StringName(str(data.get(key, "")))
		var plain := (key == "camo" or key in PART_CAMO_KEYS) and value.is_empty()
		var same := key == "pants_camo" and value == SAME_CAMO
		if plain or same or (choices[key] as Dictionary).has(value):
			profile.set(key, value)
	for key in _BOOL_KEYS:
		if data.get(key) is bool:
			profile.set(key, data[key])
	var limits := {
		"skin": GearCatalog.SKINS.size() - 1, "hair_color": GearCatalog.HAIR_COLORS.size() - 1,
		"throwing_knives": GearCatalog.EQUIPMENT[&"throwing_knives"]["max"], "grenades": GearCatalog.EQUIPMENT[&"grenades"]["max"],
		"smoke_grenades": GearCatalog.EQUIPMENT[&"smoke_grenades"]["max"], "stun_grenades": GearCatalog.EQUIPMENT[&"stun_grenades"]["max"],
		"explosives": GearCatalog.EQUIPMENT[&"explosives"]["max"], "medkit": GearCatalog.EQUIPMENT[&"medkit"]["max"],
		"shield": GearCatalog.EQUIPMENT[&"shield"]["max"], "grapnel": GearCatalog.EQUIPMENT[&"grapnel"]["max"],
		"hatchet": GearCatalog.EQUIPMENT[&"hatchet"]["max"],
	}
	# Le reste de l'équipement : la limite du catalogue.
	for key: StringName in GearCatalog.EQUIPMENT:
		if not limits.has(String(key)):
			limits[String(key)] = GearCatalog.EQUIPMENT[key]["max"]
	for key in _INT_KEYS:
		var value: Variant = data.get(key)
		if value is int or value is float:
			profile.set(key, clampi(int(value), 0, limits[key]))
	if profile.callsign.is_empty():
		profile.callsign = defaults(index).callsign
	var wound: Variant = data.get("wound")
	if wound is int or wound is float:
		profile.wound = clampf(float(wound), 0.0, 1000.0)
	if data.get("saved_outfits") is Array:
		for entry: Variant in data["saved_outfits"]:
			if profile.saved_outfits.size() >= MAX_SAVED_OUTFITS:
				break
			if entry is Dictionary and entry.get("name") is String and entry.get("outfit") is Dictionary:
				profile.saved_outfits.append({"name": (entry["name"] as String).left(24), "outfit": entry["outfit"]})
	return profile
