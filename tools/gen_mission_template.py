"""Génère addons/mission_editor/template.tscn, le gabarit d'une nouvelle
mission (bouton « Nouvelle mission » du greffon) : terrain d'herbe de
80 × 80 m, de jour, trois opérateurs au sud, zone d'extraction au nord.
Usage : python3 tools/gen_mission_template.py"""
import os

from mapkit import ROOT, MapBuilder

m = MapBuilder("template", "Mission", night=False, size=(80, 80), ground="grass")
m.out = os.path.join(ROOT, "addons", "mission_editor", "template.tscn")
m.team([("Alpha", -2.5, 34), ("Bravo", 0, 34), ("Charlie", 2.5, 34)])
m.camera_at(0, 30)
m.extraction_zone(0, -34, size=(8, 8), objective="extracted")
m.write()
