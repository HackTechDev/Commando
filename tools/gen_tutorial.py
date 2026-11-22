"""Génère scenes/levels/tutorial/tutorial.tscn (didacticiel) : terrain,
ateliers (`TutorialStation`) et leurs textes. Usage : python3 tools/gen_tutorial.py
Les touches s'écrivent {action} (nom d'une action de l'InputMap)."""
import os

from mapkit import write_scene
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes", "levels", "tutorial", "tutorial.tscn")

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

def tf(x, y, z, basis="1, 0, 0, 0, 1, 0, 0, 0, 1"):
    return f"Transform3D({basis}, {x}, {y}, {z})"

FACE_SOUTH = "-1, 0, 0, 0, 1, 0, 0, 0, -1"   # regarde vers +Z
FACE_EAST = "0, 0, -1, 0, 1, 0, 1, 0, 0"     # regarde vers +X (cf. Soldier1)

STATIONS = [
    dict(name="Move", step=1, pos=(0, 0, 35), size=(16, 10), goal="REACH", goal_offset=(0, 0, -8), radius=1.5,
         objective="tuto_move", start=True,
         title="Se déplacer",
         text="Bienvenue. Clic gauche sur un opérateur (ou touches 1, 2, 3) pour le sélectionner ; un rectangle en sélectionne plusieurs. Clic droit au sol : il y marche.\nCaméra : {camera_forward} {camera_left} {camera_back} {camera_right} ou bord de l'écran, molette pour le zoom, {camera_rotate_left} / {camera_rotate_right} pour tourner, {camera_focus} pour recentrer.\n\nAmenez un opérateur dans le cercle bleu.",
         done="Suivez l'allée vers le nord : chaque « ? » jaune est un atelier. {toggle_help} affiche toutes les commandes."),
    dict(name="Run", step=2, pos=(0, 0, 22), size=(12, 6), goal="REACH", goal_offset=(0, 0, -16), radius=1.5,
         objective="tuto_run",
         title="Courir et se baisser",
         text="Double clic droit : courir. C'est rapide mais bruyant, et on ne court que debout.\n{posture_crouch} : accroupi, plus lent mais plus discret. {posture_prone} : couché, on rampe et on est plus difficile à toucher. {dive} : roulade vers le curseur, qui finit couché.\nLe muret bas s'enjambe tout seul.\n\nCourez jusqu'au cercle au bout de l'allée.",
         done="Plus loin : le terrain d'escalade."),
    dict(name="Climb", step=3, pos=(0, 0, 0), size=(14, 6), goal="REACH", goal_offset=(5, 3, -8), radius=1.6, min_height=2.5,
         objective="tuto_climb",
         title="Grimper",
         text="Clic droit sur une caisse : l'opérateur grimpe dessus, puis saute d'une caisse à l'autre. Clic droit sur le toit du bunker : il y monte par l'échelle.\n{action_crate} puis clic sur une caisse : la pousser ou la tirer pour s'en faire un marchepied. {action_grapple} : grappin, si l'opérateur en porte un.\n\nMontez sur le toit du bunker.",
         done="Redescendez (clic droit au sol) et continuez vers les mannequins."),
    dict(name="Melee", step=4, pos=(0, 0, -16), size=(14, 6), goal="TARGETS_DOWN",
         targets=["Enemies/DummyLeft", "Enemies/DummyRight", "Enemies/DummyFront"], objective="tuto_melee",
         title="Corps à corps",
         text="{action_knockout} puis clic gauche sur un ennemi : l'opérateur s'en approche et l'assomme ; par derrière, c'est un étranglement silencieux. {action_knife} : couteau, mortel.\nClic du milieu sur un ennemi : menu des coups (balayage, projection, désarmement, bouclier humain).\nUn ennemi en alerte lève sa garde : prenez-le à revers, ou pressez {parry} quand il frappe pour parer et contrer.\n\nNeutralisez les trois mannequins.",
         done="Les mannequins se relèveront : direction le stand de tir."),
    dict(name="Shoot", step=5, pos=(0, 0, -29), size=(14, 6), goal="TARGETS_DOWN",
         targets=["Enemies/TargetLeft", "Enemies/TargetMiddle", "Enemies/TargetRight"], objective="tuto_shoot",
         title="Tirer",
         text="Clic droit sur un ennemi : les opérateurs sélectionnés s'approchent à portée et tirent jusqu'à ce qu'il tombe. On vise mieux de près et immobile.\nLes munitions s'affichent sur les portraits, en bas : {reload} recharge, {switch_weapon} passe à l'arme de poing. {action_grenade} puis clic au sol : grenade. Un tir s'entend de loin.\n\nAbattez les trois cibles.",
         done="Dernier atelier : passer la sentinelle."),
    dict(name="Stealth", step=6, pos=(0, 0, -45), size=(14, 5), goal="TARGETS_DOWN",
         targets=["Enemies/Sentry"], objective="tuto_stealth",
         title="Infiltration",
         text="Une sentinelle garde le passage derrière le mur. Son cône de vision s'affiche au sol : vert, elle ne voit rien ; jaune, elle se méfie ; rouge, elle donne l'alerte. Celle-ci n'est pas armée, mais les vraies tirent.\nRestez hors du cône, accroupi, et prenez-la par derrière ({action_knockout} ou {action_knife}). {action_throw} puis clic au sol : un caillou détourne son attention. {tactical_pause} : pause tactique, pour donner ses ordres jeu arrêté.\n\nNeutralisez la sentinelle.",
         done="Rejoignez la zone de fin, au nord."),
    dict(name="Finish", step=7, pos=(0, 0, -62), size=(10, 6), goal="FINISH", goal_offset=(0, 0, 0), radius=2.5,
         objective="tuto_end",
         title="Fin du didacticiel",
         text="Amenez un opérateur dans la zone de fin.",
         done="Bravo, vous connaissez l'essentiel. {toggle_help} affiche toutes les commandes en partie."),
]

