"""Génère scenes/levels/tower/tower.tscn (La Tour). Usage : python3 tools/gen_tower.py"""
import os

from mapkit import write_scene
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scenes", "levels", "tower", "tower.tscn")
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

def curve3(cid, points):
    """Courbe de ronde à étage : points (x, y, z)."""
    pts = ", ".join(f"0, 0, 0, 0, 0, 0, {x:g}, {y:g}, {z:g}" for x, y, z in points)
    tilts = ", ".join("0" for _ in points)
    return (f'[sub_resource type="Curve3D" id="{cid}"]\n_data = {{\n"points": PackedVector3Array({pts}),\n'
            f'"tilts": PackedFloat32Array({tilts})\n}}\npoint_count = {len(points)}\n')

ext = [
    ('Script', 'res://scripts/levels/level_root.gd', '1'),
    ('PackedScene', 'res://scenes/camera/camera_rig.tscn', '2'),
    ('PackedScene', 'res://scenes/units/commando.tscn', '3'),
    ('PackedScene', 'res://scenes/props/low_wall.tscn', '4'),
    ('PackedScene', 'res://scenes/props/crate.tscn', '5'),
    ('PackedScene', 'res://scenes/ui/hud.tscn', '6'),
    ('PackedScene', 'res://scenes/enemies/enemy.tscn', '7'),
    ('PackedScene', 'res://scenes/props/wall.tscn', '8'),
    ('Script', 'res://scripts/props/tower.gd', 'tower'),
    ('Script', 'res://scripts/props/tiltrotor.gd', 'tiltrotor'),
    ('Script', 'res://scripts/props/hiding_spot.gd', 'hiding'),
]
# Immeuble : centre (TX, TZ), 16 x 12 m, cinq étages de 3,2 m, toit à 16 m.
TX, TZ, H = 0.0, -6.0, 3.2
def y(storey):
    return storey * H
patrols = {
    # Ronde autour de l'immeuble.
    "patrol_yard": [(-12, 0, 6), (12, 0, 6), (12, 0, -18), (-12, 0, -18), (-12, 0, 6)],
    # Rondes intérieures (pièce principale, au sud de l'escalier).
    "patrol_floor1": [(5, y(1), -5), (-5, y(1), -5)],
    "patrol_floor3": [(6, y(3), -5), (-6, y(3), -5), (-6, y(3), -7), (6, y(3), -7)],
}
subs = []
for cid, pts in patrols.items():
    subs.append(curve3(cid, pts))
subs.append("""[sub_resource type="Environment" id="env"]
background_mode = 1
background_color = Color(0.55, 0.62, 0.7, 1)
ambient_light_source = 2
ambient_light_color = Color(0.66, 0.66, 0.64, 1)
ambient_light_energy = 0.65
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
size = Vector3(90, 1, 90)
""")
subs.append("""[sub_resource type="StandardMaterial3D" id="ground_mat"]
albedo_color = Color(0.36, 0.36, 0.35, 1)
roughness = 1.0
""")
subs.append("""[sub_resource type="BoxMesh" id="ground_mesh"]
material = SubResource("ground_mat")
size = Vector3(90, 1, 90)
""")
subs.append("""[sub_resource type="StandardMaterial3D" id="lane_mat"]
albedo_color = Color(0.85, 0.82, 0.7, 1)
roughness = 1.0
""")
subs.append("""[sub_resource type="BoxMesh" id="lane_mesh"]
material = SubResource("lane_mat")
size = Vector3(0.2, 0.02, 2.5)
""")

nodes = []
nodes.append('[node name="Tower" type="Node3D"]\nscript = ExtResource("1")\ndress_code = &"suit"')
nodes.append('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("env")')
nodes.append('[node name="Sun" type="DirectionalLight3D" parent="."]\n'
             'transform = Transform3D(0.866, 0.383, -0.3214, 0, 0.6428, 0.766, 0.5, -0.6634, 0.5567, 0, 10, 0)\n'
             'light_color = Color(1, 0.96, 0.9, 1)\nlight_energy = 1.1\nshadow_enabled = true\ndirectional_shadow_max_distance = 160.0')
nodes.append('[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]\nnavigation_mesh = SubResource("nav")')
nodes.append('[node name="Ground" type="StaticBody3D" parent="NavigationRegion3D"]\ncollision_mask = 0')
nodes.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Ground"]\n'
             'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)\nshape = SubResource("ground_shape")')
nodes.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Ground"]\n'
             'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)\nmesh = SubResource("ground_mesh")')
NR = "NavigationRegion3D"
# L'immeuble : porte principale au sud, porte de service verrouillée à
# l'est ; fenêtres à chaque étage (pas le long de l'escalier, au nord-ouest).
nodes.append(f'[node name="Building" type="Node3D" parent="{NR}"]\ntransform = {tf(TX, TZ)}\nscript = ExtResource("tower")\n'
             'storeys = 5\nsize = Vector2(16, 12)\n'
             'doors = Array[Vector3]([Vector3(0, 0, 0), Vector3(1, 3, 1)])\n'
             'windows = Array[Vector2]([Vector2(0, -5.5), Vector2(0, -2.5), Vector2(0, 2.5), Vector2(0, 5.5), '
             'Vector2(1, -3), Vector2(1, 0), Vector2(1, 3), Vector2(2, -3), Vector2(2, -6), Vector2(3, 1), Vector2(3, 4)])')
# Caisses : abri dans les pièces de chaque étage, et dans la cour.
crates = []
for storey in range(5):
    crates += [(TX + 4.5, y(storey), TZ + 3.5), (TX - 3.0, y(storey), TZ + 4.0)]
