"""Génère scenes/levels/frontline/frontline.tscn (Ligne de front). Usage : python3 tools/gen_frontline.py

De jour : faire sauter un dépôt dans une zone tenue, renforts minutés,
évacuation des blessés et ravitaillement dans la soute du convertible."""
from mapkit import MapBuilder

m = MapBuilder("frontline", "Frontline", night=False, size=(100, 100), ground="grass")
m.pad(-36, 36)
m.tiltrotor("Extraction", -36, 36, 45, livery="1", tail_number='"61"', objective_id='&"extracted"', extraction="true", insertion="true")
m.team([("Alpha", -34, 34), ("Bravo", -35, 35), ("Charlie", -36, 34)], explosives=("Alpha", "Bravo", "Charlie"))
m.camera_at(-26, 26)
# Lignes de tranchées (murets) et dépôt de munitions au nord-est.
m.low_walls([(x, 6, 0) for x in (-30, -24, -12, -6, 6, 12, 24)] + [(x, -14, 0) for x in (-18, -12, 0, 6, 18, 24, 30)])
DX, DZ = 22, -30
m.target("AmmoDepot", DX, DZ, 90, objective="depot", fuel=True)
m.low_walls([(DX - 6, DZ - 4, 90), (DX - 6, DZ + 3, 90), (DX + 6, DZ - 4, 90), (DX + 6, DZ + 3, 90), (DX - 2, DZ - 7, 0), (DX + 3, DZ - 7, 0)])
m.building("Bunker", -20, -30, (8, 6), "Vector3(0, 0, 0)", "Vector2(1, 0), Vector2(3, 0)", height=2.8, roof=(0.32, 0.34, 0.26))
m.building("Hq", 34, 10, (8, 6), "Vector3(3, 0, 0)", "Vector2(0, 0), Vector2(2, 2)", height=3.0)
m.crates([(-10, 10), (-8.7, 10), (2, -10), (14, 2), (15.3, 2), (30, -18), (-30, -6), (-4, 24), (10, 26), (DX + 2, DZ + 5)])
m.rocks([(-40, -40, 2.4), (40, 36, 2.2), (-44, 10, 2.0), (4, 40, 1.8), (44, -10, 2.0)])
m.bushes([(-22, 22), (-14, 30), (-2, 14), (8, 18), (20, 18), (-28, -18), (-6, -24), (36, -38), (40, -24)], size=(3.2, 2.6))
m.patrol("PatrolTrench", [(-28, 2), (26, 2), (-28, 2)])
m.patrol("PatrolMid", [(-20, -10), (28, -10), (28, -22), (-20, -22), (-20, -10)])
m.patrol("PatrolDepot", [(DX - 9, DZ - 10), (DX + 9, DZ - 10), (DX + 9, DZ + 8), (DX - 9, DZ + 8), (DX - 9, DZ - 10)])
m.enemy("TrenchPatrol", -28, 2, 90, path="PatrolTrench")
m.enemy("TrenchWest", -27, 8, 200, still=True)
m.enemy("TrenchEast", 9, 8, 180, still=True)
m.enemy("MidPatrol", -20, -10, 90, path="PatrolMid")
m.enemy("MidWatch", 3, -16, 200, still=True)
m.enemy("BunkerGuard", -20, -25.5, 180, still=True)
m.enemy("BunkerInside", -21, -30, 120, still=True)
m.enemy("HqGuard", 29, 10, 250, still=True)
m.enemy("DepotGuard", DX, DZ + 6, 180, still=True)
m.enemy("DepotPatrol", DX - 9, DZ - 10, 90, path="PatrolDepot")
m.enemy("DepotRocket", DX + 8, DZ - 2, 220, still=True, launcher="true")
# Renforts : 90 s après l'explosion, par le nord-est (pick-up 6 m derrière), vers le dépôt.
m.reinforcements(38, -40, 225, "AmmoDepot", start="depot", delay=90.0, count=5)
m.write()
