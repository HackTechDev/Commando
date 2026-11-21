"""Génère scenes/levels/convoy/convoy.tscn (Convoi de nuit). Usage : python3 tools/gen_convoy.py"""
import os
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes", "levels", "convoy", "convoy.tscn")
import math

def tf(x, z, facing=None, y=0.0):
    """Transform3D : facing = direction regardée (-Z local) en degrés, 0 = nord (-Z), 90 = est (+X)."""
    if facing is None:
        return f"Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x:g}, {y:g}, {z:g})"
    a = math.radians(facing)
    d = (math.sin(a), 0.0, -math.cos(a))          # direction regardée
    Z = (-d[0], 0.0, -d[2])                        # Z local = -direction
    X = (Z[2], 0.0, -Z[0])                         # X = Y × Z
    r = lambda v: f"{round(v, 4):g}"
    return (f"Transform3D({r(X[0])}, 0, {r(Z[0])}, 0, 1, 0, {r(X[2])}, 0, {r(Z[2])}, {x:g}, {y:g}, {z:g})")

def curve(cid, points):
    pts = ", ".join(f"0, 0, 0, 0, 0, 0, {x:g}, 0, {z:g}" for x, z in points)
    tilts = ", ".join("0" for _ in points)
    return (f'[sub_resource type="Curve3D" id="{cid}"]\n_data = {{\n"points": PackedVector3Array({pts}),\n'
            f'"tilts": PackedFloat32Array({tilts})\n}}\npoint_count = {len(points)}\n')



import math

ext = [
    ('Script', 'res://scripts/levels/level_root.gd', '1'),
    ('PackedScene', 'res://scenes/camera/camera_rig.tscn', '2'),
    ('PackedScene', 'res://scenes/units/commando.tscn', '3'),
    ('PackedScene', 'res://scenes/props/low_wall.tscn', '4'),
    ('PackedScene', 'res://scenes/props/crate.tscn', '5'),
    ('PackedScene', 'res://scenes/ui/hud.tscn', '6'),
    ('PackedScene', 'res://scenes/enemies/enemy.tscn', '7'),
    ('PackedScene', 'res://scenes/props/wall.tscn', '8'),
    ('Script', 'res://scripts/props/sabre.gd', 'sabre'),
    ('Script', 'res://scripts/props/road_barrier.gd', 'barrier'),
    ('Script', 'res://scripts/props/landmine.gd', 'mine'),
    ('Script', 'res://scripts/enemies/technical.gd', 'technical'),
    ('Script', 'res://scripts/props/hiding_spot.gd', 'hiding'),
    ('Script', 'res://scripts/props/tiltrotor.gd', 'tiltrotor'),
    ('Script', 'res://scripts/props/sabotage_target.gd', 'sabotage'),
    ('Script', 'res://scripts/levels/reinforcements.gd', 'reinforcements'),
]
# Piste : du départ (sud-ouest) au terrain d'extraction (nord-est).
TRACK = [(-36, 46), (-36, 22), (-18, 8), (4, 4), (20, -10), (24, -30), (30, -32)]
patrols = {
    # Ronde à pied entre les rochers, au nord de la piste.
    "patrol_rocks": [(-24, -6), (-6, -12), (-24, -6), (-34, 0)],
    # Gardes du terrain d'extraction.
    "patrol_lz": [(16, -44), (40, -46), (40, -26), (16, -44)],
    # Pick-up armé : boucle à l'est de la piste.
    "tech_loop": [(36, 10), (44, -14), (30, -2)],
    # Ronde autour du dépôt de carburant.
    "patrol_depot": [(-30, -30), (-14, -32), (-12, -18), (-30, -16), (-30, -30)],
}
subs = [curve(cid, pts) for cid, pts in patrols.items()]
subs.append("""[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.01, 0.015, 0.03, 1)
ambient_light_source = 2
ambient_light_color = Color(0.2, 0.25, 0.4, 1)
ambient_light_energy = 0.22
tonemap_mode = 2
ssao_enabled = true
""")
subs.append("""[sub_resource type="NavigationMesh" id="nav"]
resource_local_to_scene = true
geometry_parsed_geometry_type = 1
geometry_collision_mask = 3
agent_height = 1.75
agent_radius = 0.5
""")
subs.append("""[sub_resource type="BoxShape3D" id="ground_shape"]
size = Vector3(100, 1, 104)
""")
subs.append("""[sub_resource type="StandardMaterial3D" id="ground_mat"]
albedo_color = Color(0.4, 0.36, 0.28, 1)
roughness = 1.0
""")
subs.append("""[sub_resource type="BoxMesh" id="ground_mesh"]
material = SubResource("ground_mat")
size = Vector3(100, 1, 104)
""")
subs.append("""[sub_resource type="StandardMaterial3D" id="track_mat"]
albedo_color = Color(0.32, 0.28, 0.21, 1)
roughness = 1.0
""")
subs.append("""[sub_resource type="BoxMesh" id="track_mesh"]
material = SubResource("track_mat")
size = Vector3(1, 0.02, 1)
""")
subs.append("""[sub_resource type="StandardMaterial3D" id="rock_mat"]
albedo_color = Color(0.4, 0.38, 0.35, 1)
roughness = 1.0
""")
subs.append("""[sub_resource type="SphereMesh" id="rock_mesh"]
material = SubResource("rock_mat")
radius = 1.0
height = 1.4
radial_segments = 7
rings = 4
""")
subs.append("""[sub_resource type="StandardMaterial3D" id="post_mat"]
albedo_color = Color(0.22, 0.23, 0.24, 1)
metallic = 0.6
roughness = 0.5
""")
subs.append("""[sub_resource type="CylinderMesh" id="post_mesh"]
material = SubResource("post_mat")
top_radius = 0.06
bottom_radius = 0.09
height = 4.0
radial_segments = 8
""")
subs.append("""[sub_resource type="StandardMaterial3D" id="bulb_mat"]
albedo_color = Color(1, 0.85, 0.55, 1)
emission_enabled = true
emission = Color(1, 0.8, 0.5, 1)
emission_energy_multiplier = 3.0
""")
subs.append("""[sub_resource type="SphereMesh" id="bulb_mesh"]
material = SubResource("bulb_mat")
radius = 0.18
height = 0.36
""")

