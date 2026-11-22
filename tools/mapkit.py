"""Outils communs aux générateurs de cartes (`tools/gen_*.py`).

Une carte se décrit avec `MapBuilder` : décor, unités, ennemis, véhicules,
puis `write()` écrit la scène `.tscn`. Repère : x vers l'est, z vers le sud ;
`facing` en degrés, 0 = nord (-Z), 90 = est (+X).
"""
import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def tf(x, z, facing=None, y=0.0):
    """Transform3D : facing = direction regardée (-Z local) en degrés."""
    if facing is None:
        return f"Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x:g}, {y:g}, {z:g})"
    a = math.radians(facing)
    d = (math.sin(a), 0.0, -math.cos(a))
    Z = (-d[0], 0.0, -d[2])
    X = (Z[2], 0.0, -Z[0])
    r = lambda v: f"{round(v, 4):g}"
    return f"Transform3D({r(X[0])}, 0, {r(Z[0])}, 0, 1, 0, {r(X[2])}, 0, {r(Z[2])}, {x:g}, {y:g}, {z:g})"


def heading(a, b):
    """Cap (degrés) pour regarder de `a` vers `b` (points (x, z))."""
    return math.degrees(math.atan2(b[0] - a[0], -(b[1] - a[1])))


def vec3(v):
    return f"Vector3({v[0]:g}, {v[1]:g}, {v[2]:g})"


DAY_ENV = """background_mode = 1
background_color = Color(0.55, 0.62, 0.7, 1)
ambient_light_source = 2
ambient_light_color = Color(0.66, 0.66, 0.64, 1)
ambient_light_energy = 0.65
tonemap_mode = 2
ssao_enabled = true"""
NIGHT_ENV = """background_mode = 1
background_color = Color(0.01, 0.015, 0.03, 1)
ambient_light_source = 2
ambient_light_color = Color(0.2, 0.25, 0.4, 1)
ambient_light_energy = 0.22
tonemap_mode = 2
ssao_enabled = true"""
SUN_BASIS = "0.866, 0.383, -0.3214, 0, 0.6428, 0.766, 0.5, -0.6634, 0.5567"
GROUNDS = {
    "desert": (0.62, 0.52, 0.36),
    "sand": (0.55, 0.47, 0.33),
    "dirt": (0.4, 0.36, 0.28),
    "grass": (0.3, 0.36, 0.22),
    "urban": (0.36, 0.36, 0.35),
    "rock": (0.42, 0.4, 0.37),
}
TRACK_COLORS = {
    "desert": (0.5, 0.42, 0.3),
    "sand": (0.45, 0.38, 0.27),
    "dirt": (0.32, 0.28, 0.21),
    "grass": (0.36, 0.32, 0.24),
    "urban": (0.22, 0.22, 0.23),
    "rock": (0.33, 0.3, 0.26),
}


