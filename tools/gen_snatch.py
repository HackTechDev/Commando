"""Génère scenes/levels/snatch/snatch.tscn (Enlèvement). Usage : python3 tools/gen_snatch.py

De jour : enlever un officier dans sa villa (assommé, ou pris en otage),
le coucher sur le plateau du Sabre, et charger le véhicule dans la soute
de l'extraction. Les corps des gardes peuvent aussi y être cachés."""
from mapkit import MapBuilder

m = MapBuilder("snatch", "Snatch", night=False, size=(100, 100), ground="dirt")
TRACK = [(-38, 46), (-38, 20), (-16, 10), (6, 10), (18, -4), (22, -14)]
m.track(TRACK)
m.track([(-16, 10), (-14, -14), (-12, -34)])
m.sabre("Sabre", -38, 38, 0, stow_objective='&"sabre_extracted"')
m.team([("Alpha", -34.5, 40), ("Bravo", -34.5, 37.5), ("Charlie", -34.5, 35)])
m.camera_at(-32, 30)
# Villa de l'officier : enceinte, portail sud, deux bâtiments.
VX, VZ = 24, -26
wall = [(VX - 11, VZ + z, 90) for z in (-8, -2, 4)] + [(VX + 11, VZ + z, 90) for z in (-8, -2, 4)]
m.walls(wall + [(VX + x, VZ - 11, 0) for x in (-8, -2, 4, 8)] + [(VX - 7, VZ + 8, 0), (VX + 7, VZ + 8, 0)])
m.building("Villa", VX + 3, VZ - 4, (10, 7), "Vector3(0, -2, 0), Vector3(3, 0, 0)", "Vector2(0, 2), Vector2(1, 0), Vector2(2, 0)", height=3.2,
           roof=(0.55, 0.3, 0.22))
m.building("Garage", VX - 6, VZ - 5, (5, 6), "Vector3(1, 0, 0)", height=2.8)
m.crates([(VX - 7, VZ + 3), (VX + 8, VZ + 4), (-20, 22), (-4, 18), (6, -4), (-26, -20), (30, 20), (-12, -24)])
m.bushes([(-28, 14), (-6, 24), (10, 18), (12, -16), (36, -6), (-24, -36), (6, -40)])
m.rocks([(-44, 0, 2.2), (40, 36, 2.0), (44, -40, 2.4), (-6, 40, 1.8)])
# Extraction : se pose au sud-ouest de la villa, rampe vers la piste.
m.pad(-12, -40)
m.tiltrotor("Extraction", -12, -42, 0, livery="1", tail_number='"55"', objective_id='&"extracted"', extraction="true",
            documents_objective='&"documents"')
m.patrol("PatrolVilla", [(VX - 8, VZ + 5), (VX + 8, VZ + 5), (VX + 8, VZ - 8), (VX - 8, VZ - 8), (VX - 8, VZ + 5)])
m.patrol("PatrolRoad", [(-14, 4), (16, 4), (-14, 4)])
m.patrol("TechLoop", [(36, 10), (44, -10), (30, -4)])
m.enemy("Officer", VX + 3, VZ - 4.5, 180, still=True, documents="true")
m.enemy("VillaInside", VX + 6, VZ - 6, 220, still=True)
m.enemy("GateLeft", VX - 3, VZ + 10, 180, still=True)
m.enemy("GateRight", VX + 3, VZ + 10, 180, still=True)
m.enemy("VillaPatrol", VX - 8, VZ + 5, 90, path="PatrolVilla")
m.enemy("RoadPatrol", -14, 4, 90, path="PatrolRoad")
m.enemy("LzGuard", -6, -34, 200, still=True)
m.technical("Technical", 36, 10, 180, "TechLoop")
m.write()