GOALS = {"NONE": 0, "REACH": 1, "TARGETS_DOWN": 2, "FINISH": 3}

ext = [
    ("Script", "res://scripts/levels/level_root.gd"),
    ("PackedScene", "res://scenes/camera/camera_rig.tscn"),
    ("PackedScene", "res://scenes/units/commando.tscn"),
    ("PackedScene", "res://scenes/props/wall.tscn"),
    ("PackedScene", "res://scenes/props/crate.tscn"),
    ("PackedScene", "res://scenes/ui/hud.tscn"),
    ("PackedScene", "res://scenes/enemies/enemy.tscn"),
    ("PackedScene", "res://scenes/props/ladder.tscn"),
    ("PackedScene", "res://scenes/props/low_wall.tscn"),
    ("Script", "res://scripts/levels/tutorial_station.gd"),
]
EXT = {path.split("/")[-1].split(".")[0]: str(i + 1) for i, (_, path) in enumerate(ext)}

L = []
L.append(f"[gd_scene load_steps={len(ext) + 12} format=3]\n")
for i, (kind, path) in enumerate(ext):
    L.append(f'[ext_resource type="{kind}" path="{path}" id="{i + 1}"]')
L.append("")
L.append('''[sub_resource type="Curve3D" id="patrol_sentry"]
_data = {
"points": PackedVector3Array(0, 0, 0, 0, 0, 0, -9, 0, -55, 0, 0, 0, 0, 0, 0, 9, 0, -55),
"tilts": PackedFloat32Array(0, 0)
}
point_count = 2

[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.2, 0.24, 0.27, 1)
ambient_light_source = 2
ambient_light_color = Color(0.72, 0.78, 0.9, 1)
ambient_light_energy = 0.55
tonemap_mode = 2
ssao_enabled = true

[sub_resource type="NavigationMesh" id="nav"]
resource_local_to_scene = true
geometry_parsed_geometry_type = 1
geometry_collision_mask = 3
agent_height = 1.75
agent_radius = 0.5

[sub_resource type="BoxShape3D" id="ground_shape"]
size = Vector3(50, 1, 124)

[sub_resource type="StandardMaterial3D" id="ground_mat"]
albedo_color = Color(0.85, 0.85, 0.8, 1)
roughness = 1.0
uv1_scale = Vector3(0.33, 0.33, 0.33)
uv1_triplanar = true
uv1_world_triplanar = true
texture_filter = 5
metadata/albedo_source = "tex_nature/grass_mowed_green_a.jpg"

[sub_resource type="BoxMesh" id="ground_mesh"]
material = SubResource("ground_mat")
size = Vector3(50, 1, 124)

[sub_resource type="StandardMaterial3D" id="dirt_mat"]
roughness = 1.0
uv1_scale = Vector3(0.4, 0.4, 0.4)
uv1_triplanar = true
uv1_world_triplanar = true
texture_filter = 5
metadata/albedo_source = "tex_nature/dirt002.png"

[sub_resource type="PlaneMesh" id="dirt_path"]
material = SubResource("dirt_mat")
size = Vector2(3, 104)

[sub_resource type="BoxShape3D" id="bunker_shape"]
size = Vector3(5, 3, 5)

[sub_resource type="StandardMaterial3D" id="bunker_mat"]
albedo_color = Color(0.8, 0.78, 0.72, 1)
roughness = 0.95
uv1_scale = Vector3(0.5, 0.5, 0.5)
uv1_triplanar = true
uv1_world_triplanar = true
texture_filter = 5
metadata/albedo_source = "tex_ctp1/concrete_g_1.jpg"

[sub_resource type="BoxMesh" id="bunker_mesh"]
material = SubResource("bunker_mat")
size = Vector3(5, 3, 5)
''')

