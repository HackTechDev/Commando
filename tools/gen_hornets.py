"""Génère scenes/levels/hornets/hornets.tscn (Nid de frelons). Usage : python3 tools/gen_hornets.py

De jour : un camp défendu par des lance-roquettes. Appui depuis le
convertible (canon latéral, tireur d'élite embarqué), riposte ennemie,
ravitaillement en soute ; tout le camp est à neutraliser."""
from mapkit import MapBuilder

m = MapBuilder("hornets", "Hornets", night=False, size=(100, 100), ground="rock")
# Insertion et extraction : le même appareil, en vol à 30 m au sud-ouest ;
# renvoyé, il revient se poser au même endroit.
m.pad(-34, 34)
m.tiltrotor("Extraction", -34, 34, 45, livery="1", tail_number='"27"', objective_id='&"extracted"', extraction="true", insertion="true")
m.team([("Alpha", -32, 32), ("Bravo", -33, 33), ("Charlie", -34, 32)], explosives=("Bravo",), primary={"Alpha": "hecate"})
m.camera_at(-24, 24)
# Camp : enceinte de murets, tentes (bâtiments bas), caisses.
CX, CZ = 10, -12
ring = [(CX - 12, CZ + z, 90) for z in (-9, -3, 3, 9)] + [(CX + 12, CZ + z, 90) for z in (-9, -3, 3, 9)]
ring += [(CX + x, CZ - 12, 0) for x in (-9, -3, 3, 9)] + [(CX + x, CZ + 12, 0) for x in (-9, 9)]
m.low_walls(ring)
m.building("Tent1", CX - 5, CZ - 6, (6, 4), "Vector3(0, 0, 0)", height=2.4, roof=(0.36, 0.38, 0.26))
m.building("Tent2", CX + 5, CZ - 6, (6, 4), "Vector3(0, 0, 0)", height=2.4, roof=(0.36, 0.38, 0.26))
m.building("Command", CX + 4, CZ + 5, (6, 5), "Vector3(3, 0, 0)", "Vector2(0, 0)", height=2.8, roof=(0.3, 0.3, 0.28))
m.crates([(CX - 6, CZ + 4), (CX - 4.7, CZ + 4), (CX - 6, CZ + 5.3), (CX, CZ), (CX + 1.3, CZ), (-6, 8), (-18, 18), (24, 14), (30, -30), (-20, -20)])
m.rocks([(-8, 20, 2.6), (6, 30, 2.0), (-24, 2, 2.2), (30, 6, 1.8), (36, -28, 2.4), (-6, -34, 2.0), (-40, -10, 1.8), (20, 36, 2.2)])
m.bushes([(-14, 12), (-26, 10), (2, 22), (26, 22), (-30, -24), (32, -12)])
# Avant-postes : guetteurs et rondes autour du camp.
m.patrol("PatrolCamp", [(CX - 8, CZ - 9), (CX + 8, CZ - 9), (CX + 8, CZ + 9), (CX - 8, CZ + 9), (CX - 8, CZ - 9)])
m.patrol("PatrolOuter", [(-10, 6), (28, 4), (30, -32), (-10, -30), (-10, 6)])
m.enemy("RocketNorth", CX - 2, CZ - 9, 220, still=True, launcher="true")
m.enemy("RocketEast", CX + 9, CZ + 2, 200, still=True, launcher="true")
m.enemy("RocketHill", -12, -16, 200, still=True, launcher="true", rockets="3")
m.enemy("CampPatrol", CX - 8, CZ - 9, 90, path="PatrolCamp")
m.enemy("OuterPatrol", -10, 6, 90, path="PatrolOuter")
m.enemy("GateGuard", CX, CZ + 13.5, 180, still=True)
m.enemy("CommandGuard", CX + 4, CZ + 9, 220, still=True)
m.enemy("TentGuard", CX - 5, CZ - 2.5, 170, still=True)
m.enemy("WatchSouth", -2, 16, 200, still=True)
m.enemy("WatchEast", 30, 0, 250, still=True)
m.write()