nodes = []
nodes.append('[node name="Convoy" type="Node3D"]\nscript = ExtResource("1")\nnight = true')
nodes.append('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("env")')
nodes.append('[node name="Moon" type="DirectionalLight3D" parent="."]\n'
             'transform = Transform3D(0.866, 0.383, -0.3214, 0, 0.6428, 0.766, 0.5, -0.6634, 0.5567, 0, 10, 0)\n'
             'light_color = Color(0.6, 0.7, 1, 1)\nlight_energy = 0.16\nshadow_enabled = true\ndirectional_shadow_max_distance = 120.0')
nodes.append('[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]\nnavigation_mesh = SubResource("nav")')
nodes.append('[node name="Ground" type="StaticBody3D" parent="NavigationRegion3D"]\ncollision_mask = 0')
nodes.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Ground"]\n'
             'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)\nshape = SubResource("ground_shape")')
nodes.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Ground"]\n'
             'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)\nmesh = SubResource("ground_mesh")')
NR = "NavigationRegion3D"
# Le Sabre attend au départ de la piste, cap au nord ; il faut le mener
# jusque dans la soute du convertible d'extraction.
nodes.append(f'[node name="Sabre" type="StaticBody3D" parent="{NR}"]\ntransform = {tf(-36, 40, 0)}\nscript = ExtResource("sabre")\n'
             'stow_objective = &"sabre_extracted"')
# Extraction : appelée par radio, elle se pose au bout de la piste, nez au
# nord, rampe vers la piste.
nodes.append(f'[node name="Extraction" type="StaticBody3D" parent="{NR}"]\ntransform = {tf(30, -42, 0)}\nscript = ExtResource("tiltrotor")\n'
             'livery = 1\ntail_number = "41"\nobjective_id = &"extracted"\nextraction = true')
