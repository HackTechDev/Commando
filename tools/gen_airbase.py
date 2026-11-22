"""Génère scenes/levels/airbase/airbase.tscn (Base aérienne). Usage : python3 tools/gen_airbase.py"""
import os

from mapkit import write_scene
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes", "levels", "airbase", "airbase.tscn")
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

out = []
ext = [
    ('Script', 'res://scripts/levels/level_root.gd', '1'),
    ('PackedScene', 'res://scenes/camera/camera_rig.tscn', '2'),
    ('PackedScene', 'res://scenes/units/commando.tscn', '3'),
    ('PackedScene', 'res://scenes/props/wall.tscn', '4'),
    ('PackedScene', 'res://scenes/props/crate.tscn', '5'),
    ('PackedScene', 'res://scenes/ui/hud.tscn', '6'),
    ('PackedScene', 'res://scenes/enemies/enemy.tscn', '7'),
    ('PackedScene', 'res://scenes/props/ladder.tscn', '8'),
    ('PackedScene', 'res://scenes/props/low_wall.tscn', '9'),
    ('Script', 'res://scripts/props/building.gd', 'building'),
    ('Script', 'res://scripts/props/hiding_spot.gd', 'hiding'),
    ('Script', 'res://scripts/props/tiltrotor.gd', 'tiltrotor'),
]
patrols = {
    "patrol_pad": [(-13, -18), (13, -18), (13, 13.5), (-13, 13.5)],
    "patrol_fence": [(-28, 17), (28, 17)],
}
subs = []
for cid, pts in patrols.items():
    subs.append(curve(cid, pts))
