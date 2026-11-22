"""Génère scenes/levels/reception/reception.tscn (Réception). Usage : python3 tools/gen_reception.py

De jour : une garden-party dans le parc d'une résidence gardée. L'équipe,
en costume-cravate (tenue imposée), pistolet-mitrailleur sous la veste, se
mêle aux invités, entre dans la résidence et prend les documents de l'hôte
dans son bureau, puis ressort par la grille nord jusqu'à l'extraction."""
import math

from mapkit import MapBuilder

m = MapBuilder("reception", "Reception", night=False, size=(100, 100), ground="grass", dress_code="suit")

# Rue au sud, allée jusqu'au perron, chemin de service vers la grille nord.
m.track([(-48, 40), (48, 40)], width=6)
m.track([(0, 40), (0, -14)], width=3.5)
m.track([(18, -27), (18, -46)], width=3)
m.team([("Alpha", -36, 42), ("Bravo", -34, 42), ("Charlie", -32, 42)], nvg=False,
       primary={"Alpha": "smg", "Bravo": "smg", "Charlie": "smg"}, clothing="suit")
m.camera_at(-20, 30)

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
# Extérieur : rochers et buissons le long de la rue et au nord.
m.bushes([(-44, 30), (-40, 20), (40, 30), (44, 12), (-42, -10), (40, -20), (-20, -44), (34, -44)])

# Extraction : se pose au nord de l'enceinte, devant la grille de service.
m.pad(18, -43)
m.tiltrotor("Extraction", 18, -43, 90, livery="1", tail_number='"61"', objective_id='&"extracted"', extraction="true",
            documents_objective='&"documents"')

# Gardes en uniforme : grille d'honneur (écartés de l'allée), perron, rondes
# du parc et du tour de la résidence, bureau, grille de service.
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
m.write()
