#!/usr/bin/env python3
"""Prépare le paquet de cartes et de textures embarqué dans l'export Web.

Le jeu Web n'a pas accès au disque : les cartes UFO:AI et leurs textures,
d'habitude lues dans ../CommandoAsset, doivent voyager dans le paquet du jeu.
Ce script copie quelques cartes (trois par défaut) et les seules textures
qu'elles utilisent, plus celles des scènes du jeu (caisses, murs, sol), dans
le dossier `web_assets/` du projet :

    web_assets/maps/<carte>.map
    web_assets/textures/<dossier>/<texture>.<ext>

Chaque image reçoit un fichier `.import` « garder tel quel » (importer
`keep`) : Godot l'exporte sans la convertir, et le jeu la lit comme sur le
disque. Le filtre d'inclusion du préréglage d'export « Web » est complété
pour emporter `web_assets/*`. Sur le Web, `AssetPaths` lit alors
`res://web_assets/…` au lieu des dossiers externes.

Usage :
    tools/web_pack.py                          # training_a, training_b, fighter_crash
    tools/web_pack.py --maps dam harbour mine  # autres cartes
    tools/web_pack.py --export                 # puis lance ./export_web.sh
    tools/web_pack.py --clean                  # retire le paquet du projet

Les textures UFO:AI ont des licences mélangées (voir assets/TEXTURES.md) :
le paquet n'est pas versionné (.gitignore) ; à vérifier avant de publier.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
PACK_DIR = PROJECT / "web_assets"
DEFAULT_MAPS = ["training_a", "training_b", "fighter_crash"]
EXTENSIONS = ["png", "jpg", "jpeg", "tga", "webp"]
IMAGE_EXTENSIONS = set(EXTENSIONS)
INCLUDE_FILTER = "web_assets/*"
PRESETS = PROJECT / "export_presets.cfg"
GITIGNORE = PROJECT / ".gitignore"

# Face d'un brush : trois points, puis le nom de la texture.
FACE = re.compile(r"^\s*\(([^)]*)\)\s*\(([^)]*)\)\s*\(([^)]*)\)\s+(\S+)")
# Texture citée par une scène ou un script : "tex_<dossier>/<nom>[.ext]".
SOURCE_TEXTURE = re.compile(r"[\"'](tex_[A-Za-z0-9_]+/[A-Za-z0-9_.\-]+)[\"']")


def asset_dir(env: str, default: str) -> Path:
    """Dossier externe, comme `AssetPaths` : variable d'environnement, sinon
    chemin relatif au projet."""
    value = os.environ.get(env)
    path = Path(value) if value else PROJECT / default
    return path.resolve()


def map_textures(map_file: Path) -> set[str]:
    """Noms des textures (sans extension) portées par les faces d'une carte."""
    names: set[str] = set()
    with map_file.open(encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = FACE.match(line)
            if match:
                names.add(match.group(4))
    return names


def source_textures() -> set[str]:
    """Textures citées par les scènes et les scripts du projet."""
    names: set[str] = set()
    for folder in ("scenes", "scripts"):
        for path in (PROJECT / folder).rglob("*"):
            if path.suffix in (".tscn", ".gd", ".tres"):
                names.update(SOURCE_TEXTURE.findall(path.read_text(encoding="utf-8", errors="replace")))
    return names


def find_texture(textures_dir: Path, name: str) -> Path | None:
    """Fichier de la texture `name`, avec ou sans extension (même ordre que
    `TextureLibrary.find_file`)."""
    direct = textures_dir / name
    if direct.suffix.lstrip(".").lower() in IMAGE_EXTENSIONS and direct.is_file():
        return direct
    for extension in EXTENSIONS:
        candidate = textures_dir / f"{name}.{extension}"
        if candidate.is_file():
            return candidate
    return None


def write_keep_import(path: Path) -> None:
    """Demande à Godot d'exporter l'image telle quelle, sans l'importer."""
    path.with_name(path.name + ".import").write_text('[remap]\n\nimporter="keep"\n', encoding="utf-8")


def patch_presets() -> bool:
    """Ajoute `web_assets/*` au filtre d'inclusion du préréglage Web.
    Renvoie vrai si le fichier a changé."""
    if not PRESETS.is_file():
        print("export_presets.cfg introuvable : filtre d'inclusion à régler à la main.", file=sys.stderr)
        return False
    text = PRESETS.read_text(encoding="utf-8")
    sections = re.split(r"(?m)^(?=\[preset\.\d+\]$)", text)
    changed = False
    for i, section in enumerate(sections):
        if not re.search(r'(?m)^platform="Web"$', section):
            continue
        match = re.search(r'(?m)^include_filter="([^"]*)"$', section)
        if match is None:
            continue
        filters = [f.strip() for f in match.group(1).split(",") if f.strip()]
        if INCLUDE_FILTER in filters:
            continue
        filters.append(INCLUDE_FILTER)
        sections[i] = section[: match.start()] + f'include_filter="{", ".join(filters)}"' + section[match.end():]
        changed = True
    if changed:
        PRESETS.write_text("".join(sections), encoding="utf-8")
    return changed


def ensure_gitignore() -> None:
    lines = GITIGNORE.read_text(encoding="utf-8").splitlines() if GITIGNORE.is_file() else []
    if "/web_assets/" not in lines:
        lines.append("/web_assets/")
        GITIGNORE.write_text("\n".join(lines) + "\n", encoding="utf-8")


def human(size: int) -> str:
    for unit in ("o", "Ko", "Mo", "Go"):
        if size < 1024 or unit == "Go":
            return f"{size:.0f} {unit}" if unit == "o" else f"{size:.1f} {unit}"
        size /= 1024
    return str(size)


def build(maps: list[str], maps_dir: Path, textures_dir: Path) -> int:
    missing_maps = [name for name in maps if not (maps_dir / f"{name}.map").is_file()]
    if missing_maps:
        print(f"Cartes introuvables dans {maps_dir} : {', '.join(missing_maps)}", file=sys.stderr)
        return 1
    if not textures_dir.is_dir():
        print(f"Dossier de textures introuvable : {textures_dir}", file=sys.stderr)
        return 1
    if PACK_DIR.exists():
        shutil.rmtree(PACK_DIR)
    (PACK_DIR / "maps").mkdir(parents=True)
    wanted: set[str] = source_textures()
    for name in maps:
        source = maps_dir / f"{name}.map"
        shutil.copy2(source, PACK_DIR / "maps" / source.name)
        textures = map_textures(source)
        wanted.update(textures)
        print(f"Carte {name} : {len(textures)} textures")
    copied = 0
    total = 0
    absent: list[str] = []
    for name in sorted(wanted):
        found = find_texture(textures_dir, name)
        if found is None:
            absent.append(name)
            continue
        target = PACK_DIR / "textures" / found.relative_to(textures_dir)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(found, target)
        write_keep_import(target)
        copied += 1
        total += target.stat().st_size
    for path in (PACK_DIR / "maps").iterdir():
        total += path.stat().st_size
    # Godot n'a pas à parcourir le dossier comme des ressources de jeu dans
    # l'éditeur : les images y sont gardées telles quelles (`keep`).
    print(f"Textures copiées : {copied} ({human(total)} avec les cartes) dans {PACK_DIR.relative_to(PROJECT)}/")
    if absent:
        # Textures d'outil (clip, hint, trigger…) ou absentes du dossier : le
        # jeu ne les affiche pas ou garde la couleur de base.
        print(f"Sans fichier : {len(absent)} ({', '.join(absent[:8])}{'…' if len(absent) > 8 else ''})")
    if patch_presets():
        print(f"Préréglage Web : filtre d'inclusion complété ({INCLUDE_FILTER}).")
    ensure_gitignore()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Paquet de cartes et de textures pour l'export Web.")
    parser.add_argument("--maps", nargs="+", default=DEFAULT_MAPS, metavar="CARTE",
                        help="cartes à emporter, sans extension (par défaut : %(default)s)")
    parser.add_argument("--maps-dir", type=Path, help="dossier des cartes (défaut : COMMANDO_MAPS ou ../CommandoAsset/maps)")
    parser.add_argument("--textures-dir", type=Path, help="dossier des textures (défaut : COMMANDO_TEXTURES ou ../CommandoAsset/textures)")
    parser.add_argument("--export", action="store_true", help="lance ./export_web.sh une fois le paquet prêt")
    parser.add_argument("--clean", action="store_true", help="retire le paquet du projet et s'arrête")
    args = parser.parse_args()
    if args.clean:
        if PACK_DIR.exists():
            shutil.rmtree(PACK_DIR)
            print(f"{PACK_DIR.relative_to(PROJECT)}/ retiré.")
        return 0
    maps_dir = (args.maps_dir or asset_dir("COMMANDO_MAPS", "../CommandoAsset/maps")).resolve()
    textures_dir = (args.textures_dir or asset_dir("COMMANDO_TEXTURES", "../CommandoAsset/textures")).resolve()
    maps = [name.removesuffix(".map") for name in args.maps]
    code = build(maps, maps_dir, textures_dir)
    if code == 0 and args.export:
        return subprocess.call([str(PROJECT / "export_web.sh")])
    return code


if __name__ == "__main__":
    sys.exit(main())