# Poste de contrôle sur le tronçon nord : barrière entre deux murets.
bx, bz = 21.8, -19.0
ang = math.degrees(math.atan2(24 - 20, -(-30 + 10)))
ax = (math.cos(math.radians(ang)), math.sin(math.radians(ang)))
nodes.append(f'[node name="Barrier" type="Node3D" parent="{NR}"]\ntransform = {tf(bx, bz, ang)}\nscript = ExtResource("barrier")\nwidth = 4.6')
for i, side in enumerate((-1, 1)):
    x, z = bx + side * 4.15 * ax[0], bz + side * 4.15 * ax[1]
    nodes.append(f'[node name="Sandbags{i + 1}" parent="{NR}" instance=ExtResource("4")]\ntransform = {tf(x, z, ang)}')
nodes.append(f'[node name="Hut" parent="{NR}" instance=ExtResource("8")]\ntransform = {tf(28, -16, 90)}')
# Engin explosif sur le tronçon central.
nodes.append(f'[node name="Ied" type="Node3D" parent="{NR}"]\ntransform = {tf(12, -3)}\nscript = ExtResource("mine")\nimprovised = true')
nodes.append(f'[node name="Mine" type="Node3D" parent="{NR}"]\ntransform = {tf(-27, 15)}\nscript = ExtResource("mine")')
# Raid : dépôt de carburant à l'écart de la piste, au nord-ouest, gardé.
nodes.append(f'[node name="FuelDepot" type="StaticBody3D" parent="{NR}"]\ntransform = {tf(-22, -26, 0)}\nscript = ExtResource("sabotage")\n'
             'objective_id = &"depot"\nfuel = true\nlights = NodePath("../../Lamps/Lamp4")')
for i, (x, z, facing) in enumerate([(-28, -22, 90), (-16, -22, 90)]):
    nodes.append(f'[node name="DepotWall{i + 1}" parent="{NR}" instance=ExtResource("4")]\ntransform = {tf(x, z, facing)}')
crates = [(26, -22), (27.3, -22), (-30, 30), (8, 10), (36, -36), (36, -37.3), (-10, -4)]
for i, (x, z) in enumerate(crates):
    nodes.append(f'[node name="Crate{i + 1}" parent="{NR}" instance=ExtResource("5")]\ntransform = {tf(x, z)}' + ('\nskin = "tex_base/ecrate_dunno.jpg"' if i % 3 == 1 else ""))
for i, (x, z, facing) in enumerate([(14, -36, 90), (44, -40, 90)]):
    nodes.append(f'[node name="Wall{i + 1}" parent="{NR}" instance=ExtResource("8")]\ntransform = {tf(x, z, facing)}')
nodes.append('[node name="Decor" type="Node3D" parent="."]')
for i in range(len(TRACK) - 1):
    (x1, z1), (x2, z2) = TRACK[i], TRACK[i + 1]
    length = math.hypot(x2 - x1, z2 - z1)
    width = 4.5
    zx, zz = (x2 - x1), (z2 - z1)
    xx, xz = (z2 - z1) / length * width, -(x2 - x1) / length * width
    nodes.append(f'[node name="Track{i + 1}" type="MeshInstance3D" parent="Decor"]\n'
                 f'transform = Transform3D({xx:.4f}, 0, {zx:.4f}, 0, 1, 0, {xz:.4f}, 0, {zz:.4f}, {(x1 + x2) / 2:g}, 0.01, {(z1 + z2) / 2:g})\nmesh = SubResource("track_mesh")')
rocks = [(-26, -2, 1.8), (-14, -14, 2.2), (-2, -10, 1.6), (-44, 10, 2.0), (6, 24, 1.8), (40, 20, 2.2), (-20, 30, 1.4), (18, -48, 1.6)]
for i, (x, z, s) in enumerate(rocks):
    nodes.append(f'[node name="Rock{i + 1}" type="MeshInstance3D" parent="Decor"]\n'
                 f'transform = Transform3D({s}, 0, 0, 0, {s * 0.7:.2f}, 0, 0, 0, {s}, {x}, 0.2, {z})\nmesh = SubResource("rock_mesh")')
for i, (x, z) in enumerate([(-30, 12), (0, 12), (16, -2), (34, -26)]):
    nodes.append(f'[node name="Bush{i + 1}" type="Node3D" parent="Decor"]\ntransform = {tf(x, z)}\nscript = ExtResource("hiding")\nsize = Vector2(3, 2.4)')
