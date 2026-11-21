"""Génère scenes/levels/wadi/wadi.tscn (Oued sec). Usage : python3 tools/gen_wadi.py

De jour, en Sabre : détruire un relais radar retranché (missile antichar,
tir désigné à la 12,7 ou charge), forcer ou lever un barrage, déjouer les
mines et le pick-up armé, puis charger le véhicule dans l'extraction."""
from mapkit import MapBuilder, heading

m = MapBuilder("wadi", "Wadi", night=False, size=(100, 100), ground="desert")
TRACK = [(-40, 46), (-40, 22), (-20, 10), (0, 8), (18, -6), (30, -26), (34, -36)]
m.track(TRACK)
m.sabre("Sabre", -40, 38, 0, stow_objective='&"sabre_extracted"')
m.team([("Alpha", -36.5, 40), ("Bravo", -36.5, 37.5), ("Charlie", -36.5, 35)], explosives=("Alpha",))
m.camera_at(-34, 32)
# Barrage au milieu du tronçon (-20, 10) → (0, 8).
m.barrier(-10, 9, heading((-20, 10), (0, 8)))
m.walls([(-10, 15, 90)])
m.mine(-40, 28)
m.mine(9, 1, improvised=True)
m.mine(24, -16)
# Relais radar retranché sur l'éperon nord-ouest : murets, deux gardes.
m.target("Radar", -26, -28, 90, objective="sabotage")
m.low_walls([(-31, -24, 90), (-26, -21, 0), (-21, -24, 90), (-31, -32, 90), (-21, -32, 90)])
m.crates([(-28, -34), (-24, -34)])
# Terrain d'extraction au bout de la piste.
m.pad(34, -42)
m.tiltrotor("Extraction", 34, -42, 0, livery="1", tail_number='"33"', objective_id='&"extracted"', extraction="true")
m.crates([(42, -36), (42, -37.3), (26, -46), (-8, 18), (8, 14), (12, -12), (-34, 6)])
m.rocks([(-26, -4, 2.2), (-14, -12, 1.8), (-2, -20, 2.0), (6, 26, 1.6), (40, 22, 2.4), (-46, 0, 2.0), (22, 30, 1.8), (44, -18, 1.6)])
m.bushes([(-30, 14), (2, 18), (14, 4), (36, -28), (-16, -18)])
m.patrol("PatrolRidge", [(-20, -12), (-4, -14), (-20, -12), (-34, -10)])
m.patrol("PatrolRadar", [(-34, -36), (-18, -36), (-18, -20), (-34, -20), (-34, -36)])
m.patrol("PatrolLz", [(24, -46), (44, -46), (44, -30), (24, -46)])
m.patrol("TechLoop", [(30, 12), (44, -12), (28, -2)])
m.enemy("BarrierLeft", -12, 6, 270, still=True)
m.enemy("BarrierRight", -8, 13, 250, still=True)
m.enemy("RidgePatrol", -20, -12, 90, path="PatrolRidge")
m.enemy("RadarGuard", -26, -24, 180, still=True)
m.enemy("RadarPatrol", -34, -36, 90, path="PatrolRadar")
m.enemy("LzGuard", 28, -36, 200, still=True)
m.enemy("LzPatrol", 24, -46, 90, path="PatrolLz")
m.technical("Technical", 30, 12, 160, "TechLoop")
m.write()