L.append('''[node name="Tutorial" type="Node3D"]
script = ExtResource("%s")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("env")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866, 0.383, -0.3214, 0, 0.6428, 0.766, 0.5, -0.6634, 0.5567, 0, 10, 0)
light_color = Color(1, 0.95, 0.85, 1)
light_energy = 1.3
shadow_enabled = true
directional_shadow_max_distance = 120.0

[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]
navigation_mesh = SubResource("nav")

[node name="Ground" type="StaticBody3D" parent="NavigationRegion3D"]
collision_mask = 0

[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Ground"]
transform = %s
shape = SubResource("ground_shape")

[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Ground"]
transform = %s
mesh = SubResource("ground_mesh")

[node name="Decor" type="Node3D" parent="."]

[node name="Path" type="MeshInstance3D" parent="Decor"]
transform = %s
mesh = SubResource("dirt_path")
''' % (EXT["level_root"], tf(0, -0.5, -8), tf(0, -0.5, -8), tf(0, 0.005, -11)))

# Muret à enjamber (atelier « courir »).
L.append(f'''[node name="LowWall" parent="NavigationRegion3D" instance=ExtResource("{EXT["low_wall"]}")]
transform = {tf(0, 0, 13)}
length = 8.0
''')
# Terrain d'escalade : bunker et échelle, caisses.
L.append(f'''[node name="Bunker" type="StaticBody3D" parent="NavigationRegion3D"]
transform = {tf(5, 0, -8)}
collision_layer = 2
collision_mask = 0

[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Bunker"]
transform = {tf(0, 1.5, 0)}
shape = SubResource("bunker_shape")

[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Bunker"]
transform = {tf(0, 1.5, 0)}
mesh = SubResource("bunker_mesh")

[node name="BunkerLadder" parent="NavigationRegion3D" instance=ExtResource("{EXT["ladder"]}")]
transform = {tf(5, 0, -5.5)}
''')
for i, (x, z, skin) in enumerate([(-4, -6, ""), (-4, -7.3, "tex_base/ecrate_drty-fmtl3.jpg"), (-5.3, -6, ""), (-1.5, -9, "tex_base/ecrate_dunno.jpg")]):
    L.append(f'''[node name="Crate{i + 1}" parent="NavigationRegion3D" instance=ExtResource("{EXT["crate"]}")]
transform = {tf(x, 0, z)}''' + (f'\nskin = "{skin}"' if skin else "") + "\n")
# Mur de la sentinelle, ouvert au milieu.
for name, x in [("WallWestA", -7), ("WallWestB", -13), ("WallWestC", -19), ("WallEastA", 7), ("WallEastB", 13), ("WallEastC", 19)]:
    L.append(f'''[node name="{name}" parent="NavigationRegion3D" instance=ExtResource("{EXT["wall"]}")]
transform = {tf(x, 0, -50)}
''')

