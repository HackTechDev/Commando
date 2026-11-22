"""Génère scenes/levels/reception/reception.tscn (Réception). Usage : python3 tools/gen_reception.py

De jour : une garden-party dans le parc d'une résidence gardée, au cœur
d'un quartier résidentiel. L'équipe, en costume-cravate (tenue imposée),
pistolet-mitrailleur sous la veste, part du coin sud-ouest du quartier,
gagne la résidence par les rues ou les ruelles, se mêle aux invités, prend
les documents de l'hôte dans son bureau, puis ressort par la grille nord
jusqu'à l'extraction."""
import math

from mapkit import MapBuilder

m = MapBuilder("reception", "Reception", night=False, size=(220, 220), ground="grass", dress_code="suit")

# --- Quartier -----------------------------------------------------------------
# Rues goudronnées bordées de trottoirs : avenue de la résidence (z = 40),
# avenue sud (z = 84), rue nord (z = -62), rues ouest et est (x = ±52).
L = 104
STREETS = [[(-L, 40), (L, 40)], [(-L, 84), (L, 84)], [(-L, -62), (L, -62)], [(-52, -L), (-52, L)], [(52, -L), (52, L)]]
for street in STREETS:
    m.track(street, width=12, kind="sidewalk")
for street in STREETS:
    m.track(street, width=7, kind="road")
# Allée jusqu'au perron, chemin de service vers la grille nord et la rue nord.
m.track([(0, 40), (0, -14)], width=3.5)
m.track([(18, -27), (18, -62)], width=3)

# Îlot sud, entre les deux avenues : deux rangées de maisons de ville, une
# placette au milieu (terrasse de café) ; îlots ouest et est.
FRONT, BACK = 53, 71
for i, x in enumerate([-96, -82, -68, -38, -25, -12, 12, 25, 38, 68, 82, 96]):
    m.building(f"TownFront{i + 1}", x, FRONT, (10, 8), "Vector3(2, 0, 0)", "Vector2(2, -3), Vector2(2, 3)", height=3.4,
               roof=(0.5, 0.3, 0.24) if i % 2 else (0.33, 0.3, 0.28))
    m.building(f"TownBack{i + 1}", x, BACK, (10, 8), "Vector3(0, 0, 0)", "Vector2(0, -3), Vector2(0, 3)", height=3.0,
               roof=(0.33, 0.3, 0.28) if i % 2 else (0.5, 0.3, 0.24))
# Maisons à jardin, de part et d'autre de la résidence (portes sur la rue).
for i, z in enumerate([-48, -28, -8, 14]):
    for side, (xs, door) in enumerate([((-68, -94), 1), ((68, 94), 3)]):
        for j, x in enumerate(xs):
            d = door if j == 0 else (3 if door == 1 else 1)
            m.building(f"House{side}{i}{j}", x, z, (9, 8), f"Vector3({d}, 0, 0)", "Vector2(0, 0), Vector2(2, 0)", height=3.0,
                       roof=(0.55, 0.3, 0.22) if (i + j) % 2 else (0.36, 0.33, 0.3))
# Îlot nord, au-delà de la rue nord.
for i, x in enumerate([-94, -74, -36, -16, 36, 74, 94]):
    m.building(f"North{i + 1}", x, -78, (12, 9), "Vector3(0, 0, 0)", "Vector2(0, -3), Vector2(0, 3)", height=3.6,
               roof=(0.3, 0.32, 0.36))
# Jardins et haies du quartier (cachettes), ruelles le long des murs de la
# résidence, poubelles (caisses) dans les ruelles.
m.bushes([(-81, -38, 4, 3), (-81, -18, 4, 3), (-81, 4, 4, 3), (-81, 24, 4, 3), (81, -38, 4, 3), (81, -18, 4, 3), (81, 4, 4, 3),
          (81, 24, 4, 3), (-38, 8, 3, 8), (-38, -22, 3, 8), (38, 10, 3, 8), (38, -20, 3, 8), (-104, 62), (104, 62),
          (0, 66, 4, 2.4), (-82, -96), (60, -96), (-4, -96)])
m.crates([(-34, 30), (-35, -30), (34, 31), (35, -32), (-46, 50), (46, 76)])
# Passants : terrasse de la placette, arrêt de bus, trottoirs.
PEOPLE = []
def group(cx, cz, n, r=0.85, turn=0.0):
    items = []
    for i in range(n):
        a = turn + 2 * math.pi * i / n
        x, z = cx + r * math.sin(a), cz - r * math.cos(a)
        facing = math.degrees(math.atan2(cx - x, -(cz - z))) % 360
        items.append((round(x, 2), round(z, 2), round(facing)))
    return items
for cx, cz, n, turn in [(-2, 58, 3, 0.4), (3, 63, 2, 1.0), (-3, 64, 2, 0.0), (-70, 46.5, 2, 1.5), (30, 46.5, 2, 0.2),
                        (-46, -10, 2, 1.0), (46, 20, 3, 0.7), (-20, 89.5, 3, 0.0), (70, 89.5, 2, 1.1), (-60, -67, 2, 0.5)]:
    PEOPLE += group(cx, cz, n, turn=turn)
