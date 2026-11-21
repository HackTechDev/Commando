"""Génère scenes/levels/patrol/patrol.tscn (Patrouille Sabre). Usage : python3 tools/gen_patrol.py"""
import os
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes", "levels", "patrol", "patrol.tscn")
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
    ('Script', 'res://scripts/props/hiding_spot.gd', 'hiding'),
    ('Script', 'res://scripts/props/tiltrotor.gd', 'tiltrotor'),
]
patrols = {"patrol_ridge": [(-6, -2), (10, -12), (-6, -2), (-14, 8)]}
subs = [curve(cid, pts) for cid, pts in patrols.items()]
subs.append("""[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.55, 0.62, 0.68, 1)
ambient_light_source = 2
ambient_light_color = Color(0.68, 0.66, 0.58, 1)
ambient_light_energy = 0.6
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
size = Vector3(100, 1, 100)
""")
subs.append("""[sub_resource type="StandardMaterial3D" id="ground_mat"]
albedo_color = Color(0.56, 0.48, 0.34, 1)
roughness = 1.0
""")
subs.append("""[sub_resource type="BoxMesh" id="ground_mesh"]
material = SubResource("ground_mat")
size = Vector3(100, 1, 100)
""")
subs.append("""[sub_resource type="StandardMaterial3D" id="track_mat"]
albedo_color = Color(0.45, 0.38, 0.27, 1)
roughness = 1.0
""")
subs.append("""[sub_resource type="BoxMesh" id="track_mesh"]
material = SubResource("track_mat")
size = Vector3(1, 0.02, 1)
""")
subs.append("""[sub_resource type="StandardMaterial3D" id="flag_mat"]
albedo_color = Color(0.85, 0.2, 0.12, 1)
roughness = 0.8
""")
subs.append("""[sub_resource type="BoxMesh" id="flag_mesh"]
material = SubResource("flag_mat")
size = Vector3(0.05, 0.6, 0.9)
""")
subs.append("""[sub_resource type="CylinderMesh" id="pole_mesh"]
top_radius = 0.04
bottom_radius = 0.05
height = 4.0
radial_segments = 8
""")
subs.append("""[sub_resource type="StandardMaterial3D" id="zone_mat"]
albedo_color = Color(0.9, 0.72, 0.15, 1)
roughness = 0.8
""")
subs.append("""[sub_resource type="TorusMesh" id="zone_mesh"]
material = SubResource("zone_mat")
inner_radius = 4.7
outer_radius = 5.0
rings = 40
ring_segments = 4
""")
subs.append("""[sub_resource type="StandardMaterial3D" id="rock_mat"]
albedo_color = Color(0.48, 0.45, 0.4, 1)
roughness = 1.0
""")
subs.append("""[sub_resource type="SphereMesh" id="rock_mesh"]
material = SubResource("rock_mat")
radius = 1.0
height = 1.4
radial_segments = 7
rings = 4
""")

nodes = []
nodes.append('[node name="Patrol" type="Node3D"]\nscript = ExtResource("1")')
nodes.append('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("env")')
nodes.append('[node name="Sun" type="DirectionalLight3D" parent="."]\n'
             'transform = Transform3D(0.866, 0.383, -0.3214, 0, 0.6428, 0.766, 0.5, -0.6634, 0.5567, 0, 10, 0)\n'
             'light_color = Color(1, 0.95, 0.85, 1)\nlight_energy = 1.15\nshadow_enabled = true\ndirectional_shadow_max_distance = 160.0')
nodes.append('[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]\nnavigation_mesh = SubResource("nav")')
nodes.append('[node name="Ground" type="StaticBody3D" parent="NavigationRegion3D"]\ncollision_mask = 0')
nodes.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Ground"]\n'
             'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)\nshape = SubResource("ground_shape")')
nodes.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Ground"]\n'
             'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)\nmesh = SubResource("ground_mesh")')
NR = "NavigationRegion3D"
# Convertible d'insertion, nez au sud, rampe vers la piste ; le Sabre est
# garé dans sa soute, l'équipe derrière lui.
nodes.append(f'[node name="Insertion" type="StaticBody3D" parent="{NR}"]\ntransform = {tf(-30, 30, 180)}\nscript = ExtResource("tiltrotor")\n'
             'livery = 1\ntail_number = "33"\nobjective_id = &""\nends_mission = false')
nodes.append(f'[node name="Sabre" type="StaticBody3D" parent="{NR}"]\ntransform = {tf(-30, 10, 0)}\nscript = ExtResource("sabre")\n'
             'arrival_objective = &"sabre_rally"\narrival_point = Vector3(26, 0, -38)\nstart_stowed_in = NodePath("../Insertion")')
# Extraction en course contre la montre : appelée par radio, elle reste
# 60 s en vol stationnaire à l'ouest du poste, sans se poser.
nodes.append(f'[node name="Extraction" type="StaticBody3D" parent="{NR}"]\ntransform = {tf(6, -44, 90)}\nscript = ExtResource("tiltrotor")\n'
             'livery = 1\ntail_number = "34"\nobjective_id = &"extracted"\nextraction = true\npickup_window = 60.0')
# Poste de contrôle : murets de sacs de sable, caisses, abri.
for i, (x, z, facing) in enumerate([(21, -26, 0), (29, -26, 0), (18, -31, 90), (32, -31, 90)]):
    nodes.append(f'[node name="Sandbags{i + 1}" parent="{NR}" instance=ExtResource("4")]\ntransform = {tf(x, z, facing)}')
