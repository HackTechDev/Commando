"""Génère scenes/levels/motorcade/motorcade.tscn (Escorte motorisée). Usage : python3 tools/gen_motorcade.py

De jour : prendre un VIP à la maison sûre et le conduire en Sabre jusqu'à
la zone d'extraction, par une piste tenue par deux pick-ups armés, un
barrage et une embuscade (points de passage, débarquement d'assaut)."""
from mapkit import MapBuilder, heading

m = MapBuilder("motorcade", "Motorcade", night=False, size=(100, 100), ground="desert")
TRACK = [(-40, 44), (-40, 26), (-24, 14), (-4, 14), (8, 0), (8, -18), (24, -30), (36, -36)]
m.track(TRACK)
m.sabre("Sabre", -40, 36, 0)
m.team([("Alpha", -36.5, 38), ("Bravo", -36.5, 35.5), ("Charlie", -36.5, 33)], explosives=("Charlie",))
# Maison sûre du VIP, à côté du départ.
m.building("SafeHouse", -28, 36, (8, 6), "Vector3(3, 0, 0)", "Vector2(0, 0), Vector2(2, 0)", height=3.0)
m.vip(-28, 36, display="Ambassadeur")
m.camera_at(-34, 30)
m.extraction_zone(36, -40, size=(10, 8), objective="vip_extracted")
# Barrage au milieu du tronçon (-24, 14) → (-4, 14).
m.barrier(-14, 14, heading((-24, 14), (-4, 14)))
m.mine(8, -9)
m.mine(16, -24, improvised=True)
# Village de l'embuscade, de part et d'autre du tronçon (8, 0) → (8, -18).
m.building("HouseW", -2, -8, (6, 6), "Vector3(1, 0, 0)", "Vector2(1, 1.5)", height=3.0)
m.building("HouseE", 18, -6, (6, 8), "Vector3(3, 0, 0)", "Vector2(3, 2)", height=3.0)
m.low_walls([(0, 4, 0), (16, 4, 0), (-4, -16, 90)])
m.crates([(-18, 20), (-16.7, 20), (4, 6), (12, -14), (13.3, -14), (28, -26), (-30, 0), (30, 10), (-10, -30)])
m.rocks([(-44, 0, 2.4), (-20, -20, 2.0), (26, 26, 2.2), (44, 0, 1.8), (-6, 36, 2.0), (40, -18, 1.6)])
m.bushes([(-34, 18), (-10, 24), (0, -24), (26, -16), (30, -46), (-22, 4)])
m.patrol("TechNorth", [(26, 4), (40, -16), (20, -12)])
m.patrol("TechWest", [(-30, -8), (-12, -26), (-36, -26)])
m.patrol("PatrolVillage", [(0, -2), (16, -2), (16, -14), (0, -14), (0, -2)])
m.patrol("PatrolLz", [(30, -46), (44, -46), (44, -32), (30, -46)])
m.enemy("BarrierLeft", -16, 11, 270, still=True)
m.enemy("BarrierRight", -12, 17, 250, still=True)
m.enemy("VillagePatrol", 0, -2, 90, path="PatrolVillage")
m.enemy("HouseWGuard", -2, -8, 90, still=True)
m.enemy("HouseERoof", 18, -6, 270, still=True, y=3.0)
m.enemy("AmbushRocket", 14, -16, 240, still=True)
m.enemy("LzPatrol", 30, -46, 90, path="PatrolLz")
m.enemy("LzGuard", 42, -38, 260, still=True)
m.technical("TechnicalNorth", 26, 4, 160, "TechNorth")
m.technical("TechnicalWest", -30, -8, 130, "TechWest")
m.write()