m.guests(PEOPLE, dress="casual")

m.team([("Alpha", -96, 90), ("Bravo", -94, 90), ("Charlie", -92, 90)], nvg=False,
       primary={"Alpha": "smg", "Bravo": "smg", "Charlie": "smg"}, clothing="suit")
m.camera_at(-86, 80)

# Enceinte : x de -30 à 30, z de -36 à 26. Grille d'honneur au sud (x = 0),
# grille de service au nord (x = 18).
W, E, N, S = -30, 30, -36, 26
m.wall_line((W, S), (-3, S))
m.wall_line((3, S), (E, S))
m.wall_line((W, N), (W, S))
m.wall_line((E, N), (E, S))
m.wall_line((W, N), (15.5, N))
m.wall_line((20.5, N), (E, N))

# Résidence : porte d'honneur au sud, porte de service au nord ; le bureau
# de l'hôte est dans l'aile ouest.
m.building("Residence", 0, -24, (20, 12), "Vector3(0, 0, 0), Vector3(2, -6, 0)",
           "Vector2(0, -6), Vector2(0, 6), Vector2(1, 0), Vector2(3, 0), Vector2(2, 4)", height=3.6, roof=(0.3, 0.32, 0.36))
m.building("Pavilion", -20, -26, (6, 6), "Vector3(1, 0, 0)", "Vector2(0, 0)", height=2.8, roof=(0.55, 0.3, 0.22))

# Invités : groupes qui bavardent (regards tournés vers le centre du groupe).
def group(cx, cz, n, r=0.85, turn=0.0):
    items = []
    for i in range(n):
        a = turn + 2 * math.pi * i / n
        x, z = cx + r * math.sin(a), cz - r * math.cos(a)
        facing = math.degrees(math.atan2(cx - x, -(cz - z))) % 360
        items.append((round(x, 2), round(z, 2), round(facing)))
    return items

guests = []
for cx, cz, n, turn in [(-14, 14, 4, 0.3), (-6, 8, 3, 1.0), (8, 12, 4, 0.0), (15, 4, 3, 0.5), (-16, 2, 3, 2.0),
                        (5, 0, 4, 0.8), (-8, -4, 3, 0.2), (20, 16, 2, 1.2), (-22, 10, 2, 0.0), (10, -8, 3, 1.6)]:
    guests += group(cx, cz, n, turn=turn)
m.guests(guests)

# Haies taillées le long des murs, massifs dans le parc.
m.bushes([(-27, 18, 3, 6), (27, 18, 3, 6), (-27, -4, 3, 8), (27, -6, 3, 8), (-12, -12, 4, 2.4), (12, -14, 4, 2.4),
          (24, -30, 6, 3), (-8, 22, 6, 2.4), (8, 22, 6, 2.4)])
m.lamps([(-4, 30), (4, 30), (-4, 18), (4, 18), (-4, 4), (4, 4), (-4, -14), (4, -14)])

# Extraction : se pose au nord de l'enceinte, devant la grille de service.
m.pad(18, -43)
m.tiltrotor("Extraction", 18, -43, 90, livery="1", tail_number='"61"', objective_id='&"extracted"', extraction="true",
            documents_objective='&"documents"')

# Gardes en uniforme : grille d'honneur (écartés de l'allée), perron, rondes
# du parc et du tour de la résidence, bureau, grille de service ; dans le
# quartier, rondes sur l'avenue et dans les rues ouest et est, guetteur au
# nord, au-dessus de la pelouse d'atterrissage.
m.patrol("ParkWest", [(-24, 20), (-24, -2), (-10, -10), (-24, -2), (-24, 20)])
m.patrol("ParkEast", [(24, 20), (24, 0), (12, -2), (24, 0), (24, 20)])
m.patrol("AroundHouse", [(-13, -31), (13, -31), (13, -17), (-13, -17), (-13, -31)])
m.enemy("GateWest", -7, 29, 180, still=True)
m.enemy("GateEast", 7, 29, 180, still=True)
m.enemy("Steps", 6, -15.5, 210, still=True)
m.enemy("Host", -7, -25, 90, still=True, documents="true")
m.enemy("Office", -2, -21, 250, still=True)
m.enemy("ParkWestGuard", -24, 20, 180, path="ParkWest")
m.enemy("ParkEastGuard", 24, 20, 180, path="ParkEast")
m.enemy("HouseRound", -13, -31, 90, path="AroundHouse")
m.enemy("ServiceGate", 22, -39, 270, still=True)
m.patrol("Avenue", [(-46, 45), (46, 45), (-46, 45)])
m.patrol("WestStreet", [(-46, -56), (-46, 34), (-46, -56)])
m.patrol("EastStreet", [(46, 34), (46, -56), (46, 34)])
m.enemy("AvenuePatrol", -46, 45, 90, path="Avenue")
m.enemy("WestPatrol", -46, -56, 180, path="WestStreet")
m.enemy("EastPatrol", 46, 34, 0, path="EastStreet")
m.enemy("NorthLookout", 40, -57, 250, still=True)
m.write()
