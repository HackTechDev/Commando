#!/bin/sh
## Ouvre des scènes dans l'éditeur Godot et les photographie, dans une copie
## du projet (le projet lui-même n'est jamais modifié) où le greffon de
## capture (`capture.gd`) est activé.
##
## Usage : tools/editor_check/run.sh res://a.tscn,res://b.tscn [taille] [focus "x z"]
## Variables : CAPTURE_SAVE=1 enregistre chaque scène après l'avoir ouverte
## (voir check_all.sh pour la comparaison) ; CAPTURE_TEST=<nom> lance le
## scénario <nom>.gd sur chaque scène ; LINES_MAX : lignes de journal gardées.
## Images : build/shots/out/editor_<scène>.png.
set -e
SRC=$(cd "$(dirname "$0")/../.." && pwd)
DST=${CAPTURE_COPY:-/tmp/claude-1000/commando_editor_copy}
G=$HOME/JEUX/GODOT/Godot_v4.7.2-stable_linux.x86_64
mkdir -p "$DST"
# Textures et cartes UFO:AI, cherchées à côté du projet.
ln -sfn "$(cd "$SRC/.." && pwd)/CommandoAsset" "$(dirname "$DST")/CommandoAsset"
rsync -a --delete --exclude .git --exclude build --exclude /orig --exclude /saved "$SRC/" "$DST/"
mkdir -p "$DST/addons/capture"
cp "$SRC/tools/editor_check/plugin.cfg" "$SRC/tools/editor_check/"*.gd "$DST/addons/capture/"
sed -i 's|^enabled=PackedStringArray(\(.*\))|enabled=PackedStringArray(\1, "res://addons/capture/plugin.cfg")|' "$DST/project.godot"
mkdir -p "$SRC/build/shots/out"
CAPTURE_TEST="${CAPTURE_TEST:-}" CAPTURE_SAVE="${CAPTURE_SAVE:-}" CAPTURE_SCENES="$1" CAPTURE_SIZE="${2:-}" CAPTURE_FOCUS="${3:-}" \
	OUT="$SRC/build/shots/out" timeout 900 "$G" --editor --path "$DST" --resolution 1400x1000 2>&1 \
	| grep -E "CAPTURE|TEST|SCRIPT ERROR|ERROR: Failed|Parse Error|^ *at: (res|GDScript)" | head -"${LINES_MAX:-60}"