subs.append('''[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.36, 0.33, 0.38, 1)
ambient_light_source = 2
ambient_light_color = Color(0.78, 0.72, 0.7, 1)
ambient_light_energy = 0.55
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
size = Vector3(70, 1, 70)
''')
subs.append('''[sub_resource type="StandardMaterial3D" id="ground_mat"]
albedo_color = Color(0.62, 0.62, 0.6, 1)
roughness = 1.0
uv1_scale = Vector3(0.25, 0.25, 0.25)
uv1_triplanar = true
uv1_world_triplanar = true
texture_filter = 5
metadata/albedo_source = "tex_ctp1/concrete_g_1.jpg"
''')
subs.append('''[sub_resource type="BoxMesh" id="ground_mesh"]
material = SubResource("ground_mat")
size = Vector3(70, 1, 70)
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
subs.append('''[sub_resource type="BoxMesh" id="stripe_mesh"]
material = SubResource("paint_mat")
size = Vector3(0.5, 0.02, 30)
''')

nodes = []
def node(name, parent, body):
    head = f'[node name="{name}"'
    nodes.append(head + body.split("\n", 1)[0] + (f' parent="{parent}"' if parent else "") + "]" + ("\n" + body.split("\n", 1)[1] if "\n" in body else ""))

nodes.append('[node name="Airbase" type="Node3D"]\nscript = ExtResource("1")')
nodes.append('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("env")')
nodes.append('[node name="Sun" type="DirectionalLight3D" parent="."]\n'
             'transform = Transform3D(0.866, 0.383, -0.3214, 0, 0.6428, 0.766, 0.5, -0.6634, 0.5567, 0, 10, 0)\n'
             'light_color = Color(1, 0.8, 0.62, 1)\nlight_energy = 1.25\nshadow_enabled = true\ndirectional_shadow_max_distance = 140.0')
nodes.append('[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]\nnavigation_mesh = SubResource("nav")')
nodes.append('[node name="Ground" type="StaticBody3D" parent="NavigationRegion3D"]\ncollision_mask = 0')
nodes.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Ground"]\n'
             'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)\nshape = SubResource("ground_shape")')
nodes.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Ground"]\n'
             'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)\nmesh = SubResource("ground_mesh")')

NR = "NavigationRegion3D"
# Clôture sud, deux brèches (x de -15 à -9 et de 9 à 15).
for i, x in enumerate([-30, -24, -18, -6, 0, 6, 18, 24, 30]):
    nodes.append(f'[node name="Fence{i + 1}" parent="{NR}" instance=ExtResource("4")]\ntransform = {tf(x, 21)}')
# Convertible sur la plateforme.
nodes.append(f'[node name="Tiltrotor" type="StaticBody3D" parent="{NR}"]\ntransform = {tf(0, -4)}\nscript = ExtResource("tiltrotor")\nlivery = 1\ntail_number = "07"')
# Hangar (ouest), avec une échelle vers le toit ; poste de garde et armurerie (est).
nodes.append(f'[node name="Hangar" type="Node3D" parent="{NR}"]\ntransform = {tf(-22, -12)}\nscript = ExtResource("building")\n'
             'size = Vector2(12, 10)\nwall_height = 3.5\ndoors = Array[Vector3]([Vector3(1, -2, 0), Vector3(1, 2.5, 0)])\n'
             'windows = Array[Vector2]([Vector2(0, -3), Vector2(0, 3), Vector2(2, 0)])\nroof_color = Color(0.3, 0.32, 0.3, 1)')
nodes.append(f'[node name="HangarLadder" parent="{NR}" instance=ExtResource("8")]\ntransform = {tf(-26, -7)}\nheight = 3.7')
nodes.append(f'[node name="GuardPost" type="Node3D" parent="{NR}"]\ntransform = {tf(22, 10)}\nscript = ExtResource("building")\n'
             'size = Vector2(6, 5)\ndoors = Array[Vector3]([Vector3(3, 0, 0)])\nwindows = Array[Vector2]([Vector2(0, 0), Vector2(2, 0), Vector2(1, 0)])')
nodes.append(f'[node name="Armory" type="Node3D" parent="{NR}"]\ntransform = {tf(24, -14)}\nscript = ExtResource("building")\n'
             'size = Vector2(7, 6)\ndoors = Array[Vector3]([Vector3(3, 0, 1)])\nwindows = Array[Vector2]([Vector2(0, 1.5)])\n'
             'wall_color = Color(0.55, 0.56, 0.52, 1)')
# Murets autour de la plateforme.
for i, (x, z, facing, length) in enumerate([(-10, 9, None, 3.0), (10, 9, None, 3.0), (-15.5, -6, 90, 4.0), (15.5, -6, 90, 4.0), (0, 15.5, None, 5.0)]):
    nodes.append(f'[node name="Sandbags{i + 1}" parent="{NR}" instance=ExtResource("9")]\ntransform = {tf(x, z, facing)}\nlength = {length}')
# Caisses.
crates = [(8, 10.5), (9.3, 10.5), (8, 11.8), (-8, -17.5), (-6.7, -17.5), (16, -3), (-16, 15.5), (5, 17.5), (-25, 3), (27, 3)]
for i, (x, z) in enumerate(crates):
    nodes.append(f'[node name="Crate{i + 1}" parent="{NR}" instance=ExtResource("5")]\ntransform = {tf(x, z)}' + ('\nskin = "tex_base/ecrate_dunno.jpg"' if i % 3 == 1 else ""))

nodes.append('[node name="Decor" type="Node3D" parent="."]')
nodes.append(f'[node name="Pad" type="MeshInstance3D" parent="Decor"]\ntransform = {tf(0, -4, y=0.01)}\nmesh = SubResource("pad_mesh")')
nodes.append(f'[node name="PadRing" type="MeshInstance3D" parent="Decor"]\ntransform = Transform3D(1, 0, 0, 0, 0.05, 0, 0, 0, 1, 0, 0.03, -4)\nmesh = SubResource("ring_mesh")')
nodes.append(f'[node name="Taxiway" type="MeshInstance3D" parent="Decor"]\ntransform = {tf(0, 22, y=0.012)}\nmesh = SubResource("stripe_mesh")')
for i, (x, z, sx, sz) in enumerate([(-20, 25, 3, 2), (17, 25, 3, 2.2), (-31, 9, 2.4, 3), (31, -3, 2.4, 3), (2, -29, 4, 2)]):
    nodes.append(f'[node name="Bush{i + 1}" type="Node3D" parent="Decor"]\ntransform = {tf(x, z)}\nscript = ExtResource("hiding")\nsize = Vector2({sx}, {sz})')

nodes.append('[node name="Units" type="Node3D" parent="."]')
for i, (name, x, z, charges) in enumerate([("Alpha", 0, 29, 1), ("Bravo", -1.6, 30.2, 0), ("Charlie", 1.6, 30.2, 1)]):
    extra = f"\nmission_explosives = {charges}" if charges else ""
    nodes.append(f'[node name="{name}" parent="Units" instance=ExtResource("3")]\ntransform = {tf(x, z)}\nunit_index = {i + 1}\ndisplay_name = "{name}"{extra}')
nodes.append(f'[node name="CameraRig" parent="." instance=ExtResource("2")]\ntransform = {tf(0, 29)}')

nodes.append('[node name="PatrolPaths" type="Node3D" parent="."]')
nodes.append('[node name="PatrolPad" type="Path3D" parent="PatrolPaths"]\ncurve = SubResource("patrol_pad")')
nodes.append('[node name="PatrolFence" type="Path3D" parent="PatrolPaths"]\ncurve = SubResource("patrol_fence")')

nodes.append('[node name="Enemies" type="Node3D" parent="."]')
enemies = [
    ("PadPatrol", -13, -18, 90, "PatrolPad"),
    ("FencePatrol", -28, 17, 90, "PatrolFence"),
    ("PadSentryNorth", 6, -20, 180, None),
    ("PadSentrySouth", -7, 9, 200, None),
    ("PostGuard", 22, 10, 270, None),
    ("HangarGuard", -22, -12, 90, None),
    ("ArmorySentry", 19.3, -14, 240, None),
]
for name, x, z, facing, path in enemies:
    if path:
        nodes.append(f'[node name="{name}" parent="Enemies" node_paths=PackedStringArray("patrol_path") instance=ExtResource("7")]\n'
                     f'transform = {tf(x, z, facing)}\npatrol_path = NodePath("../../PatrolPaths/{path}")')
    else:
        nodes.append(f'[node name="{name}" parent="Enemies" instance=ExtResource("7")]\ntransform = {tf(x, z, facing)}')
nodes.append('[node name="HUD" parent="." instance=ExtResource("6")]')

text = f"[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]\n\n"
text += "\n".join(f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in ext) + "\n\n"
text += "\n".join(subs) + "\n"
text += "\n\n".join(nodes) + "\n"
write_scene(OUT, text)
print(len(nodes), "nœuds")
