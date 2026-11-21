"""Génère scenes/levels/blackout/blackout.tscn (Feux éteints). Usage : python3 tools/gen_blackout.py

De nuit : insertion tous feux éteints, appareil ennemi à projecteur,
diversion par le convertible pour attirer les sentinelles de la station
radio, sabotage du groupe électrogène."""
from mapkit import MapBuilder

m = MapBuilder("blackout", "Blackout", night=True, size=(100, 100), ground="grass")
m.pad(-36, 36)
m.tiltrotor("Extraction", -36, 36, 45, livery="1", tail_number='"09"', objective_id='&"extracted"', extraction="true", insertion="true")
m.team([("Alpha", -34, 34), ("Bravo", -35, 35), ("Charlie", -36, 34)], explosives=("Alpha", "Bravo"))
m.camera_at(-26, 26)
# Station radio : enceinte, deux bâtiments, pylônes (murs étroits), groupe
# électrogène qui alimente les lampadaires.
SX, SZ = 14, -14
fence = [(SX - 14, SZ + z, 90) for z in (-11, -5, 1, 7)] + [(SX + 14, SZ + z, 90) for z in (-11, -5, 1, 7)]
fence += [(SX + x, SZ - 14, 0) for x in (-11, -5, 1, 7, 11)] + [(SX + x, SZ + 10, 0) for x in (-11, -5, 5, 11)]
m.low_walls(fence)
m.building("Station", SX - 5, SZ - 5, (8, 6), "Vector3(0, 0, 0), Vector3(1, 0, 1)", "Vector2(0, 2), Vector2(3, 0)", height=3.2, roof=(0.25, 0.26, 0.26))
m.building("Barracks", SX + 7, SZ - 6, (6, 8), "Vector3(3, 0, 0)", "Vector2(0, 0)", height=3.0)
lamps = m.lamps([(SX - 2.5, SZ + 11), (SX + 2.5, SZ + 11), (SX - 8, SZ + 3), (SX + 8, SZ + 4), (SX, SZ - 10)])
m.target("Generator", SX + 2, SZ + 4, 90, objective="sabotage", lights="Lamps")
m.crates([(SX - 9, SZ + 6), (SX - 7.7, SZ + 6), (SX + 10, SZ + 7), (-4, 8), (-16, 20), (30, 20), (-24, -18), (6, 26)])
m.walls([(SX - 1, SZ - 16, 0)])
m.bushes([(-20, 24), (-8, 14), (4, 18), (26, 10), (-28, -2), (36, -30), (-14, -30)], size=(3.2, 2.6))
m.rocks([(-40, 0, 2.2), (40, 30, 2.0), (-2, -40, 1.8), (20, 40, 2.4)])
# Rondes, sentinelles du portail (la diversion les attire), appareil ennemi.
m.patrol("PatrolYard", [(SX - 10, SZ + 6), (SX + 10, SZ + 6), (SX + 10, SZ - 10), (SX - 10, SZ - 10), (SX - 10, SZ + 6)])
m.patrol("PatrolOutside", [(-6, 4), (32, 4), (32, -32), (-6, -32), (-6, 4)])
m.patrol("PatrolAir", [(-10, 10), (36, 10), (36, -36), (-10, -36), (-10, 10)])
m.enemy("GateLeft", SX - 3.5, SZ + 12, 180, still=True)
m.enemy("GateRight", SX + 3.5, SZ + 12, 180, still=True)
m.enemy("YardPatrol", SX - 10, SZ + 6, 90, path="PatrolYard")
m.enemy("OutsidePatrol", -6, 4, 90, path="PatrolOutside")
m.enemy("GeneratorGuard", SX + 5, SZ + 1, 230, still=True)
m.enemy("StationGuard", SX - 5, SZ - 1.2, 180, still=True)
m.enemy("RocketGuard", SX + 9, SZ - 1, 200, still=True, launcher="true")
m.gunship("Gunship", "PatrolAir", altitude=25.0, speed=6.0)
m.write()