class MapBuilder:
    """Scène de carte : `ext`, sous-ressources et nœuds rangés par parent."""

    def __init__(self, folder, root_name, night=False, size=(100, 100), ground="desert", dress_code=""):
        self.out = os.path.join(ROOT, "scenes", "levels", folder, folder + ".tscn")
        self.root_name = root_name
        self.night = night
        self.dress_code = dress_code
        self.size = size
        self.ground = ground
        self._ext = []
        self._ext_ids = {}
        self.subs = []
        self.nav = []
        self.decor = []
        self.lamp_nodes = []
        self.units = []
        self.paths = []
        self.enemies = []
        self.camera = None
        self.after_root = []
        self._count = {}
        self._mat("ground_mat", GROUNDS[ground])
        self._mat("track_mat", TRACK_COLORS[ground])
        self.subs.append('[sub_resource type="BoxMesh" id="track_mesh"]\nmaterial = SubResource("track_mat")\nsize = Vector3(1, 0.02, 1)\n')
        self._mat("rock_mat", (0.4, 0.38, 0.35))
        self.subs.append('[sub_resource type="SphereMesh" id="rock_mesh"]\nmaterial = SubResource("rock_mat")\nradius = 1.0\nheight = 1.4\nradial_segments = 7\nrings = 4\n')
        self.subs.append('[sub_resource type="StandardMaterial3D" id="post_mat"]\nalbedo_color = Color(0.22, 0.23, 0.24, 1)\nmetallic = 0.6\nroughness = 0.5\n')
        self.subs.append('[sub_resource type="CylinderMesh" id="post_mesh"]\nmaterial = SubResource("post_mat")\ntop_radius = 0.06\nbottom_radius = 0.09\nheight = 4.0\nradial_segments = 8\n')
        self.subs.append('[sub_resource type="StandardMaterial3D" id="bulb_mat"]\nalbedo_color = Color(1, 0.85, 0.55, 1)\nemission_enabled = true\n'
                         'emission = Color(1, 0.8, 0.5, 1)\nemission_energy_multiplier = 3.0\n')
        self.subs.append('[sub_resource type="SphereMesh" id="bulb_mesh"]\nmaterial = SubResource("bulb_mat")\nradius = 0.18\nheight = 0.36\n')
        self.subs.append('[sub_resource type="StandardMaterial3D" id="pad_mat"]\nalbedo_color = Color(0.3, 0.31, 0.3, 1)\nroughness = 1.0\n')
        self.subs.append('[sub_resource type="CylinderMesh" id="pad_mesh"]\nmaterial = SubResource("pad_mat")\ntop_radius = 7.0\nbottom_radius = 7.0\nheight = 0.04\nradial_segments = 32\n')

    # --- Ressources ---------------------------------------------------------

    def ext(self, kind, path):
        if path not in self._ext_ids:
            ident = str(len(self._ext) + 1)
            self._ext.append((kind, path, ident))
            self._ext_ids[path] = ident
        return f'ExtResource("{self._ext_ids[path]}")'

    def scene(self, path):
        return self.ext("PackedScene", path)

    def script(self, path):
        return self.ext("Script", path)

    def _mat(self, ident, color):
        r, g, b = color
        self.subs.append(f'[sub_resource type="StandardMaterial3D" id="{ident}"]\nalbedo_color = Color({r}, {g}, {b}, 1)\nroughness = 1.0\n')

    def _name(self, base):
        self._count[base] = self._count.get(base, 0) + 1
        return f"{base}{self._count[base]}"

    @staticmethod
    def _props(props):
        return "".join(f"\n{key} = {value}" for key, value in props.items())

    # --- Décor --------------------------------------------------------------

    def track(self, points, width=4.5):
        """Piste : bandes plates entre les points (x, z)."""
        for i in range(len(points) - 1):
            (x1, z1), (x2, z2) = points[i], points[i + 1]
            length = math.hypot(x2 - x1, z2 - z1)
            ux, uz = (x2 - x1) / length, (z2 - z1) / length
            # Prolongé d'une demi-largeur à chaque bout : les virages se
            # recouvrent sans laisser d'encoche.
            ext = width * 0.5
            x1, z1, x2, z2 = x1 - ux * ext, z1 - uz * ext, x2 + ux * ext, z2 + uz * ext
            xx, xz = uz * width, -ux * width
            self.decor.append(f'[node name="{self._name("Track")}" type="MeshInstance3D" parent="Decor"]\n'
                              f'transform = Transform3D({xx:.4f}, 0, {x2 - x1:.4f}, 0, 1, 0, {xz:.4f}, 0, {z2 - z1:.4f}, '
                              f'{(x1 + x2) / 2:g}, {0.01 + 0.001 * i:g}, {(z1 + z2) / 2:g})\nmesh = SubResource("track_mesh")')

    def pad(self, x, z):
        """Aire de poser circulaire (décor)."""
        self.decor.append(f'[node name="{self._name("Pad")}" type="MeshInstance3D" parent="Decor"]\ntransform = {tf(x, z, y=0.02)}\nmesh = SubResource("pad_mesh")')

    def rocks(self, items):
        """Rochers (décor sans collision) : (x, z, taille)."""
        for x, z, s in items:
            self.decor.append(f'[node name="{self._name("Rock")}" type="MeshInstance3D" parent="Decor"]\n'
                              f'transform = Transform3D({s}, 0, 0, 0, {s * 0.7:.2f}, 0, 0, 0, {s}, {x}, 0.2, {z})\nmesh = SubResource("rock_mesh")')

    def bushes(self, items, size=(3, 2.4)):
        hiding = self.script("res://scripts/props/hiding_spot.gd")
        for item in items:
            x, z = item[0], item[1]
            sx, sz = (item[2], item[3]) if len(item) == 4 else size
            self.decor.append(f'[node name="{self._name("Bush")}" type="Node3D" parent="Decor"]\ntransform = {tf(x, z)}\nscript = {hiding}\nsize = Vector2({sx}, {sz})')

    def crates(self, items, movable=False):
        crate = self.scene("res://scenes/props/crate.tscn")
        for i, item in enumerate(items):
            x, z = item[0], item[1]
            y = item[2] if len(item) > 2 else 0.0
            skin = '\nskin = "tex_base/ecrate_dunno.jpg"' if self._count.get("Crate", 0) % 3 == 1 else ""
            self.nav.append(f'[node name="{self._name("Crate")}" parent="NavigationRegion3D" instance={crate}]\ntransform = {tf(x, z, y=y)}{skin}')

    def low_walls(self, items):
        """Murets (sacs de sable) : (x, z, cap)."""
        scene = self.scene("res://scenes/props/low_wall.tscn")
        for x, z, facing in items:
            self.nav.append(f'[node name="{self._name("LowWall")}" parent="NavigationRegion3D" instance={scene}]\ntransform = {tf(x, z, facing)}')

    def walls(self, items):
        """Murs de 6 m : (x, z, cap)."""
        scene = self.scene("res://scenes/props/wall.tscn")
        for x, z, facing in items:
            self.nav.append(f'[node name="{self._name("Wall")}" parent="NavigationRegion3D" instance={scene}]\ntransform = {tf(x, z, facing)}')

    def wall_line(self, a, b):
        """Murs de 6 m bout à bout de `a` à `b` (x, z)."""
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        count = max(1, math.ceil(length / 6.0))
        facing = heading(a, b) + 90.0
        for i in range(count):
            t = (i + 0.5) / count
            self.walls([(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, facing)])

    def building(self, name, x, z, size=(8, 6), doors="Vector3(0, 0, 0)", windows="", height=3.0, roof=None):
        script = self.script("res://scripts/props/building.gd")
        text = (f'[node name="{name}" type="Node3D" parent="NavigationRegion3D"]\ntransform = {tf(x, z)}\nscript = {script}\n'
                f'size = Vector2({size[0]:g}, {size[1]:g})\nwall_height = {height:g}\ndoors = Array[Vector3]([{doors}])')
        if windows:
            text += f"\nwindows = Array[Vector2]([{windows}])"
        if roof:
            text += f"\nroof_color = Color({roof[0]}, {roof[1]}, {roof[2]}, 1)"
        self.nav.append(text)

    def lamps(self, items):
        """Lampadaires : (x, z). Renvoie leurs noms (Lamp1, Lamp2…)."""
        names = []
        for x, z in items:
            name = self._name("Lamp")
            names.append(name)
            self.lamp_nodes.append(f'[node name="{name}" type="Node3D" parent="Lamps"]\ntransform = {tf(x, z)}')
            self.lamp_nodes.append(f'[node name="Post" type="MeshInstance3D" parent="Lamps/{name}"]\ntransform = {tf(0, 0, y=2)}\nmesh = SubResource("post_mesh")')
            self.lamp_nodes.append(f'[node name="Bulb" type="MeshInstance3D" parent="Lamps/{name}"]\ntransform = {tf(0, 0, y=4.05)}\nmesh = SubResource("bulb_mesh")')
            self.lamp_nodes.append(f'[node name="Light" type="OmniLight3D" parent="Lamps/{name}"]\ntransform = {tf(0, 0, y=3.9)}\n'
                              'light_color = Color(1, 0.8, 0.52, 1)\nlight_energy = 2.2\nomni_range = 9.0\nomni_attenuation = 1.4')
        return names

    # --- Objets de mission --------------------------------------------------

    def tiltrotor(self, name, x, z, facing=0, y=0.0, **props):
        script = self.script("res://scripts/props/tiltrotor.gd")
        self.nav.append(f'[node name="{name}" type="StaticBody3D" parent="NavigationRegion3D"]\ntransform = {tf(x, z, facing, y)}\nscript = {script}' + self._props(props))

    def sabre(self, name, x, z, facing=0, **props):
        script = self.script("res://scripts/props/sabre.gd")
        self.nav.append(f'[node name="{name}" type="StaticBody3D" parent="NavigationRegion3D"]\ntransform = {tf(x, z, facing)}\nscript = {script}' + self._props(props))

    def barrier(self, x, z, facing, width=4.6, posts=True):
        """Barrière en travers d'une piste orientée `facing`, avec deux murets."""
        script = self.script("res://scripts/props/road_barrier.gd")
        self.nav.append(f'[node name="{self._name("Barrier")}" type="Node3D" parent="NavigationRegion3D"]\ntransform = {tf(x, z, facing)}\n'
                        f'script = {script}\nwidth = {width:g}')
        if posts:
            a = math.radians(facing)
            ax = (math.cos(a), math.sin(a))
            for side in (-1, 1):
                self.low_walls([(x + side * (width * 0.5 + 1.85) * ax[0], z + side * (width * 0.5 + 1.85) * ax[1], facing)])

    def mine(self, x, z, improvised=False):
        script = self.script("res://scripts/props/landmine.gd")
        self.nav.append(f'[node name="{self._name("Ied" if improvised else "Mine")}" type="Node3D" parent="NavigationRegion3D"]\ntransform = {tf(x, z)}\n'
                        f'script = {script}' + ("\nimprovised = true" if improvised else ""))

    def target(self, name, x, z, facing=0, objective="sabotage", fuel=False, lights=None):
        script = self.script("res://scripts/props/sabotage_target.gd")
        text = f'[node name="{name}" type="StaticBody3D" parent="NavigationRegion3D"]\ntransform = {tf(x, z, facing)}\nscript = {script}\nobjective_id = &"{objective}"'
        if fuel:
            text += "\nfuel = true"
        if lights:
            text += f'\nlights = NodePath("../../Lamps/{lights}")' if lights != "Lamps" else '\nlights = NodePath("../../Lamps")'
        self.nav.append(text)

    def extraction_zone(self, x, z, size=(6, 6), objective="vip_extracted"):
        script = self.script("res://scripts/levels/extraction_zone.gd")
        self.after_root.append(f'[node name="ExtractionZone" type="Area3D" parent="."]\ntransform = {tf(x, z)}\nscript = {script}\n'
                               f'size = Vector2({size[0]:g}, {size[1]:g})\nobjective_id = &"{objective}"')

    # --- Unités -------------------------------------------------------------

    def team(self, members, nvg=None, explosives=(), primary=None, clothing=""):
        """Opérateurs : (nom, x, z) ; `explosives` : noms qui reçoivent une
        charge ; `primary` : {nom: arme imposée} ; `clothing` : tenue imposée."""
        scene = self.scene("res://scenes/units/commando.tscn")
        nvg = self.night if nvg is None else nvg
        primary = primary or {}
        for i, (name, x, z) in enumerate(members):
            text = f'[node name="{name}" parent="Units" instance={scene}]\ntransform = {tf(x, z)}\nunit_index = {i + 1}\ndisplay_name = "{name}"'
            if nvg:
                text += "\nmission_nvg = true"
            if name in explosives:
                text += "\nmission_explosives = 1"
            if name in primary:
                text += f'\nmission_primary = &"{primary[name]}"'
            if clothing:
                text += f'\nmission_clothing = &"{clothing}"'
            self.units.append(text)

    def guests(self, items, dress="suit"):
        """Invités (décor, barrent le passage) : (x, z, cap)."""
        script = self.script("res://scripts/props/guest.gd")
        for x, z, facing in items:
            name = self._name("Guest")
            self.nav.append(f'[node name="{name}" type="StaticBody3D" parent="NavigationRegion3D"]\ntransform = {tf(x, z, facing)}\n'
                            f'script = {script}\nlook_seed = {self._count["Guest"] * 7919 % 100003}\ndress = &"{dress}"')

    def vip(self, x, z, name="Vip", display="VIP"):
        scene = self.scene("res://scenes/units/vip.tscn")
        self.units.append(f'[node name="{name}" parent="Units" instance={scene}]\ntransform = {tf(x, z)}\ndisplay_name = "{display}"')

    def camera_at(self, x, z, bounds=None):
        scene = self.scene("res://scenes/camera/camera_rig.tscn")
        if bounds is None:
            hx, hz = self.size[0] / 2 - 2, self.size[1] / 2 - 2
            bounds = (-hx, -hz, 2 * hx, 2 * hz)
        self.camera = (f'[node name="CameraRig" parent="." instance={scene}]\ntransform = {tf(x, z)}\n'
                       f'bounds = AABB({bounds[0]:g}, 0, {bounds[1]:g}, {bounds[2]:g}, 0, {bounds[3]:g})')

    # --- Ennemis ------------------------------------------------------------

    def patrol(self, name, points):
        """Chemin de ronde : points (x, z) ou (x, y, z)."""
        pts = []
        for p in points:
            x, y, z = (p[0], 0.0, p[1]) if len(p) == 2 else p
            pts.append(f"0, 0, 0, 0, 0, 0, {x:g}, {y:g}, {z:g}")
        cid = "curve_" + name
        self.subs.append(f'[sub_resource type="Curve3D" id="{cid}"]\n_data = {{\n"points": PackedVector3Array({", ".join(pts)}),\n'
                         f'"tilts": PackedFloat32Array({", ".join("0" for _ in points)})\n}}\npoint_count = {len(points)}\n')
        self.paths.append(f'[node name="{name}" type="Path3D" parent="PatrolPaths"]\ncurve = SubResource("{cid}")')
        return name

    def enemy(self, name, x, z, facing=0, path=None, still=False, y=0.0, **props):
        scene = self.scene("res://scenes/enemies/enemy.tscn")
        if still:
            props["stationary"] = "true"
        if path:
            self.enemies.append(f'[node name="{name}" parent="Enemies" node_paths=PackedStringArray("patrol_path") instance={scene}]\n'
                                f'transform = {tf(x, z, facing, y)}\npatrol_path = NodePath("../../PatrolPaths/{path}")' + self._props(props))
        else:
            self.enemies.append(f'[node name="{name}" parent="Enemies" instance={scene}]\ntransform = {tf(x, z, facing, y)}' + self._props(props))

    def technical(self, name, x, z, facing, path):
        script = self.script("res://scripts/enemies/technical.gd")
        self.enemies.append(f'[node name="{name}" type="StaticBody3D" parent="Enemies"]\ntransform = {tf(x, z, facing)}\nscript = {script}\n'
                            f'patrol_path = NodePath("../../PatrolPaths/{path}")')

    def gunship(self, name, path, altitude=25.0, speed=7.0):
        script = self.script("res://scripts/enemies/enemy_aircraft.gd")
        self.enemies.append(f'[node name="{name}" type="Node3D" parent="Enemies"]\nscript = {script}\npatrol_path = NodePath("../../PatrolPaths/{path}")\n'
                            f'altitude = {altitude:g}\nspeed = {speed:g}')

    def reinforcements(self, x, z, facing, target, start="depot", objective="raid_in_time", delay=120.0, count=4, technical=True):
        script = self.script("res://scripts/levels/reinforcements.gd")
        self.enemies.append(f'[node name="Reinforcements" type="Node3D" parent="Enemies"]\ntransform = {tf(x, z, facing)}\nscript = {script}\n'
                            f'start_objective = &"{start}"\nobjective_id = &"{objective}"\ndelay = {delay:g}\ncount = {count}\n'
                            f'technical = {"true" if technical else "false"}\ntarget = NodePath("../../NavigationRegion3D/{target}")')

    # --- Écriture -----------------------------------------------------------

    def write(self):
        root_script = self.script("res://scripts/levels/level_root.gd")
        hud = self.scene("res://scenes/ui/hud.tscn")
        sx, sz = self.size
        subs = list(self.subs)
        subs.append(f'[sub_resource type="Environment" id="env"]\n{NIGHT_ENV if self.night else DAY_ENV}\n')
        subs.append('[sub_resource type="NavigationMesh" id="nav"]\nresource_local_to_scene = true\ngeometry_parsed_geometry_type = 1\n'
                    'geometry_collision_mask = 3\nagent_height = 1.75\nagent_radius = 0.5\n')
        subs.append(f'[sub_resource type="BoxShape3D" id="ground_shape"]\nsize = Vector3({sx}, 1, {sz})\n')
        subs.append(f'[sub_resource type="BoxMesh" id="ground_mesh"]\nmaterial = SubResource("ground_mat")\nsize = Vector3({sx}, 1, {sz})\n')
        nodes = [f'[node name="{self.root_name}" type="Node3D"]\nscript = {root_script}' + ("\nnight = true" if self.night else "") + (f'\ndress_code = &"{self.dress_code}"' if self.dress_code else "")]
        nodes.append('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("env")')
        if self.night:
            nodes.append(f'[node name="Moon" type="DirectionalLight3D" parent="."]\ntransform = Transform3D({SUN_BASIS}, 0, 10, 0)\n'
                         'light_color = Color(0.6, 0.7, 1, 1)\nlight_energy = 0.16\nshadow_enabled = true\ndirectional_shadow_max_distance = 120.0')
        else:
            nodes.append(f'[node name="Sun" type="DirectionalLight3D" parent="."]\ntransform = Transform3D({SUN_BASIS}, 0, 10, 0)\n'
                         'light_color = Color(1, 0.96, 0.9, 1)\nlight_energy = 1.1\nshadow_enabled = true\ndirectional_shadow_max_distance = 160.0')
        nodes.append('[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]\nnavigation_mesh = SubResource("nav")')
        nodes.append('[node name="Ground" type="StaticBody3D" parent="NavigationRegion3D"]\ncollision_mask = 0')
        nodes.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Ground"]\n'
                     'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)\nshape = SubResource("ground_shape")')
        nodes.append('[node name="MeshInstance3D" type="MeshInstance3D" parent="NavigationRegion3D/Ground"]\n'
                     'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)\nmesh = SubResource("ground_mesh")')
        nodes += self.nav
        nodes.append('[node name="Decor" type="Node3D" parent="."]')
        nodes += self.decor
        nodes.append('[node name="Lamps" type="Node3D" parent="."]')
        nodes += self.lamp_nodes
        nodes.append('[node name="Units" type="Node3D" parent="."]')
        nodes += self.units
        nodes += self.after_root
        if self.camera:
            nodes.append(self.camera)
        nodes.append('[node name="PatrolPaths" type="Node3D" parent="."]')
        nodes += self.paths
        nodes.append('[node name="Enemies" type="Node3D" parent="."]')
        nodes += self.enemies
        nodes.append(f'[node name="HUD" parent="." instance={hud}]')
        text = f"[gd_scene load_steps={len(self._ext) + len(subs) + 1} format=3]\n\n"
        text += "\n".join(f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in self._ext) + "\n\n"
        text += "\n".join(subs) + "\n"
        text += "\n\n".join(nodes) + "\n"
        os.makedirs(os.path.dirname(self.out), exist_ok=True)
        with open(self.out, "w") as handle:
            handle.write(text)
        print(os.path.relpath(self.out, ROOT), len(nodes), "nœuds")


def add_tower(m, name, x, z, storeys=3, size=(14, 10), doors="Vector3(0, 0, 0)", windows=""):
    """Immeuble à étages (`Tower`) ; renvoie la hauteur du toit."""
    script = m.script("res://scripts/props/tower.gd")
    text = (f'[node name="{name}" type="Node3D" parent="NavigationRegion3D"]\ntransform = {tf(x, z)}\nscript = {script}\n'
            f'storeys = {storeys}\nsize = Vector2({size[0]:g}, {size[1]:g})\ndoors = Array[Vector3]([{doors}])')
    if windows:
        text += f"\nwindows = Array[Vector2]([{windows}])"
    m.nav.append(text)
    return storeys * 3.2
