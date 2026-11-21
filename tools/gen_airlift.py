"""Génère scenes/levels/airlift/airlift.tscn (Pont aérien). Usage : python3 tools/gen_airlift.py

De jour : un ravin coupe la carte. Le Sabre attend au sud ; l'équipe, en
vol au nord, va l'élinguer, le passe au-dessus du ravin, le dépose, puis
le conduit jusqu'au poste d'observation au-delà d'un barrage."""
from mapkit import MapBuilder, heading

m = MapBuilder("airlift", "Airlift", night=False, size=(100, 100), ground="sand")
# Ravin d'ouest en est (z = 10) : un mur continu, bordé de rochers.
m.wall_line((-50, 10), (50, 10))
m.rocks([(x, 12.5 if i % 2 else 7.5, 1.4 + (i % 3) * 0.3) for i, x in enumerate(range(-46, 48, 7))])
# Le Sabre, vide, sur la rive sud.
m.sabre("Sabre", -24, 30, 0, arrival_objective='&"sabre_rally"', arrival_point="Vector3(32, 0, -38)")
m.track([(-24, 40), (-24, 22)])
# Insertion et extraction : en vol à 30 m au-dessus de la zone de poser,
# rive nord ; renvoyé, l'appareil revient s'y poser.
m.pad(-30, -6)
m.tiltrotor("Extraction", -30, -6, 90, livery="1", tail_number='"44"', objective_id='&"extracted"', extraction="true", insertion="true")
m.team([("Alpha", -30, -4), ("Bravo", -31, -5), ("Charlie", -32, -4)])
m.camera_at(-26, 8)
# Rive nord : piste vers le poste d'observation, barrage, pick-up armé.
TRACK = [(-24, 2), (-10, -8), (8, -12), (20, -26), (32, -34)]
m.track(TRACK)
m.barrier(14, -19, heading((8, -12), (20, -26)))
m.mine(-17, -3)
m.building("Observation", 38, -40, (6, 6), "Vector3(3, 0, 0)", "Vector2(0, 0), Vector2(2, 0)", height=3.2)
m.low_walls([(28, -44, 0), (40, -32, 0)])
m.crates([(2, -4), (3.3, -4), (24, -14), (-6, -24), (30, -22), (-38, 20), (10, 30)])
m.bushes([(-14, -16), (0, 0), (26, -6), (12, -36), (-36, -20), (0, 34), (30, 30)])
m.rocks([(-40, -36, 2.4), (8, -44, 2.0), (40, -6, 2.2), (-20, 40, 1.8), (30, 40, 2.0)])
m.patrol("PatrolNorth", [(-10, -20), (8, -28), (-10, -36), (-24, -26), (-10, -20)])
m.patrol("PatrolPost", [(26, -42), (44, -44), (44, -30), (26, -42)])
m.patrol("TechLoop", [(36, -2), (44, -20), (24, 2)])
m.patrol("PatrolSouth", [(-6, 24), (20, 24), (20, 38), (-6, 38), (-6, 24)])
m.enemy("BarrierGuard1", 11, -21, 230, still=True)
m.enemy("BarrierGuard2", 17, -16, 220, still=True)
m.enemy("NorthPatrol", -10, -20, 90, path="PatrolNorth")
m.enemy("PostPatrol", 26, -42, 90, path="PatrolPost")
m.enemy("PostGuard", 34, -40, 230, still=True)
m.enemy("SouthPatrol", -6, 24, 90, path="PatrolSouth")
m.technical("Technical", 36, -2, 200, "TechLoop")
m.write()
