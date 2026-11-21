"""Génère scenes/levels/kasbah/kasbah.tscn (Kasbah). Usage : python3 tools/gen_kasbah.py

De jour, en ville : insertion en vol stationnaire, déplacement de
l'appareil et rappel sur les toits, documents d'un officier au 2e étage
d'un immeuble, extraction au treuil depuis sa terrasse, en temps limité."""
from mapkit import MapBuilder, add_tower

m = MapBuilder("kasbah", "Kasbah", night=False, size=(90, 90), ground="urban")
TX, TZ = 12, -12
roof = add_tower(m, "Office", TX, TZ, storeys=3, size=(14, 10), doors="Vector3(0, 2, 0), Vector3(3, 2, 1)",
                 windows="Vector2(0, -4), Vector2(0, 5), Vector2(1, -2), Vector2(1, 2), Vector2(2, -4), Vector2(3, -2)")
# Maisons à toit plat : on peut s'y déposer en rappel.
houses = [
    ("HouseA", -14, -14, (8, 6), "Vector3(0, 0, 0)", "Vector2(1, 0), Vector2(3, 0)"),
    ("HouseB", -14, 4, (10, 6), "Vector3(1, 0, 0)", "Vector2(0, -2), Vector2(2, 2)"),
    ("HouseC", 6, 10, (8, 6), "Vector3(3, 0, 0)", "Vector2(0, 0)"),
    ("HouseD", 26, 6, (8, 8), "Vector3(0, 0, 0)", "Vector2(3, 0), Vector2(2, 0)"),
    ("HouseE", 30, -20, (6, 8), "Vector3(3, 0, 0)", "Vector2(0, 0)"),
    ("HouseF", -26, -28, (8, 6), "Vector3(1, 0, 0)", "Vector2(0, 0)"),
    ("HouseG", -2, -32, (10, 6), "Vector3(0, -2, 0)", "Vector2(0, 2), Vector2(1, 0)"),
]
for name, x, z, size, doors, windows in houses:
    m.building(name, x, z, size, doors, windows, height=3.2, roof=(0.42, 0.36, 0.3))
# Insertion : l'équipe commence à bord, à 30 m au-dessus de la place sud-
# ouest, hors de portée d'oreille ; on déplace l'appareil et on descend en
# rappel où l'on veut (rue, toit), puis on le renvoie.
m.pad(-32, 32)
m.tiltrotor("Insertion", -32, 32, 45, livery="1", tail_number='"17"', objective_id='&""', ends_mission="false", insertion="true")
m.team([("Alpha", -30, 30), ("Bravo", -31, 31), ("Charlie", -32, 30)])
m.camera_at(-24, 24)
# Extraction : appelée par radio, elle attend 75 s au-dessus de la terrasse
# de l'immeuble (point de pose à la hauteur du toit), rampe au-dessus.
m.tiltrotor("Extraction", TX, TZ + 10.8, 180, y=roof, livery="1", tail_number='"18"', objective_id='&"extracted"',
            extraction="true", pickup_window="75.0", documents_objective='&"documents"')
m.crates([(-6, -2), (-4.7, -2), (18, 16), (-20, -6), (2, -20), (34, -6), (TX + 4, TZ + 4, 3.2), (TX - 1, TZ + 4, 6.4), (-28, 14)])
m.low_walls([(-8, 22, 0), (0, 22, 0), (20, 22, 0), (-36, -8, 90)])
m.bushes([(-34, 20), (36, 24), (-36, -16), (20, -34)])
# Rondes de rue et gardes de l'immeuble.
m.patrol("PatrolMain", [(-20, -4), (18, -2), (18, 18), (-20, 14), (-20, -4)])
m.patrol("PatrolSouth", [(-8, 26), (30, 26), (-8, 26)])
m.patrol("PatrolBack", [(-12, -24), (22, -26), (36, -30), (-12, -24)])
m.patrol("PatrolFloor1", [(TX + 5, 3.2, TZ + 2), (TX - 4, 3.2, TZ + 2)])
m.enemy("MainPatrol", -20, -4, 90, path="PatrolMain")
m.enemy("SouthPatrol", -8, 26, 90, path="PatrolSouth")
m.enemy("BackPatrol", -12, -24, 90, path="PatrolBack")
m.enemy("DoorGuard", TX + 2, TZ + 6.6, 180, still=True)
m.enemy("SideGuard", TX - 8.6, TZ + 2, 270, still=True)
m.enemy("LobbyGuard", TX + 4, TZ, 200, still=True)
m.enemy("Floor1Patrol", TX + 5, TZ + 2, 270, path="PatrolFloor1", y=3.2)
m.enemy("Officer", TX + 4, TZ + 2, 200, still=True, y=6.4, documents="true")
m.enemy("Floor2Guard", TX - 3, TZ + 3, 120, still=True, y=6.4)
m.enemy("RoofLookout", TX + 5, TZ - 2, 180, still=True, y=roof)
m.enemy("RoofHouseD", 26, 6, 270, still=True, y=3.2)
m.write()