for i, (x, z, facing) in enumerate([(20, -42, 0), (32, -42, 0)]):
    nodes.append(f'[node name="Wall{i + 1}" parent="{NR}" instance=ExtResource("8")]\ntransform = {tf(x, z, facing)}')
crates = [(23, -33), (24.3, -33), (12, -18), (-4, 4), (-2.7, 4), (-18, 14), (6, -6), (36, -20)]
for i, (x, z) in enumerate(crates):
    nodes.append(f'[node name="Crate{i + 1}" parent="{NR}" instance=ExtResource("5")]\ntransform = {tf(x, z)}' + ('\nskin = "tex_base/ecrate_dunno.jpg"' if i % 3 == 1 else ""))
nodes.append('[node name="Decor" type="Node3D" parent="."]')
# Piste : du départ vers le nord, puis en biais jusqu'au poste.
track = [(-30, 38), (-30, 10), (-12, -4), (8, -14), (25, -24), (26, -40)]
for i in range(len(track) - 1):
    (x1, z1), (x2, z2) = track[i], track[i + 1]
    length = math.hypot(x2 - x1, z2 - z1)
    a = math.atan2(x2 - x1, -(z2 - z1))
    width = 4.5
    zx, zz = (x2 - x1) / length * length, (z2 - z1) / length * length
    xx, xz = (z2 - z1) / length * width, -(x2 - x1) / length * width
    nodes.append(f'[node name="Track{i + 1}" type="MeshInstance3D" parent="Decor"]\n'
                 f'transform = Transform3D({xx:.4f}, 0, {zx:.4f}, 0, 1, 0, {xz:.4f}, 0, {zz:.4f}, {(x1 + x2) / 2:g}, 0.01, {(z1 + z2) / 2:g})\nmesh = SubResource("track_mesh")')
# Point de ralliement : anneau au sol et drapeau.
nodes.append(f'[node name="Rally" type="MeshInstance3D" parent="Decor"]\ntransform = {tf(26, -38, y=0.02)}\nmesh = SubResource("zone_mesh")')
nodes.append(f'[node name="Pole" type="MeshInstance3D" parent="Decor"]\ntransform = {tf(26, -38, y=2)}\nmesh = SubResource("pole_mesh")')
nodes.append(f'[node name="Flag" type="MeshInstance3D" parent="Decor"]\ntransform = {tf(26, -37.55, y=3.6)}\nmesh = SubResource("flag_mesh")')
for i, (x, z, s) in enumerate([(-16, 27, 1.4), (-38, -6, 1.8), (2, 18, 1.2), (38, 6, 2.0), (-8, -30, 1.6)]):
    nodes.append(f'[node name="Rock{i + 1}" type="MeshInstance3D" parent="Decor"]\n'
                 f'transform = Transform3D({s}, 0, 0, 0, {s * 0.7:.2f}, 0, 0, 0, {s}, {x}, 0.2, {z})\nmesh = SubResource("rock_mesh")')
for i, (x, z) in enumerate([(-24, -14), (14, 8)]):
    nodes.append(f'[node name="Bush{i + 1}" type="Node3D" parent="Decor"]\ntransform = {tf(x, z)}\nscript = ExtResource("hiding")\nsize = Vector2(3, 2.4)')
nodes.append('[node name="Units" type="Node3D" parent="."]')
for i, (name, x, z) in enumerate([("Alpha", -30, 26.6), ("Bravo", -30.8, 25.2), ("Charlie", -29.2, 25.2)]):
    nodes.append(f'[node name="{name}" parent="Units" instance=ExtResource("3")]\ntransform = {tf(x, z, 0, 1.5)}\nunit_index = {i + 1}\ndisplay_name = "{name}"')
nodes.append(f'[node name="CameraRig" parent="." instance=ExtResource("2")]\ntransform = {tf(-30, 20)}')
nodes.append('[node name="PatrolPaths" type="Node3D" parent="."]')
nodes.append('[node name="PatrolRidge" type="Path3D" parent="PatrolPaths"]\ncurve = SubResource("patrol_ridge")')
nodes.append('[node name="Enemies" type="Node3D" parent="."]')
enemies = [
    ("RidgePatrol", -6, -2, 120, "PatrolRidge", False),
    ("CheckpointLeft", 22, -29, 200, None, True),
    ("CheckpointRight", 28, -29, 160, None, True),
    ("CheckpointChief", 25, -36, 180, None, True),
    ("Lookout", 34, -16, 230, None, True),
]
for name, x, z, facing, path, still in enemies:
    extra = "\nstationary = true" if still else ""
    if path:
        nodes.append(f'[node name="{name}" parent="Enemies" node_paths=PackedStringArray("patrol_path") instance=ExtResource("7")]\n'
                     f'transform = {tf(x, z, facing)}\npatrol_path = NodePath("../../PatrolPaths/{path}")' + extra)
    else:
        nodes.append(f'[node name="{name}" parent="Enemies" instance=ExtResource("7")]\ntransform = {tf(x, z, facing)}' + extra)
nodes.append('[node name="HUD" parent="." instance=ExtResource("6")]')

text = f"[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]\n\n"
text += "\n".join(f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in ext) + "\n\n"
text += "\n".join(subs) + "\n"
text += "\n\n".join(nodes) + "\n"
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w").write(text)
print(len(nodes), "nœuds")