crates += [(-8, 0, 12), (-6.7, 0, 12), (9, 0, 14), (14, 0, -4), (-15, 0, -10), (6, 0, 22), (-10, 0, 24)]
for i, (x, cy, z) in enumerate(crates):
    nodes.append(f'[node name="Crate{i + 1}" parent="{NR}" instance=ExtResource("5")]\ntransform = {tf(x, z, y=cy)}' + ('\nskin = "tex_base/ecrate_dunno.jpg"' if i % 3 == 1 else ""))
# Enceinte basse autour de la cour, ouverte au sud.
fence = [(-14, 10, 0), (14, 10, 0)] + [(-20, z, 90) for z in (6, 0, -6, -12, -18)] + [(20, z, 90) for z in (6, 0, -6, -12, -18)] \
    + [(x, -22, 0) for x in (-17, -11, -5, 1, 7, 13, 17)]
for i, (x, z, facing) in enumerate(fence):
    nodes.append(f'[node name="Fence{i + 1}" parent="{NR}" instance=ExtResource("4")]\ntransform = {tf(x, z, facing)}')
for i, (x, z, facing) in enumerate([(-24, 20, 90), (26, 24, 0), (-30, -6, 0)]):
    nodes.append(f'[node name="Wall{i + 1}" parent="{NR}" instance=ExtResource("8")]\ntransform = {tf(x, z, facing)}')
# Extraction : appelée par radio, elle attend 90 s en vol stationnaire au-
# dessus du toit (point de pose à 16 m), rampe au-dessus de la terrasse.
nodes.append(f'[node name="Extraction" type="StaticBody3D" parent="{NR}"]\ntransform = {tf(TX, 4.8, 180, y=y(5))}\nscript = ExtResource("tiltrotor")\n'
             'livery = 1\ntail_number = "52"\nobjective_id = &"extracted"\nextraction = true\npickup_window = 90.0\ndocuments_objective = &"documents"')
nodes.append('[node name="Decor" type="Node3D" parent="."]')
# Rue au sud : marquage au sol.
for i, x in enumerate(range(-40, 44, 6)):
    nodes.append(f'[node name="Lane{i + 1}" type="MeshInstance3D" parent="Decor"]\ntransform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, {x}, 0.01, 30)\nmesh = SubResource("lane_mesh")')
for i, (x, z) in enumerate([(-26, 8), (24, -12), (-4, 26), (30, 10)]):
    nodes.append(f'[node name="Bush{i + 1}" type="Node3D" parent="Decor"]\ntransform = {tf(x, z)}\nscript = ExtResource("hiding")\nsize = Vector2(3, 2.4)')
nodes.append('[node name="Units" type="Node3D" parent="."]')
for i, (name, x, z) in enumerate([("Alpha", -4, 38), ("Bravo", -5.5, 39.5), ("Charlie", -2.5, 39.5)]):
    nodes.append(f'[node name="{name}" parent="Units" instance=ExtResource("3")]\ntransform = {tf(x, z)}\nunit_index = {i + 1}\ndisplay_name = "{name}"')
nodes.append(f'[node name="CameraRig" parent="." instance=ExtResource("2")]\ntransform = {tf(0, 28)}\nbounds = AABB(-42, 0, -42, 84, 0, 84)')
nodes.append('[node name="PatrolPaths" type="Node3D" parent="."]')
for cid in patrols:
    name = "".join(part.capitalize() for part in cid.split("_"))
    nodes.append(f'[node name="{name}" type="Path3D" parent="PatrolPaths"]\ncurve = SubResource("{cid}")')
nodes.append('[node name="Enemies" type="Node3D" parent="."]')
# (nom, x, étage, z, cap, ronde, fixe, extra)
enemies = [
    ("YardPatrol", -12, 0, 6, 90, "PatrolYard", False, ""),
    ("DoorGuard", 1.6, 0, 1.6, 180, None, True, ""),
    ("LobbyGuard", 2, 0, -2, 200, None, True, ""),
    ("Floor1Patrol", 5, 1, -5, 270, "PatrolFloor1", False, ""),
    ("Floor2Guard", 5, 2, -9, 270, None, True, ""),
    ("Floor3Patrol", 6, 3, -5, 270, "PatrolFloor3", False, ""),
    ("Bodyguard", -4, 4, -7, 300, None, True, ""),
    ("Officer", 6, 4, -4, 200, None, True, "\ndocuments = true"),
    ("RoofLookout", 5, 5, -2, 180, None, True, ""),
]
for name, x, storey, z, facing, path, still, extra in enemies:
    extra = ("\nstationary = true" if still else "") + extra
    if path:
        nodes.append(f'[node name="{name}" parent="Enemies" node_paths=PackedStringArray("patrol_path") instance=ExtResource("7")]\n'
                     f'transform = {tf(x, z, facing, y=y(storey))}\npatrol_path = NodePath("../../PatrolPaths/{path}")' + extra)
    else:
        nodes.append(f'[node name="{name}" parent="Enemies" instance=ExtResource("7")]\ntransform = {tf(x, z, facing, y=y(storey))}' + extra)
nodes.append('[node name="HUD" parent="." instance=ExtResource("6")]')

text = f"[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]\n\n"
text += "\n".join(f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in ext) + "\n\n"
text += "\n".join(subs) + "\n"
text += "\n\n".join(nodes) + "\n"
os.makedirs(os.path.dirname(OUT), exist_ok=True)
write_scene(OUT, text)
print(len(nodes), "nœuds")
