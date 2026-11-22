#!/bin/sh
## Ouvre des missions dans l'éditeur (copie du projet, voir run.sh), les
## capture, les enregistre, puis compare chaque scène enregistrée à celle du
## projet, nœud par nœud et propriété par propriété (`compare.gd`) :
## l'affichage dans l'éditeur ne doit rien changer aux scènes.
## Usage : tools/editor_check/check_all.sh [res://a.tscn,res://b.tscn]  (toutes par défaut)
set -e
SRC=$(cd "$(dirname "$0")/../.." && pwd)
DST=${CAPTURE_COPY:-/tmp/claude-1000/commando_editor_copy}
G=$HOME/JEUX/GODOT/Godot_v4.7.2-stable_linux.x86_64
SCENES=${1:-$(cd "$SRC" && ls scenes/levels/*/*.tscn | grep -v ufo_map | sed 's|^|res://|' | tr '\n' ',' | sed 's/,$//')}
CAPTURE_SAVE=1 LINES_MAX=${LINES_MAX:-2000} "$SRC/tools/editor_check/run.sh" "$SCENES" | grep -E "CAPTURE res|terminé|SCRIPT ERROR" | sort | uniq -c | sort -rn | head -40
rm -rf "$DST/orig" "$DST/saved"
mkdir -p "$DST/orig" "$DST/saved"
NAMES=""
for f in $(echo "$SCENES" | tr ',' ' '); do
	rel=${f#res://}
	n=$(basename "$rel")
	cp "$SRC/$rel" "$DST/orig/$n"
	cp "$DST/$rel" "$DST/saved/$n"
	NAMES="$NAMES $n"
done
cp "$SRC/tools/editor_check/compare.gd" "$DST/compare.gd"
# shellcheck disable=SC2086
timeout 300 "$G" --headless --path "$DST" -s res://compare.gd -- res://orig res://saved $NAMES 2>&1 | grep -E "^COMPARE|^   [^ ]" | grep -v "^   at:\|backtrace\|^   *\["
