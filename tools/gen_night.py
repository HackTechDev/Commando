"""Génère scenes/levels/night/night.tscn (Nuit sans lune). Usage : python3 tools/gen_night.py"""
import os
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes", "levels", "night", "night.tscn")
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
    ('PackedScene', 'res://scenes/props/wall.tscn', '4'),
    ('PackedScene', 'res://scenes/props/crate.tscn', '5'),
    ('PackedScene', 'res://scenes/ui/hud.tscn', '6'),
    ('PackedScene', 'res://scenes/enemies/enemy.tscn', '7'),
    ('Script', 'res://scripts/props/building.gd', 'building'),
    ('Script', 'res://scripts/props/hiding_spot.gd', 'hiding'),
    ('Script', 'res://scripts/props/tiltrotor.gd', 'tiltrotor'),
    ('Script', 'res://scripts/props/sabotage_target.gd', 'sabotage'),
    ('Script', 'res://scripts/enemies/enemy_aircraft.gd', 'enemy_air'),
]
patrols = {
    "patrol_gate": [(-14, 9), (14, 9)],
    "patrol_yard": [(-5, -3), (6, -3), (6, -24), (-5, -24)],
    # Ronde de l'appareil ennemi autour du dépôt (boucle fermée).
    "patrol_air": [(-22, -28), (22, -28), (22, 12), (-22, 12), (-22, -28)],
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
size = Vector3(64, 1, 70)
""")
subs.append("""[sub_resource type="StandardMaterial3D" id="ground_mat"]
albedo_color = Color(0.24, 0.27, 0.2, 1)
roughness = 1.0
""")
subs.append("""[sub_resource type="BoxMesh" id="ground_mesh"]
material = SubResource("ground_mat")
size = Vector3(64, 1, 70)
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
nodes.append('[node name="Night" type="Node3D"]\nscript = ExtResource("1")\nnight = true')
nodes.append('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("env")')
# Lune basse et froide.
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
# Clôture sud du dépôt (entrée de x -6 à 6) et côtés.
fence = [(-27, 4, None), (-21, 4, None), (-15, 4, None), (-9, 4, None), (9, 4, None), (15, 4, None), (21, 4, None), (27, 4, None)]
fence += [(-30, z, 90) for z in (1, -5, -11, -17, -23)] + [(30, z, 90) for z in (1, -5, -11, -17, -23)]
for i, (x, z, facing) in enumerate(fence):
    nodes.append(f'[node name="Fence{i + 1}" parent="{NR}" instance=ExtResource("4")]\ntransform = {tf(x, z, facing)}')
# Entrepôt (ouest) et dortoir (est), portes vers la cour.
nodes.append(f'[node name="Depot" type="Node3D" parent="{NR}"]\ntransform = {tf(-15, -15)}\nscript = ExtResource("building")\n'
             'size = Vector2(10, 8)\nwall_height = 3.5\ndoors = Array[Vector3]([Vector3(1, 0, 0), Vector3(0, -2.5, 0)])\n'
             'windows = Array[Vector2]([Vector2(0, 2), Vector2(2, 0)])\nroof_color = Color(0.25, 0.26, 0.26, 1)')
nodes.append(f'[node name="Barracks" type="Node3D" parent="{NR}"]\ntransform = {tf(16, -16)}\nscript = ExtResource("building")\n'
             'size = Vector2(8, 6)\ndoors = Array[Vector3]([Vector3(3, 0, 0)])\nwindows = Array[Vector2]([Vector2(0, -1.5), Vector2(0, 1.5), Vector2(1, 0)])')
crates = [(-4, -8), (-2.7, -8), (-4, -6.7), (9, -6), (10.3, -6), (-21, -4), (22, -3), (-8, 12), (11, 14), (0, -27)]
for i, (x, z) in enumerate(crates):
    nodes.append(f'[node name="Crate{i + 1}" parent="{NR}" instance=ExtResource("5")]\ntransform = {tf(x, z)}' + ('\nskin = "tex_base/ecrate_dunno.jpg"' if i % 3 == 1 else ""))
# Lampadaires : les seules vraies lumières de la nuit.
nodes.append('[node name="Lamps" type="Node3D" parent="."]')
for i, (x, z) in enumerate([(-4.5, 4.8), (4.5, 4.8), (-8, -11), (9, -12), (0, -21)]):
    nodes.append(f'[node name="Lamp{i + 1}" type="Node3D" parent="Lamps"]\ntransform = {tf(x, z)}')
    nodes.append(f'[node name="Post" type="MeshInstance3D" parent="Lamps/Lamp{i + 1}"]\ntransform = {tf(0, 0, y=2)}\nmesh = SubResource("post_mesh")')
    nodes.append(f'[node name="Bulb" type="MeshInstance3D" parent="Lamps/Lamp{i + 1}"]\ntransform = {tf(0, 0, y=4.05)}\nmesh = SubResource("bulb_mesh")')
    nodes.append(f'[node name="Light" type="OmniLight3D" parent="Lamps/Lamp{i + 1}"]\ntransform = {tf(0, 0, y=3.9)}\n'
                 'light_color = Color(1, 0.8, 0.52, 1)\nlight_energy = 2.2\nomni_range = 9.0\nomni_attenuation = 1.4')
# Groupe électrogène du dépôt, au fond de la cour : il alimente les
# lampadaires ; le saboter les éteint.
nodes.append(f'[node name="Generator" type="StaticBody3D" parent="{NR}"]\ntransform = {tf(4, -27, 90)}\nscript = ExtResource("sabotage")\n'
             'objective_id = &"sabotage"\nlights = NodePath("../../Lamps")')
# Convertible : l'équipe commence à bord, en vol stationnaire au sud-ouest,
# hors de portée d'oreille des gardes ; renvoyé, il revient se poser au même
# endroit pour l'extraction.
nodes.append(f'[node name="Extraction" type="StaticBody3D" parent="{NR}"]\ntransform = {tf(-17, 27, 90)}\nscript = ExtResource("tiltrotor")\n'
             'livery = 1\ntail_number = "21"\nobjective_id = &"extracted"\nextraction = true\ninsertion = true')
nodes.append('[node name="Decor" type="Node3D" parent="."]')
for i, (x, z, sx, sz) in enumerate([(-18, 18, 3, 2.4), (16, 20, 3.2, 2.2), (-25, 10, 2.4, 3), (24, -28, 3, 2)]):
    nodes.append(f'[node name="Bush{i + 1}" type="Node3D" parent="Decor"]\ntransform = {tf(x, z)}\nscript = ExtResource("hiding")\nsize = Vector2({sx}, {sz})')
nodes.append('[node name="Units" type="Node3D" parent="."]')
for i, (name, x, z) in enumerate([("Alpha", -22, 29), ("Bravo", -23.6, 30.2), ("Charlie", -20.4, 30.2)]):
    nodes.append(f'[node name="{name}" parent="Units" instance=ExtResource("3")]\ntransform = {tf(x, z)}\nunit_index = {i + 1}\ndisplay_name = "{name}"\nmission_nvg = true' + ('\nmission_explosives = 1' if i < 2 else ''))
nodes.append(f'[node name="CameraRig" parent="." instance=ExtResource("2")]\ntransform = {tf(-16, 24)}')
nodes.append('[node name="PatrolPaths" type="Node3D" parent="."]')
nodes.append('[node name="PatrolGate" type="Path3D" parent="PatrolPaths"]\ncurve = SubResource("patrol_gate")')
nodes.append('[node name="PatrolYard" type="Path3D" parent="PatrolPaths"]\ncurve = SubResource("patrol_yard")')
nodes.append('[node name="PatrolAir" type="Path3D" parent="PatrolPaths"]\ncurve = SubResource("patrol_air")')
nodes.append('[node name="Enemies" type="Node3D" parent="."]')
enemies = [
    ("GatePatrol", -14, 9, 90, "PatrolGate"),
    ("YardPatrol", -5, -3, 90, "PatrolYard"),
    ("GateSentry", 3, 2, 180, None),
    ("DepotGuard", -9.2, -15, 90, None),
    ("BarracksGuard", 11.2, -14, 220, None),
]
for name, x, z, facing, path in enemies:
    if path:
        nodes.append(f'[node name="{name}" parent="Enemies" node_paths=PackedStringArray("patrol_path") instance=ExtResource("7")]\n'
                     f'transform = {tf(x, z, facing)}\npatrol_path = NodePath("../../PatrolPaths/{path}")')
    else:
        nodes.append(f'[node name="{name}" parent="Enemies" instance=ExtResource("7")]\ntransform = {tf(x, z, facing)}')
# Convertible ennemi en ronde à 25 m, projecteur allumé.
nodes.append('[node name="Gunship" type="Node3D" parent="Enemies"]\nscript = ExtResource("enemy_air")\npatrol_path = NodePath("../../PatrolPaths/PatrolAir")')
nodes.append('[node name="HUD" parent="." instance=ExtResource("6")]')

text = f"[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]\n\n"
text += "\n".join(f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in ext) + "\n\n"
text += "\n".join(subs) + "\n"
text += "\n\n".join(nodes) + "\n"
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w").write(text)
print(len(nodes), "nœuds")
