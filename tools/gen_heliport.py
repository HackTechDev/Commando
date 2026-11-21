"""Génère scenes/levels/heliport/heliport.tscn (Héliportage). Usage : python3 tools/gen_heliport.py"""
import os
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes", "levels", "heliport", "heliport.tscn")
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


ext = [
    ('Script', 'res://scripts/levels/level_root.gd', '1'),
    ('PackedScene', 'res://scenes/camera/camera_rig.tscn', '2'),
    ('PackedScene', 'res://scenes/units/commando.tscn', '3'),
    ('PackedScene', 'res://scenes/ui/hud.tscn', '6'),
    ('PackedScene', 'res://scenes/enemies/enemy.tscn', '7'),
    ('Script', 'res://scripts/props/tiltrotor.gd', 'tiltrotor'),
]
subs = []
subs.append('''[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.45, 0.55, 0.62, 1)
ambient_light_source = 2
ambient_light_color = Color(0.62, 0.68, 0.6, 1)
ambient_light_energy = 0.6
tonemap_mode = 2
ssao_enabled = true
''')
subs.append('''[sub_resource type="NavigationMesh" id="nav"]
resource_local_to_scene = true
geometry_parsed_geometry_type = 1
geometry_collision_mask = 3
agent_height = 1.75
agent_radius = 0.5
''')
subs.append('''[sub_resource type="BoxShape3D" id="ground_shape"]
size = Vector3(60, 1, 60)
''')
subs.append('''[sub_resource type="StandardMaterial3D" id="ground_mat"]
albedo_color = Color(0.3, 0.38, 0.2, 1)
roughness = 1.0
''')
subs.append('''[sub_resource type="BoxMesh" id="ground_mesh"]
material = SubResource("ground_mat")
size = Vector3(60, 1, 60)
''')
subs.append('''[sub_resource type="StandardMaterial3D" id="pad_mat"]
albedo_color = Color(0.32, 0.33, 0.33, 1)
roughness = 0.95
''')
subs.append('''[sub_resource type="CylinderMesh" id="pad_mesh"]
material = SubResource("pad_mat")
top_radius = 13.5
bottom_radius = 13.5
height = 0.02
radial_segments = 48
''')
subs.append('''[sub_resource type="StandardMaterial3D" id="paint_mat"]
albedo_color = Color(0.9, 0.72, 0.15, 1)
roughness = 0.8
''')
subs.append('''[sub_resource type="TorusMesh" id="ring_mesh"]
material = SubResource("paint_mat")
inner_radius = 12.8
outer_radius = 13.2
rings = 48
ring_segments = 4
''')

nodes = []
nodes.append('[node name="Heliport" type="Node3D"]\nscript = ExtResource("1")')
nodes.append('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("env")')
nodes.append('[node name="Sun" type="DirectionalLight3D" parent="."]\n'
             'transform = Transform3D(0.866, 0.383, -0.3214, 0, 0.6428, 0.766, 0.5, -0.6634, 0.5567, 0, 10, 0)\n'
             'light_color = Color(1, 0.95, 0.85, 1)\nlight_energy = 1.1\nshadow_enabled = true\ndirectional_shadow_max_distance = 140.0')
nodes.append('[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]\nnavigation_mesh = SubResource("nav")')
nodes.append('[node name="Ground" type="StaticBody3D" parent="NavigationRegion3D"]\ncollision_mask = 0')
nodes.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Ground"]\n'
             'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)\nshape = SubResource("ground_shape")')
nodes.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Ground"]\n'
             'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)\nmesh = SubResource("ground_mesh")')
NR = "NavigationRegion3D"
# Convertible : n'est pas une cible ; monter et descendre en rappel sont des objectifs.
nodes.append(f'[node name="Tiltrotor" type="StaticBody3D" parent="{NR}"]\ntransform = {tf(0, 0)}\nscript = ExtResource("tiltrotor")\n'
             'tail_number = "12"\nobjective_id = &""\nends_mission = false\nhover_objective = &"heli_hover"\nrappel_objective = &"heli_rappel"')
nodes.append('[node name="Decor" type="Node3D" parent="."]')
nodes.append(f'[node name="Pad" type="MeshInstance3D" parent="Decor"]\ntransform = {tf(0, 0, y=0.01)}\nmesh = SubResource("pad_mesh")')
nodes.append('[node name="PadRing" type="MeshInstance3D" parent="Decor"]\ntransform = Transform3D(1, 0, 0, 0, 0.05, 0, 0, 0, 1, 0, 0.03, 0)\nmesh = SubResource("ring_mesh")')
nodes.append('[node name="Units" type="Node3D" parent="."]')
for i, (name, x, z) in enumerate([("Alpha", -12, 8), ("Bravo", -13.6, 9.2), ("Charlie", -10.4, 9.2)]):
    nodes.append(f'[node name="{name}" parent="Units" instance=ExtResource("3")]\ntransform = {tf(x, z)}\nunit_index = {i + 1}\ndisplay_name = "{name}"')
nodes.append(f'[node name="CameraRig" parent="." instance=ExtResource("2")]\ntransform = {tf(-4, 10)}')
# Cibles d'entraînement (immobiles, désarmées), derrière l'appareil.
nodes.append('[node name="Enemies" type="Node3D" parent="."]')
for name, x, z in [("TargetLeft", -9, 8), ("TargetMiddle", 0, 13), ("TargetRight", 9, 8)]:
    nodes.append(f'[node name="{name}" parent="Enemies" instance=ExtResource("7")]\ntransform = {tf(x, z, 0)}\narmed = false\nstationary = true')
nodes.append('[node name="HUD" parent="." instance=ExtResource("6")]')

text = f"[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]\n\n"
text += "\n".join(f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in ext) + "\n\n"
text += "\n".join(subs) + "\n"
text += "\n\n".join(nodes) + "\n"
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w").write(text)
print(len(nodes), "nœuds")