L.append(f'''[node name="Units" type="Node3D" parent="."]

[node name="Alpha" parent="Units" instance=ExtResource("{EXT["commando"]}")]
transform = {tf(0, 0, 38)}
unit_index = 1
display_name = "Alpha"

[node name="Bravo" parent="Units" instance=ExtResource("{EXT["commando"]}")]
transform = {tf(-1.6, 0, 39.2)}
unit_index = 2
display_name = "Bravo"

[node name="Charlie" parent="Units" instance=ExtResource("{EXT["commando"]}")]
transform = {tf(1.6, 0, 39.2)}
unit_index = 3
display_name = "Charlie"

[node name="CameraRig" parent="." instance=ExtResource("{EXT["camera_rig"]}")]
transform = {tf(0, 0, 36)}
bounds = AABB(-24, 0, -68, 48, 0, 118)

[node name="PatrolPaths" type="Node3D" parent="."]

[node name="PatrolSentry" type="Path3D" parent="PatrolPaths"]
curve = SubResource("patrol_sentry")

[node name="Enemies" type="Node3D" parent="."]
''')
enemies = [
    ("DummyLeft", -3, -21, "1, 0, 0, 0, 1, 0, 0, 0, 1", True),
    ("DummyRight", 3, -21, "1, 0, 0, 0, 1, 0, 0, 0, 1", True),
    ("DummyFront", 0, -24, FACE_SOUTH, True),
    ("TargetLeft", -4, -40, FACE_SOUTH, True),
    ("TargetMiddle", 0, -42, FACE_SOUTH, True),
    ("TargetRight", 4, -40, FACE_SOUTH, True),
]
for name, x, z, basis, blind in enemies:
    L.append(f'''[node name="{name}" parent="Enemies" instance=ExtResource("{EXT["enemy"]}")]
transform = {tf(x, 0, z, basis)}
armed = false
stationary = true
blind = true
''')
L.append(f'''[node name="Sentry" parent="Enemies" node_paths=PackedStringArray("patrol_path") instance=ExtResource("{EXT["enemy"]}")]
transform = {tf(-9, 0, -55, FACE_EAST)}
patrol_path = NodePath("../../PatrolPaths/PatrolSentry")
armed = false
''')

L.append('[node name="Stations" type="Node3D" parent="."]\n')
for st in STATIONS:
    x, y, z = st["pos"]
    lines = [f'[node name="{st["name"]}" type="Area3D" parent="Stations"]',
             f"transform = {tf(x, y, z)}",
             f'script = ExtResource("{EXT["tutorial_station"]}")',
             f'title = "{esc(st["title"])}"',
             f'text = "{esc(st["text"])}"',
             f'done_text = "{esc(st["done"])}"',
             f'step = {st["step"]}',
             f'objective_id = &"{st["objective"]}"',
             f'size = Vector2({st["size"][0]}, {st["size"][1]})',
             f'goal = {GOALS[st["goal"]]}']
    if "goal_offset" in st:
        lines.append("goal_offset = Vector3(%s, %s, %s)" % st["goal_offset"])
    if "radius" in st:
        lines.append(f'goal_radius = {st["radius"]}')
    if "min_height" in st:
        lines.append(f'goal_min_height = {st["min_height"]}')
    if "targets" in st:
        paths = ", ".join(f'NodePath("../../{t}")' for t in st["targets"])
        lines.append(f"targets = Array[NodePath]([{paths}])")
    if st.get("start"):
        lines.append("show_at_start = true")
    L.append("\n".join(lines) + "\n")

L.append(f'[node name="HUD" parent="." instance=ExtResource("{EXT["hud"]}")]\n')
write_scene(OUT, "\n".join(L))

# Objectifs, pour le catalogue.
for st in STATIONS:
    print(st["objective"], "|", st["title"])