# Lampadaires du poste et du terrain d'extraction.
nodes.append('[node name="Lamps" type="Node3D" parent="."]')
for i, (x, z) in enumerate([(25, -21), (19, -44), (41, -30), (-19, -29)]):
    nodes.append(f'[node name="Lamp{i + 1}" type="Node3D" parent="Lamps"]\ntransform = {tf(x, z)}')
    nodes.append(f'[node name="Post" type="MeshInstance3D" parent="Lamps/Lamp{i + 1}"]\ntransform = {tf(0, 0, y=2)}\nmesh = SubResource("post_mesh")')
    nodes.append(f'[node name="Bulb" type="MeshInstance3D" parent="Lamps/Lamp{i + 1}"]\ntransform = {tf(0, 0, y=4.05)}\nmesh = SubResource("bulb_mesh")')
    nodes.append(f'[node name="Light" type="OmniLight3D" parent="Lamps/Lamp{i + 1}"]\ntransform = {tf(0, 0, y=3.9)}\n'
                 'light_color = Color(1, 0.8, 0.52, 1)\nlight_energy = 2.2\nomni_range = 9.0\nomni_attenuation = 1.4')
nodes.append('[node name="Units" type="Node3D" parent="."]')
for i, (name, x, z) in enumerate([("Alpha", -32.5, 42), ("Bravo", -32.5, 39.5), ("Charlie", -32.5, 37)]):
    nodes.append(f'[node name="{name}" parent="Units" instance=ExtResource("3")]\ntransform = {tf(x, z)}\nunit_index = {i + 1}\ndisplay_name = "{name}"\nmission_nvg = true' + ('\nmission_explosives = 1' if i < 2 else ''))
nodes.append(f'[node name="CameraRig" parent="." instance=ExtResource("2")]\ntransform = {tf(-32, 34)}\nbounds = AABB(-48, 0, -50, 96, 0, 100)')
nodes.append('[node name="PatrolPaths" type="Node3D" parent="."]')
for cid in patrols:
    name = "".join(part.capitalize() for part in cid.split("_"))
    nodes.append(f'[node name="{name}" type="Path3D" parent="PatrolPaths"]\ncurve = SubResource("{cid}")')
nodes.append('[node name="Enemies" type="Node3D" parent="."]')
enemies = [
    ("RockPatrol", -24, -6, 110, "PatrolRocks", False),
    ("CheckpointLeft", 18, -21, 190, None, True),
    ("CheckpointRight", 25, -23, 170, None, True),
    ("Lookout", -4, -9, 200, None, True),
    ("LzPatrol", 16, -44, 90, "PatrolLz", False),
    ("LzGuard", 22, -38, 160, None, True),
    ("DepotGuard", -20, -21, 170, None, True),
    ("DepotPatrol", -30, -30, 90, "PatrolDepot", False),
]
for name, x, z, facing, path, still in enemies:
    extra = "\nstationary = true" if still else ""
    if path:
        nodes.append(f'[node name="{name}" parent="Enemies" node_paths=PackedStringArray("patrol_path") instance=ExtResource("7")]\n'
                     f'transform = {tf(x, z, facing)}\npatrol_path = NodePath("../../PatrolPaths/{path}")' + extra)
    else:
        nodes.append(f'[node name="{name}" parent="Enemies" instance=ExtResource("7")]\ntransform = {tf(x, z, facing)}' + extra)
nodes.append(f'[node name="Technical" type="StaticBody3D" parent="Enemies"]\ntransform = {tf(36, 10, 160)}\nscript = ExtResource("technical")\npatrol_path = NodePath("../../PatrolPaths/TechLoop")')
# Renforts du raid : ils arrivent par le nord, deux minutes après la
# destruction du dépôt, et foncent vers lui.
nodes.append(f'[node name="Reinforcements" type="Node3D" parent="Enemies"]\ntransform = {tf(-24, -48, 180)}\nscript = ExtResource("reinforcements")\n'
             'target = NodePath("../../NavigationRegion3D/FuelDepot")')
nodes.append('[node name="HUD" parent="." instance=ExtResource("6")]')

text = f"[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]\n\n"
text += "\n".join(f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in ext) + "\n\n"
text += "\n".join(subs) + "\n"
text += "\n\n".join(nodes) + "\n"
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w").write(text)
print(len(nodes), "nœuds")
