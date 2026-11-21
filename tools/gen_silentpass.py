"""Génère scenes/levels/silentpass/silentpass.tscn (Col silencieux). Usage : python3 tools/gen_silentpass.py

De nuit : faire passer le Sabre par un défilé gardé jusqu'au point de
ralliement, sans donner l'alerte : phares éteints, moteur coupé en roue
libre, leurre du moteur au ralenti, abri derrière le véhicule ; extraction
au treuil, en temps limité."""
from mapkit import MapBuilder

m = MapBuilder("silentpass", "SilentPass", night=True, size=(100, 100), ground="rock")
TRACK = [(-36, 46), (-36, 22), (-14, 8), (0, -2), (0, -26), (18, -34), (32, -36)]
m.track(TRACK)
m.sabre("Sabre", -36, 38, 0, arrival_objective='&"sabre_rally"', arrival_point="Vector3(32, 0, -36)")
m.team([("Alpha", -32.5, 40), ("Bravo", -32.5, 37.5), ("Charlie", -32.5, 35)])
m.camera_at(-30, 32)
# Défilé : falaises (murs) de part et d'autre de la piste, de z = 0 à -24.
m.wall_line((-5, 2), (-5, -26))
m.wall_line((5, 2), (5, -26))
m.wall_line((-5, 2), (-50, 2))
m.wall_line((5, 2), (50, 2))
m.rocks([(-8, -6, 2.4), (8, -10, 2.2), (-8, -20, 2.0), (8, -22, 2.6), (-12, 6, 1.8), (12, 6, 2.0)])
# Poste à la sortie du défilé, sous un lampadaire ; guetteur au-dessus.
m.lamps([(4, -30), (26, -42)])
m.low_walls([(-4, -31, 0), (7, -32, 90)])
m.crates([(-30, 20), (-20, 18), (-14, 24), (12, -40), (13.3, -40), (24, -30), (-26, -12), (30, 16)])
m.bushes([(-24, 12), (-12, 16), (-40, 4), (14, -26), (22, -24), (34, -28)], size=(3.2, 2.6))
m.rocks([(-40, -30, 2.4), (38, 30, 2.2), (-20, -40, 2.0), (40, -10, 1.8)])
m.patrol("PatrolApproach", [(-28, 12), (-10, 14), (-28, 12)])
m.patrol("PatrolPost", [(-2, -32), (14, -38), (-2, -32)])
m.patrol("PatrolRally", [(24, -46), (40, -46), (40, -30), (24, -46)])
m.enemy("ApproachPatrol", -28, 12, 90, path="PatrolApproach")
m.enemy("PassLeft", -2.5, -28, 180, still=True)
m.enemy("PassRight", 2.5, -28, 180, still=True)
m.enemy("PostPatrol", -2, -32, 120, path="PatrolPost")
m.enemy("RallyPatrol", 24, -46, 90, path="PatrolRally")
m.enemy("RallyGuard", 36, -32, 230, still=True)
# Extraction : 60 s au-dessus d'une clairière au sud du point de ralliement.
m.tiltrotor("Extraction", 20, -20, 90, livery="1", tail_number='"72"', objective_id='&"extracted"', extraction="true", pickup_window="60.0")
m.write()
