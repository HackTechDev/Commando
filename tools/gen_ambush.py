"""Génère scenes/levels/ambush/ambush.tscn (Embuscade). Usage : python3 tools/gen_ambush.py

De jour : une vallée tenue des deux côtés. Le Sabre la traverse sous le
feu (12,7, 7,62 latérales, missile), se ravitaille et se répare ; toute
l'embuscade est à neutraliser, puis extraction au treuil."""
from mapkit import MapBuilder

m = MapBuilder("ambush", "Ambush", night=False, size=(100, 100), ground="sand")
TRACK = [(-42, 44), (-30, 26), (-12, 14), (4, -4), (14, -22), (30, -34), (40, -38)]
m.track(TRACK)
m.sabre("Sabre", -40, 40, 30, arrival_objective='&"sabre_rally"', arrival_point="Vector3(38, 0, -38)")
m.team([("Alpha", -36, 42), ("Bravo", -36, 39.5), ("Charlie", -36, 37)], explosives=("Charlie",))
m.camera_at(-32, 32)
# Crêtes de part et d'autre de la vallée : murets en chapelet, rochers.
west = [(-30, 10), (-20, -2), (-10, -14), (0, -26), (6, -38)]
east = [(-12, 30), (2, 20), (14, 8), (24, -6), (32, -20)]
m.low_walls([(x, z, 315) for x, z in west] + [(x, z, 315) for x, z in east])
m.rocks([(x - 3, z - 3, 2.2) for x, z in west] + [(x + 3, z + 3, 2.4) for x, z in east])
m.crates([(-26, 12), (-6, -16), (4, -28), (-8, 28), (18, 10), (28, -4), (-20, 30), (20, -40)])
m.bushes([(-24, -6), (-14, -20), (10, 22), (28, 0), (34, -26), (-34, 18)])
m.mine(-2, 3)
m.mine(20, -27, improvised=True)
m.low_walls([(34, -44, 0), (44, -32, 90)])
# Les tireurs de l'embuscade, abrités derrière les murets.
for i, (x, z) in enumerate(west):
    m.enemy(f"West{i + 1}", x - 1.2, z - 1.2, 135, still=True)
for i, (x, z) in enumerate(east):
    m.enemy(f"East{i + 1}", x + 1.2, z + 1.2, 315, still=True)
m.patrol("TechWest", [(-40, -10), (-24, -30), (-40, -30)])
m.patrol("TechEast", [(26, 26), (44, 0), (30, 6)])
m.patrol("TechNorth", [(10, -46), (-10, -40), (16, -34)])
m.patrol("PatrolRally", [(30, -46), (46, -44), (46, -30), (30, -46)])
m.enemy("RallyPatrol", 30, -46, 90, path="PatrolRally")
m.technical("TechnicalWest", -40, -10, 150, "TechWest")
m.technical("TechnicalEast", 26, 26, 120, "TechEast")
m.technical("TechnicalNorth", 10, -46, 270, "TechNorth")
# Extraction : 90 s en vol stationnaire au-dessus du point de ralliement.
m.tiltrotor("Extraction", 32, -26, 270, livery="1", tail_number='"80"', objective_id='&"extracted"', extraction="true", pickup_window="90.0")
m.write()
